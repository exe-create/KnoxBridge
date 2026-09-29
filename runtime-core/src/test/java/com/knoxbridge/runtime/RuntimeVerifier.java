package com.knoxbridge.runtime;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public final class RuntimeVerifier {
    private static int checks;
    public static void main(String[] args) throws Exception {
        Path temp = Files.createTempDirectory("knoxbridge-verify-");
        Path mod = Files.createDirectories(temp.resolve("enabled-mod"));
        Path moduleJar = Path.of(System.getProperty("knoxbridge.testModuleJar"));
        Files.copy(moduleJar, mod.resolve("knoxbridge-example-module.jar"));
        Files.writeString(mod.resolve("mod.info"), "name=Example Java Mod\nauthor=Example Author\n");
        Files.writeString(mod.resolve("knoxbridge.properties"), "id=org.example.knoxbridge.greeting\nversion=1.0.0\napiVersion=1\nentrypoint=org.example.knoxbridge.ExampleModule\njar=knoxbridge-example-module.jar\n");
        Path helperJar = Files.createDirectories(mod.resolve("lib")).resolve("helper.jar");
        Files.copy(moduleJar, helperJar);
        Path disabled = Files.createDirectories(temp.resolve("disabled-mod"));
        Files.copy(mod.resolve("knoxbridge.properties"), disabled.resolve("knoxbridge.properties"));
        Path duplicate = Files.createDirectories(temp.resolve("duplicate-mod"));
        Files.copy(mod.resolve("knoxbridge.properties"), duplicate.resolve("knoxbridge.properties"));
        Files.copy(mod.resolve("knoxbridge-example-module.jar"), duplicate.resolve("knoxbridge-example-module.jar"));

        List<ModuleDiscovery.Candidate> candidates = ModuleDiscovery.inspectEnabledRoots(List.of(mod), s -> { });
        ModuleDiscovery.Candidate moduleCandidate = candidates.stream().filter(c -> c.descriptor() != null).findFirst().orElseThrow();
        String hash = Hashing.sha256(moduleCandidate.descriptor().jar());
        check(candidates.size() == 2 && moduleCandidate.problem() == null, "enabled module and companion JAR discovery");
        check(candidates.stream().anyMatch(c -> helperJar.equals(c.jar()) && c.descriptor() == null
                && c.problem().contains("not the entry point")), "non-entrypoint JAR is shown but not loadable");
        check(ModuleDiscovery.inspectEnabledRoots(List.of(disabled), s -> { }).isEmpty(),
            "mod without a JAR has no review entry");
        Path plainMod = Files.createDirectories(temp.resolve("enabled-plain-mod"));
        Path plainJar = plainMod.resolve("legacy-java-mod.jar");
        Files.copy(moduleJar, plainJar);
        List<ModuleDiscovery.Candidate> plainCandidates = ModuleDiscovery.inspectEnabledRoots(List.of(plainMod), s -> { });
        check(plainCandidates.size() == 1 && plainCandidates.get(0).descriptor() == null
                && plainCandidates.get(0).jar().equals(plainJar.toAbsolutePath())
                && plainCandidates.get(0).problem().contains("author must add"),
            "all enabled mod JARs are visible but unsupported Java is never loaded generically");
        check(ModuleReviewFiles.entry(moduleCandidate, hash, "BLOCKED BY DEFAULT").author().equals("Example Author"),
            "review list displays author claim from mod.info");
        Path manifest = temp.resolve("Lua/KnoxBridge/module-review.txt");
        ModuleReviewFiles.writeManifest(manifest, List.of(
            new ModuleReviewFiles.Entry("org.example.knoxbridge.greeting", "1.0", hash,
                "Example\tJava Mod", "Example Author", "BLOCKED BY DEFAULT", "example.jar")));
        List<String> manifestLines = Files.readAllLines(manifest);
        check(manifestLines.get(0).equals(ModuleReviewFiles.MANIFEST_HEADER)
                && manifestLines.get(1).split("\\t", -1).length == 7
                && !manifestLines.get(1).contains("Example\tJava"),
            "review manifest is versioned and metadata cannot inject fields");
        Path trustQueueStorePath = temp.resolve("review-queue-trust.properties");
        TrustStore reviewTrust = new TrustStore(trustQueueStorePath);
        check(reviewTrust.check(hash) == TrustStore.Decision.APPROVAL_REQUIRED, "unknown module defaults blocked");
        Path queue = temp.resolve("Lua/KnoxBridge/module-decisions.txt");
        Files.createDirectories(queue.getParent());
        Files.writeString(queue, ModuleReviewFiles.DECISIONS_HEADER + "\n" + hash + "\tallow\tremember\n"
                + ModuleReviewFiles.DECISIONS_COMMIT + "\n");
        ModuleReviewFiles.applyQueuedDecisions(reviewTrust, queue, s -> { });
        check(reviewTrust.check(hash) == TrustStore.Decision.ALLOW_EXACT && !Files.exists(queue),
            "in-game approval persists exact-hash allow for the next startup");
        String legacyQueueHash = "5".repeat(64);
        Files.writeString(queue, "KNOXBRIDGE-DECISIONS-1\n" + legacyQueueHash + "\tdeny\n"
                + ModuleReviewFiles.DECISIONS_COMMIT + "\n");
        ModuleReviewFiles.applyQueuedDecisions(reviewTrust, queue, s -> { });
        check(reviewTrust.check(legacyQueueHash) == TrustStore.Decision.DENY_EXACT,
            "legacy version-1 review queue remains readable as a remembered decision");
        String oneTimeHash = "3".repeat(64);
        Files.writeString(queue, ModuleReviewFiles.DECISIONS_HEADER + "\n" + oneTimeHash + "\tallow\tonce\n"
                + ModuleReviewFiles.DECISIONS_COMMIT + "\n");
        ModuleReviewFiles.applyQueuedDecisions(reviewTrust, queue, s -> { });
        check(reviewTrust.check(oneTimeHash) == TrustStore.Decision.ALLOW_ONCE
                && reviewTrust.check(oneTimeHash) == TrustStore.Decision.APPROVAL_REQUIRED,
            "unchecked remember option grants an exact-hash approval for one launch only");
        String rememberedDenyHash = "4".repeat(64);
        Files.writeString(queue, ModuleReviewFiles.DECISIONS_HEADER + "\n" + rememberedDenyHash + "\tdeny\tremember\n"
                + ModuleReviewFiles.DECISIONS_COMMIT + "\n");
        ModuleReviewFiles.applyQueuedDecisions(reviewTrust, queue, s -> { });
        check(reviewTrust.check(rememberedDenyHash) == TrustStore.Decision.DENY_EXACT,
            "checked remember option persists exact-hash deny");
        String changedReviewHash = "1".repeat(64);
        check(reviewTrust.check(changedReviewHash) == TrustStore.Decision.APPROVAL_REQUIRED,
            "changed JAR remains blocked after another exact hash is allowed");
        Files.writeString(queue, ModuleReviewFiles.DECISIONS_HEADER + "\ninvalid\tallow\tremember\n"
                + ModuleReviewFiles.DECISIONS_COMMIT + "\n");
        ModuleReviewFiles.applyQueuedDecisions(reviewTrust, queue, s -> { });
        check(reviewTrust.check("2".repeat(64)) == TrustStore.Decision.APPROVAL_REQUIRED,
            "malformed in-game decision queue fails closed");
        check(ModuleDiscovery.inspectEnabledRoots(List.of(mod, duplicate), s -> { }).stream()
                .filter(c -> c.descriptor() != null).allMatch(c -> c.problem() != null),
            "duplicate module IDs both rejected");
        check(Hashing.sha256(candidates.get(0).descriptor().jar()).length() == 64, "SHA-256 identity");

        TrustStore trust = new TrustStore(temp.resolve("trust.properties"));
        check(trust.check(hash) == TrustStore.Decision.APPROVAL_REQUIRED, "unknown jar requires approval");
        trust.decide(hash, TrustStore.Decision.ALLOW_ONCE);
        check(trust.check(hash) == TrustStore.Decision.ALLOW_ONCE, "allow once");
        check(trust.check(hash) == TrustStore.Decision.APPROVAL_REQUIRED, "allow once expires after one check");
        trust.decide(hash, TrustStore.Decision.DENY_ONCE);
        check(trust.check(hash) == TrustStore.Decision.DENY_ONCE, "deny once");
        trust.decide(hash, TrustStore.Decision.ALLOW_EXACT);
        check(trust.check(hash) == TrustStore.Decision.ALLOW_EXACT, "persistent exact hash approval");
        String changedHash = "0".repeat(64);
        check(trust.check(changedHash) == TrustStore.Decision.APPROVAL_REQUIRED, "changed hash requires approval");
        trust.decide(changedHash, TrustStore.Decision.DENY_EXACT);
        check(trust.check(changedHash) == TrustStore.Decision.DENY_EXACT, "persistent exact hash denial");
        trust.observe(hash, "org.example.knoxbridge.greeting", mod);
        check(new String(Files.readAllBytes(temp.resolve("trust.properties"))).contains(hash + ".moduleId=org.example.knoxbridge.greeting"),
            "trust metadata records module identity");
        trust.decideNextLaunch(changedHash, TrustStore.Decision.ALLOW_ONCE);
        TrustStore nextRun = new TrustStore(temp.resolve("trust.properties"));
        check(nextRun.check(changedHash) == TrustStore.Decision.ALLOW_ONCE, "queued allow-once decision");
        check(nextRun.check(changedHash) == TrustStore.Decision.APPROVAL_REQUIRED, "queued one-time approval consumed");

        List<String> moduleLog = new ArrayList<>();
        PatchEngine modulePatches = new PatchEngine(moduleLog::add);
        try (ModuleLoader.LoadedModule loaded = ModuleLoader.load(candidates.get(0).descriptor(),
                candidates.get(0).descriptor().jar(), "test-runtime", modulePatches, null, moduleLog::add)) {
            check(moduleLog.stream().anyMatch(s -> s.contains("independent example module ready")), "independent module entrypoint");
            check(moduleLog.stream().anyMatch(s -> s.contains("patch registered module=org.example.knoxbridge.greeting")), "module patch API registration");
        }

        List<String> patchLog = new ArrayList<>();
        PatchEngine patches = new PatchEngine(patchLog::add);
        Path logTarget = temp.resolve("fixture.class");
        patches.module("verifier");
        patches.register(new com.knoxbridge.api.PatchRegistrar.Patch("probe",
            new com.knoxbridge.api.PatchRegistrar.Target("fixture.Target", "run", "()V"), false,
            (name, bytes) -> { Files.writeString(logTarget, name); return bytes.clone(); }));
        byte[] classFile = Files.readAllBytes(Path.of(RuntimeVerifier.class.getResource("RuntimeVerifier.class").toURI()));
        check(patches.transform(null, "fixture/Target", null, null, classFile) == null, "mismatched class does not run transformer");
        check(!Files.exists(logTarget), "mismatched target ignored");
        check(ClassFileMethods.descriptors(classFile, "main").size() == 1, "exact method descriptor discovery");
        patches.module("verifier-exact");
        boolean[] exactCallback = {false};
        patches.register(new com.knoxbridge.api.PatchRegistrar.Patch("exact-main",
            new com.knoxbridge.api.PatchRegistrar.Target("com.knoxbridge.runtime.RuntimeVerifier", "main", "([Ljava/lang/String;)V"), false,
            (name, bytes) -> { exactCallback[0] = true; return bytes.clone(); }));
        check(patches.transform(null, "com/knoxbridge/runtime/RuntimeVerifier", null, null, classFile) == null && exactCallback[0],
            "exact class and method target invokes transformer");
        patches.module("verifier-bad-bytes");
        patches.register(new com.knoxbridge.api.PatchRegistrar.Patch("bad-bytes",
            new com.knoxbridge.api.PatchRegistrar.Target("com.knoxbridge.runtime.RuntimeVerifier", "check", "(ZLjava/lang/String;)V"), false,
            (name, bytes) -> new byte[] {1, 2, 3}));
        check(patches.transform(null, "com/knoxbridge/runtime/RuntimeVerifier", null, null, classFile) == null
                && patchLog.stream().anyMatch(s -> s.contains("patch FAIL module=verifier-bad-bytes")),
            "invalid transformer output is rejected and attributed");
        ArrayList<String> implementations = new ArrayList<>();
        implementations.add("enabled");
        SignatureFixture fixture = new SignatureFixture();
        fixture.loadMods(implementations);
        check(ClassFileMethods.descriptors(Files.readAllBytes(Path.of(RuntimeVerifier.class.getResource("RuntimeVerifier$SignatureFixture.class").toURI())), "loadMods")
                .contains("(Ljava/util/List;)V"), "interface method accepts concrete ArrayList implementation");
        byte[] zfsBytes = Files.readAllBytes(Path.of(zombie.ZomboidFileSystem.class.getResource("ZomboidFileSystem.class").toURI()));
        List<String> intercepted = new ArrayList<>();
        KnoxBridgeAgent.setTestObserver((fs, ids) -> ids.forEach(id -> intercepted.add((String) id)));
        byte[] transformed = new PzEnabledModTransformer(s -> { }).transform(null, "zombie/ZomboidFileSystem", null, null, zfsBytes);
        check(transformed != null, "42.21 enabled-mod adapter targets List signature");
        ClassLoader fixtureLoader = new ClassLoader(RuntimeVerifier.class.getClassLoader()) {
            @Override protected synchronized Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
                if (!name.equals("zombie.ZomboidFileSystem")) return super.loadClass(name, resolve);
                Class<?> type = findLoadedClass(name);
                if (type == null) type = defineClass(name, transformed, 0, transformed.length);
                if (resolve) resolveClass(type);
                return type;
            }
        };
        Class<?> isolatedFixture = fixtureLoader.loadClass("zombie.ZomboidFileSystem");
        Object pzFileSystem = isolatedFixture.getConstructor().newInstance();
        isolatedFixture.getMethod("loadMods", List.class).invoke(pzFileSystem, implementations);
        KnoxBridgeAgent.setTestObserver(null);
        check(intercepted.equals(List.of("enabled")), "PZ loaded IDs captured after loadMods with ArrayList argument");
        Path selectedMod = Files.createDirectories(temp.resolve("pz-mod/42.21"));
        Files.writeString(selectedMod.resolve("knoxbridge.properties"), "fixture");
        FakeFileSystem fakeFs = new FakeFileSystem(temp.resolve("pz-mod").toString());
        check(PzModDiscovery.resolve(fakeFs, List.of("enabled", "disabled"), s -> { }).equals(List.of(selectedMod.toAbsolutePath())),
            "PZ resolver returns only active mod IDs and selected version directory");
        Path plainRoot = Files.createDirectories(temp.resolve("plain-root"));
        Files.createDirectories(plainRoot.resolve("42.21"));
        FakeFileSystem plainFs = new FakeFileSystem(plainRoot.toString());
        check(PzModDiscovery.resolve(plainFs, List.of("enabled"), s -> { })
                .equals(List.of(plainRoot.resolve("42.21").toAbsolutePath())),
            "enabled mod roots are surfaced for safe JAR inventory even without a Bridge descriptor");
        check(KnoxBridgeAgent.hasCompetingBootstrap(List.of("-agentlib:exampleRuntime")), "native instrumentation conflict detected");
        check(KnoxBridgeAgent.hasCompetingBootstrap(List.of("-javaagent:another-runtime.jar")), "competing Java agent conflict detected");
        check(!KnoxBridgeAgent.hasCompetingBootstrap(List.of("-javaagent:C:/game/.knoxbridge/knoxbridge-agent.jar")), "KnoxBridge agent not treated as foreign");
        System.out.println("KnoxBridge offline verification PASS checks=" + checks);
    }

    private static void check(boolean ok, String name) {
        checks++;
        if (!ok) throw new AssertionError(name);
    }

    private static final class SignatureFixture {
        void loadMods(List<String> mods) { if (mods.isEmpty()) throw new IllegalArgumentException(); }
    }

    public static final class FakeFileSystem {
        private final String path;
        public FakeFileSystem(String path) { this.path = path; }
        public String getModDir(String id) { return id.equals("enabled") ? path : null; }
        public FakeModInfo getModInfoForDir(String root) { return new FakeModInfo("42.21"); }
    }
    public static final class FakeModInfo {
        private final String versionDir;
        public FakeModInfo(String versionDir) { this.versionDir = versionDir; }
        public String getVersionDir() { return versionDir; }
    }
}
