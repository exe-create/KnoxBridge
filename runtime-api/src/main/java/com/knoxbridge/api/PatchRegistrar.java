package com.knoxbridge.api;

public interface PatchRegistrar {
    /** Registers a patch during synchronous {@link KnoxModule#initialize(ModuleContext)} execution. */
    void register(Patch patch);

    /** Entry and normal-return callbacks. Requires a runtime providing the hook API. */
    default void registerHook(Hook hook) {
        throw new UnsupportedOperationException("This KnoxBridge runtime does not provide registerHook");
    }

    /** Public static void callback() in a class visible to the target's class loader. */
    record Callback(String className, String methodName) {
        public Callback {
            if (className == null || className.isBlank() || methodName == null || methodName.isBlank())
                throw new IllegalArgumentException("callback class and method are required");
        }
    }

    /** Callbacks observe entry/normal exit; they receive no arguments and do not replace results. */
    record Hook(String patchId, Target target, boolean required, Callback onEnter, Callback onReturn) {
        public Hook {
            if (patchId == null || patchId.isBlank() || target == null || (onEnter == null && onReturn == null))
                throw new IllegalArgumentException("hook id, target and at least one callback are required");
        }
    }

    @FunctionalInterface
    interface Transformer {
        byte[] transform(String className, byte[] originalBytes) throws Exception;
    }

    /**
     * @param required diagnostic metadata only; current runtimes do not block a module or PZ when it fails
     */
    record Patch(String patchId, Target target, boolean required, Transformer transformer) {
        public Patch {
            if (patchId == null || patchId.isBlank()) throw new IllegalArgumentException("patchId is required");
            if (target == null || transformer == null) throw new IllegalArgumentException("target and transformer are required");
        }
    }

    record Target(String className, String methodName, String descriptor) {
        public Target {
            if (className == null || className.isBlank()) throw new IllegalArgumentException("className is required");
            if (methodName == null || methodName.isBlank()) throw new IllegalArgumentException("methodName is required");
        }
    }
}
