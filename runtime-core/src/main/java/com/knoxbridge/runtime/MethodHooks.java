package com.knoxbridge.runtime;

import com.knoxbridge.api.PatchRegistrar;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.MethodInsnNode;

/** Straight-line void calls preserve existing frames, operands, locals and return values. */
final class MethodHooks implements PatchRegistrar.Transformer {
    private final PatchRegistrar.Hook hook;

    MethodHooks(PatchRegistrar.Hook hook) { this.hook = hook; }

    @Override public byte[] transform(String name, byte[] bytes) { return transform(hook, bytes); }

    void validateCallbacks(ClassLoader loader) throws Exception {
        for (var callback : new PatchRegistrar.Callback[] { hook.onEnter(), hook.onReturn() }) {
            if (callback == null) continue;
            if (callback.className().equals(hook.target().className()))
                throw new IllegalArgumentException("callback helper must be separate from the target class");
            Class<?> type = Class.forName(callback.className(), false, loader);
            var method = type.getMethod(callback.methodName());
            if (type.isInterface() || !java.lang.reflect.Modifier.isPublic(type.getModifiers())
                    || !java.lang.reflect.Modifier.isPublic(method.getDeclaringClass().getModifiers())
                    || !java.lang.reflect.Modifier.isStatic(method.getModifiers()) || method.getReturnType() != void.class)
                throw new IllegalArgumentException("callback must be a visible public static void method() in a public class");
        }
    }

    static byte[] transform(PatchRegistrar.Hook hook, byte[] bytes) {
        ClassNode type = new ClassNode(Opcodes.ASM9);
        new ClassReader(bytes).accept(type, 0);
        var matches = type.methods.stream().filter(m -> m.name.equals(hook.target().methodName())
            && (hook.target().descriptor() == null || m.desc.equals(hook.target().descriptor()))).toList();
        if (matches.size() != 1) throw new IllegalArgumentException("hook target must match exactly one method");
        var method = matches.get(0);
        if (method.name.startsWith("<") || (method.access & (Opcodes.ACC_ABSTRACT | Opcodes.ACC_NATIVE)) != 0)
            throw new IllegalArgumentException("hooks require a concrete ordinary method");
        if (hook.onEnter() != null) method.instructions.insert(call(hook.onEnter()));
        if (hook.onReturn() != null) {
            for (var instruction = method.instructions.getFirst(); instruction != null;) {
                var next = instruction.getNext();
                if (instruction.getOpcode() >= Opcodes.IRETURN && instruction.getOpcode() <= Opcodes.RETURN)
                    method.instructions.insertBefore(instruction, call(hook.onReturn()));
                instruction = next;
            }
        }
        ClassWriter writer = new ClassWriter(0);
        type.accept(writer);
        return writer.toByteArray();
    }

    private static MethodInsnNode call(PatchRegistrar.Callback callback) {
        return new MethodInsnNode(Opcodes.INVOKESTATIC, callback.className().replace('.', '/'),
            callback.methodName(), "()V", false);
    }
}
