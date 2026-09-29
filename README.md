# KnoxBridge Runtime

KnoxBridge is an independently built Java-mod runtime for Project Zomboid. Knox Survivors is one module using its general API; the runtime does not depend on Knox gameplay.

## Install as a player

Subscribe to the KnoxBridge Runtime Workshop dependency and Knox Survivors. Windows users download `KnoxBridgeSetup.exe` from [GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest) and follow [the setup steps](docs/INSTALLATION.md). The installer is self-contained and uses PZ's bundled Java; no separate Java or .NET download is needed. Its roughly 65 MB size is mostly the bundled self-contained .NET runtime/framework plus the small Bridge payload. A framework-dependent build could be smaller but would require installing .NET first; trimming also needs separate compatibility testing. File size alone is not a security verdict. It is unsigned, so Windows may show an unknown-publisher notice. If Defender reports a Trojan or other malware, stop; do not restore, run, or whitelist the file. Linux/macOS players use the ZIP and run `sh scripts/setup-unix.sh` with Steam closed; that helper requires Python 3 and those platforms remain unverified. Then enable Knox Survivors in the PZ Mods menu and start normally through Steam.

The KnoxBridge Workshop item contains the dependency marker, its Bridge-owned PZ menu UI, default ModTemplate images, compile-time API JAR, and concise player/mod-author guides. Enable **KnoxBridge Runtime** and Knox Survivors in the PZ Mods menu. The Workshop item does not install or activate the Java runtime: player setup remains a separate download from GitHub Releases. The Workshop API JAR is only a compile dependency, not the runtime agent. One-time local setup is required on every operating system.

The previous alpha4 EXE remains withdrawn. Alpha5 replaced its unsafe self-extractor with a self-contained .NET Windows installer. This worktree adds a PZ main-menu **Review Java Mods** screen to the Bridge Workshop mod and queues exact-hash choices for the next runtime launch. **This new UI is not included in the currently published runtime or Workshop payload.** It requires an updated KnoxBridge runtime package and KnoxBridge Workshop item; Knox Survivors itself does not need a code update. Unknown JARs are blocked by default; JARs found in enabled mod folders are listed with hashes and claimed (unverified) authors. JARs without a valid KnoxBridge module descriptor are shown as incompatible and cannot be enabled until their authors add Bridge compatibility. Choices apply on the next full launch because Java modules cannot safely load late after PZ startup. If the review UI cannot save a decision, the module remains blocked. The UI and file handoff are not yet live-verified in Build 42. Java modules have full account permissions; approve only code you trust. Linux/macOS setup and Knox gameplay/save-reload remain unverified.

## Build and verify

Requires Java 17 or newer for building the runtime and the .NET 8 SDK for the self-contained Windows installer. PZ uses its own bundled Java runtime when the agent launches.

```powershell
./gradlew verify
./gradlew packageManualInstaller
./gradlew buildWindowsInstaller
./gradlew packageRuntime
```

The player archive is written to `build/distributions/KnoxBridgeRuntime-0.1.0-alpha7.zip`; the Windows self-contained installer is `bootstrap-windows/build/KnoxBridgeSetup.exe`. `packageRuntime` is the developer/test package and includes the independent example fixture. `scripts/verify-windows-installer.ps1` verifies the embedded archive, confirms no command-shell launch, and exercises disposable install/uninstall fixtures. `scripts/stage-workshop.ps1` stages the Bridge Lua menu UI, dependency marker, compile-time API, icon, and guides while excluding installers and test fixtures.

Tracked project sources include the generic Java API/runtime, independent test module, Windows native bootstrap source, Windows and Unix setup tools, verification scripts, and documentation. See [Architecture](docs/ARCHITECTURE.md), [Module API](docs/MODULE_API.md), [Patch API](docs/PATCH_API.md), [Trust and security](docs/SECURITY_AND_TRUST.md), [Compatibility](docs/COMPATIBILITY.md), and [Development testing](docs/DEVELOPMENT_TESTING.md).
