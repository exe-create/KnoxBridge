package com.knoxbridge.runtime;

import com.knoxbridge.api.KnoxModule;
import com.knoxbridge.api.ModuleContext;
import java.net.URLClassLoader;
import java.nio.file.Path;
import java.util.function.Consumer;

final class ModuleLoader {
    static LoadedModule load(ModuleDescriptor d, Path jar, String runtimeVersion, PatchEngine patches, Consumer<String> log) throws Exception {
        URLClassLoader classLoader = new URLClassLoader(new java.net.URL[] { jar.toUri().toURL() }, ModuleLoader.class.getClassLoader());
        try {
            Class<?> type = Class.forName(d.entrypoint(), true, classLoader);
            if (!KnoxModule.class.isAssignableFrom(type)) throw new IllegalArgumentException("entrypoint does not implement KnoxModule");
            KnoxModule module = (KnoxModule) type.getDeclaredConstructor().newInstance();
            patches.module(d.id());
            module.initialize(new ModuleContext() {
                public String runtimeVersion() { return runtimeVersion; }
                public String moduleId() { return d.id(); }
                public String moduleVersion() { return d.version(); }
                public Consumer<String> logger() { return log; }
                public com.knoxbridge.api.PatchRegistrar patches() { return patches; }
            });
            log.accept("module loaded id=" + d.id() + " version=" + d.version());
            return new LoadedModule(module, classLoader);
        } catch (Exception | Error e) { classLoader.close(); throw e; }
    }

    record LoadedModule(KnoxModule module, URLClassLoader loader) implements AutoCloseable {
        @Override public void close() throws Exception { try { module.shutdown(); } finally { loader.close(); } }
    }
}
