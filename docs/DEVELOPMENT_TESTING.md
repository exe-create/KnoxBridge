# Development and acceptance

The owner request to address Byte Buddy authoring and publisher-signature feedback is implemented in the source candidate. `gradlew verify` passes with 101 runtime checks; the Workshop Lua fixture and syntax check pass, and `git diff --check` is clean. These are offline results. Entry/return hooks and detached signatures have focused coverage in `AuthorFeaturesVerifier`, called by the existing runtime verifier. Checks cover all JVM return categories, multiple normal returns, original exception propagation, constructor rejection, helper visibility/shape rejection, signed metadata/JAR tampering, wrong keys, malformed sidecars, unsigned compatibility, expected-fingerprint CLI verification, and hash substitution before initialization. The Workshop fixture checks version-2/3/4 parsing, the full two-line signer display, invalid-signature blocking and unchanged signed-module restart behavior. These additions still require a live Build 42 run with a signed test module: compare the two-line key fingerprint, test valid/invalid/unsigned modules, confirm unchanged loaded-set choices need no restart, and invoke an actual PZ hook whose helpers use the system loader. The permanent .exe Ed25519 key is provisioned outside the repository with a restricted directory and DPAPI protection. No Windows Authenticode certificate is provisioned.

Changed files for this request (pre-existing local author-example/documentation changes were preserved and extended):

- API/runtime: `runtime-api/src/main/java/com/knoxbridge/api/PatchRegistrar.java`; `runtime-core/src/main/java/com/knoxbridge/runtime/{PatchEngine,MethodHooks,DetachedSignature,SigningTool,KnoxBridgeAgent,ModuleLoader,ModuleReviewFiles}.java`.
- Example: `examples/minimal-module/src/main/java/org/example/mymod/{MyModule,GreetingPatch}.java`.
- Verification/UI: `runtime-core/src/test/java/com/knoxbridge/runtime/{RuntimeVerifier,AuthorFeaturesVerifier}.java`; `scripts/test-workshop-ui.lua`; `workshop/mod/42/media/lua/client/KnoxBridgeModuleReview.lua`.
- Authority/evidence: `docs/{PATCH_API,SECURITY_AND_TRUST,ARCHITECTURE,DEVELOPMENT_TESTING,RELEASE_NOTES}.md`.

2026-10-11 first-party continuation: the current compiled KnoxSurvivors module
(`f9f33ff0d83cd0b995aeb5d889f28e7d6fc728e77a5604dcf95572700737e52a`)
passed six separate JVM/agent cases under the installed PZ Java 25.0.1:
signed unknown, signed allowed, signed denied, invalid signature despite hash
approval, unsigned allowed, and changed signed JAR with only the old hash
approved. Each case also invoked the installed PZ `UpdateLimit.Check()Z`
through `registerHook`, observing both entry/return callbacks and unchanged
true/false results. Allowed cases completed the actual KnoxSurvivors module
bootstrap. This is real-module/JVM evidence, not in-world gameplay.
`scripts/verify-first-party.ps1` reproduces the cases using temporary test keys
and isolated trust stores; private test-key files are removed on exit.
Evidence: `build/first-party-dd3f2dd3df004a93a1177319c05309c6/summary.json`.

Native isolated PZ 42.21.0/Windows replay reached the main-menu review screen
with the actual signed KnoxSurvivors JAR, full two-line key fingerprint, valid
signature label, blocked-by-default state and enabled Allow button. The owner
reported approving the JAR and quitting. The first disposable launch had zero
active mods because PZ performs a first-release mod reset; restarting with the
saved selection produced two enabled roots and one signed module candidate.
`scripts/prepare-live-test.ps1` now creates the Build 42 reset marker for its
explicit test selection and starts unapproved by default; `-PreApproveModule`
is an opt-in bootstrap-only shortcut. Normal installed config, player trust
and saves were not modified. The test uses a copied native launcher,
`-nosteam` and a separate cache, so normal Steam acceptance remains separate.
The owner approved once and quit; the next native launch imported one exact-hash
decision, verified the signature, loaded KnoxSurvivors and reported
`runtime ready modules=1`. Knox's combat callbacks, visibility and impact/human
gates reported ready, `runtime start PASS source=knoxbridge` completed, and
`Lua bridge exposed global=KnoxJavaBridge` was observed. This verifies the
native isolated approval-to-load path; world combat,
other platforms and publication remain pending. Owner release signing is covered by the alpha11 evidence below.
Native evidence is under `build/live-signature-5b1f0906dadd479e9f8d8624fc477355/`.

Additional continuation files: `bootstrap-smoke/build.gradle.kts`;
`bootstrap-smoke/src/main/java/com/knoxbridge/smoke/{FirstPartySmokeMain,PzHookProbeModule,PzHookCallbacks}.java`;
`scripts/verify-first-party.ps1`; `scripts/prepare-live-test.ps1`.

Run `gradlew verify` for the Java runtime verifier, the real fixture transformation, author module packaging checks, and a ready-to-copy example PZ mod directory. To build the example by itself, run `gradlew -p examples/minimal-module stagePzMod "-PknoxbridgeApiJar=<path to runtime-api JAR>"`. For target inspection, add `inspectPzMethods` with `-PpzJar`, `-PtargetClass`, and `-PtargetMethod`; this lists exact signatures from a local game JAR without modifying it. Run `powershell -ExecutionPolicy Bypass -File scripts/verify-installer.ps1` for isolated legacy-script fixture checks and `python scripts/verify-unix-setup.py` for Unix Steam VDF edit/restore fixtures. `gradlew verify packageManualInstaller buildWindowsInstaller` builds the player ZIP and self-contained .NET Windows installer. `powershell -ExecutionPolicy Bypass -File scripts/verify-windows-installer.ps1` verifies the embedded package hash, confirms the installer starts no shell, and runs its disposable install/uninstall/state-integrity fixtures. `packageRuntime` builds the developer archive with the runtime fixture, ready-to-copy PZ example mod, author module JAR, and example source. Build-time PowerShell is used only by maintainers for the verification scripts; the distributed Windows installer does not start PowerShell.

The local Windows launcher fixture passed with Java 25.0.1 after loading the native preloader before the Java agent. On 2026-09-28, normal Steam Play reached installed Project Zomboid 42.21.0 / Java 25.0.1. PZ supplied the selected roots for `KnoxBridgeIndependentTest` and `KnoxSurvivors`. Both previously unknown JARs were blocked, then loaded after exact-hash approval and restart. The independent module initialized and registered its harmless probe. Knox initialized under the system-loader policy; its required combat/visibility hooks reported ready and `KnoxJavaBridge` was exposed. This is live bootstrap/discovery/trust/module-init evidence, not in-world NPC gameplay or save/reload evidence.

That full game session predates the alpha2 packaging/version update. Alpha2 was rechecked offline, through the Windows installer fixtures, and through the copied-launcher wrapper smoke, but was not rerun through normal Steam/PZ. Alpha3/alpha4 standalone installers were withdrawn after Defender reported a severe detection on the alpha4 EXE. Alpha5 replaces the self-extracting PowerShell launcher. Its eight native installer fixture checks pass, and its release candidate passed a targeted local Defender scan, but the app is unsigned and does not have Microsoft cloud reputation clearance. A fresh normal Steam/PZ installer replay remains required.

To check KnoxBridge's own PZ adapter against a local game JAR, run `gradlew :runtime-core:verifyPzApi '-PpzJar=<path to projectzomboid.jar>'`; this reports whether the exact `loadMods(List)` descriptor is present. It does not validate module patch targets. `gradlew packageRuntime` creates a ZIP containing the agent JAR, checksums, installer scripts, docs, staged runtime fixture, and standalone author example.

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

The prior runtime build passed live bootstrap, enabled-mod discovery, unknown-hash blocking, exact-hash approval/load, module lifecycle, Knox patch readiness, bridge exposure, and uninstall/restore. Current offline verification covers JAR inventory, default blocking, version-1 and version-2 decision queues, persistent decisions beneath one-time overrides, repeated same-hash checks within one launch, malformed-queue fail-closed behavior, metadata sanitization, the Workshop UI's queue/selection/remember/restart interaction model, module patch registration scope, and observable fixture bytecode transformations. The author example now verifies ASM entry and normal-return advice calls while preserving the target method's result. The alpha10 package, current full-screen menu gate, and Java/Lua handoff still require live Build 42 replay: enable KnoxBridge Runtime and one test module; confirm each enabled-mod JAR filename/hash appears before entering a world; allow that module and separately test deny; verify the remember toggle applies to one choice and resets; confirm one-time decisions override then restore persistent trust; confirm a changed module set warns and asks before exiting, then relaunch manually through Steam; verify unchanged effective choices do not require restart; change the module JAR and confirm its new hash is blocked. Exercise the author example patch and a target-mod patch separately; measure startup scan time with a normal mod list. Windows Defender has detected prior installer builds; never run, restore, whitelist, or publish a flagged binary. Linux/macOS setup remains unverified.

Run the UI contract test and syntax check from the repository root with Lua 5.1+: `lua scripts/test-workshop-ui.lua`, then `lua -e "assert(loadfile('workshop/mod/42/media/lua/client/KnoxBridgeModuleReview.lua'))"`. These tests do not substitute for the required PZ Build 42 menu and filesystem replay.

2026-10-11 alpha11 release preparation: runtime verification passes 101 checks; the version-2/3/4 Workshop UI fixture passes, including anchored publisher display. The six-case first-party harness rerun is retained at `build/first-party-70cca5a0a35d478490860e9a001a13ed/summary.json`. The exact PZ loadMods(List) adapter probe passes against installed 42.21.0. The copied Windows launcher bootstrap passes on Java 25.0.1 (`build/bootstrap-smoke-42bf554ecfd54011bbe3a3e3c443ad7f`). Owner signing validates the permanent fingerprint and every signed artifact; `scripts/verify-release-signatures.ps1` checks both final archives, EXE and embedded runtime/API/DLL plus exclusion of private-key files. The final alpha11 installer passes embedded archive verification and all eight native self-tests; the targeted Defender scan reports no threats. Unix helper fixtures pass nine checks. Repeat installer checks, all release-signature checks and the scan after any rebuild. Commit/push and local Workshop staging are authorized; no GitHub release or Workshop upload is authorized by this preparation request. Existing KnoxSurvivors source/distribution is unchanged. Full Steam/world gameplay, invalid-signature UI replay and Unix live gates remain outstanding.
