# Player setup

KnoxBridge has a small Steam Workshop dependency marker and a separate manual setup download. Steam rejects executable and installer file types in Workshop uploads, so the Workshop item contains only the PZ metadata and default ModTemplate images. The player installer is distributed from [KnoxBridge GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest).

## Windows

1. Subscribe to KnoxBridge Runtime and Knox Survivors, and wait for Steam downloads to finish.
2. Download `KnoxBridgeSetup.exe` from the latest GitHub release. It includes its own installer runtime and uses Project Zomboid's bundled Java; no separate Java or archive extraction is needed. Check the release page's SHA-256 if you want to verify the download.
3. Run setup and choose **1**. It checks for the usual Steam location; if needed, enter the game folder containing `ProjectZomboid64.json`. It refuses to stack with ZombieBuddy or another detected Java agent.
4. Enable Knox Survivors in the PZ Mods menu and start a disposable save through Steam.
5. The first run blocks unknown module hashes. Close PZ, run setup again, choose **2**, inspect each module ID and exact SHA-256, then type `ALLOW` or `DENY`. A saved decision applies only to that exact JAR hash; restart through Steam. Blank input leaves the decision unchanged.
6. To remove KnoxBridge, run setup and choose **3**. If the PZ config is unchanged, it restores the exact original bytes; if edited later, it removes only KnoxBridge's entries and preserves the other edits.

The alpha5 installer is unsigned. Windows may show an **Unknown publisher** notice; that is not the same as a malware detection. If Windows Security reports a Trojan or other malware, stop and do not restore the file from quarantine, run it, add an exclusion, or try another archive as a workaround. Report the detection name and SHA-256 from the release page.

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

Run `scripts/stage-workshop.ps1` on Windows to prepare the KnoxBridge dependency marker under `%USERPROFILE%\Zomboid\Workshop\KnoxBridgeRuntime`. If that stage exists, the script first moves it to `%USERPROFILE%\Zomboid\WorkshopBackups` so the previous payload is preserved outside the upload folder. It then emits exactly four files under `Contents/mods/KnoxBridgeRuntime`: `mod.info`, `poster.png`, `42/mod.info`, and `42/poster.png`. It copies the default ModTemplate images without modification and checks the payload against Steam's forbidden extensions. The public Workshop item points players to the GitHub release for setup; the marker itself does not install KnoxBridge.

## Acceptance boundaries

- **Offline verified:** runtime (29 checks), legacy script installer fixtures (13 checks), Windows native-installer fixtures (8 checks), archive integrity, and Unix config helper tests. The alpha5 build had a targeted Microsoft Defender scan with no threats on the maintainer's machine; this is not universal antivirus or Microsoft cloud-reputation clearance.
- **Wrapper smoke verified:** Windows native bootstrap against the copied launcher fixture.
- **Real PZ 42.21 verified on the prior runtime build:** Windows normal Steam startup, enabled-mod discovery, unknown-hash block, approved module load, and restore/uninstall/reinstall. Alpha5's new installer still needs a fresh normal-Steam/PZ install, first-launch block, trust decision, uninstall, and reinstall replay.
- **Unix setup implemented, not live verified:** Linux/macOS Steam config editing and direct Java-agent launch path.
- **Knox module verified:** required Knox hooks and bridge were observed in a live Windows process; movement/combat and persistence still have remaining live acceptance.
