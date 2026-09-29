# Module API and author quick start

KnoxBridge loads an author's Java module only from a Project Zomboid-enabled mod root and only after its descriptor, API version, JAR digest and player trust check pass. It is a general runtime API; Knox Survivors is a first-party consumer, not a promise that outside modules are supported or compatible.

## Build a minimal module

1. Obtain `runtime-api-<version>.jar` from the KnoxBridge Workshop item's `developer/lib` directory, or build it from source with `gradlew :runtime-api:jar` (output: `runtime-api/build/libs`). This is the **compile-time API**, not the player runtime agent and not a player installer. Players separately install the runtime using the setup package described in [Installation](INSTALLATION.md).
2. Build the supplied standalone example in `examples/minimal-module` using the included Gradle project. With the repository checkout's wrapper, run:

   ```powershell
   ./gradlew -p examples/minimal-module build "-PknoxbridgeApiJar=C:/path/to/runtime-api-0.1.0-alpha9.jar"
   ```

   This project requires Java 17 and Gradle 8.14.3 or newer. The example is also included at `developer/example` in the Workshop payload; there, run `gradle build "-PknoxbridgeApiJar=<path to ../lib/runtime-api-<version>.jar>"`. Alternatively copy the Workshop `developer/lib/runtime-api-<version>.jar` to `lib/runtime-api.jar` and omit the `-P` argument. The resulting module JAR is `build/libs/minimal-module.jar`. Do not bundle a second copy of `com.knoxbridge.api` in your module JAR. The separate `test-module` is KnoxBridge's runtime fixture, not a PZ compatibility guarantee.
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

5. Copy the example's `mod.info` and `knoxbridge.properties` into your mod's `42/` folder, then edit the descriptor as needed. All five non-comment fields are required:

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

Minimal entrypoint:

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

The API has no committed binary/source compatibility or deprecation policy yet. `apiVersion=1` is the currently accepted module contract version, not a promise of future stability or compatibility with a particular PZ build. Check the release notes and rebuild/test against the API JAR shipped for the runtime you target. A future incompatible API change may require a new API version and author migration; no automatic migration is promised. Keep module versions and release notes so users can identify changed JARs; every changed JAR has a new trust hash.

## Diagnostics and common packaging mistakes

The player log is `%USERPROFILE%/Zomboid/KnoxBridge/knoxbridge.log` on Windows (equivalent `~/Zomboid/KnoxBridge/knoxbridge.log` elsewhere). Useful messages include `module incompatible ... reason=api-version`, descriptor/path errors such as `missing entrypoint` or `jar path escapes mod root`, `module blocked ... APPROVAL_REQUIRED`, and `module failed ... reason=...`. Check the exact mod root PZ enabled, case-sensitive entrypoint spelling, relative JAR path, and API version before changing runtime configuration. A module JAR by itself, or the compile-time API JAR, is not a loadable module: it needs its descriptor and a `KnoxModule` entrypoint.

An author name in `mod.info` is unverified metadata. KnoxBridge does not authenticate module authors, sandbox Java code, or guarantee outside-author support/compatibility.
