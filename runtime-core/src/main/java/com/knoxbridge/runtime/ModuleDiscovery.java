package com.knoxbridge.runtime;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.Consumer;
import java.util.stream.Stream;

/** Inspects only the mod roots supplied by a PZ-version-specific enabled-mod adapter. */
final class ModuleDiscovery {
    record Candidate(Path modRoot, ModuleDescriptor descriptor, String problem, Path jar) { }

    static List<Candidate> inspectEnabledRoots(List<Path> enabledRoots, Consumer<String> log) {
        List<Candidate> found = new ArrayList<>();
        for (Path root : enabledRoots) {
            Path normalized = root.toAbsolutePath().normalize();
            if (!normalized.toFile().isDirectory()) { log.accept("mod root missing path=" + normalized); continue; }
            Set<Path> jars = findJars(normalized, log);
            log.accept("enabled mod JAR inventory root=" + normalized + " count=" + jars.size());
            if (jars.isEmpty()) continue;
            Path descriptorPath = normalized.resolve("knoxbridge.properties");
            if (!Files.isRegularFile(descriptorPath)) {
                for (Path jar : jars) found.add(new Candidate(normalized, null,
                    "JAR has no KnoxBridge module descriptor; the author must add KnoxBridge compatibility", jar));
                continue;
            }
            try {
                ModuleDescriptor descriptor = ModuleDescriptor.read(normalized);
                found.add(new Candidate(normalized, descriptor, null, descriptor.jar()));
                for (Path jar : jars) if (!jar.equals(descriptor.jar())) found.add(new Candidate(normalized, null,
                    "JAR is not the entry point named by knoxbridge.properties", jar));
            } catch (IOException | RuntimeException e) {
                for (Path jar : jars) found.add(new Candidate(normalized, null,
                    "Invalid KnoxBridge descriptor: " + e.getMessage(), jar));
                log.accept("module incompatible path=" + normalized + " reason=" + e.getMessage());
            }
        }
        java.util.Map<String, Long> counts = found.stream().filter(c -> c.descriptor() != null)
            .collect(java.util.stream.Collectors.groupingBy(c -> c.descriptor().id(), java.util.stream.Collectors.counting()));
        List<Candidate> checked = new ArrayList<>(found.size());
        for (Candidate candidate : found) {
            if (candidate.descriptor() != null && counts.get(candidate.descriptor().id()) > 1) {
                log.accept("module incompatible id=" + candidate.descriptor().id() + " reason=duplicate-id");
                checked.add(new Candidate(candidate.modRoot(), candidate.descriptor(), "duplicate module id", candidate.jar()));
            } else checked.add(candidate);
        }
        return List.copyOf(checked);
    }

    private static Set<Path> findJars(Path root, Consumer<String> log) {
        Set<Path> jars = new HashSet<>();
        try (Stream<Path> paths = Files.find(root, 12, (path, attributes) -> attributes.isRegularFile()
                && path.getFileName().toString().toLowerCase(java.util.Locale.ROOT).endsWith(".jar"))) {
            paths.map(path -> path.toAbsolutePath().normalize()).forEach(jars::add);
        } catch (IOException | SecurityException e) {
            log.accept("enabled mod JAR scan failed path=" + root + " reason=" + e.getClass().getSimpleName());
        }
        return jars;
    }
}
