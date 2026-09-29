# Player setup

**Release note:** The in-game review UI described below is in the alpha7 source candidate and is not part of the published alpha5 download or current Workshop payload. It requires a new KnoxBridge runtime package and updated KnoxBridge Workshop item. Knox Survivors does not need a runtime code update for this feature.

KnoxBridge has a Steam Workshop dependency marker and a separate player setup download. The Workshop item carries PZ metadata, the compile-time API JAR, and concise player/mod-author guides; it does not install or activate the runtime. Download player setup from [KnoxBridge GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest). The separate Knox Survivors Launcher is deprecated and unsupported. Do not download or use its old releases, or combine it or a direct legacy Knox agent with KnoxBridge.

## Windows

1. Subscribe to KnoxBridge Runtime and Knox Survivors, and wait for Steam downloads to finish.
2. Download `KnoxBridgeSetup.exe` from the latest GitHub release. It includes its own installer runtime and uses Project Zomboid's bundled Java; no separate Java or .NET install, or archive extraction, is needed. The Windows EXE is much larger than the Bridge ZIP because it bundles the self-contained .NET runtime and framework libraries along with the small Bridge payload. A framework-dependent EXE could be smaller but would require users to install .NET first; trimming the self-contained build would need separate compatibility testing. The size difference is a packaging tradeoff, not a malware verdict; check the release SHA-256 if you want to confirm file integrity. If Windows Security reports malware, stop and do not run or whitelist it.
3. Run setup and choose **1**. It checks for the usual Steam location; if needed, enter the game folder containing `ProjectZomboid64.json`. It detects an existing Java instrumentation runtime and stops before changing configuration.
4. Enable **KnoxBridge Runtime** and Knox Survivors in the PZ Mods menu, then start a disposable save through Steam.
5. At the main menu, KnoxBridge opens **Review Java Mods** automatically when it finds a new enabled Java module. You can also open it with the **Review Java Mods** button. JARs are blocked by default. Select a file to see its module ID and exact SHA-256; the displayed author is only an unverified `mod.info` claim. Choose **Allow exact JAR** or **Keep JAR denied**. Your choice is saved by exact hash and applies next time you fully restart Project Zomboid; no installer trust step is needed for normal use. JARs without a KnoxBridge descriptor are listed as incompatible and stay blocked until their author adds Bridge support. This screen is new and still needs live Build 42 verification.
6. To remove KnoxBridge, run setup and choose **2**. If the PZ config is unchanged, it restores the exact original bytes; if edited later, it removes only KnoxBridge's entries and preserves the other edits.

The Windows installer is unsigned. Windows may show an **Unknown publisher** or SmartScreen **isn't commonly downloaded** warning because this new release has limited file/publisher reputation. That is different from Windows Security identifying malware; it is not a malware verdict or proof of safety. Verify that the download came from the official GitHub release and compare its SHA-256. If Windows Security reports a Trojan or other malware, stop and do not restore the file from quarantine, run it, add an exclusion, or try another archive as a workaround. Report the detection name and SHA-256 from the release page. The in-game list is a Bridge Workshop Lua UI backed by the runtime's discovered-JAR manifest; it requires the KnoxBridge Runtime mod to be enabled. If that UI cannot read or save its Bridge files, unknown JARs remain blocked; do not use the installer to approve them. Close the game and report the problem. You can uninstall KnoxBridge from the installer menu if needed.

## Linux and macOS

The release includes a Unix setup helper. It uses Python 3 from the standard library and modifies only Project Zomboid's `LaunchOptions` entry in your Steam `localconfig.vdf`.

1. Subscribe to KnoxBridge Runtime and Knox Survivors, and wait for Steam downloads to finish.
2. Download and extract `KnoxBridgeRuntime-*.zip` from GitHub Releases.
3. Close Steam, open a terminal in the extracted folder, and run `sh scripts/setup-unix.sh`.
4. Choose **1** to install/update. If setup asks for a `localconfig.vdf` path, select the one under your Steam `userdata/<account>/config/` directory.
5. Reopen Steam, enable **KnoxBridge Runtime** and Knox Survivors in the PZ Mods menu, and start normally.
6. At the main menu, use **Review Java Mods** to inspect the enabled mods' JAR files and save exact-hash allow/deny choices for the next full launch. Unknown JARs remain blocked by default. This menu is not yet live-verified on Linux/macOS. If its file bridge cannot be used, leave the module blocked and report the problem.

The helper backs up the exact Steam config before its first edit, records the installed hash, preserves other launch options, and removes only its own option if Steam settings change later. Choose **2** to uninstall. Do not run the helper while Steam is open; Steam can overwrite its local config while running.

Linux/macOS continue to use the `KnoxBridgeRuntime-*.zip` archive and `scripts/setup-unix.sh`; Python 3 is required for the Steam config helper. This path has **not** been live-tested on those operating systems and is not yet a one-file installer. The runtime itself uses Project Zomboid's bundled Java on every platform, so KnoxBridge does not require players to install Java separately. The proven live path remains Windows x64 on PZ 42.21.0. Keep a copy of your Steam config and avoid important saves while testing this alpha.

## Trust and safety

Unknown or changed Java module JARs are blocked by default. The Bridge Workshop main-menu review screen shows JARs discovered under enabled PZ mods, claimed author metadata (unverified), and the exact SHA-256. The screen writes exact-hash choices for the next launch; it never loads a Java module late in the current session. Only a valid KnoxBridge descriptor/API module can be allowed. Other JARs remain blocked until their author integrates with KnoxBridge. If the review UI cannot save a decision, leave that module blocked and report the problem. Java modules run with the same permissions as Project Zomboid and are not sandboxed. Approve only code you trust. The independent test module is a developer fixture and is not installed by the player setup.

## Workshop publishing

Run `scripts/stage-workshop.ps1` on Windows to prepare the KnoxBridge Workshop item under `%USERPROFILE%\Zomboid\Workshop\KnoxBridgeRuntime`. If that stage exists, the script first moves it to `%USERPROFILE%\Zomboid\WorkshopBackups` so the previous payload is preserved outside the upload folder. The upload contains PZ dependency metadata and default ModTemplate images, a short in-mod README, the compile-time `runtime-api` JAR, its license, and the existing module-author, patch, compatibility, and installation guides. It does not contain the player runtime installer: download that from GitHub Releases and follow `developer/docs/INSTALLATION.md` (also linked from the Workshop description). The API JAR is for compiling compatible modules; it does not install or activate KnoxBridge. Developer test modules and installer executables are excluded. The staging script checks the exact expected payload and rejects installer/system-launch file types before upload.

## Acceptance boundaries

- **Offline verified:** alpha7 runtime inventory/decision checks, Windows native-installer fixtures, archive integrity, Bridge Workshop Lua checks, and Unix config helper tests. This does not establish Build 42 UI behavior or antivirus clearance for any EXE.
- **Wrapper smoke verified:** Windows native bootstrap against the copied launcher fixture.
- **Real PZ 42.21 verified on the prior runtime build:** Windows normal Steam startup, enabled-mod discovery, unknown-hash block, approved module load, and restore/uninstall/reinstall. The new Bridge Workshop menu, enabled-JAR inventory, next-launch allow/deny queue, updated Windows package, and normal no-installer trust flow still need fresh Build 42 replay.
- **Unix setup implemented, not live verified:** Linux/macOS Steam config editing and direct Java-agent launch path.
- **Knox module verified:** required Knox hooks and bridge were observed in a live Windows process; movement/combat and persistence still have remaining live acceptance.
