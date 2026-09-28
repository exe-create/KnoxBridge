# Compatibility and research notes

The first target is PZ Build 42.21, but this repository has not yet proven runtime compatibility. The local installed game contains a PZ JSON launch definition and bundled Java 25.0.1; the local Knox Survivors source/build evidence predates 42.21 and is not runtime proof. The installed PZ JAR signature probe reports `loadMods(String)` and `loadMods(List)`; other public methods used by the adapter were inspected in that JAR. This is offline bytecode evidence, not proof the agent callback executes successfully in game.

Public ZombieBuddy issue #53 reports that its 42.21 `ZomboidFileSystem.loadMods` hook did not bind when the method parameter changed from `ArrayList<String>` to `List<String>`. Our installed JAR independently reports the `List` descriptor. KnoxBridge targets that exact API descriptor, and its fixture passes an `ArrayList` at runtime to a method declared with `List`. It does not guess when a future PZ build changes the declared method signature.

Public documentation shows these externally visible ZombieBuddy concepts: early JVM startup, `javaJarFile`/`javaPkgName` metadata, unknown/changed-JAR approval using SHA-256, lifecycle entry points, and a Lua-visible status API. KnoxBridge keeps only the interoperability problem space in view. It uses its own `knoxbridge.properties`, exact-hash store and `KnoxModule` API, and did not reuse its source, classes, algorithms, patch engine, names, or trust data. Supporting a limited legacy metadata parser is not implemented.

## ZombieBuddy research summary

Public installation docs describe a one-time early bootstrap: direct Java-agent startup on Unix-like systems and a Windows `zbNative` agentlib route that loads the Java agent and stages updates when a running JAR cannot be replaced. Its modding guide documents Java-JAR/package metadata, early and normal entry points, and annotation-based patch contracts. Its approval UX identifies new or changed JARs by SHA-256 and lets players persist or session-limit allow/deny decisions. Public Lua docs expose runtime/module status. These are useful user problems and lifecycle examples; none of those implementation artifacts are used here.

KnoxBridge deliberately begins with a platform-neutral Java agent core and a small Windows configurator that edits one owned JSON VM argument. It captures PZ's active mod list at the public PZ `loadMods(List)` boundary, uses a separate native descriptor/API, records exact binary trust, isolates module JARs, and reports status through its own log. It does not copy ZombieBuddy's native loader, patch annotations, class names, metadata, algorithm, approval store or update mechanism. Interactive approval, signatures and Lua status are later work. For 42.21 signature drift, KnoxBridge binds only the exact observed PZ `loadMods(List)` contract and emits an incompatibility if it changes again.

Sources consulted: [ZombieBuddy installation](https://github.com/zed-0xff/ZombieBuddy/blob/master/doc/Installation.md), [modding guide](https://github.com/zed-0xff/ZombieBuddy/blob/master/doc/ModdingGuide.md), [Lua API](https://github.com/zed-0xff/ZombieBuddy/blob/master/doc/LuaAPI.md), [42.21 issue #53](https://github.com/zed-0xff/ZombieBuddy/issues/53), and [PZ 42.21 release announcement](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/).

## Still requiring exact 42.21 evidence

- Steam starts the same launcher/config path used by the copied-launcher fixture.
- The agent executes before relevant PZ classes/mod discovery.
- PZ version/build can be detected reliably at that point.
- The live timing of this adapter relative to PZ's other Java and Lua mod initialization.
- Java 25 instrumentation and transformation behavior in the actual game.
- Duplicate-runtime detection against active process arguments/native bootstrap.
- At least one exact safe patch against the 42.21 game JAR.
- Knox Survivors and an independent module live load, denial, and disabled-mod behavior.
