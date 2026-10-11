package com.knoxbridge.runtime;

import com.knoxbridge.api.PatchRegistrar;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPairGenerator;
import java.util.ArrayList;
import java.util.List;

public final class AuthorFeaturesVerifier {
    private static int checks;
    public static int enters, returns;
    public static void enter() { enters++; }
    public static void returned() { returns++; }

    static int verify(Path temp, ModuleDescriptor d, Path root) throws Exception {
        var keys = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
        var context = DetachedSignature.moduleContext(d, root);
        check(DetachedSignature.verify(d.jar(), context) == null, "legacy unsigned module");
        DetachedSignature.sign(d.jar(), context, keys.getPrivate(), keys.getPublic());
        String fingerprint = DetachedSignature.fingerprint(keys.getPublic());
        check(DetachedSignature.verify(d.jar(), context).equals(fingerprint), "module signature verifies");
        var candidate = new ModuleDiscovery.Candidate(root, d, null, d.jar());
        check(ModuleReviewFiles.entry(candidate, Hashing.sha256(d.jar()), "BLOCKED BY DEFAULT", fingerprint)
            .signer().equals(fingerprint), "review includes full signer fingerprint");
        var trust = new TrustStore(temp.resolve("signature-trust.properties"));
        check(trust.check(Hashing.sha256(d.jar())) == TrustStore.Decision.APPROVAL_REQUIRED,
            "valid signature never grants approval");
        var changed = new ArrayList<>(context);
        for (int i = 0; i < changed.size(); i++) {
            changed.set(i, context.get(i) + "changed");
            var altered = List.copyOf(changed);
            rejects(() -> DetachedSignature.verify(d.jar(), altered), "signed metadata alteration " + i);
            changed.set(i, context.get(i));
        }
        Path sidecar = DetachedSignature.sidecar(d.jar());
        String valid = Files.readString(sidecar);
        Files.writeString(sidecar, valid.replace("v1", "v2"));
        rejects(() -> DetachedSignature.verify(d.jar(), context), "unsupported signature version");
        Files.writeString(sidecar, valid + "extra\n");
        rejects(() -> DetachedSignature.verify(d.jar(), context), "extra signature fields");
        var other = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
        String[] lines = valid.split("\n");
        Files.writeString(sidecar, lines[0] + "\n" + java.util.Base64.getEncoder().encodeToString(other.getPublic().getEncoded())
            + "\n" + lines[2] + "\n");
        rejects(() -> DetachedSignature.verify(d.jar(), context), "wrong signing key");
        Files.writeString(sidecar, lines[0] + "\n" + lines[1] + "\nnot-base64\n");
        rejects(() -> DetachedSignature.verify(d.jar(), context), "malformed signature");
        Files.writeString(sidecar, valid);
        String approvedHash = Hashing.sha256(d.jar());
        byte[] original = Files.readAllBytes(d.jar());
        try {
            Files.write(d.jar(), new byte[] { 1, 2, 3 });
            rejects(() -> DetachedSignature.verify(d.jar(), context), "changed artifact");
            rejects(() -> ModuleLoader.load(d, d.jar(), "test", new PatchEngine(s -> {}), null, s -> {}, approvedHash),
                "changed approved file cannot initialize");
        } finally { Files.write(d.jar(), original); }
        Path privateKey = temp.resolve("test.pk8"), publicKey = temp.resolve("test.der");
        Files.write(privateKey, keys.getPrivate().getEncoded());
        Files.write(publicKey, keys.getPublic().getEncoded());
        SigningTool.main(new String[] { "verify-module", root.toString(), fingerprint });
        rejects(() -> SigningTool.main(new String[] { "verify-module", root.toString(), "0".repeat(64) }),
            "verification requires independently supplied fingerprint");
        Path artifact = temp.resolve("release.zip");
        Files.writeString(artifact, "fixture release artifact");
        SigningTool.main(new String[] { "sign-file", artifact.toString(), privateKey.toString(), publicKey.toString() });
        SigningTool.main(new String[] { "verify-file", artifact.toString(), fingerprint });
        Files.delete(privateKey);
        Files.delete(publicKey);
        rejects(() -> DetachedSignature.verify(artifact, context), "file/module domain separation");
        Files.delete(sidecar);
        check(DetachedSignature.verify(d.jar(), context) == null, "unsigned policy remains explicit after sidecar removal");
        Path unsignedArtifact = temp.resolve("unsigned.zip");
        Files.writeString(unsignedArtifact, "unsigned fixture");
        rejects(() -> SigningTool.main(new String[] { "verify-file", unsignedArtifact.toString(), fingerprint }),
            "expected-fingerprint verification rejects unsigned downloads");
        Files.writeString(artifact, "changed release artifact");
        rejects(() -> SigningTool.main(new String[] { "verify-file", artifact.toString(), fingerprint }),
            "CLI rejects altered release downloads");

        byte[] originalClass;
        try (var in = Fixture.class.getResourceAsStream("AuthorFeaturesVerifier$Fixture.class")) { originalClass = in.readAllBytes(); }
        PatchRegistrar.Callback entry = new PatchRegistrar.Callback(AuthorFeaturesVerifier.class.getName(), "enter");
        PatchRegistrar.Callback exit = new PatchRegistrar.Callback(AuthorFeaturesVerifier.class.getName(), "returned");
        PatchEngine engine = new PatchEngine(s -> {});
        try (var registration = engine.beginModule("hooks")) {
            for (String method : List.of("integer", "wide", "floating", "number", "reference", "nothing", "branch", "throwsOut"))
                registration.registerHook(new PatchRegistrar.Hook("hook." + method,
                    new PatchRegistrar.Target(Fixture.class.getName(), method, null), false, entry, exit));
            registration.commit();
        }
        byte[] transformed = engine.transform(Fixture.class.getClassLoader(), Fixture.class.getName().replace('.', '/'),
            null, null, originalClass);
        check(transformed != null, "visible callbacks accepted");
        ClassLoader hidingLoader = new ClassLoader(AuthorFeaturesVerifier.class.getClassLoader()) {
            @Override protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
                if (name.equals(AuthorFeaturesVerifier.class.getName())) throw new ClassNotFoundException("isolated helper");
                return super.loadClass(name, resolve);
            }
        };
        check(engine.transform(hidingLoader, Fixture.class.getName().replace('.', '/'), null, null, originalClass) == null,
            "invisible helpers leave original target unchanged");
        PatchEngine badCallback = new PatchEngine(s -> {});
        try (var registration = badCallback.beginModule("bad-helper")) {
            registration.registerHook(new PatchRegistrar.Hook("bad-shape",
                new PatchRegistrar.Target(Fixture.class.getName(), "integer", "()I"), false,
                new PatchRegistrar.Callback(AuthorFeaturesVerifier.class.getName(), "notVoid"), null));
            registration.commit();
        }
        check(badCallback.transform(Fixture.class.getClassLoader(), Fixture.class.getName().replace('.', '/'),
            null, null, originalClass) == null, "invalid callback shape leaves target unchanged");
        Class<?> fixture = new ClassLoader(AuthorFeaturesVerifier.class.getClassLoader()) {
            Class<?> define() { return defineClass(Fixture.class.getName(), transformed, 0, transformed.length); }
        }.define();
        Object object = fixture.getConstructor().newInstance();
        enters = returns = 0;
        check(fixture.getMethod("integer").invoke(object).equals(42), "int result preserved");
        check(fixture.getMethod("wide").invoke(object).equals(123456789012L), "long result preserved");
        check(fixture.getMethod("floating").invoke(object).equals(1.25f), "float result preserved");
        check(fixture.getMethod("number").invoke(object).equals(3.5d), "double result preserved");
        check(fixture.getMethod("reference").invoke(object).equals("unchanged"), "reference result preserved");
        check(fixture.getMethod("nothing").invoke(object) == null, "void return preserved");
        check(fixture.getMethod("branch", boolean.class).invoke(object, true).equals(1)
            && fixture.getMethod("branch", boolean.class).invoke(object, false).equals(2), "all return branches execute");
        try { fixture.getMethod("throwsOut").invoke(object); throw new AssertionError("exception lost"); }
        catch (java.lang.reflect.InvocationTargetException e) {
            check(e.getCause() instanceof IllegalStateException, "original exception preserved");
        }
        check(enters == 9 && returns == 8, "entry/normal return counts; exceptional exit excluded");
        rejects(() -> MethodHooks.transform(new PatchRegistrar.Hook("constructor",
            new PatchRegistrar.Target(Fixture.class.getName(), "<init>", "()V"), false, entry, exit), originalClass),
            "constructor hook explicitly rejected");
        return checks;
    }

    private static void check(boolean ok, String name) {
        checks++;
        if (!ok) throw new AssertionError(name);
    }
    public static int notVoid() { return 1; }
    private interface Action { void run() throws Exception; }
    private static void rejects(Action action, String name) throws Exception {
        try { action.run(); } catch (Exception expected) { check(true, name); return; }
        throw new AssertionError("Expected rejection: " + name);
    }
    public static class Fixture {
        public int integer() { return 42; }
        public long wide() { return 123456789012L; }
        public float floating() { return 1.25f; }
        public double number() { return 3.5d; }
        public String reference() { return "unchanged"; }
        public void nothing() { }
        public int branch(boolean first) { if (first) return 1; return 2; }
        public void throwsOut() { throw new IllegalStateException("original"); }
    }
}
