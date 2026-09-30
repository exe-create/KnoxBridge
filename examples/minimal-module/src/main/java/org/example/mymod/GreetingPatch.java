package org.example.mymod;

import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.InsnList;
import org.objectweb.asm.tree.InsnNode;
import org.objectweb.asm.tree.LdcInsnNode;
import org.objectweb.asm.tree.MethodNode;

/** Replaces one exact fixture method body using ASM. */
final class GreetingPatch {
    private GreetingPatch() { }

    static byte[] replaceGreeting(String className, byte[] originalBytes) {
        ClassNode type = new ClassNode(Opcodes.ASM9);
        new ClassReader(originalBytes).accept(type, 0);
        MethodNode method = type.methods.stream()
            .filter(candidate -> candidate.name.equals("greeting") && candidate.desc.equals("()Ljava/lang/String;"))
            .findFirst().orElseThrow(() -> new IllegalArgumentException("fixture greeting method is missing"));
        InsnList replacement = new InsnList();
        replacement.add(new LdcInsnNode("greeting changed by a KnoxBridge patch"));
        replacement.add(new InsnNode(Opcodes.ARETURN));
        method.instructions = replacement;
        method.tryCatchBlocks.clear();
        method.localVariables = null;
        method.maxStack = 1;
        method.maxLocals = 1;
        ClassWriter writer = new ClassWriter(ClassWriter.COMPUTE_MAXS);
        type.accept(writer);
        return writer.toByteArray();
    }
}
