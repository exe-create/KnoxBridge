# Development and acceptance

Run `gradlew verify` for the Java module/runtime verifier and independent example-module build. Run `powershell -ExecutionPolicy Bypass -File scripts/verify-installer.ps1` for isolated fixture installation checks. These prove only offline logic and packaging.

The current local Windows launcher fixture passed with Java 25.0.1 after loading the native preloader before the Java agent. This confirms the copied wrapper/JVM boundary only; the Project Zomboid game and Steam were not launched.

To inspect a local game JAR without modifying it, run `gradlew :runtime-core:verifyPzApi '-PpzJar=<path to projectzomboid.jar>'`. The verifier reports whether the exact `loadMods(List)` descriptor is present. `gradlew packageRuntime` creates a ZIP containing the agent JAR, checksums, installer scripts, docs, and staged independent example mod.

`scripts/verify-windows-bootstrap.ps1 -GameDirectory <PZ folder>` copies the PZ Windows launcher and its adjacent DLLs into an isolated fixture, links the bundled JRE, and gives it a tiny non-game main class plus a separate config containing the native preloader and Java agent. It does not modify the game folder or start Project Zomboid. It verifies the wrapper-to-JVM bootstrap on Java 25; it does not prove normal Steam behavior, active-mod timing or game startup.

## Current Build 42.21 live acceptance checklist

- [ ] Steam starts PZ normally with the installed agent and without a separate recurring launcher.
- [ ] Runtime starts early, reports actual PZ build and Java version.
- [ ] Only mods enabled for the current game context are offered for discovery.
- [ ] Unknown module waits for an explicit allow/deny decision.
- [ ] Approved independent example module initializes and its patch target is exercised.
- [ ] Denied and changed-hash modules do not load.
- [ ] Disabling the Java-enabled PZ mod prevents discovery/loading.
- [ ] Knox Survivors module integration preserves `KnoxJavaBridge`, Lua simulation, and save schema.
- [ ] Representative Knox NPC creation, movement, awareness, combat, damage, and save/load still work.
- [ ] Uninstall restores ordinary Steam startup.

No live item is currently checked. The real game was not launched during offline verification.
