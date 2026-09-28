package com.knoxbridge.runtime;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;

final class TrustStore {
    enum Decision { ALLOW_ONCE, ALLOW_EXACT, DENY_ONCE, DENY_EXACT, APPROVAL_REQUIRED }
    private final Path path;
    private final Properties saved = new Properties();
    private final Map<String, Decision> once = new ConcurrentHashMap<>();

    TrustStore(Path path) throws IOException {
        this.path = path;
        if (Files.isRegularFile(path)) try (var in = Files.newInputStream(path)) { saved.load(in); }
    }

    synchronized Decision check(String hash) throws IOException {
        Decision one = once.remove(hash);
        if (one == Decision.ALLOW_ONCE || one == Decision.DENY_ONCE) return one;
        String stored = saved.getProperty(hash);
        if ("allow-once".equals(stored) || "deny-once".equals(stored)) {
            saved.remove(hash);
            saved.remove(hash + ".updated");
            persist();
            return "allow-once".equals(stored) ? Decision.ALLOW_ONCE : Decision.DENY_ONCE;
        }
        return "allow".equals(stored) ? Decision.ALLOW_EXACT
            : "deny".equals(stored) ? Decision.DENY_EXACT : Decision.APPROVAL_REQUIRED;
    }

    synchronized void observe(String hash, String moduleId, Path sourceRoot) throws IOException {
        saved.setProperty(hash + ".moduleId", moduleId);
        saved.setProperty(hash + ".sourceRoot", sourceRoot.toString());
        saved.setProperty(hash + ".seen", Instant.now().toString());
        persist();
    }

    synchronized void decide(String hash, Decision decision) throws IOException {
        if (decision == Decision.ALLOW_ONCE || decision == Decision.DENY_ONCE) { once.put(hash, decision); return; }
        if (decision != Decision.ALLOW_EXACT && decision != Decision.DENY_EXACT) throw new IllegalArgumentException("persistent decision required");
        saved.setProperty(hash, decision == Decision.ALLOW_EXACT ? "allow" : "deny");
        saved.setProperty(hash + ".updated", Instant.now().toString());
        persist();
    }

    synchronized void decideNextLaunch(String hash, Decision decision) throws IOException {
        if (decision != Decision.ALLOW_ONCE && decision != Decision.DENY_ONCE)
            throw new IllegalArgumentException("one-time decision required");
        saved.setProperty(hash, decision == Decision.ALLOW_ONCE ? "allow-once" : "deny-once");
        saved.setProperty(hash + ".updated", Instant.now().toString());
        persist();
    }

    private void persist() throws IOException {
        Files.createDirectories(path.getParent());
        Path tmp = path.resolveSibling(path.getFileName() + ".tmp");
        try (var out = Files.newOutputStream(tmp)) { saved.store(out, "KnoxBridge exact-JAR trust decisions; keys are SHA-256 digests"); }
        try { Files.move(tmp, path, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING); }
        catch (IOException e) { Files.move(tmp, path, StandardCopyOption.REPLACE_EXISTING); }
    }
}
