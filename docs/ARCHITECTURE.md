# Architecture

## Ownership

`runtime-api` is the stable, small contract modules compile against. `runtime-core` is an early Java agent that owns module metadata, hashing, trust decisions, isolated module class loaders, lifecycle, patch registration/dispatch, and diagnostics. `test-module` is an unrelated example PZ mod and is built independently from Knox Survivors. Windows setup scripts own a single exact JVM argument and their own backup/state files.

KnoxBridge does not own any Knox gameplay, survivor persistence, Lua bridge, or NPC state. A later Knox adapter can continue exposing `KnoxJavaBridge` from Knox's own Java module. One runtime per process is the policy; users must remove or disable another Java-agent bootstrap before installing KnoxBridge.

## Startup and discovery

The selected Windows route is an ordered native preloader (`-agentpath`) followed by the Java agent (`-javaagent`) in `ProjectZomboid64.json`, allowing Steam to remain the normal launch surface. A smoke fixture using a copy of the installed `ProjectZomboid64.exe`, its bundled Java 25 JRE, and a non-game test main confirmed the native preloader fixes the wrapper's `instrument.dll` dependency lookup and the Java agent starts. A direct `java.exe -javaagent` smoke also passes. The actual game was not launched and Steam handoff is still unverified. On the installed game, JSON has a `vmArgs` array and names `zombie/gameStates/MainScreenState`; the local game also has pre-existing Knox backup state. KnoxBridge scripts operate only on an explicitly selected game folder, keep an exact original copy, and do not touch the local game unless a user runs them.

The PZ adapter instruments exactly `ZomboidFileSystem.loadMods(List)` and captures `getModIDs()` after that method returns. For each captured ID, it calls PZ's `getModDir` and `getModInfoForDir`, then checks only that mod's selected version directory (falling back to its resolved root when the descriptor is there). The installed PZ JAR exposes the expected `loadMods(List)`, `getModIDs`, `getModDir`, `getModInfoForDir`, and `Mod.getVersionDir` methods; the optional `verifyPzApi` task checks the method descriptor. The transformed fixture proves an `ArrayList` caller is accepted through the method's declared `List` contract. Steam startup and actual callback timing still need a live 42.21 run. The explicit `knoxbridge.enabledModPaths` property is retained only as a development override.

At agent startup, KnoxBridge checks JVM input arguments for another Java agent or ZombieBuddy's Windows `zbNative` agentlib. On conflict it reports that KnoxBridge is disabled and leaves PZ startup to continue.

## Loading and compatibility

Each module gets a separate `URLClassLoader`; it inherits the runtime/API and PZ classes through the parent. Module metadata must provide a module ID, version, API version, entrypoint and a relative JAR path. Duplicate IDs are rejected for the later candidate. Modules with an unknown API version or invalid JAR path are blocked. Module initialization errors are attributed to that module and do not by themselves abort PZ startup.

The patch engine first requires the exact target class and method name. If no descriptor is given, exactly one method with that name must exist; zero is missing and multiple are ambiguous. A descriptor, when supplied, must match exactly. The module supplies the byte transformation function. This prevents the runtime from guessing a method by name, but does not automatically rewrite unsafe patch code or guarantee a target's semantics across game updates.

## Bootstrap design decision

A direct Java agent worked with the bundled `java.exe` but failed under the PZ Windows launcher: its JVM could not resolve `instrument.dll`'s JRE dependencies. The native shim now sets the process DLL search directory to the JRE bundled beside the game before the Java agent loads. It derives the game path from its own location and changes no global environment or registry values. A copied-launcher smoke confirmed the sequence on the installed Java 25 runtime. Real Steam startup and a PZ launch remain required before player recommendation. Linux and macOS can use platform-specific bootstrap implementations while sharing the Java API/core.

ZombieBuddy public docs describe a Windows native workaround for the same broad JVM DLL-loading constraint. KnoxBridge's helper is independently authored and only calls Windows `SetDllDirectoryW` for the sibling PZ JRE; it does not depend on or reuse ZombieBuddy code, DLLs, classes, annotations, patch engine, or trust store.
