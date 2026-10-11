package org.example.mymod;

import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.InsnList;
import org.objectweb.asm.tree.MethodInsnNode;
import org.objectweb.asm.tree.LdcInsnNode;
import org.objectweb.asm.tree.MethodNode;

/** Adds entry and exit calls to one exact fixture method using ASM. */
public final class GreetingPatch {
    private GreetingPatch() { }

    public static void onEnter() { log("enter greeting"); }
    public static void onReturn() { log("exit greeting"); }

    static byte[] addAdvice(String className, byte[] originalBytes) {
        ClassNode type = new ClassNode(Opcodes.ASM9);
        new ClassReader(originalBytes).accept(type, 0);
        MethodNode method = type.methods.stream()
            .filter(candidate -> candidate.name.equals("greeting") && candidate.desc.equals("()Ljava/lang/String;"))
            .findFirst().orElseThrow(() -> new IllegalArgumentException("fixture greeting method is missing"));
        InsnList entry = new InsnList();
        entry.add(new LdcInsnNode("enter greeting"));
        entry.add(new MethodInsnNode(Opcodes.INVOKESTATIC, "org/example/mymod/GreetingPatch",
            "log", "(Ljava/lang/String;)V", false));
        method.instructions.insert(entry);

        for (var instruction = method.instructions.getFirst(); instruction != null;) {
            var next = instruction.getNext();
            if (instruction.getOpcode() >= Opcodes.IRETURN && instruction.getOpcode() <= Opcodes.RETURN) {
                InsnList exit = new InsnList();
                exit.add(new LdcInsnNode("exit greeting"));
                exit.add(new MethodInsnNode(Opcodes.INVOKESTATIC, "org/example/mymod/GreetingPatch",
                    "log", "(Ljava/lang/String;)V", false));
                method.instructions.insertBefore(instruction, exit);
            }
            instruction = next;
        }
        ClassWriter writer = new ClassWriter(ClassWriter.COMPUTE_FRAMES | ClassWriter.COMPUTE_MAXS);
        type.accept(writer);
        return writer.toByteArray();
    }

    public static void log(String message) {
        System.out.println("[KnoxBridge example] " + message);
    }
}
