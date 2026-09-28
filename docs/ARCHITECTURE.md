# Architecture

## Ownership

`runtime-api` is the stable, small contract modules compile against. `runtime-core` is an early Java agent that owns module metadata, hashing, trust decisions, isolated module class loaders, lifecycle, patch registration/dispatch, and diagnostics. `test-module` is an unrelated example PZ mod and is built independently from Knox Survivors. Windows setup scripts own a single exact JVM argument and their own backup/state files.

KnoxBridge does not own any Knox gameplay, survivor persistence, Lua bridge, or NPC state. A later Knox adapter can continue exposing `KnoxJavaBridge` from Knox's own Java module. One runtime per process is the policy; users must remove or disable another Java-agent bootstrap before installing KnoxBridge.

## Startup and discovery

The selected Windows route is an ordered native preloader (`-agentpath`) followed by the Java agent (`-javaagent`) in `ProjectZomboid64.json`, allowing Steam to remain the normal launch surface. A copied `ProjectZomboid64.exe` fixture using the bundled Java 25 JRE confirmed the native preloader fixes the wrapper's `instrument.dll` dependency lookup. A normal Steam AppID launch on 2026-09-28 started the installed game and logged Java 25.0.1, PZ build 42.21.0, and a successful application of the `loadMods(List)` discovery adapter. The current mod context had zero active IDs, so enabled-mod resolution and module loading are still open. The actual JSON's exact pre-install bytes are backed up under KnoxBridge ownership; its backup hash was verified. The older `.bat.knox-bak` was left untouched.

The PZ adapter instruments exactly `ZomboidFileSystem.loadMods(List)` and captures `getModIDs()` after that method returns. For each captured ID, it calls PZ's `getModDir` and `getModInfoForDir`, then checks only that mod's selected version directory (falling back to its resolved root when the descriptor is there). The installed PZ JAR exposes the expected APIs; the optional `verifyPzApi` task checks the method descriptor. The transformed fixture proves an `ArrayList` caller is accepted through the method's declared `List` contract. The live 42.21.0 process confirms the transform was applied and its callback ran, but the observed list was empty. The explicit `knoxbridge.enabledModPaths` property is retained only as a development override.

At agent startup, KnoxBridge checks JVM input arguments for another Java agent or ZombieBuddy's Windows `zbNative` agentlib. On conflict it reports that KnoxBridge is disabled and leaves PZ startup to continue.

## Loading and compatibility

Each module gets a separate `URLClassLoader`; it inherits the runtime/API and PZ classes through the parent. Module metadata must provide a module ID, version, API version, entrypoint and a relative JAR path. Duplicate IDs are rejected for the later candidate. Modules with an unknown API version or invalid JAR path are blocked. Module initialization errors are attributed to that module and do not by themselves abort PZ startup.

The patch engine first requires the exact target class and method name. If no descriptor is given, exactly one method with that name must exist; zero is missing and multiple are ambiguous. A descriptor, when supplied, must match exactly. The module supplies the byte transformation function. This prevents the runtime from guessing a method by name, but does not automatically rewrite unsafe patch code or guarantee a target's semantics across game updates.

## Bootstrap design decision

A direct Java agent worked with the bundled `java.exe` but failed under the PZ Windows launcher: its JVM could not resolve `instrument.dll`'s JRE dependencies. The native shim now sets the process DLL search directory to the JRE bundled beside the game before the Java agent loads. It derives the game path from its own location and changes no global environment or registry values. A copied-launcher smoke confirmed the sequence on the installed Java 25 runtime. Real Steam startup and a PZ launch remain required before player recommendation. Linux and macOS can use platform-specific bootstrap implementations while sharing the Java API/core.

ZombieBuddy public docs describe a Windows native workaround for the same broad JVM DLL-loading constraint. KnoxBridge's helper is independently authored and only calls Windows `SetDllDirectoryW` for the sibling PZ JRE; it does not depend on or reuse ZombieBuddy code, DLLs, classes, annotations, patch engine, or trust store.
