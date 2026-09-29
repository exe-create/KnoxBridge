# Compatibility and research notes

The installed Windows target was live-tested on 2026-09-28 through normal Steam Play and reported PZ 42.21.0 / Java 25.0.1. That live session used the pre-alpha2 runtime source. PZ supplied the resolved roots for two enabled mods, the independent example and Knox Survivors. Both unknown JARs were blocked on the first run. After exact-hash approval and restart, both modules loaded; the test module initialized and registered its probe, and Knox reported required patch readiness and `KnoxJavaBridge` exposure. Uninstall restored the exact original config; normal Steam started without a new runtime log, then reinstall and Steam startup loaded both modules again. A narrow live Knox probe then logged native NPC spawn, movement transitions, bat attacks, and zombie health reaching zero, with one stuck-route report. Alpha2 passed offline checks, installer fixtures and the copied-launcher smoke; the full game was not rerun after packaging/version changes. Full pathing, awareness, persistence, deny/changed-hash policy, and live 42.20 remain unverified.

The new Linux/macOS setup helper edits the Steam `localconfig.vdf` launch option using a small independent VDF tokenizer and uses the same Java agent JAR. Its install, update, and preservation logic has offline fixtures only; no Linux or macOS PZ/Steam process has been tested. Do not treat Unix support as live verified.

Public ZombieBuddy issue #53 reports that its 42.21 `ZomboidFileSystem.loadMods` hook did not bind when the method parameter changed from `ArrayList<String>` to `List<String>`. Our installed JAR independently reports the `List` descriptor. KnoxBridge targets that exact API descriptor, and its fixture passes an `ArrayList` at runtime to a method declared with `List`. It does not guess when a future PZ build changes the declared method signature.

Public documentation shows these externally visible ZombieBuddy concepts: early JVM startup, `javaJarFile`/`javaPkgName` metadata, unknown/changed-JAR approval using SHA-256, lifecycle entry points, and a Lua-visible status API. KnoxBridge keeps only the interoperability problem space in view. It uses its own `knoxbridge.properties`, exact-hash store and `KnoxModule` API, and did not reuse its source, classes, algorithms, patch engine, names, or trust data. Supporting a limited legacy metadata parser is not implemented.

## ZombieBuddy research summary

Public installation docs describe a one-time early bootstrap: direct Java-agent startup on Unix-like systems and a Windows `zbNative` agentlib route that loads the Java agent and stages updates when a running JAR cannot be replaced. Its modding guide documents Java-JAR/package metadata, early and normal entry points, and annotation-based patch contracts. Its approval UX identifies new or changed JARs by SHA-256 and lets players persist or session-limit allow/deny decisions. Public Lua docs expose runtime/module status. These are useful user problems and lifecycle examples; none of those implementation artifacts are used here.

KnoxBridge uses a Java agent core and a small Windows configurator that edits only its owned JSON VM arguments. It captures PZ's active mod list at the public PZ `loadMods(List)` boundary, uses its own descriptor/API, records exact binary trust, supports isolated or system class-loader policies, and reports status through its own log. It does not copy ZombieBuddy's native loader, patch annotations, class names, metadata, algorithm, approval store or update mechanism. For 42.21 signature drift, KnoxBridge binds only the exact observed PZ `loadMods(List)` contract and emits an incompatibility if it changes again.

Sources consulted: [ZombieBuddy installation](https://github.com/zed-0xff/ZombieBuddy/blob/master/doc/Installation.md), [modding guide](https://github.com/zed-0xff/ZombieBuddy/blob/master/doc/ModdingGuide.md), [Lua API](https://github.com/zed-0xff/ZombieBuddy/blob/master/doc/LuaAPI.md), [42.21 issue #53](https://github.com/zed-0xff/ZombieBuddy/issues/53), and [PZ 42.21 release announcement](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/).

## Still requiring exact 42.21 evidence

- Deny, changed-hash, and disabled-mod behavior for live Java modules.
- Full Knox movement/awareness and save/reload acceptance.
- Live Build 42.20 compatibility.
- Live Linux and macOS Steam startup, uninstall, and module-loading acceptance.
