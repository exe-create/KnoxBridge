package com.knoxbridge.runtime;

import java.lang.instrument.Instrumentation;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.BiConsumer;
import java.lang.management.ManagementFactory;

/** Early JVM bootstrap and PZ-specific adapter owner. */
public final class KnoxBridgeAgent {
    private static final String VERSION = KnoxBridgeAgent.class.getPackage().getImplementationVersion() == null
        ? "0.1.0-alpha4" : KnoxBridgeAgent.class.getPackage().getImplementationVersion();
    private static final AtomicBoolean STARTED = new AtomicBoolean();
    private static final AtomicBoolean MODULES_STARTED = new AtomicBoolean();
    private static final List<ModuleLoader.LoadedModule> LOADED = new CopyOnWriteArrayList<>();
    private static volatile RuntimeLog log;
    private static volatile Instrumentation instrumentation;
    private static volatile PatchEngine patchEngine;
    private static volatile BiConsumer<Object, List<?>> testObserver;

    private KnoxBridgeAgent() { }
    public static void premain(String args, Instrumentation instrumentation) { start(instrumentation); }
    public static void agentmain(String args, Instrumentation instrumentation) { start(instrumentation); }

    private static void start(Instrumentation inst) {
        if (!STARTED.compareAndSet(false, true)) return;
        instrumentation = inst;
        log = new RuntimeLog();
        log.write("KnoxBridge runtime start PASS version=" + VERSION + " at=" + Instant.now());
        log.write("java version=" + System.getProperty("java.version") + " platform=" + System.getProperty("os.name"));
        List<String> inputArgs = ManagementFactory.getRuntimeMXBean().getInputArguments();
        if (hasCompetingBootstrap(inputArgs)) {
            log.write("runtime conflict reason=another-java-runtime-active action=knoxbridge-disabled args="
                + inputArgs.stream().filter(a -> a.toLowerCase().contains("javaagent") || a.toLowerCase().contains("agentlib:zbNative")).toList());
            return;
        }
        String explicitRoots = System.getProperty("knoxbridge.enabledModPaths", "");
        if (!explicitRoots.isBlank()) {
            log.write("discovery source=explicit-development-override");
            List<Path> roots = Arrays.stream(explicitRoots.split(java.util.regex.Pattern.quote(System.getProperty("path.separator"))))
                .filter(s -> !s.isBlank()).map(Path::of).toList();
            if (MODULES_STARTED.compareAndSet(false, true)) startModules(roots);
        } else {
            PzEnabledModTransformer adapter = new PzEnabledModTransformer(log::write);
            boolean canRetransform = inst.isRetransformClassesSupported();
            inst.addTransformer(adapter, canRetransform);
            boolean alreadyLoaded = Arrays.stream(inst.getAllLoadedClasses())
                .anyMatch(c -> c.getName().equals("zombie.ZomboidFileSystem"));
            if (alreadyLoaded && canRetransform) {
                try {
                    Class<?> target = Arrays.stream(inst.getAllLoadedClasses())
                        .filter(c -> c.getName().equals("zombie.ZomboidFileSystem")).findFirst().orElseThrow();
                    if (inst.isModifiableClass(target)) inst.retransformClasses(target);
                } catch (Throwable e) { log.write("discovery adapter install failed reason=" + e); }
            }
            log.write("discovery adapter armed target=zombie.ZomboidFileSystem.loadMods(Ljava/util/List;)V");
        }
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            for (int i = LOADED.size() - 1; i >= 0; i--) try { LOADED.get(i).close(); }
            catch (Exception e) { log.write("module shutdown failed reason=" + e); }
        }, "KnoxBridge-shutdown"));
    }

    /** Called by the narrow bytecode adapter after PZ has populated its active mod list. */
    public static void onPzModsLoaded(Object fileSystem, List<?> activeIds) {
        BiConsumer<Object, List<?>> observer = testObserver;
        if (observer != null) { observer.accept(fileSystem, List.copyOf(activeIds)); return; }
        if (!STARTED.get() || !MODULES_STARTED.compareAndSet(false, true)) return;
        try {
            log.write("PZ build detected=" + detectPzVersion());
            log.write("enabled mods discovered count=" + activeIds.size());
            List<Path> roots = PzModDiscovery.resolve(fileSystem, activeIds, log::write);
            startModules(roots);
        } catch (Throwable failure) {
            log.write("runtime startup failed after mod discovery reason=" + failure);
        }
    }

    static void setTestObserver(BiConsumer<Object, List<?>> observer) { testObserver = observer; }

    static boolean hasCompetingBootstrap(List<String> inputArgs) {
        return inputArgs.stream().anyMatch(arg -> {
            String lower = arg.toLowerCase();
            return lower.contains("agentlib:zbnative")
                || (lower.startsWith("-agentpath:") && !lower.contains("knoxbridge-bootstrap"))
                || (lower.startsWith("-javaagent:") && !lower.contains("knoxbridge-agent"));
        });
    }

    private static String detectPzVersion() {
        try {
            Class<?> core = Class.forName("zombie.core.Core");
            Object instance = core.getMethod("getInstance").invoke(null);
            Object value = core.getMethod("getGameAndBuildVersion").invoke(instance);
            return String.valueOf(value);
        } catch (Throwable e) { return "unknown"; }
    }

    private static void startModules(List<Path> roots) {
        List<ModuleDiscovery.Candidate> candidates = ModuleDiscovery.inspectEnabledRoots(roots, log::write);
        patchEngine = new PatchEngine(log::write);
        instrumentation.addTransformer(patchEngine, instrumentation.isRetransformClassesSupported());
        Path trustPath = Path.of(System.getProperty("user.home"), "Zomboid", "KnoxBridge", "trust.properties");
        TrustStore trust;
        try { trust = new TrustStore(trustPath); }
        catch (Exception e) { log.write("runtime fatal reason=trust-store-unavailable error=" + e); return; }
        for (ModuleDiscovery.Candidate candidate : candidates) {
            ModuleDescriptor d = candidate.descriptor();
            if (d == null || candidate.problem() != null) continue;
            if (!"1".equals(d.apiVersion())) { log.write("module incompatible id=" + d.id() + " reason=api-version"); continue; }
            try {
                String hash = Hashing.sha256(d.jar());
                trust.observe(hash, d.id(), candidate.modRoot());
                log.write("module discovered id=" + d.id() + " source=" + candidate.modRoot() + " hash=" + hash);
                TrustStore.Decision decision = trust.check(hash);
                if (decision != TrustStore.Decision.ALLOW_ONCE && decision != TrustStore.Decision.ALLOW_EXACT) {
                    log.write("module approval required id=" + d.id() + " decision=" + decision);
                    continue;
                }
                LOADED.add(ModuleLoader.load(d, d.jar(), VERSION, patchEngine, instrumentation, log::write));
            } catch (Throwable failure) { log.write("module failed id=" + d.id() + " reason=" + failure); }
        }
        retransformRegisteredTargets();
        log.write("runtime ready modules=" + LOADED.size());
    }

    private static void retransformRegisteredTargets() {
        if (!instrumentation.isRetransformClassesSupported() || patchEngine == null) return;
        for (Class<?> type : instrumentation.getAllLoadedClasses()) {
            if (!patchEngine.targetsClass(type.getName()) || !instrumentation.isModifiableClass(type)) continue;
            try {
                instrumentation.retransformClasses(type);
                log.write("patch retransform requested class=" + type.getName());
            } catch (Throwable e) { log.write("patch retransform failed class=" + type.getName() + " reason=" + e); }
        }
    }
}
