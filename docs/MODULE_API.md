# Module API and author quick start

KnoxBridge loads an author's Java module only from a Project Zomboid-enabled mod root and only after its descriptor, API version, JAR digest and player trust check pass. It is a general runtime API; Knox Survivors is a first-party consumer, not a promise that outside modules are supported or compatible.

## Build a minimal module

1. Obtain `runtime-api-<version>.jar` from the KnoxBridge Workshop item's `developer/lib` directory, or build it from source with `gradlew :runtime-api:jar` (output: `runtime-api/build/libs`). This is the **compile-time API**, not the player runtime agent and not a player installer. Players separately install the runtime using the setup package described in [Installation](INSTALLATION.md).
2. Build the supplied standalone example in `examples/minimal-module` using the included Gradle project. With the repository checkout's wrapper, run:

   ```powershell
   ./gradlew -p examples/minimal-module stagePzMod "-PknoxbridgeApiJar=C:/path/to/runtime-api-0.1.0-alpha10.jar"
   ```

   This project requires a Java 17 JDK and Gradle 8.14.3 or newer; Gradle resolves the pinned ASM 9.10.1 compile-time author-tool dependency from Maven Central. The example is also included at `developer/example` in the Workshop payload. From there, run:

   ```powershell
   gradle -p developer/example stagePzMod "-PknoxbridgeApiJar=../lib/runtime-api-<version>.jar"
   ```

   The module JAR is `build/libs/minimal-module.jar`; the ready-to-copy PZ mod directory is `build/staged-mod/KnoxBridgeMinimalExample`. It contains mod metadata, a descriptor, and the module JAR. Alternatively copy the Workshop API JAR to `developer/example/lib/runtime-api.jar` and omit the `-P` argument. Do not bundle duplicate `com.knoxbridge.api` or `org.objectweb.asm` classes in your module JAR: the matching KnoxBridge runtime supplies both. The separate `test-module` is a KnoxBridge runtime fixture, not a PZ compatibility guarantee.
3. Implement a public, no-argument-constructible class implementing `KnoxModule`. Put the class and any private helper classes in your module JAR.
4. Place `knoxbridge.properties` at the mod root beside `mod.info`, and place the module JAR at the declared relative path. For a Build 42 mod layout:

   ```text
   MyMod/
     mod.info
     42/
       mod.info
       knoxbridge.properties
       media/java/my-module.jar
   ```

5. The example's `knoxbridge.properties` shows the complete descriptor. Copy it into your mod's selected PZ version directory (for example `42/`) beside that directory's `mod.info`, edit its values, and update `jar=` if your JAR name/path differs. All five non-comment fields are required:

   ```properties
   id=org.example.mymod
   version=1.0.0
   apiVersion=1
   entrypoint=org.example.mymod.MyModule
   jar=media/java/my-module.jar
   # Optional: isolated (default) or system
   classLoader=isolated
   ```

   `id` cannot contain spaces, `/`, or `\\`; duplicate IDs across discovered modules are incompatible. Other ID/version formatting is not validated. `apiVersion` must be the literal `1`; unsupported versions are incompatible and are not loaded. The JAR path must be relative, point to a regular file, and remain inside the mod root after normalization and symlink resolution. The descriptor itself must be in that root. Properties values are trimmed. Keep the entrypoint's exact fully qualified Java class name, including case.

6. Compile and package, then verify the PZ adapter against a local game JAR:

   ```powershell
   ./gradlew :runtime-core:verifyPzApi "-PpzJar=C:/path/to/ProjectZomboid/projectzomboid.jar"
   ```

   This offline check verifies the runtime's observed `ZomboidFileSystem.loadMods(List)` method contract. It does not prove your patch targets, module, or game behavior work. For installation and a repeatable live acceptance list, see [Compatibility](COMPATIBILITY.md).
7. Install/enable the mod and KnoxBridge Runtime in PZ. At the main-menu review screen, check the module ID and full JAR SHA-256 before approving. Unknown or changed hashes are blocked by default. Use a disposable save; do not test first on a valued save.

The example includes an ASM-based patch of its harmless `ExampleGreeting.greeting()` fixture. Build and package it with `stagePzMod`, then use the source as a starting point for transformations. To inspect exact signatures from your local game JAR before declaring a target, run:

```powershell
gradle -p developer/example inspectPzMethods `
  "-PknoxbridgeApiJar=../lib/runtime-api-<version>.jar" `
  "-PpzJar=C:/path/to/ProjectZomboid/projectzomboid.jar" `
  "-PtargetClass=zombie.some.package.TargetClass" `
  "-PtargetMethod=methodName"
```

This lists JVM descriptors declared by that class in the JAR; it does not validate patch semantics or establish live game compatibility. The alpha10 author toolkit is pinned to ASM 9.10.1, which the matching runtime supplies; keep it `compileOnly` and do not bundle it. The supported dependency version is recorded in `THIRD_PARTY_NOTICES.md`; rebuild/test against the actual target API/runtime when that version changes.

The bare entrypoint (without a patch) looks like this:

```java
package org.example.mymod;

import com.knoxbridge.api.KnoxModule;
import com.knoxbridge.api.ModuleContext;

public final class MyModule implements KnoxModule {
    @Override
    public void initialize(ModuleContext context) {
        context.logger().accept("ready module=" + context.moduleId());
    }
}
```

## Lifecycle and class loading

The runtime discovers selected enabled-mod roots after PZ resolves its active mod list. For a candidate, it validates the descriptor and API version, hashes the JAR, checks trust, constructs the entrypoint, and calls `initialize(ModuleContext)` once. Initialization receives runtime/module IDs and versions, a diagnostic `Consumer<String>`, patch registrar, and JVM `Instrumentation`. An exception or class-loading failure is logged for that module and prevents that module from loading; it does not itself abort PZ startup. `shutdown()` is called during orderly JVM shutdown, in reverse module load order; do not rely on it after a crash or forced process termination.

`classLoader=isolated` is the default: each module's classes use a per-module URL class loader, parented by the runtime loader. Prefer it for ordinary module-private helpers. `classLoader=system` appends the module JAR to the system class-loader search; choose it only when transformed/system-loaded PZ classes must resolve classes from your module. That choice exposes helpers globally and can create conflicts with other modules. Neither option isolates permissions.

`apiVersion=1` identifies the module contract, not compatibility with a particular PZ build. KnoxBridge's API policy is: additive, binary-compatible additions may remain on the same API version; an incompatible API or descriptor change must use a new API version, and a runtime must explicitly accept that version before modules can use it. No cross-version adapter or automatic migration is promised. During this alpha runtime line, check release notes and rebuild/test against the API JAR shipped for the runtime you target. Keep module versions and release notes so users can identify changes; every changed JAR has a new trust hash.

## Diagnostics and common packaging mistakes

The player log is `%USERPROFILE%/Zomboid/KnoxBridge/knoxbridge.log` on Windows (equivalent `~/Zomboid/KnoxBridge/knoxbridge.log` elsewhere). Useful messages include `module incompatible ... reason=api-version`, descriptor/path errors such as `missing entrypoint` or `jar path escapes mod root`, `module blocked ... APPROVAL_REQUIRED`, and `module failed ... reason=...`. Check the exact mod root PZ enabled, case-sensitive entrypoint spelling, relative JAR path, and API version before changing runtime configuration. A module JAR by itself, or the compile-time API JAR, is not a loadable module: it needs its descriptor and a `KnoxModule` entrypoint.

An author name in `mod.info` is unverified metadata. KnoxBridge does not authenticate module authors, sandbox Java code, or guarantee outside-author support/compatibility.
