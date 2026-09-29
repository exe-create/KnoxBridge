# Development and acceptance

Run `gradlew verify` for the Java module/runtime verifier and independent example-module build. Run `powershell -ExecutionPolicy Bypass -File scripts/verify-installer.ps1` for isolated fixture installation checks and `python scripts/verify-unix-setup.py` for the Unix Steam VDF edit/restore fixtures. These prove offline logic and packaging. `gradlew clean verify packageManualInstaller` builds the player setup archive; `packageRuntime` builds the developer archive with the independent test module.

The local Windows launcher fixture passed with Java 25.0.1 after loading the native preloader before the Java agent. On 2026-09-28, normal Steam Play reached installed Project Zomboid 42.21.0 / Java 25.0.1. PZ supplied the selected roots for `KnoxBridgeIndependentTest` and `KnoxSurvivors`. Both previously unknown JARs were blocked, then loaded after exact-hash approval and restart. The independent module initialized and registered its harmless probe. Knox initialized under the system-loader policy; its required combat/visibility hooks reported ready and `KnoxJavaBridge` was exposed. This is live bootstrap/discovery/trust/module-init evidence, not in-world NPC gameplay or save/reload evidence.

That full game session predates the alpha2 packaging/version update. Alpha2 was rechecked offline, through the Windows installer fixtures, and through the copied-launcher wrapper smoke, but was not rerun through normal Steam/PZ.

To inspect a local game JAR without modifying it, run `gradlew :runtime-core:verifyPzApi '-PpzJar=<path to projectzomboid.jar>'`. The verifier reports whether the exact `loadMods(List)` descriptor is present. `gradlew packageRuntime` creates a ZIP containing the agent JAR, checksums, installer scripts, docs, and staged independent example mod.

`scripts/verify-windows-bootstrap.ps1 -GameDirectory <PZ folder>` copies the PZ Windows launcher and its adjacent DLLs into an isolated fixture, links the bundled JRE, and gives it a tiny non-game main class plus a separate config containing the native preloader and Java agent. It does not modify the game folder or start Project Zomboid. It verifies the wrapper-to-JVM bootstrap on Java 25; it does not prove normal Steam behavior, active-mod timing or game startup. The Unix VDF verifier exercises a temporary config only; it does not prove a Linux or macOS PZ launch.

## Current Build 42.21 live acceptance checklist

- [x] Normal Steam Play starts installed PZ with the agent; no recurring launcher is needed.
- [x] Runtime starts early and reports PZ build 42.21.0 and Java 25.0.1.
- [x] Exact `ZomboidFileSystem.loadMods(List)` transformation applies and callback executes.
- [x] PZ's enabled roots drive module discovery; live run offered only the enabled independent test and Knox mods.
- [x] Unknown hashes receive `APPROVAL_REQUIRED` and are not loaded on the first run.
- [x] Exact-approved independent example initializes and registers its harmless probe. Its optional no-op patch target is fixture-only, not a live PZ patch.
- [ ] Denied and changed-hash modules are not yet live-tested.
- [ ] Disabling a Java-enabled PZ mod and confirming it prevents discovery/loading is not yet tested.
- [x] Knox Survivors module initializes, required combat/visibility hooks report ready, and `KnoxJavaBridge` is exposed. Lua simulation/save schema were not changed.
- [x] Narrow in-world Knox probe logged native spawn, door/fence movement transitions, baseball-bat attacks, and zombie health reaching zero. A route also logged `FailedStuck`; this is not full pathing or awareness acceptance.
- [ ] Persistence and save/reload remain unverified.
- [x] Uninstall restores the exact original JSON; normal Steam starts with no new runtime log, then reinstall and another Steam start load both approved modules.
- [ ] Linux/macOS setup, Steam restart, direct Java agent, and uninstall have offline tests only; no live platform acceptance yet.

Live bootstrap, discovery, unknown-hash blocking, exact-hash approval/load, module lifecycle, Knox patch readiness, bridge exposure, and uninstall/restore are checked. Deny/changed-hash behavior and in-world gameplay/save acceptance remain open.
