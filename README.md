# KnoxBridge Runtime

KnoxBridge is an independently built Java-mod runtime for Project Zomboid. Knox Survivors is one module using its general API; the runtime does not depend on Knox gameplay or ZombieBuddy code.

## Install as a player

Subscribe to the KnoxBridge Runtime Workshop dependency and Knox Survivors. Download the setup from [GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest). Windows players run `KnoxBridgeSetup.exe` directly; it contains the full installer and uses PZ's bundled Java, so no separate Java download or archive extraction is needed. Linux/macOS players use the ZIP and run `sh scripts/setup-unix.sh` with Steam closed; that helper currently requires Python 3. Setup options are **1** install/update, **2** manage a module's exact SHA-256 (**ALLOW** or **DENY**), **3** uninstall, and **4** exit. Then enable Knox Survivors in the PZ Mods menu and start normally through Steam. See [installation details](docs/INSTALLATION.md).

Steam Workshop rejects installer binaries and scripts. Its KnoxBridge item therefore contains only the dependency marker and default ModTemplate images; it cannot install the runtime by itself. One-time local setup is required on every operating system.

The runtime and Knox module path were observed in normal Steam startup on Project Zomboid 42.21.0, including enabled-mod discovery and module loading after exact-hash approval. Alpha4 adds active-mod discovery selection and setup controls to ALLOW or DENY exact JAR hashes. The alpha4 standalone installer still needs its own full Steam-path replay. Linux/macOS setup needs real installations for live validation and is not a single-file installer. Knox module gameplay and save/reload remain under test. Java modules have full account permissions; approve only modules you trust. Trust decisions apply to exact hashes.

## Build and verify

Requires Java 17 or newer for building. PZ uses its own bundled Java runtime when the agent launches.

```powershell
./gradlew verify
./gradlew packageManualInstaller
./gradlew buildWindowsInstaller
./gradlew packageRuntime
```

The Unix/player archive is written to `build/distributions/KnoxBridgeRuntime-0.1.0-alpha4.zip`; the Windows self-contained installer is `bootstrap-windows/build/KnoxBridgeSetup.exe`. `packageRuntime` is the developer/test package and includes the independent example fixture. `scripts/verify-windows-installer.ps1` verifies the EXE's embedded archive. `scripts/stage-workshop.ps1` creates the Steam-safe marker-only Workshop upload folder.

Tracked project sources include the generic Java API/runtime, independent test module, Windows native bootstrap source, Windows and Unix setup tools, verification scripts, and documentation. See [Architecture](docs/ARCHITECTURE.md), [Module API](docs/MODULE_API.md), [Patch API](docs/PATCH_API.md), [Trust and security](docs/SECURITY_AND_TRUST.md), [Compatibility](docs/COMPATIBILITY.md), and [Development testing](docs/DEVELOPMENT_TESTING.md).
