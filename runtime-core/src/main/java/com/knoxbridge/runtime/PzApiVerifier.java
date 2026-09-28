package com.knoxbridge.runtime;

import java.nio.file.Path;
import java.util.zip.ZipFile;

/** Optional local probe for a user-supplied Project Zomboid JAR; it changes nothing. */
public final class PzApiVerifier {
    public static void main(String[] args) throws Exception {
        if (args.length != 1) throw new IllegalArgumentException("Pass the path to projectzomboid.jar");
        try (ZipFile jar = new ZipFile(Path.of(args[0]).toFile())) {
            var entry = jar.getEntry("zombie/ZomboidFileSystem.class");
            if (entry == null) throw new IllegalStateException("zombie/ZomboidFileSystem.class is missing");
            byte[] classBytes;
            try (var input = jar.getInputStream(entry)) { classBytes = input.readAllBytes(); }
            var descriptors = ClassFileMethods.descriptors(classBytes, "loadMods");
            System.out.println("PZ loadMods signatures=" + descriptors);
            if (!descriptors.contains("(Ljava/util/List;)V"))
                throw new IllegalStateException("Expected loadMods(List) was not found; no runtime compatibility claim is made.");
            System.out.println("KnoxBridge PZ API signature probe PASS method=loadMods(Ljava/util/List;)V");
            byte[] transformed = new PzEnabledModTransformer(System.out::println)
                .transform(null, "zombie/ZomboidFileSystem", null, null, classBytes);
            if (transformed == null) throw new IllegalStateException("PZ enabled-mod callback transform was not produced.");
            new org.objectweb.asm.ClassReader(transformed).accept(new org.objectweb.asm.ClassVisitor(org.objectweb.asm.Opcodes.ASM9) { }, 0);
            System.out.println("KnoxBridge offline PZ transform parse PASS");
        }
    }
}
