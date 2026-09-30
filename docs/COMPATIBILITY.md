# Compatibility and author verification

KnoxBridge's PZ adapter targets the observed `zombie.ZomboidFileSystem.loadMods(Ljava/util/List;)V` method. If that method contract changes, the runtime fails closed rather than guessing another hook. A successful adapter/API check is not a game-version compatibility guarantee: descriptors have no PZ build range, and `apiVersion=1` only selects the KnoxBridge API contract.

## Evidence boundary

| Environment | Evidence | What it does not establish |
| --- | --- | --- |
| Windows x64, normal Steam, PZ 42.21.0, Java 25.0.1 | On 2026-09-28, the then-current runtime bootstrapped, discovered enabled mod roots, blocked unknown hashes, and loaded the approved independent module after restart. | The alpha9 review UI carried in the alpha10 source candidate and its current decision handoff; the alpha10 packaged runtime; full game, save/reload, or outside modules' patches. |
| Windows copied-launcher smoke | Native wrapper reached a fixture JVM. | Steam behavior, PZ startup or active-mod timing. |
| Linux/macOS | Steam config helper has offline parser/edit/restore checks. | Native setup, game launch, runtime/module loading or Workshop UI. |
| Current Bridge review screen and trust handoff | Lua/parser, queue and UI contract checks are offline-tested; release notes document a callback correction following a 42.21 UI selection defect. | Current screen visibility/focus, real file access, allow/deny persistence, restart behavior, or current end-to-end launch. |

No claim is made for Build 42.21 beyond the dated evidence above, nor for other PZ builds or operating systems. Recheck current [release notes](RELEASE_NOTES.md) and [development acceptance record](DEVELOPMENT_TESTING.md) before publishing a compatibility statement.

## Offline checks for authors

1. Build against the `runtime-api` JAR shipped with the intended KnoxBridge version; it is a compile dependency, not the player runtime.
2. Run `./gradlew :runtime-core:verifyPzApi "-PpzJar=<path-to-projectzomboid.jar>"` against the target installation. This checks the exact adapter method contract only.
3. Validate the module descriptor, public no-argument entrypoint and packaging. Run `./gradlew verify` in a source checkout to build/test the author patch fixture and assemble a ready-to-copy mod directory. In the author example, `inspectPzMethods` prints exact descriptors from a local game JAR. Review the KnoxBridge log for discovery, compatibility, approval, load and patch messages.
4. Check every patch target and descriptor against the target PZ JAR/build. The generic adapter check and signature inspector cannot validate patch semantics or transformed behavior.

Offline checks are useful diagnostics, not live acceptance. Do not describe a target PZ version as supported based only on a target setting, API version, or successful build.

## Repeatable live acceptance for an outside module

Use a disposable PZ profile/save and record exact game build, OS, Java version, KnoxBridge version, module version, and module JAR SHA-256. Verify separately on each OS/build you intend to claim.

1. Enable KnoxBridge Runtime and only the test module. Confirm its enabled-mod root and JAR appear in review with the expected ID/hash. Confirm an unknown hash is blocked and no module initialization appears in the runtime log.
2. Allow that exact hash; test one-launch and remembered choices. Confirm the remember toggle resets after one saved choice. A one-launch choice must apply to that hash for the launch and then return to any prior persistent decision. Confirm remembered allow persists after another restart.
3. Deny the module (once and remembered where applicable); restart and confirm it does not initialize. Confirm the UI clearly identifies the selected JAR, warns before quitting, and tells the player to relaunch manually through Steam. Confirm an unchanged decision does not create a spurious load change/restart prompt.
4. Change/rebuild the JAR without changing its module ID. Confirm the new hash is unknown and blocked by default; the old approval must not authorize it. Exercise allow and deny persistence for the changed hash independently.
5. Confirm normal startup reaches the main menu and a disposable world, check runtime and PZ logs, exercise each module feature/patch, then quit and relaunch. Confirm no duplicate initialization and expected `shutdown()` behavior on orderly exit.
6. Repeat after changing KnoxBridge, PZ build, OS, module JAR or patch targets. Keep offline results and live results distinct in release notes.

Only exact hashes are trusted; unknown or changed files are blocked by default. The review screen's declared author is unverified text. Approved Java code runs with the game user's permissions and KnoxBridge is not a sandbox. KnoxBridge provides the API/runtime, but outside authors remain responsible for module integration, compatibility testing, support, and communicating their own tested matrix. First-party attention focuses on KnoxBridge itself and Knox Survivors' integration; it is not an outside-module support guarantee.
