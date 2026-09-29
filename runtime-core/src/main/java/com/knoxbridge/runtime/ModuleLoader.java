package com.knoxbridge.runtime;

import com.knoxbridge.api.KnoxModule;
import com.knoxbridge.api.ModuleContext;
import java.lang.instrument.Instrumentation;
import java.util.jar.JarFile;
import java.net.URLClassLoader;
import java.nio.file.Path;
import java.util.function.Consumer;

final class ModuleLoader {
    static LoadedModule load(ModuleDescriptor d, Path jar, String runtimeVersion, PatchEngine patches,
            Instrumentation instrumentation, Consumer<String> log) throws Exception {
        JarFile systemJar = null;
        URLClassLoader isolatedLoader = null;
        try {
            ClassLoader classLoader;
            if (d.classLoader().equals("system")) {
                systemJar = new JarFile(jar.toFile());
                instrumentation.appendToSystemClassLoaderSearch(systemJar);
                classLoader = ClassLoader.getSystemClassLoader();
                log.accept("module classloader policy=system id=" + d.id());
            } else {
                isolatedLoader = new URLClassLoader(new java.net.URL[] { jar.toUri().toURL() }, ModuleLoader.class.getClassLoader());
                classLoader = isolatedLoader;
            }
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
                public Instrumentation instrumentation() { return instrumentation; }
            });
            log.accept("module loaded id=" + d.id() + " version=" + d.version());
            return new LoadedModule(module, isolatedLoader, systemJar);
        } catch (Exception | Error e) {
            if (isolatedLoader != null) isolatedLoader.close();
            if (systemJar != null) systemJar.close();
            throw e;
        }
    }

    record LoadedModule(KnoxModule module, URLClassLoader loader, JarFile systemJar) implements AutoCloseable {
        @Override public void close() throws Exception {
            try { module.shutdown(); }
            finally {
                if (loader != null) loader.close();
                if (systemJar != null) systemJar.close();
            }
        }
    }
}
