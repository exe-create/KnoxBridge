package org.example.mymod;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.jar.JarFile;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassVisitor;
import org.objectweb.asm.Opcodes;

/** Prints the exact method descriptors present in a class in a local PZ JAR. */
public final class PzMethodInspector {
    private PzMethodInspector() { }

    public static void main(String[] args) throws IOException {
        if (args.length != 3) {
            throw new IllegalArgumentException("Usage: <projectzomboid.jar> <fully.qualified.ClassName> <methodName>");
        }
        String className = args[1];
        String entryName = className.replace('.', '/') + ".class";
        List<String> descriptors = new ArrayList<>();
        try (JarFile jar = new JarFile(args[0])) {
            var entry = jar.getJarEntry(entryName);
            if (entry == null) throw new IllegalArgumentException("Class not found in PZ JAR: " + className);
            try (var input = jar.getInputStream(entry)) {
                new ClassReader(input).accept(new ClassVisitor(Opcodes.ASM9) {
                    @Override public org.objectweb.asm.MethodVisitor visitMethod(int access, String name,
                            String descriptor, String signature, String[] exceptions) {
                        if (name.equals(args[2])) descriptors.add(descriptor);
                        return null;
                    }
                }, ClassReader.SKIP_CODE | ClassReader.SKIP_DEBUG | ClassReader.SKIP_FRAMES);
            }
        }
        if (descriptors.isEmpty()) throw new IllegalArgumentException("Method not found: " + className + "." + args[2]);
        System.out.println(className + "." + args[2] + " descriptors in " + args[0] + ":");
        descriptors.stream().sorted().forEach(descriptor -> System.out.println("  " + descriptor));
    }
}
