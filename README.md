# KnoxBridge Runtime

KnoxBridge is an independently built Java-mod runtime for Project Zomboid. Knox Survivors is one first-party module using its general API; the runtime does not depend on Knox gameplay. Outside authors can integrate with the API, but support and compatibility are not guaranteed.

## Start here

| If you are… | Start with… |
| --- | --- |
| Installing as a player | [Player setup](docs/INSTALLATION.md) and [Trust and security](docs/SECURITY_AND_TRUST.md) |
| Building a Java module | [Module API and quick start](docs/MODULE_API.md), then [Patch API](docs/PATCH_API.md) and [Compatibility and testing](docs/COMPATIBILITY.md) |
| Contributing to KnoxBridge | [Development and acceptance](docs/DEVELOPMENT_TESTING.md), [Architecture](docs/ARCHITECTURE.md), and [Release notes](docs/RELEASE_NOTES.md) |

## Player essentials

Subscribe to the KnoxBridge Runtime Workshop dependency, then separately download the player setup package from [GitHub Releases](https://github.com/exe-create/KnoxBridge/releases/latest). The Workshop item supplies the PZ dependency marker and in-game review UI; it does **not** install or activate the Java runtime. The API JAR in Workshop is for compiling modules, not for player runtime use.

Unknown or changed module JAR hashes are blocked by default. Approved Java modules run with the same permissions as the game user; KnoxBridge is not a sandbox. A changed module set requires the player to confirm quitting, then relaunch PZ through Steam; it does not auto-relaunch. The current review UI and Java/Lua trust handoff still need live PZ acceptance. Linux/macOS setup and runtime are not live-verified. See [installation](docs/INSTALLATION.md) for platform-specific steps and [compatibility](docs/COMPATIBILITY.md) for the evidence boundary.

## Build and verify

Building the runtime requires Java 17 or newer. The self-contained Windows installer also requires the .NET 8 SDK. Players use Project Zomboid's bundled Java at runtime.

```powershell
./gradlew verify
./gradlew packageManualInstaller
./gradlew buildWindowsInstaller
./gradlew packageRuntime
```

The player archive is written to `build/distributions/KnoxBridgeRuntime-0.1.0-alpha10.zip`; the Windows installer is `bootstrap-windows/build/KnoxBridgeSetup.exe`. `packageRuntime` creates a developer/test archive with the independent fixtures and minimal author example. For detailed checks and live-vs-offline acceptance, see [Development and acceptance](docs/DEVELOPMENT_TESTING.md).

## Repository map

- `runtime-api/` — compile-time Java interfaces for module authors.
- `runtime-core/` — Java agent, enabled-mod discovery, trust decisions, and patch engine.
- `examples/minimal-module/` — independently buildable author example.
- `test-module/` — KnoxBridge runtime fixture; not a PZ compatibility guarantee.
- `bootstrap-windows/` and `windows-installer/` — Windows player bootstrap and installer source.
- `workshop/` — Workshop artwork and Bridge-owned Lua UI sources.
- `scripts/` — setup, verification, and guarded Workshop staging tools.
- `docs/` — player setup, module authoring, API, security, compatibility, and release records.

Run `scripts/stage-workshop.ps1` on Windows to prepare the Workshop payload locally. The script preserves an existing stage in `Zomboid/WorkshopBackups`, checks the exact allowed payload, and excludes player installers and test binaries. Staging does not upload to Steam; release and Workshop publication remain owner actions.
