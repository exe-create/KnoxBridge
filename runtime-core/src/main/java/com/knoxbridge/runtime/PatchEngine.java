package com.knoxbridge.runtime;

import com.knoxbridge.api.PatchRegistrar;
import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

final class PatchEngine implements ClassFileTransformer {
    private record Owned(String module, PatchRegistrar.Patch patch) { }
    private final List<Owned> patches = new CopyOnWriteArrayList<>();
    private final Consumer<String> log;

    PatchEngine(Consumer<String> log) { this.log = log; }
    Registration beginModule(String id) {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("module id is required");
        return new Registration(id);
    }
    boolean targetsClass(String className) {
        return patches.stream().anyMatch(p -> p.patch().target().className().equals(className));
    }

    final class Registration implements PatchRegistrar, AutoCloseable {
        private final String moduleId;
        private final Thread owner = Thread.currentThread();
        private final List<Owned> pending = new java.util.ArrayList<>();
        private boolean open = true;

        private Registration(String moduleId) { this.moduleId = moduleId; }

        @Override public void register(Patch patch) {
            java.util.Objects.requireNonNull(patch, "patch");
            synchronized (PatchEngine.this) {
                if (Thread.currentThread() != owner)
                    throw new IllegalStateException("patch registration must be synchronous in initialize for module=" + moduleId);
                if (!open) throw new IllegalStateException("patch registration is closed for module=" + moduleId);
                Owned candidate = new Owned(moduleId, patch);
                ensureUnique(candidate, pending);
                ensureUnique(candidate, patches);
                pending.add(candidate);
            }
        }

        void commit() {
            List<Owned> committed;
            synchronized (PatchEngine.this) {
                if (Thread.currentThread() != owner)
                    throw new IllegalStateException("patch registration must be committed by the initializing thread for module=" + moduleId);
                if (!open) throw new IllegalStateException("patch registration is closed for module=" + moduleId);
                for (Owned candidate : pending) ensureUnique(candidate, patches);
                committed = List.copyOf(pending);
                patches.addAll(committed);
                pending.clear();
                open = false;
            }
            for (Owned owned : committed) log.accept("patch registered module=" + moduleId + " id="
                + owned.patch().patchId() + " target=" + owned.patch().target());
        }

        @Override public void close() {
            synchronized (PatchEngine.this) {
                if (!open) return;
                pending.clear();
                open = false;
            }
        }
    }

    private static void ensureUnique(Owned candidate, List<Owned> existing) {
        boolean duplicate = existing.stream().anyMatch(p -> p.patch().patchId().equals(candidate.patch().patchId())
            || (p.patch().target().className().equals(candidate.patch().target().className())
                && p.patch().target().methodName().equals(candidate.patch().target().methodName())
                && java.util.Objects.equals(p.patch().target().descriptor(), candidate.patch().target().descriptor())));
        if (duplicate) throw new IllegalArgumentException("duplicate patch id or target: " + candidate.patch().patchId());
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
                    log.accept("patch INCOMPATIBLE module=" + owned.module() + " id=" + patch.patchId()
                        + " target=" + patch.target() + " reason=method-missing");
                    continue;
                }
                if (matching > 1) {
                    log.accept("patch INCOMPATIBLE module=" + owned.module() + " id=" + patch.patchId()
                        + " target=" + patch.target() + " reason=ambiguous-method");
                    continue;
                }
                byte[] changed = patch.transformer().transform(className, current.clone());
                if (changed != null) {
                    if (java.util.Arrays.equals(changed, current)) {
                        log.accept("patch NOOP module=" + owned.module() + " id=" + patch.patchId()
                            + " target=" + patch.target());
                        continue;
                    }
                    new org.objectweb.asm.ClassReader(changed).accept(
                        new org.objectweb.asm.ClassVisitor(org.objectweb.asm.Opcodes.ASM9) { }, 0);
                    current = changed;
                    log.accept("patch PASS module=" + owned.module() + " id=" + patch.patchId()
                        + " target=" + patch.target());
                }
            } catch (Throwable failure) {
                log.accept("patch FAIL module=" + owned.module() + " id=" + patch.patchId()
                    + " target=" + patch.target() + " required=" + patch.required() + " reason=" + failure);
            }
        }
        return current == bytes ? null : current;
    }
}
