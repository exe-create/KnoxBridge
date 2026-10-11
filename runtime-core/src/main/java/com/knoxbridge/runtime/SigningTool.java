package com.knoxbridge.runtime;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.KeyFactory;
import java.security.KeyPairGenerator;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.List;

/** Offline author/release tool. Private keys must live outside distributed project/package folders. */
public final class SigningTool {
    private SigningTool() { }

    public static void main(String[] args) throws Exception {
        if (args.length == 2 && args[0].equals("fingerprint")) {
            var key = KeyFactory.getInstance("Ed25519").generatePublic(
                new X509EncodedKeySpec(Files.readAllBytes(Path.of(args[1]))));
            System.out.println(DetachedSignature.fingerprint(key));
            return;
        }
        if (args.length == 3 && args[0].equals("keygen")) {
            Path privatePath = Path.of(args[1]);
            Path publicPath = Path.of(args[2]);
            if (privatePath.toAbsolutePath().normalize().equals(publicPath.toAbsolutePath().normalize())
                    || Files.exists(privatePath) || Files.exists(publicPath))
                throw new IllegalArgumentException("key output paths must be different and must not exist");
            var pair = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
            Files.write(privatePath, pair.getPrivate().getEncoded(), StandardOpenOption.CREATE_NEW);
            Files.write(publicPath, pair.getPublic().getEncoded(), StandardOpenOption.CREATE_NEW);
            System.out.println("Public key SHA-256: " + DetachedSignature.fingerprint(pair.getPublic()));
            System.out.println("Private key is unencrypted: protect it offline; never distribute it.");
            return;
        }
        boolean module = args.length > 0 && args[0].endsWith("-module");
        boolean sign = args.length > 0 && args[0].startsWith("sign-");
        boolean verify = args.length > 0 && args[0].startsWith("verify-");
        if ((!sign && !verify) || !(args[0].equals("sign-module") || args[0].equals("verify-module")
                || args[0].equals("sign-file") || args[0].equals("verify-file"))
                || args.length != (sign ? 4 : 3))
            throw new IllegalArgumentException("Usage: keygen <private.pk8> <public.der> | sign-module <modRoot> <private.pk8> <public.der> | verify-module <modRoot> <expectedFingerprint> | sign-file <file> <private.pk8> <public.der> | verify-file <file> <expectedFingerprint>");
        Path input = Path.of(args[1]).toAbsolutePath().normalize();
        ModuleDescriptor descriptor = module ? ModuleDescriptor.read(input) : null;
        Path artifact = module ? descriptor.jar() : input;
        List<String> context = module ? DetachedSignature.moduleContext(descriptor, input) : List.of("file");
        if (sign) {
            var factory = KeyFactory.getInstance("Ed25519");
            var privateKey = factory.generatePrivate(new PKCS8EncodedKeySpec(Files.readAllBytes(Path.of(args[2]))));
            var publicKey = factory.generatePublic(new X509EncodedKeySpec(Files.readAllBytes(Path.of(args[3]))));
            DetachedSignature.sign(artifact, context, privateKey, publicKey);
            System.out.println("Signed " + artifact + " public key SHA-256=" + DetachedSignature.fingerprint(publicKey));
        } else {
            if (!args[2].matches("[0-9a-fA-F]{64}")) throw new IllegalArgumentException("expected fingerprint must be a SHA-256 hex value");
            String fingerprint = DetachedSignature.verify(artifact, context);
            if (fingerprint == null || !fingerprint.equalsIgnoreCase(args[2]))
                throw new SecurityException("artifact is unsigned or signer differs from expected fingerprint");
            System.out.println("Verified " + artifact + " public key SHA-256=" + fingerprint);
        }
    }
}
