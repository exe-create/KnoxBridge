# Player setup

**Release note:** The full-screen startup review gate and optional remember choices are in the alpha10 source candidate (the gate correction is recorded in alpha9 history). They require a matching KnoxBridge runtime package and Workshop payload. Knox Survivors does not need a runtime code update for this feature.

KnoxBridge has a Steam Workshop dependency marker and a separate player setup download. The Workshop item carries PZ metadata, the compile-time API JAR, and concise player/mod-author guides; it does not install or activate the runtime. Download player setup from [KnoxBridge GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest). The separate Knox Survivors Launcher is deprecated and unsupported. Do not download or use its old releases, or combine it or a direct legacy Knox agent with KnoxBridge.

## Same steps on every OS

Installing KnoxBridge is the same four steps everywhere; only the last step's tool differs by OS:

1. Subscribe to KnoxBridge Runtime (and Knox Survivors if you play it) and wait for Steam downloads to finish.
2. Download the player setup from GitHub Releases.
3. Point Project Zomboid at the KnoxBridge runtime (Windows: run the setup EXE; Linux/macOS: paste one line into Steam Launch Options — details below).
4. Enable the mods in the PZ Mods menu, start through Steam, and approve the exact JAR hash in the main-menu review screen. Unknown or changed JARs stay blocked until you allow them.

No Java, .NET, or Python install is required on any OS: the runtime uses Project Zomboid's bundled Java.

## Windows

1. Subscribe to KnoxBridge Runtime and Knox Survivors, and wait for Steam downloads to finish.
2. Download `KnoxBridgeSetup.exe` from the latest GitHub release. It includes its own installer runtime and uses Project Zomboid's bundled Java; no separate Java or .NET install, or archive extraction, is needed. The Windows EXE is much larger than the Bridge ZIP because it bundles the self-contained .NET runtime and framework libraries along with the small Bridge payload. A framework-dependent EXE could be smaller but would require users to install .NET first; trimming the self-contained build would need separate compatibility testing. The size difference is a packaging tradeoff, not a malware verdict; check the release SHA-256 if you want to confirm file integrity. If Windows Security reports malware, stop and do not run or whitelist it.
3. Run setup and choose **1**. It checks for the usual Steam location; if needed, enter the game folder containing `ProjectZomboid64.json`. It detects an existing Java instrumentation runtime and stops before changing configuration.
4. Enable **KnoxBridge Runtime** and Knox Survivors in the PZ Mods menu, then start a disposable save through Steam.
5. At the main menu, KnoxBridge opens **Review Java Mods** automatically when it finds a new enabled Java module. You can also open it with the **Review Java Mods** button. JARs are blocked by default. The highlighted row and **Selected JAR** details identify which file the buttons affect; review its module ID and exact SHA-256. The displayed author is only an unverified `mod.info` claim. Choose **Allow selected JAR** or **Deny selected JAR**. **Remember next choice** applies only to the next saved choice and resets afterward. Without it the choice applies for one game launch; with it the exact-hash choice persists. A one-time override does not erase a previous remembered choice.
6. If choices change which modules load, **Quit to apply changes** first shows a confirmation. Confirming exits Project Zomboid to desktop; start PZ again through Steam to apply the choices. KnoxBridge does not automatically relaunch the game. If the effective module set is unchanged, continue without restarting. JARs without a KnoxBridge descriptor remain blocked. This screen and restart flow are new and still need live Build 42 verification.
7. To remove KnoxBridge, run setup and choose **2**. If the PZ config is unchanged, it restores the exact original bytes; if edited later, it removes only KnoxBridge's entries and preserves the other edits.

The Windows installer is unsigned. Windows may show an **Unknown publisher** or SmartScreen **isn't commonly downloaded** warning because this new release has limited file/publisher reputation. That is different from Windows Security identifying malware; it is not a malware verdict or proof of safety. Verify that the download came from the official GitHub release and compare its SHA-256. If Windows Security reports a Trojan or other malware, stop and do not restore the file from quarantine, run it, add an exclusion, or try another archive as a workaround. Report the detection name and SHA-256 from the release page. The in-game list is a Bridge Workshop Lua UI backed by the runtime's discovered-JAR manifest; it requires the KnoxBridge Runtime mod to be enabled. If that UI cannot read or save its Bridge files, unknown JARs remain blocked; do not use the installer to approve them. Close the game and report the problem. You can uninstall KnoxBridge from the installer menu if needed.

## Linux and macOS

No Python, terminal scripting, or Steam config editing is required. You copy one file and paste one line into Steam's own Launch Options box.

1. Subscribe to KnoxBridge Runtime and Knox Survivors, and wait for Steam downloads to finish.
2. Download and extract `KnoxBridgeRuntime-*.zip` from GitHub Releases.
3. Copy `knoxbridge-agent-*.jar` from the extracted archive into a new folder called `.knoxbridge` in your home directory, so the path is `~/.knoxbridge/knoxbridge-agent-*.jar` (use the exact versioned filename from your download).
4. In Steam, right-click Project Zomboid → Properties → Launch Options, and append this text after anything already there (keep existing text; the trailing `--` is mandatory):
   `-javaagent:"$HOME/.knoxbridge/knoxbridge-agent-0.1.0-alpha10.jar" --`
   Replace the version with the one you downloaded if it differs.
5. Enable **KnoxBridge Runtime** and Knox Survivors in the PZ Mods menu, and start normally through Steam.
6. At the PZ main menu, review enabled-mod JARs in the full-screen gate before entering a world. Unknown JARs remain blocked unless allowed. Leave **Remember next choice** unchecked for a one-launch decision or check it to remember the next exact-hash choice; the toggle resets after that saved choice. If you change a queued decision before continuing, use **Undo pending choice**. If choices change which modules load, the gate asks for confirmation before quitting; then start PZ again through Steam. KnoxBridge does not automatically relaunch the game. If the file bridge cannot be used, leave the module blocked and report the problem.

To uninstall, remove the pasted text from Launch Options and delete the JAR from `~/.knoxbridge/`. A legacy `scripts/setup-unix.sh` helper (Python 3) is still included in the archive as an alternative, but it is no longer the recommended path.

This manual path has **not** been live-tested on Linux/macOS and is not yet a one-file installer. The runtime itself uses Project Zomboid's bundled Java on every platform, so KnoxBridge does not require players to install Java separately. The proven live path remains Windows x64 on PZ 42.21.0. Keep a copy of your Steam config and avoid important saves while testing this alpha.

## Trust and safety

Unknown or changed Java module JARs are blocked by default. The Bridge Workshop review gate opens at the PZ main menu before a player can enter a world. It shows enabled-mod JAR names, the highlighted selection, unverified author metadata, and exact SHA-256 hashes. Only a valid KnoxBridge descriptor/API module can be allowed. Unchecked choices apply for one launch and then revert to the prior remembered decision; **Remember next choice** remembers only the next saved exact-hash choice and then resets. A queued choice can be removed with **Undo pending choice** before continuing. A changed module load set requires quit and manual relaunch through Steam; the UI warns and asks for confirmation before quitting, but does not auto-relaunch PZ. Unchanged choices do not require a restart. If the review UI cannot save a decision, leave that module blocked and report the problem. Java modules run with the same permissions as Project Zomboid and are not sandboxed. Approve only code you trust. The independent test module is a developer fixture and is not installed by the player setup.

## Workshop publishing

Run `scripts/stage-workshop.ps1` on Windows to prepare the KnoxBridge Workshop item under `%USERPROFILE%\Zomboid\Workshop\KnoxBridgeRuntime`. If that stage exists, the script first moves it to `%USERPROFILE%\Zomboid\WorkshopBackups` so the previous payload is preserved outside the upload folder. The upload contains PZ dependency metadata and KnoxBridge Workshop artwork, the Bridge Lua UI, a short in-mod README, the compile-time `runtime-api` JAR, third-party notices, a standalone author example with patch and method-inspector source, and the module-author, patch, compatibility, and installation guides. It does not contain the player runtime installer: download that from GitHub Releases and follow `developer/docs/INSTALLATION.md` (also linked from the Workshop description). The API JAR is for compiling compatible modules; it does not install or activate KnoxBridge. Runtime test fixtures and installer executables are excluded. Publish the Workshop stage only alongside the matching KnoxBridge player runtime version; the stage README and description name the required version. The staging script checks the exact expected payload and rejects installer/system-launch file types before upload.

## Acceptance boundaries

- **Offline verified:** alpha10 runtime/patch fixtures, module package checks, once/remember decision checks, Windows native-installer fixtures, archive integrity, Bridge Workshop Lua checks, and Unix config helper tests. This does not establish Build 42 UI behavior or antivirus clearance for any EXE.
- **Wrapper smoke verified:** Windows native bootstrap against the copied launcher fixture.
- **Real PZ 42.21 verified on the prior runtime build:** Windows normal Steam startup, enabled-mod discovery, unknown-hash block, approved module load, and restore/uninstall/reinstall. The current Bridge Workshop menu, enabled-JAR inventory, next-launch allow/deny queue, alpha10 Windows package, and normal no-installer trust flow still need fresh Build 42 replay.
- **Unix setup implemented, not live verified:** Linux/macOS Steam config editing and direct Java-agent launch path.
- **Knox module verified:** required Knox hooks and bridge were observed in a live Windows process; movement/combat and persistence still have remaining live acceptance.
