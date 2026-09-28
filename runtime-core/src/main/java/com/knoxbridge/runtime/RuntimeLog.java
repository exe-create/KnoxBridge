package com.knoxbridge.runtime;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;

final class RuntimeLog {
    private final Path path = Path.of(System.getProperty("user.home"), "Zomboid", "KnoxBridge", "knoxbridge.log");
    synchronized void write(String message) {
        String line = "[" + Instant.now() + "] " + message;
        System.out.println(line);
        try {
            Files.createDirectories(path.getParent());
            Files.writeString(path, line + System.lineSeparator(), StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException ignored) { System.err.println("KnoxBridge log write failed path=" + path); }
    }
}
