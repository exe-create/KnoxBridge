# KnoxBridge Runtime

KnoxBridge is an independently built Java-mod runtime for Project Zomboid. Knox Survivors is one module using its general API; the runtime does not depend on Knox gameplay or ZombieBuddy code.

## Install as a player

Subscribe to the KnoxBridge Runtime Workshop dependency and Knox Survivors. Download the separate [manual installer from GitHub Releases](https://github.com/exe-create/KnoxBridgeRuntime/releases/latest), extract it, and use its numbered setup menu. Windows uses `KnoxBridge Setup.cmd`; Linux and macOS use `sh scripts/setup-unix.sh` from a terminal with Steam closed. Setup options are **1** install/update, **2** approve a module's exact SHA-256, **3** uninstall, and **4** exit. Then enable Knox Survivors in the PZ Mods menu and start normally through Steam. See [installation details](docs/INSTALLATION.md).

Steam Workshop rejects installer binaries and scripts. Its KnoxBridge item therefore contains only the dependency marker and default ModTemplate images; it cannot install the runtime by itself. One-time local setup is required on every operating system.

The Windows runtime path was observed in normal Steam startup on Project Zomboid 42.21.0, including enabled-mod discovery and test/Knox module loading after explicit hash approval. That live run preceded this alpha2 packaging pass; alpha2 has passed offline checks, installer fixtures, and copied-launcher smoke, but has not been rerun through normal Steam. Linux/macOS setup is newly implemented and still needs real installations for live validation. Knox module gameplay and save/reload remain under test. Java modules have full account permissions; approve only code you trust.

## Build and verify

Requires Java 17 or newer for building. PZ uses its own bundled Java runtime when the agent launches.

```powershell
./gradlew verify
./gradlew packageManualInstaller
./gradlew packageRuntime
```

The player package is written to `build/distributions/KnoxBridgeRuntime-0.1.0-alpha2.zip`. `packageRuntime` is the developer/test package and includes the independent example fixture. `scripts/stage-workshop.ps1` creates the Steam-safe marker-only Workshop upload folder.

Tracked project sources include the generic Java API/runtime, independent test module, Windows native bootstrap source, Windows and Unix setup tools, verification scripts, and documentation. See [Architecture](docs/ARCHITECTURE.md), [Module API](docs/MODULE_API.md), [Patch API](docs/PATCH_API.md), [Trust and security](docs/SECURITY_AND_TRUST.md), [Compatibility](docs/COMPATIBILITY.md), and [Development testing](docs/DEVELOPMENT_TESTING.md).
