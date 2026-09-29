package com.knoxbridge.runtime;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.regex.Pattern;

/** Shared, versioned text-file protocol between the early Java agent and Bridge's PZ Lua UI. */
final class ModuleReviewFiles {
    static final String MANIFEST_NAME = "module-review.txt";
    static final String DECISIONS_NAME = "module-decisions.txt";
    static final String MANIFEST_HEADER = "KNOXBRIDGE-MODULES-2";
    static final String DECISIONS_HEADER = "KNOXBRIDGE-DECISIONS-2";
    private static final String LEGACY_DECISIONS_HEADER = "KNOXBRIDGE-DECISIONS-1";
    static final String DECISIONS_COMMIT = "KNOXBRIDGE-COMMIT-1";
    private static final Pattern SHA256 = Pattern.compile("[0-9a-f]{64}");

    record Entry(String id, String version, String hash, String name, String author, String state, String jarName) { }
    private record QueuedDecision(String hash, TrustStore.Decision decision, boolean remember) { }

    private ModuleReviewFiles() { }

    static Path userLuaDirectory() {
        return Path.of(System.getProperty("user.home"), "Zomboid", "Lua", "KnoxBridge");
    }

    static Path manifestPath() { return userLuaDirectory().resolve(MANIFEST_NAME); }
    static Path decisionsPath() { return userLuaDirectory().resolve(DECISIONS_NAME); }

    static void applyQueuedDecisions(TrustStore trust, Path queuePath, java.util.function.Consumer<String> log) throws IOException {
        if (!Files.isRegularFile(queuePath)) return;
        List<String> lines = Files.readAllLines(queuePath, StandardCharsets.UTF_8);
        boolean version2 = !lines.isEmpty() && DECISIONS_HEADER.equals(lines.get(0));
        boolean version1 = !lines.isEmpty() && LEGACY_DECISIONS_HEADER.equals(lines.get(0));
        if (lines.size() < 2 || (!version1 && !version2)
                || !DECISIONS_COMMIT.equals(lines.get(lines.size() - 1))) {
            log.accept("module review queue ignored reason=invalid-header; no decisions applied");
            return;
        }

        Map<String, TrustStore.Decision> unique = new HashMap<>();
        List<QueuedDecision> decisions = new ArrayList<>();
        for (int i = 1; i < lines.size() - 1; i++) {
            String line = lines.get(i);
            if (line.isBlank()) continue;
            String[] fields = line.split("\\t", -1);
            if ((version2 ? fields.length != 3 : fields.length != 2) || !SHA256.matcher(fields[0]).matches()
                    || !("allow".equals(fields[1]) || "deny".equals(fields[1]))) {
                log.accept("module review queue ignored reason=invalid-row; no decisions applied");
                return;
            }
            boolean remember = !version2 || "remember".equals(fields[2]);
            if (version2 && !remember && !"once".equals(fields[2])) {
                log.accept("module review queue ignored reason=invalid-row; no decisions applied");
                return;
            }
            TrustStore.Decision decision = "allow".equals(fields[1])
                ? (remember ? TrustStore.Decision.ALLOW_EXACT : TrustStore.Decision.ALLOW_ONCE)
                : (remember ? TrustStore.Decision.DENY_EXACT : TrustStore.Decision.DENY_ONCE);
            TrustStore.Decision previous = unique.putIfAbsent(fields[0], decision);
            if (previous != null && previous != decision) {
                log.accept("module review queue ignored reason=conflicting-duplicate; no decisions applied");
                return;
            }
            if (previous == null) decisions.add(new QueuedDecision(fields[0], decision, remember));
        }

        for (QueuedDecision decision : decisions) {
            if (decision.remember()) trust.decide(decision.hash(), decision.decision());
            else trust.decideNextLaunch(decision.hash(), decision.decision());
        }
        Files.deleteIfExists(queuePath);
        log.accept("module review decisions applied count=" + decisions.size() + " scope=exact-jar-hash");
    }

    static void writeManifest(Path manifestPath, List<Entry> entries) throws IOException {
        StringBuilder contents = new StringBuilder(MANIFEST_HEADER).append('\n');
        for (Entry entry : entries.stream().sorted(java.util.Comparator.comparing(Entry::id)
                .thenComparing(Entry::hash)).toList()) {
            contents.append(field(entry.id())).append('\t')
                .append(field(entry.version())).append('\t')
                .append(field(entry.hash())).append('\t')
                .append(field(entry.name())).append('\t')
                .append(field(entry.author())).append('\t')
                .append(field(entry.state())).append('\t')
                .append(field(entry.jarName())).append('\n');
        }
        writeAtomically(manifestPath, contents.toString());
    }

    static Entry entry(ModuleDiscovery.Candidate candidate, String hash, String state) {
        Properties info = new Properties();
        Path infoPath = candidate.modRoot().resolve("mod.info");
        if (Files.isRegularFile(infoPath)) {
            try (var input = Files.newInputStream(infoPath)) { info.load(input); }
            catch (Exception ignored) { }
        }
        ModuleDescriptor descriptor = candidate.descriptor();
        String id = descriptor == null ? candidate.modRoot().getFileName().toString() : descriptor.id();
        String version = descriptor == null ? "unknown" : descriptor.version();
        return new Entry(id, version, hash, fallback(info.getProperty("name"), "Not provided"),
            fallback(info.getProperty("author"), "Not provided"), state,
            candidate.jar() == null ? "unavailable" : candidate.jar().getFileName().toString());
    }

    static boolean isValidHash(String hash) { return hash != null && SHA256.matcher(hash).matches(); }

    private static String fallback(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

    private static String field(String value) {
        if (value == null) return "";
        return value.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();
    }

    private static void writeAtomically(Path path, String contents) throws IOException {
        Files.createDirectories(path.getParent());
        Path temporary = path.resolveSibling(path.getFileName() + ".tmp");
        Files.writeString(temporary, contents, StandardCharsets.UTF_8);
        try { Files.move(temporary, path, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING); }
        catch (IOException unsupportedAtomicMove) {
            Files.move(temporary, path, StandardCopyOption.REPLACE_EXISTING);
        }
    }
}
