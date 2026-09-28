package com.knoxbridge.runtime;

import com.knoxbridge.api.PatchRegistrar;
import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

final class PatchEngine implements ClassFileTransformer, PatchRegistrar {
    private record Owned(String module, Patch patch) { }
    private final List<Owned> patches = new CopyOnWriteArrayList<>();
    private final Consumer<String> log;
    private String registeringModule;

    PatchEngine(Consumer<String> log) { this.log = log; }
    void module(String id) { registeringModule = id; }
    boolean targetsClass(String className) {
        return patches.stream().anyMatch(p -> p.patch().target().className().equals(className));
    }

    @Override public void register(Patch patch) {
        if (registeringModule == null) throw new IllegalStateException("patch registration outside module initialization");
        boolean duplicate = patches.stream().anyMatch(p -> p.patch().patchId().equals(patch.patchId())
            || (p.patch().target().className().equals(patch.target().className())
                && p.patch().target().methodName().equals(patch.target().methodName())
                && java.util.Objects.equals(p.patch().target().descriptor(), patch.target().descriptor())));
        if (duplicate) throw new IllegalArgumentException("duplicate patch id or target: " + patch.patchId());
        patches.add(new Owned(registeringModule, patch));
        log.accept("patch registered module=" + registeringModule + " id=" + patch.patchId() + " target=" + patch.target());
    }

    @Override public byte[] transform(ClassLoader loader, String internalName, Class<?> redef, ProtectionDomain domain, byte[] bytes) {
        String className = internalName == null ? "" : internalName.replace('/', '.');
        byte[] current = bytes;
        for (Owned owned : patches) {
            PatchRegistrar.Patch patch = owned.patch();
            if (!patch.target().className().equals(className)) continue;
            try {
                List<String> candidates = ClassFileMethods.descriptors(current, patch.target().methodName());
                long matching = candidates.stream().filter(d -> patch.target().descriptor() == null
                    || patch.target().descriptor().equals(d)).count();
                if (matching == 0) {
                    log.accept("patch INCOMPATIBLE module=" + owned.module() + " id=" + patch.patchId() + " reason=method-missing");
                    continue;
                }
                if (matching > 1) {
                    log.accept("patch INCOMPATIBLE module=" + owned.module() + " id=" + patch.patchId() + " reason=ambiguous-method");
                    continue;
                }
                byte[] changed = patch.transformer().transform(className, current.clone());
                if (changed != null) {
                    if (java.util.Arrays.equals(changed, current)) {
                        log.accept("patch NOOP module=" + owned.module() + " id=" + patch.patchId() + " target=" + className);
                        continue;
                    }
                    new org.objectweb.asm.ClassReader(changed).accept(
                        new org.objectweb.asm.ClassVisitor(org.objectweb.asm.Opcodes.ASM9) { }, 0);
                    current = changed;
                    log.accept("patch PASS module=" + owned.module() + " id=" + patch.patchId() + " target=" + className);
                }
            } catch (Throwable failure) {
                log.accept("patch FAIL module=" + owned.module() + " id=" + patch.patchId() + " required=" + patch.required() + " reason=" + failure);
            }
        }
        return current == bytes ? null : current;
    }
}
