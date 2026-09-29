# Player setup

KnoxBridge has a small Steam Workshop dependency marker and a separate manual setup download. Steam rejects executable and installer file types in Workshop uploads, so the Workshop item contains only the PZ metadata and default ModTemplate images. The player installer is distributed from [KnoxBridge GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest).

## Windows

1. Subscribe to KnoxBridge Runtime and Knox Survivors, and wait for Steam downloads to finish.
2. Download and run `KnoxBridgeSetup.exe` from the latest GitHub release. It contains the complete setup archive; no Java download, extraction tool, or separate runtime download is needed. If Windows shows its unsigned-app warning, verify that you downloaded the release from the official KnoxBridge GitHub page before choosing to continue.
3. Choose **1** in the setup menu. It finds the usual Steam install or lets you select the Project Zomboid game folder.
4. Enable Knox Survivors in the PZ Mods menu and start a disposable save through Steam.
5. The first run blocks an unknown module hash. Close PZ, reopen the setup app, choose **2**, verify the module ID and SHA-256, then type `ALLOW` or `DENY`. A saved decision applies only to that exact JAR hash; restart through Steam. Blank input leaves the current decision unchanged.

The installer owns and backs up only the PZ startup JSON and its own runtime files. It detects competing Java instrumentation and refuses to stack runtimes. Uninstall with menu option **3**. If the startup config is unchanged, it restores the original bytes; if it has later user edits, it removes only KnoxBridge's arguments and preserves those edits.

## Linux and macOS

The release includes a Unix setup helper. It uses Python 3 from the standard library and modifies only Project Zomboid's `LaunchOptions` entry in your Steam `localconfig.vdf`.

1. Subscribe to KnoxBridge Runtime and Knox Survivors, and wait for Steam downloads to finish.
2. Download and extract `KnoxBridgeRuntime-*.zip` from GitHub Releases.
3. Close Steam, open a terminal in the extracted folder, and run `sh scripts/setup-unix.sh`.
4. Choose **1** to install/update. If setup asks for a `localconfig.vdf` path, select the one under your Steam `userdata/<account>/config/` directory.
5. Reopen Steam, enable Knox Survivors in the PZ Mods menu, and start a disposable save normally.
6. For module trust, close PZ, close Steam, run the setup helper again and choose **2**. Verify each module ID and SHA-256 and type `ALLOW` or `DENY`; restart PZ. Blank input leaves the current decision unchanged.

The helper backs up the exact Steam config before its first edit, records the installed hash, preserves other launch options, and removes only its own option if Steam settings change later. Choose **3** to uninstall. Do not run the helper while Steam is open; Steam can overwrite its local config while running.

Linux/macOS continue to use the `KnoxBridgeRuntime-*.zip` archive and `scripts/setup-unix.sh`; Python 3 is required for the Steam config helper. This path has **not** been live-tested on those operating systems and is not yet a one-file installer. The runtime itself uses Project Zomboid's bundled Java on every platform, so KnoxBridge does not require players to install Java separately. The proven live path remains Windows x64 on PZ 42.21.0. Keep a copy of your Steam config and avoid important saves while testing this alpha.

## Trust and safety

Unknown or changed Java module JARs are not loaded until explicitly allowed by exact SHA-256. Players can persist ALLOW or DENY decisions for modules discovered in the latest game launch. Java modules run with the same permissions as Project Zomboid and are not sandboxed. Approve only code you trust. The independent test module is a developer fixture and is not installed by the player setup.

## Workshop publishing

Run `scripts/stage-workshop.ps1` on Windows to prepare the KnoxBridge dependency marker under `%USERPROFILE%\Zomboid\Workshop\KnoxBridgeRuntime`. If that stage exists, the script first moves it to `%USERPROFILE%\Zomboid\WorkshopBackups` so the previous installer payload is preserved outside the upload folder. It then emits exactly four files under `Contents/mods/KnoxBridgeRuntime`: `mod.info`, `poster.png`, `42/mod.info`, and `42/poster.png`. It copies the default ModTemplate images without modification and checks the payload against Steam's forbidden extensions. The Workshop item points players to the GitHub release for setup. Keep it private until its release visibility and Knox Survivors' Required Items link are ready.

## Acceptance boundaries

- **Offline verified:** runtime, exact-hash trust, Windows installer fixture suite, and standalone EXE payload verification.
- **Wrapper smoke verified:** Windows native bootstrap against the copied launcher fixture.
- **Real PZ 42.21 verified on the prior runtime build:** Windows normal Steam startup, enabled-mod discovery, unknown-hash block, approved module load, and restore/uninstall/reinstall. Alpha2 itself has wrapper smoke and installer fixture checks, but was not rerun through the full game.
- **Unix setup implemented, not live verified:** Linux/macOS Steam config editing and direct Java-agent launch path.
- **Knox module verified:** required Knox hooks and bridge were observed in a live Windows process; movement/combat and persistence still have remaining live acceptance.
