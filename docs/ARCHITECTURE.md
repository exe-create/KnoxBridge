# Architecture

## Ownership

`runtime-api` is the small contract that Java modules build against. `runtime-core` owns metadata checks, JAR hashing, exact-hash trust, class loading, lifecycle, patch registration, and diagnostics. `test-module` is an independent example PZ mod. The self-contained Windows installer owns only KnoxBridge's startup arguments and backup/state files; the Unix setup script owns its single Steam launch-option entry.

KnoxBridge owns no Knox gameplay, survivor persistence, Lua bridge, or NPC state. Knox Survivors is a normal client module that supplies its Java bridge and PZ-specific patches. One instrumentation runtime per PZ process is the policy.

## Startup and discovery

On Windows, an ordered native preloader (`-agentpath`) then Java agent (`-javaagent`) are stored in PZ's `ProjectZomboid64.json`. That lets players keep Steam's normal **Play** button and requires no Steam Launch Options. The native preloader prepares the bundled JRE's DLL search path before agent startup. The installer backs up the exact original JSON and records ownership; the actual uninstall restored the original SHA-256, normal Steam launched without a new KnoxBridge log, and reinstall passed.

The agent instruments exactly `ZomboidFileSystem.loadMods(List)` and reads `getModIDs()` after the method returns. For each ID PZ actually resolved, KnoxBridge asks PZ for that mod's selected root, then checks only its metadata and declared JAR. It does not scan Workshop folders or load disabled modules. In a normal Steam Play launch on 2026-09-28, PZ 42.21.0 / Java 25.0.1 supplied the enabled roots for `KnoxBridgeIndependentTest` and `KnoxSurvivors`. Unknown hashes were blocked on the first run. After approval and restart, both module entrypoints loaded.

## Module loading and trust

A module declares ID, version, API version, entrypoint, and an in-root JAR path. The default `isolated` policy uses a separate `URLClassLoader`. `classLoader=system` appends the module JAR to the system loader; Knox uses this because its transformed PZ classes must resolve helper methods. `ModuleContext.instrumentation()` gives the trusted module the instrumentation handle. Modules have normal JVM permissions and are not sandboxed.

JAR SHA-256 is the trust identity. Unknown hashes are blocked by default. The Bridge Workshop Lua screen inventories JARs found under PZ-enabled mod roots and writes versioned exact-hash allow/deny choices to a queue in the user's Zomboid Lua directory. Before module loading on the next launch, the agent validates the complete queue and imports either one-launch or remembered choices into the trust store; malformed or incomplete queues fail closed. The full-screen review gate opens at the PZ main menu before world entry. Newly allowed modules are not loaded late from Lua because instrumentation may have missed early startup classes; when a choice changes the loaded module set, the player quits and relaunches once. The screen may show declared PZ mod names and authors, clearly labeled unverified metadata. Only a valid KnoxBridge descriptor/API entry point can load; unrelated or unsupported JARs are visible but remain blocked. Duplicate module IDs, unsupported API versions, invalid paths, and malformed descriptors are reported and skipped. A module initialization failure is attributed to that module and does not by itself abort PZ startup.

## Patches

The patch engine validates exact class/method targets and requires a unique target when no descriptor is provided. `registerHook` supplies simple public static no-argument callbacks at entry and normal return; advanced authors can still provide their own ASM transform. The runtime does not guess overloads or guarantee semantic compatibility after a PZ update. Exceptional exits and argument/result binding require a raw transform.

Optional Ed25519 `.knoxsig` sidecars bind module metadata and exact JAR bytes. Invalid present signatures block loading before hash approval is consulted; valid signatures identify a public-key fingerprint without granting publisher trust or approval. Module loading copies the JAR to a temporary snapshot and checks its hash against the reviewed bytes before executing code. The review handoff uses manifest version 4 with separate signer and runtime-anchored publisher fields; the Lua UI also accepts versions 2 and 3 from older agents. See `SECURITY_AND_TRUST.md` for format, key lifecycle, and release-artifact signing.

Modules must be self-contained in the declared JAR (apart from runtime/game APIs); resources inside it remain available. The snapshot is the code-source location, so modules must not rely on neighboring files or external manifest `Class-Path` dependency JARs. Unsupported companion JARs remain inventory entries, never approved module dependencies. Signatures cover the declared JAR and descriptor context, not arbitrary external code or data read by a trusted module.

Knox's 42.21 module reported its required combat and visibility hooks ready, exposed `KnoxJavaBridge`, and later logged a native NPC probe spawn, movement transitions, bat attacks, and zombie health reaching zero. A stuck movement route was also recorded. These are narrow live runtime/hook results, not full gameplay, pathing, awareness, or persistence acceptance.

## Bootstrap safety

A direct agent could not resolve `instrument.dll` dependencies under the PZ Windows wrapper. The independent native shim sets the process DLL search path to the bundled PZ JRE before Java starts; it changes no system PATH or registry values. Linux and macOS use the Java agent directly through Steam's per-user `LaunchOptions` entry; setup edits only that VDF property and has hash-aware restore behavior. This Unix installation path has not yet been live-tested against a PZ process on those operating systems.
