# KnoxBridge Runtime

KnoxBridge is an independently built Java-mod runtime for Project Zomboid. Knox Survivors is one module using its general API; the runtime does not depend on Knox gameplay or ZombieBuddy code.

## Install as a player

Subscribe to the KnoxBridge Runtime Workshop dependency and Knox Survivors. Windows users download `KnoxBridgeSetup.exe` from [GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest) and follow [the setup steps](docs/INSTALLATION.md). The installer is self-contained and uses PZ's bundled Java; no separate Java download is needed. It is unsigned, so Windows may show an unknown-publisher notice. If Defender reports a Trojan or other malware, stop; do not restore, run, or whitelist the file. Linux/macOS players use the ZIP and run `sh scripts/setup-unix.sh` with Steam closed; that helper requires Python 3 and those platforms remain unverified. Then enable Knox Survivors in the PZ Mods menu and start normally through Steam.

Steam Workshop rejects installer binaries and scripts. Its KnoxBridge item therefore contains only the dependency marker and default ModTemplate images; it cannot install the runtime by itself. One-time local setup is required on every operating system.

The previous alpha4 EXE remains withdrawn. Alpha5 replaces it with a self-contained .NET Windows installer that performs checked package extraction, configuration updates, trust management, and uninstall without starting PowerShell or a command shell. Its SHA-256 is shown on the release page. A targeted Microsoft Defender scan of the alpha5 release candidate found no threats on the maintainer's machine; this is not a guarantee for every antivirus product or machine. Alpha5 installer behavior has offline fixture coverage but still needs a fresh normal-Steam/PZ acceptance run. The runtime and Knox module path were observed in normal Steam startup on Project Zomboid 42.21.0 on the prior runtime build. Linux/macOS setup remains unverified. Knox module gameplay and save/reload remain under test. Java modules have full account permissions; approve only modules you trust. Trust decisions apply to exact hashes.

## Build and verify

Requires Java 17 or newer for building the runtime and the .NET 8 SDK for the self-contained Windows installer. PZ uses its own bundled Java runtime when the agent launches.

```powershell
./gradlew verify
./gradlew packageManualInstaller
./gradlew buildWindowsInstaller
./gradlew packageRuntime
```

The Unix/player archive is written to `build/distributions/KnoxBridgeRuntime-0.1.0-alpha5.zip`; the Windows self-contained installer is `bootstrap-windows/build/KnoxBridgeSetup.exe`. `packageRuntime` is the developer/test package and includes the independent example fixture. `scripts/verify-windows-installer.ps1` verifies the embedded archive, confirms no command-shell launch, and exercises disposable install/uninstall fixtures. `scripts/stage-workshop.ps1` creates the Steam-safe marker-only Workshop upload folder.

Tracked project sources include the generic Java API/runtime, independent test module, Windows native bootstrap source, Windows and Unix setup tools, verification scripts, and documentation. See [Architecture](docs/ARCHITECTURE.md), [Module API](docs/MODULE_API.md), [Patch API](docs/PATCH_API.md), [Trust and security](docs/SECURITY_AND_TRUST.md), [Compatibility](docs/COMPATIBILITY.md), and [Development testing](docs/DEVELOPMENT_TESTING.md).
