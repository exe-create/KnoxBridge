package com.knoxbridge.runtime;

import java.io.IOException;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

/** Inspects only the mod roots supplied by a PZ-version-specific enabled-mod adapter. */
final class ModuleDiscovery {
    record Candidate(Path modRoot, ModuleDescriptor descriptor, String problem) { }

    static List<Candidate> inspectEnabledRoots(List<Path> enabledRoots, Consumer<String> log) {
        List<Candidate> found = new ArrayList<>();
        for (Path root : enabledRoots) {
            Path normalized = root.toAbsolutePath().normalize();
            if (!normalized.toFile().isDirectory()) { log.accept("mod root missing path=" + normalized); continue; }
            if (!normalized.resolve("knoxbridge.properties").toFile().isFile()) continue;
            try {
                ModuleDescriptor descriptor = ModuleDescriptor.read(normalized);
                found.add(new Candidate(normalized, descriptor, null));
            } catch (IOException | RuntimeException e) {
                found.add(new Candidate(normalized, null, e.getMessage()));
                log.accept("module incompatible path=" + normalized + " reason=" + e.getMessage());
            }
        }
        java.util.Map<String, Long> counts = found.stream().filter(c -> c.descriptor() != null)
            .collect(java.util.stream.Collectors.groupingBy(c -> c.descriptor().id(), java.util.stream.Collectors.counting()));
        List<Candidate> checked = new ArrayList<>(found.size());
        for (Candidate candidate : found) {
            if (candidate.descriptor() != null && counts.get(candidate.descriptor().id()) > 1) {
                log.accept("module incompatible id=" + candidate.descriptor().id() + " reason=duplicate-id");
                checked.add(new Candidate(candidate.modRoot(), candidate.descriptor(), "duplicate module id"));
            } else checked.add(candidate);
        }
        return List.copyOf(checked);
    }
}
