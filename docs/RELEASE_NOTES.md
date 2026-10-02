# KnoxBridge Runtime 0.1.0-alpha2

- Steam Workshop payload is reduced to the dependency marker and default ModTemplate images. Installer and runtime files are distributed separately.
- Added a numbered Linux/macOS setup helper that backs up and edits only the PZ Steam `LaunchOptions` entry, remembers its own argument, detects a competing Java runtime, and restores safely.
- Kept the established Windows native bootstrap and reversible startup JSON installer.
- Preserved the independent Java test module in the developer build and the existing exact-hash approval model.
- Windows remains the only platform with normal Steam/PZ live acceptance, from the pre-alpha2 runtime build. Alpha2 passed offline checks, Windows installer fixtures and copied-launcher smoke; the full game was not rerun after packaging/version changes. Unix setup has offline parser/restore checks but awaits Linux/macOS live validation.

Install from the [latest GitHub release](https://github.com/exe-create/KnoxBridge/releases/latest). See [player setup](INSTALLATION.md) before installing.

# KnoxBridge Runtime 0.1.0-alpha3

- Added a standalone Windows x64 setup executable containing the player archive; Windows players do not need to install Java or extract a ZIP.
- The executable uses Windows' built-in PowerShell for its setup menu and the Project Zomboid installation's bundled Java at runtime.
- Added an offline verifier that extracts the embedded archive and checks its hash and required runtime files.
- Linux/macOS remain on the ZIP plus Python 3 helper and are not yet live-tested or packaged as native one-file installers.
- The Windows installer is unsigned; Windows may show an unknown-publisher warning. Verify it came from the official KnoxBridge release before running it.
- The full normal-Steam/PZ live acceptance and the live Linux/macOS paths have not been rerun for this packaging update.

# KnoxBridge Runtime 0.1.0-alpha4

- Selects Java modules from active Project Zomboid mod roots, so disabled Workshop mods are not loaded just because their files are installed.
- Adds setup controls to ALLOW or DENY a module's exact JAR SHA-256 from the most recent launch; blank input leaves the decision unchanged.
- Keeps KnoxBridge independent of Knox Survivors gameplay. Use only one Java instrumentation runtime at a time.
- Windows download: `KnoxBridgeSetup.exe` (self-contained setup; uses the game's bundled Java). Linux/macOS download: `KnoxBridgeRuntime-0.1.0-alpha4.zip` (Python 3 helper; close Steam while changing its config).
- Unknown or changed module hashes remain blocked until the player explicitly allows that exact file. Java modules have the same permissions as the game and are not sandboxed.
- Offline packaging and verifier checks pass. The alpha4 package has not yet had its own live Build 42 acceptance run. Linux/macOS still require native live testing.
- Security notice (2026-09-29): Microsoft Defender reported a severe Trojan detection on `KnoxBridgeSetup.exe`. The Windows asset was withdrawn pending review; do not restore or run it. Existing installations are unaffected. Windows setup is unavailable until a reviewed replacement is published.

# KnoxBridge Runtime 0.1.0-alpha5

- Replaces the Windows self-extractor/PowerShell launcher with a self-contained Knox-owned .NET installer that performs checksum-verified package reading, install, conflict checks, trust approval, and uninstall directly.
- The installer does not launch PowerShell or another command shell. The player ZIP no longer includes Windows setup scripts; it contains the Unix helper and shared runtime files only.
- Adds disposable native-installer fixture coverage for idempotent install, exact backup restoration, user-edit preservation, and blocking a competing runtime.
- Targeted Microsoft Defender scan of the built release artifact found no threats on the maintainer's machine. The installer remains unsigned; this scan is not a guarantee for other antivirus products or a Microsoft cloud-reputation verdict. Stop and report any malware detection; never bypass it.
- Alpha5 installer behavior has offline fixture coverage. The new installer still needs a fresh normal-Steam/PZ acceptance run; no full live acceptance is claimed.

# KnoxBridge Runtime 0.1.0-alpha6

- Unknown Java modules now trigger a modal startup approval dialog before their JAR is loaded.
- The dialog shows the KnoxBridge module ID, exact JAR SHA-256, PZ mod name, and any declared author. Author text is explicitly unverified metadata, not authenticated identity.
- Allow and deny decisions are saved only for the displayed exact JAR hash. Skip, closing the window, headless execution, or UI errors leave the module blocked.
- Earlier installer builds included a terminal trust fallback; the alpha7 source candidate removes that path in favor of the KnoxBridge Workshop review screen.

# KnoxBridge Runtime 0.1.0-alpha7 source candidate
- Replace per-JAR desktop approval dialogs with the KnoxBridge Workshop main-menu review UI.
- Inventory JAR files beneath Project Zomboid-enabled mod roots; unknown hashes remain blocked by default.
- Save exact-hash allow/deny choices in a versioned handoff file and import them before the next Java module load.
- Show unsupported JAR files as not Bridge-compatible; do not load arbitrary JARs without a KnoxBridge descriptor/API entry point.
- Require updated KnoxBridge runtime and Workshop uploads; no Knox Survivors code change is involved.
- Simplify Windows and Linux/macOS setup menus to install/update, uninstall, and exit; trust decisions are no longer managed by setup.
- The installer verifies bundled runtime JAR and Windows bootstrap checksums. This is package integrity validation, not a publisher signature or antivirus guarantee.
- Build 42 UI visibility, file-path access, and end-to-end restart acceptance remain unverified.
- Windows Defender has flagged a local unsigned setup build; do not release or run a flagged build. A fresh approved scan and live Build 42 replay are required before publishing binaries.
- Offline decision and metadata checks pass. Visibility/focus during real PZ startup and full Build 42 acceptance remain live-unverified.

# KnoxBridge Runtime 0.1.0-alpha8 source candidate
- Open the Bridge Java review as a full-screen gate at the PZ main menu before entering a world.
- Keep unknown or changed JAR hashes blocked by default and visible; only compatible modules can be allowed.
- Add an optional remember toggle: unchecked choices apply once, while checked choices persist for the exact JAR hash.
- Clarify that the remember control applies to the next decision and let players undo a queued choice before continuing.
- Require one quit/relaunch only when a choice changes which Java modules are loaded. An unchanged allow or an already blocked file does not require a restart.
- Keep accepting the version-1 queued decision format and add version-2 once/remember choices.
- Offline validation is recorded separately from live Build 42 visibility, gate, persistence, and restart acceptance.

# KnoxBridge Runtime 0.1.0-alpha9 source candidate
- Fix the main-menu JAR selection callback by registering it with Project Zomboid's `ISScrollingListBox:setOnMouseDownFunction` API.
- Alpha8 live logs showed the runtime and Knox Survivors module initialized on Project Zomboid 42.21, but selecting a listed JAR raised `attempted index of non-table` in the review callback. The UI click failure was isolated to the callback target binding.
- Extend the Workshop UI regression checks to exercise the native callback target and selection behavior.
- Build 42 live verification of the corrected review screen remains required.

# KnoxBridge Runtime 0.1.0-alpha10 source candidate
- Add an author example that performs an observable ASM patch against a harmless fixture; include the pinned ASM Core and Tree 9.10.1 tool dependency in the agent, with third-party notices. The example compiles against ASM as `compileOnly` and does not bundle duplicate tool classes.
- Add an author task to inspect exact class/method descriptors in a local Project Zomboid JAR and a task to assemble a ready-to-copy example mod layout. Verify the example package omits bundled KnoxBridge API classes.
- Scope patch registration to the synchronous `initialize` call. Registrations commit only after successful initialization; late, asynchronous, failed-initialization, and duplicate registrations are rejected or discarded instead of being attributed to another module.
- Patch diagnostics now include the complete target descriptor. Offline verification exercises successful observable transformation, invalid bytes, missing/ambiguous methods, duplicate IDs, closed scopes, and abandoned registrations.
- Document API-version policy: binary-compatible additions can remain on the current API version; incompatible API/descriptor changes require a new version accepted explicitly by the runtime. API version does not imply PZ build compatibility.
- Reset **Remember next choice** after one successfully saved choice; show the selected JAR in list, details, and action labels; restore pending state on reopen. Reopening a queued decision now distinguishes one-launch from remembered choices.
- Make one-launch trust a scoped override that applies to every matching hash during one PZ launch, then expires without replacing a prior persistent allow/deny. Continue accepting alpha9 trust entries.
- Require a second explicit confirmation before the UI quits PZ for a load-set change, and tell the player to relaunch through Steam. Automatic Steam/game relaunch is not implemented.
- Reject malformed/conflicting decision queues as a whole in the Lua UI, matching Java's fail-closed importer; surface queue and write-close errors.
- Expand offline UI/runtime fixtures for remember reset, selected-item synchronization, invalid queue rejection, quit confirmation, persistent trust restoration, and one-time same-hash reuse. Live Build 42 behavior remains unverified.
- Linux/macOS setup no longer needs Python: copy the agent JAR to `~/.knoxbridge/` and paste one `-javaagent` line into Steam Launch Options. Player docs rewritten around one unified flow on every OS.
- The current Workshop review gate, trust handoff, packaged alpha10 runtime, live PZ module patches, and Linux/macOS launch paths have not been live-verified for this candidate. No release or compatibility claim is made.
