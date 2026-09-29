# KnoxBridge Runtime

KnoxBridge is an independently built Java-mod runtime for Project Zomboid. Knox Survivors is one module using its general API; the runtime does not depend on Knox gameplay.

## Install as a player

Subscribe to the KnoxBridge Runtime Workshop dependency and Knox Survivors. Windows users download `KnoxBridgeSetup.exe` from [GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest) and follow [the setup steps](docs/INSTALLATION.md). The installer is self-contained and uses PZ's bundled Java; no separate Java or .NET download is needed. Its roughly 65 MB size is mostly the bundled self-contained .NET runtime/framework plus the small Bridge payload. A framework-dependent build could be smaller but would require installing .NET first; trimming also needs separate compatibility testing. File size alone is not a security verdict. The installer is unsigned and has limited download history, so Windows may show an unknown-publisher or SmartScreen "isn't commonly downloaded" warning. That reputation warning is not a malware verdict or proof of safety; verify the release source and published SHA-256. If Defender identifies a Trojan or other malware, stop; do not restore, run, or whitelist the file. Linux/macOS players use the ZIP and run `sh scripts/setup-unix.sh` with Steam closed; that helper requires Python 3 and those platforms remain unverified. Then enable Knox Survivors in the PZ Mods menu and start normally through Steam.

The KnoxBridge Workshop item contains the dependency marker, its Bridge-owned PZ menu UI, default ModTemplate images, compile-time API JAR, and concise player/mod-author guides. Enable **KnoxBridge Runtime** and Knox Survivors in the PZ Mods menu. The Workshop item does not install or activate the Java runtime: player setup remains a separate download from GitHub Releases. The Workshop API JAR is only a compile dependency, not the runtime agent. One-time local setup is required on every operating system.

The Bridge Workshop mod opens a full-screen Java review gate at the PZ main menu before a player can enter a world. It lists JARs from enabled mods; unknown hashes remain blocked by default and visible. Players can allow or deny compatible modules by exact SHA-256. If a choice changes which Java modules load, quit and relaunch once to apply it. The optional **Remember choices** toggle saves exact-hash decisions across launches; with it off, choices apply for one launch. If no effective load choice changes, continue without restarting. Unsupported JARs stay blocked until their authors add KnoxBridge compatibility. If the UI cannot save a decision, the module remains blocked. This alpha8 startup gate and Java/Lua handoff still need live Build 42 verification. Java modules have full account permissions; approve only code you trust. Linux/macOS setup and Knox gameplay/save-reload remain unverified.

## Build and verify

Requires Java 17 or newer for building the runtime and the .NET 8 SDK for the self-contained Windows installer. PZ uses its own bundled Java runtime when the agent launches.

```powershell
./gradlew verify
./gradlew packageManualInstaller
./gradlew buildWindowsInstaller
./gradlew packageRuntime
```

The player archive is written to `build/distributions/KnoxBridgeRuntime-0.1.0-alpha8.zip`; the Windows self-contained installer is `bootstrap-windows/build/KnoxBridgeSetup.exe`. `packageRuntime` is the developer/test package and includes the independent example fixture. `scripts/verify-windows-installer.ps1` verifies the embedded archive, confirms no command-shell launch, and exercises disposable install/uninstall fixtures. `scripts/stage-workshop.ps1` stages the Bridge Lua review gate, dependency marker, compile-time API, icon, and guides while excluding installers and test fixtures.

Tracked project sources include the generic Java API/runtime, independent test module, Windows native bootstrap source, Windows and Unix setup tools, verification scripts, and documentation. See [Architecture](docs/ARCHITECTURE.md), [Module API](docs/MODULE_API.md), [Patch API](docs/PATCH_API.md), [Trust and security](docs/SECURITY_AND_TRUST.md), [Compatibility](docs/COMPATIBILITY.md), and [Development testing](docs/DEVELOPMENT_TESTING.md).
