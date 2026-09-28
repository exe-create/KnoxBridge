package com.knoxbridge.api;

public interface PatchRegistrar {
    void register(Patch patch);

    @FunctionalInterface
    interface Transformer {
        byte[] transform(String className, byte[] originalBytes) throws Exception;
    }

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
