# Development and acceptance

Run `gradlew verify` for the Java module/runtime verifier and independent example-module build. Run `powershell -ExecutionPolicy Bypass -File scripts/verify-installer.ps1` for isolated fixture installation checks. These prove only offline logic and packaging. A clean rebuild initially exposed and fixed a missing `runtime-api:jar` dependency in the shaded agent task; `gradlew clean verify packageRuntime` now passed.

The local Windows launcher fixture passed with Java 25.0.1 after loading the native preloader before the Java agent. A live Steam AppID launch on 2026-09-28 then reached the installed Project Zomboid 42.21.0 process. KnoxBridge reported startup, Java 25.0.1, PZ 42.21.0, successful discovery adapter transformation, callback execution with zero active mod IDs, and `runtime ready modules=0`.

To inspect a local game JAR without modifying it, run `gradlew :runtime-core:verifyPzApi '-PpzJar=<path to projectzomboid.jar>'`. The verifier reports whether the exact `loadMods(List)` descriptor is present. `gradlew packageRuntime` creates a ZIP containing the agent JAR, checksums, installer scripts, docs, and staged independent example mod.

`scripts/verify-windows-bootstrap.ps1 -GameDirectory <PZ folder>` copies the PZ Windows launcher and its adjacent DLLs into an isolated fixture, links the bundled JRE, and gives it a tiny non-game main class plus a separate config containing the native preloader and Java agent. It does not modify the game folder or start Project Zomboid. It verifies the wrapper-to-JVM bootstrap on Java 25; it does not prove normal Steam behavior, active-mod timing or game startup.

## Current Build 42.21 live acceptance checklist

- [x] Steam AppID launch starts installed PZ with the agent and without a separate recurring launcher.
- [x] Runtime starts early and reports PZ build 42.21.0 and Java 25.0.1.
- [x] Exact `ZomboidFileSystem.loadMods(List)` transformation applies and callback executes.
- [ ] Only mods enabled for the current game context are offered for discovery.
- [ ] Unknown module waits for an explicit allow/deny decision.
- [ ] Approved independent example module initializes; lifecycle init is logged. Its optional no-op patch target is fixture-only and is not proof of a live PZ patch.
- [ ] Denied and changed-hash modules do not load.
- [ ] Disabling the Java-enabled PZ mod prevents discovery/loading.
- [ ] Knox Survivors module integration preserves `KnoxJavaBridge`, Lua simulation, and save schema.
- [ ] Representative Knox NPC creation, movement, awareness, combat, damage, and save/load still work.
- [ ] Uninstall restores ordinary Steam startup.

Live bootstrap and adapter installation are checked; enabled-module loading, trust policy, module lifecycle, uninstall/restore, and all Knox integration checks remain open.
