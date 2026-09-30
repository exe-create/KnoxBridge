package com.knoxbridge.runtime;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import java.util.regex.Pattern;

final class TrustStore {
    enum Decision { ALLOW_ONCE, ALLOW_EXACT, DENY_ONCE, DENY_EXACT, APPROVAL_REQUIRED }
    private static final Pattern SHA256 = Pattern.compile("[0-9a-f]{64}");
    private final Path path;
    private final Properties saved = new Properties();
    private final Map<String, Decision> once = new HashMap<>();

    TrustStore(Path path) throws IOException {
        this.path = path;
        if (Files.isRegularFile(path)) try (var in = Files.newInputStream(path)) { saved.load(in); }
        Set<String> legacyOnceKeys = new HashSet<>();
        for (String key : saved.stringPropertyNames()) {
            if (SHA256.matcher(key).matches()) {
                Decision legacy = legacyOnceDecision(saved.getProperty(key));
                if (legacy != null) {
                    once.put(key, legacy);
                    legacyOnceKeys.add(key);
                }
            } else if (key.endsWith(".once")) {
                String hash = key.substring(0, key.length() - ".once".length());
                if (SHA256.matcher(hash).matches()) {
                    Decision queued = onceDecision(saved.getProperty(key));
                    if (queued != null) once.put(hash, queued);
                }
            }
        }
        // Alpha9 stored one-time values over the persistent trust key. Preserve the
        // one-time decision for this launch, while removing that ambiguous value.
        legacyOnceKeys.forEach(hash -> {
            saved.remove(hash);
            saved.remove(hash + ".updated");
        });
    }

    synchronized Decision check(String hash) throws IOException {
        Decision one = once.get(hash);
        if (one == Decision.ALLOW_ONCE || one == Decision.DENY_ONCE) return one;
        String stored = saved.getProperty(hash);
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
        once.remove(hash);
        saved.remove(hash + ".once");
        saved.remove(hash + ".once.updated");
        saved.setProperty(hash, decision == Decision.ALLOW_EXACT ? "allow" : "deny");
        saved.setProperty(hash + ".updated", Instant.now().toString());
        persist();
    }

    synchronized void decideNextLaunch(String hash, Decision decision) throws IOException {
        if (decision != Decision.ALLOW_ONCE && decision != Decision.DENY_ONCE)
            throw new IllegalArgumentException("one-time decision required");
        once.put(hash, decision);
        saved.setProperty(hash + ".once", decision == Decision.ALLOW_ONCE ? "allow" : "deny");
        saved.setProperty(hash + ".once.updated", Instant.now().toString());
        persist();
    }

    synchronized void finishLaunch() throws IOException {
        if (once.isEmpty()) return;
        for (String hash : once.keySet()) {
            saved.remove(hash + ".once");
            saved.remove(hash + ".once.updated");
        }
        persist();
        once.clear();
    }

    private static Decision onceDecision(String value) {
        return "allow".equals(value) ? Decision.ALLOW_ONCE
            : "deny".equals(value) ? Decision.DENY_ONCE : null;
    }

    private static Decision legacyOnceDecision(String value) {
        return "allow-once".equals(value) ? Decision.ALLOW_ONCE
            : "deny-once".equals(value) ? Decision.DENY_ONCE : null;
    }

    private void persist() throws IOException {
        Files.createDirectories(path.getParent());
        Path tmp = path.resolveSibling(path.getFileName() + ".tmp");
        try (var out = Files.newOutputStream(tmp)) { saved.store(out, "KnoxBridge exact-JAR trust decisions; keys are SHA-256 digests"); }
        try { Files.move(tmp, path, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING); }
        catch (IOException e) { Files.move(tmp, path, StandardCopyOption.REPLACE_EXISTING); }
    }
}
