# KnoxBridge Runtime

KnoxBridge is an independently built Java-mod runtime for Project Zomboid. Knox Survivors is one module using its general API; the runtime does not depend on Knox gameplay or ZombieBuddy code.

## Install as a player

Subscribe to the KnoxBridge Runtime Workshop dependency and Knox Survivors. Windows users download `KnoxBridgeSetup.exe` from [GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest) and follow [the setup steps](docs/INSTALLATION.md). The installer is self-contained and uses PZ's bundled Java; no separate Java download is needed. It is unsigned, so Windows may show an unknown-publisher notice. If Defender reports a Trojan or other malware, stop; do not restore, run, or whitelist the file. Linux/macOS players use the ZIP and run `sh scripts/setup-unix.sh` with Steam closed; that helper requires Python 3 and those platforms remain unverified. Then enable Knox Survivors in the PZ Mods menu and start normally through Steam.

The KnoxBridge Workshop item contains the dependency marker, default ModTemplate images, compile-time API JAR, and concise player/mod-author guides. It does not install or activate the runtime: player setup remains a separate download from GitHub Releases. The Workshop API JAR is only a compile dependency, not the runtime agent. One-time local setup is required on every operating system.

The previous alpha4 EXE remains withdrawn. Alpha5 replaced its unsafe self-extractor with a self-contained .NET Windows installer. Alpha6 adds a startup approval dialog before an unknown Java module is loaded. It shows the module ID, file hash, and any author claimed in `mod.info` (not verified); choices apply only to that exact JAR hash. If a graphical prompt is unavailable, the module remains blocked and the installer trust menu remains available as a fallback. Java modules have full account permissions; approve only modules you trust. The startup dialog still needs live Windows/Build 42 acceptance. Linux/macOS setup and Knox gameplay/save-reload remain unverified.

## Build and verify

Requires Java 17 or newer for building the runtime and the .NET 8 SDK for the self-contained Windows installer. PZ uses its own bundled Java runtime when the agent launches.

```powershell
./gradlew verify
./gradlew packageManualInstaller
./gradlew buildWindowsInstaller
./gradlew packageRuntime
```

The Unix/player archive is written to `build/distributions/KnoxBridgeRuntime-0.1.0-alpha6.zip`; the Windows self-contained installer is `bootstrap-windows/build/KnoxBridgeSetup.exe`. `packageRuntime` is the developer/test package and includes the independent example fixture. `scripts/verify-windows-installer.ps1` verifies the embedded archive, confirms no command-shell launch, and exercises disposable install/uninstall fixtures. `scripts/stage-workshop.ps1` stages the dependency marker, compile-time API, and existing guides while excluding installers and test fixtures.

Tracked project sources include the generic Java API/runtime, independent test module, Windows native bootstrap source, Windows and Unix setup tools, verification scripts, and documentation. See [Architecture](docs/ARCHITECTURE.md), [Module API](docs/MODULE_API.md), [Patch API](docs/PATCH_API.md), [Trust and security](docs/SECURITY_AND_TRUST.md), [Compatibility](docs/COMPATIBILITY.md), and [Development testing](docs/DEVELOPMENT_TESTING.md).
