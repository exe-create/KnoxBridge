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
- Keeps KnoxBridge independent of Knox Survivors gameplay and ZombieBuddy code. Use only one Java runtime agent at a time; do not stack KnoxBridge with ZombieBuddy.
- Windows download: `KnoxBridgeSetup.exe` (self-contained setup; uses the game's bundled Java). Linux/macOS download: `KnoxBridgeRuntime-0.1.0-alpha4.zip` (Python 3 helper; close Steam while changing its config).
- Unknown or changed module hashes remain blocked until the player explicitly allows that exact file. Java modules have the same permissions as the game and are not sandboxed.
- Offline packaging and verifier checks pass. The alpha4 package has not yet had its own live Build 42 acceptance run. Linux/macOS still require native live testing.
