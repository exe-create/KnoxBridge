package com.knoxbridge.runtime;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.function.Consumer;

/** Resolves only roots returned by PZ's active getModIDs() list. */
final class PzModDiscovery {
    static List<Path> resolve(Object fileSystem, Collection<?> activeIds, Consumer<String> log) {
        LinkedHashSet<Path> roots = new LinkedHashSet<>();
        try {
            var getDirectory = fileSystem.getClass().getMethod("getModDir", String.class);
            var getInfo = fileSystem.getClass().getMethod("getModInfoForDir", String.class);
            for (Object rawId : activeIds) {
                if (!(rawId instanceof String id) || id.isBlank()) continue;
                try {
                    Object rawRoot = getDirectory.invoke(fileSystem, id);
                    if (!(rawRoot instanceof String rootText) || rootText.isBlank()) {
                        log.accept("enabled mod path missing id=" + id);
                        continue;
                    }
                    Path base = Path.of(rootText);
                    if (!base.isAbsolute()) base = Path.of(System.getProperty("user.dir")).resolve(base);
                    Object info = getInfo.invoke(fileSystem, rootText);
                    String versionDir = (String) info.getClass().getMethod("getVersionDir").invoke(info);
                    Path selected = versionDir == null || versionDir.isBlank() ? base : base.resolve(versionDir);
                    selected = selected.toAbsolutePath().normalize();
                    if (Files.isDirectory(selected)) {
                        roots.add(selected);
                        log.accept("enabled mod root id=" + id + " path=" + selected);
                    } else if (Files.isDirectory(base)) {
                        roots.add(base.toAbsolutePath().normalize());
                        log.accept("enabled mod root id=" + id + " path=" + base.toAbsolutePath().normalize());
                    } else log.accept("enabled mod root unavailable id=" + id);
                } catch (Throwable failure) {
                    log.accept("enabled mod resolve failed id=" + id + " reason=" + failure);
                }
            }
        } catch (Throwable failure) {
            log.accept("discovery adapter failed reason=" + failure);
        }
        return List.copyOf(roots);
    }
}
