package com.knoxbridge.runtime;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;

/** Detached Ed25519 signatures; embedded keys prove key possession, never publisher identity. */
final class DetachedSignature {
    static Path sidecar(Path artifact) { return artifact.resolveSibling(artifact.getFileName() + ".knoxsig"); }

    static byte[] payload(Path artifact, List<String> context) throws Exception {
        return payload(artifact, context, Hashing.sha256(artifact));
    }

    private static byte[] payload(Path artifact, List<String> context, String hash) throws Exception {
        var bytes = new ByteArrayOutputStream();
        try (var out = new DataOutputStream(bytes)) {
            field(out, "KnoxBridge detached signature v1");
            field(out, artifact.getFileName().toString());
            field(out, hash);
            out.writeInt(context.size());
            for (String value : context) field(out, value);
        }
        return bytes.toByteArray();
    }

    private static void field(DataOutputStream out, String value) throws IOException {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        out.writeInt(bytes.length);
        out.write(bytes);
    }

    static String fingerprint(PublicKey key) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(key.getEncoded()));
    }

    static void sign(Path artifact, List<String> context, PrivateKey privateKey, PublicKey publicKey) throws Exception {
        Signature signer = Signature.getInstance("Ed25519");
        signer.initSign(privateKey);
        byte[] payload = payload(artifact, context);
        signer.update(payload);
        byte[] signature = signer.sign();
        Signature check = Signature.getInstance("Ed25519");
        check.initVerify(publicKey);
        check.update(payload);
        if (!check.verify(signature)) throw new IllegalArgumentException("private and public keys do not match");
        Files.writeString(sidecar(artifact), "KnoxBridge-Ed25519-v1\n"
            + Base64.getEncoder().encodeToString(publicKey.getEncoded()) + "\n"
            + Base64.getEncoder().encodeToString(signature) + "\n", StandardCharsets.US_ASCII,
            java.nio.file.StandardOpenOption.CREATE_NEW);
    }

    /** Null means absent. A present invalid sidecar always fails; never downgrades to unsigned. */
    static String verify(Path artifact, List<String> context) throws Exception {
        return verify(artifact, context, Hashing.sha256(artifact));
    }

    static String verify(Path artifact, List<String> context, String expectedHash) throws Exception {
        Path sidecar = sidecar(artifact);
        if (!Files.exists(sidecar, LinkOption.NOFOLLOW_LINKS)) return null;
        if (!Files.isRegularFile(sidecar, LinkOption.NOFOLLOW_LINKS) || Files.size(sidecar) > 1024)
            throw new IOException("invalid signature sidecar");
        String contents = Files.readString(sidecar, StandardCharsets.US_ASCII);
        String[] lines = contents.split("\n", -1);
        if (lines.length != 4 || !lines[0].equals("KnoxBridge-Ed25519-v1") || !lines[3].isEmpty())
            throw new IOException("invalid signature format/version");
        byte[] keyBytes = Base64.getDecoder().decode(lines[1]);
        byte[] signature = Base64.getDecoder().decode(lines[2]);
        if (signature.length != 64) throw new IOException("invalid Ed25519 signature length");
        PublicKey key = KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(keyBytes));
        if (!MessageDigest.isEqual(key.getEncoded(), keyBytes)) throw new IOException("noncanonical public key");
        Signature verifier = Signature.getInstance("Ed25519");
        verifier.initVerify(key);
        verifier.update(payload(artifact, context, expectedHash));
        if (!verifier.verify(signature)) throw new IOException("signature does not match artifact/metadata");
        return fingerprint(key);
    }

    static List<String> moduleContext(ModuleDescriptor d, Path root) {
        return List.of("module", d.id(), d.version(), d.apiVersion(), d.entrypoint(), d.classLoader(),
            root.toAbsolutePath().normalize().relativize(d.jar().toAbsolutePath().normalize()).toString().replace('\\', '/'));
    }
}
