package com.knoxbridge.runtime;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

record ModuleDescriptor(String id, String version, String apiVersion, String entrypoint, Path jar) {
    static ModuleDescriptor read(Path modRoot) throws IOException {
        Path descriptor = modRoot.resolve("knoxbridge.properties").normalize();
        if (!descriptor.startsWith(modRoot.normalize()) || !Files.isRegularFile(descriptor))
            throw new IOException("missing knoxbridge.properties");
        Properties p = new Properties();
        try (var in = Files.newInputStream(descriptor)) { p.load(in); }
        String id = required(p, "id");
        String version = required(p, "version");
        String api = required(p, "apiVersion");
        String entry = required(p, "entrypoint");
        String jarValue = required(p, "jar");
        Path relativeJar = Path.of(jarValue);
        if (relativeJar.isAbsolute()) throw new IOException("jar path must be relative to mod root");
        Path jar = modRoot.resolve(relativeJar).normalize();
        if (!jar.startsWith(modRoot.normalize())) throw new IOException("jar path escapes mod root");
        if (!Files.isRegularFile(jar)) throw new IOException("module jar missing: " + jarValue);
        Path realRoot = modRoot.toRealPath();
        if (!jar.toRealPath().startsWith(realRoot)) throw new IOException("jar symlink escapes mod root");
        if (id.contains(" ") || id.contains("/") || id.contains("\\")) throw new IOException("invalid module id");
        return new ModuleDescriptor(id, version, api, entry, jar);
    }

    private static String required(Properties p, String key) throws IOException {
        String value = p.getProperty(key);
        if (value == null || value.isBlank()) throw new IOException("missing " + key);
        return value.trim();
    }
}
