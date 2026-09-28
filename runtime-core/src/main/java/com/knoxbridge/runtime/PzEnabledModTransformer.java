package com.knoxbridge.runtime;

import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassVisitor;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.MethodVisitor;
import org.objectweb.asm.Opcodes;
import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/** Captures PZ's own active mod list after its List-signature loadMods method returns. */
final class PzEnabledModTransformer implements ClassFileTransformer {
    private static final String CLASS = "zombie/ZomboidFileSystem";
    private static final String METHOD = "loadMods";
    private static final String DESCRIPTOR = "(Ljava/util/List;)V";
    private final Consumer<String> log;
    private final AtomicBoolean instrumented = new AtomicBoolean();

    PzEnabledModTransformer(Consumer<String> log) { this.log = log; }

    @Override public byte[] transform(ClassLoader loader, String className, Class<?> redef,
            ProtectionDomain domain, byte[] original) {
        if (!CLASS.equals(className)) return null;
        try {
            ClassReader reader = new ClassReader(original);
            ClassWriter writer = new ClassWriter(reader, ClassWriter.COMPUTE_MAXS);
            int[] matches = {0};
            ClassVisitor visitor = new ClassVisitor(Opcodes.ASM9, writer) {
                @Override public MethodVisitor visitMethod(int access, String name, String descriptor,
                        String signature, String[] exceptions) {
                    MethodVisitor mv = super.visitMethod(access, name, descriptor, signature, exceptions);
                    if (!METHOD.equals(name) || !DESCRIPTOR.equals(descriptor)) return mv;
                    matches[0]++;
                    return new MethodVisitor(Opcodes.ASM9, mv) {
                        @Override public void visitInsn(int opcode) {
                            if (opcode == Opcodes.RETURN) {
                                // Capture ZomboidFileSystem.getModIDs() after loadMods(List) completed.
                                super.visitVarInsn(Opcodes.ALOAD, 0);
                                super.visitVarInsn(Opcodes.ALOAD, 0);
                                super.visitMethodInsn(Opcodes.INVOKEVIRTUAL, CLASS, "getModIDs", "()Ljava/util/List;", false);
                                super.visitMethodInsn(Opcodes.INVOKESTATIC,
                                    "com/knoxbridge/runtime/KnoxBridgeAgent", "onPzModsLoaded",
                                    "(Ljava/lang/Object;Ljava/util/List;)V", false);
                            }
                            super.visitInsn(opcode);
                        }
                    };
                }
            };
            reader.accept(visitor, 0);
            if (matches[0] != 1) {
                log.accept("discovery adapter incompatible class=zombie.ZomboidFileSystem method=loadMods reason="
                    + (matches[0] == 0 ? "expected-list-signature-missing" : "ambiguous-signature"));
                return null;
            }
            instrumented.set(true);
            log.accept("discovery adapter PASS target=zombie.ZomboidFileSystem.loadMods(Ljava/util/List;)V");
            return writer.toByteArray();
        } catch (Throwable failure) {
            log.accept("discovery adapter failed class=zombie.ZomboidFileSystem reason=" + failure);
            return null;
        }
    }

    boolean wasInstrumented() { return instrumented.get(); }
}
