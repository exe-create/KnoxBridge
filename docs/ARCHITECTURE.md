# Architecture

## Ownership

`runtime-api` is the small contract that Java modules build against. `runtime-core` owns metadata checks, JAR hashing, exact-hash trust, class loading, lifecycle, patch registration, and diagnostics. `test-module` is an independent example PZ mod. The self-contained Windows installer owns only KnoxBridge's startup arguments and backup/state files; the Unix setup script owns its single Steam launch-option entry.

KnoxBridge owns no Knox gameplay, survivor persistence, Lua bridge, or NPC state. Knox Survivors is a normal client module that supplies its Java bridge and PZ-specific patches. One instrumentation runtime per PZ process is the policy.

## Startup and discovery

On Windows, an ordered native preloader (`-agentpath`) then Java agent (`-javaagent`) are stored in PZ's `ProjectZomboid64.json`. That lets players keep Steam's normal **Play** button and requires no Steam Launch Options. The native preloader prepares the bundled JRE's DLL search path before agent startup. The installer backs up the exact original JSON and records ownership; the actual uninstall restored the original SHA-256, normal Steam launched without a new KnoxBridge log, and reinstall passed.

The agent instruments exactly `ZomboidFileSystem.loadMods(List)` and reads `getModIDs()` after the method returns. For each ID PZ actually resolved, KnoxBridge asks PZ for that mod's selected root, then checks only its metadata and declared JAR. It does not scan Workshop folders or load disabled modules. In a normal Steam Play launch on 2026-09-28, PZ 42.21.0 / Java 25.0.1 supplied the enabled roots for `KnoxBridgeIndependentTest` and `KnoxSurvivors`. Unknown hashes were blocked on the first run. After approval and restart, both module entrypoints loaded.

## Module loading and trust

A module declares ID, version, API version, entrypoint, and an in-root JAR path. The default `isolated` policy uses a separate `URLClassLoader`. `classLoader=system` appends the module JAR to the system loader; Knox uses this because its transformed PZ classes must resolve helper methods. `ModuleContext.instrumentation()` gives the trusted module the instrumentation handle. Modules have normal JVM permissions and are not sandboxed.

JAR SHA-256 is the trust identity. Unknown hashes are blocked by default. The Bridge Workshop Lua screen inventories JARs found under PZ-enabled mod roots and writes exact-hash allow/deny choices to a versioned queue in the user's Zomboid Lua directory. Before module loading on the next launch, the agent validates the complete queue and imports the choices into the trust store; malformed or incomplete queues fail closed. Newly allowed modules are not loaded late from Lua because instrumentation may have missed early startup classes. The screen may show declared PZ mod names and authors, clearly labeled unverified metadata. Only a valid KnoxBridge descriptor/API entry point can load; unrelated or unsupported JARs are visible but remain blocked. Duplicate module IDs, unsupported API versions, invalid paths, and malformed descriptors are reported and skipped. A module initialization failure is attributed to that module and does not by itself abort PZ startup.

## Patches

The patch engine validates exact class/method targets and requires a unique target when no descriptor is provided. Module code supplies the actual transformation. The runtime does not guess overloaded targets or guarantee that patch code remains semantically correct after a PZ update.

Knox's 42.21 module reported its required combat and visibility hooks ready, exposed `KnoxJavaBridge`, and later logged a native NPC probe spawn, movement transitions, bat attacks, and zombie health reaching zero. A stuck movement route was also recorded. These are narrow live runtime/hook results, not full gameplay, pathing, awareness, or persistence acceptance.

## Bootstrap safety

A direct agent could not resolve `instrument.dll` dependencies under the PZ Windows wrapper. The independent native shim sets the process DLL search path to the bundled PZ JRE before Java starts; it changes no system PATH or registry values. Linux and macOS use the Java agent directly through Steam's per-user `LaunchOptions` entry; setup edits only that VDF property and has hash-aware restore behavior. This Unix installation path has not yet been live-tested against a PZ process on those operating systems.
