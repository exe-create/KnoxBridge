# KnoxBridge Runtime

Independent Java-mod runtime/bootstrap for Project Zomboid. The project is separate from Knox Survivors; Knox is a future client of the generic module API, not a runtime dependency.

## Current milestone

This repository contains an early Windows runtime vertical slice: a public module API, a small native DLL-search bootstrap followed by a Java agent, a PZ adapter that captures the active IDs passed through `ZomboidFileSystem.loadMods(List)` and resolves their selected mod directories, SHA-256 identity, exact-hash allow/deny storage, isolated per-module class loaders, lifecycle callbacks, class-and-method patch target checks, a separate harmless example module, and reversible `ProjectZomboid64.json` setup scripts.

Build with `gradlew verify`. The build targets Java 17 bytecode for compatibility, while the installed PZ copy uses a bundled Java 25 runtime. The actual 42.21 agent startup has not been live-tested.

## Try it as a player (Windows)

Download and extract `knoxbridge-runtime-0.1.0-alpha1.zip`, then double-click `KnoxBridge Setup.cmd`. Choose Install, enable **KnoxBridge Independent Test Module** in PZ's Mods menu, and start a game. For the first run, exit PZ and choose **Approve a module** in setup; verify its ID and exact SHA-256 before typing `ALLOW`. Restart PZ to load the test module. Use **Uninstall** in the same menu to remove KnoxBridge. Start with a copied game folder until Steam and live-game acceptance are complete.

This is a user-facing alpha install and test flow, not yet a universal loader for existing Java mods. Modules must be built for the KnoxBridge API. See [Windows installation](docs/INSTALLATION.md) for the complete steps and limits.

The adapter was checked offline against the installed PZ JAR signature and a transformed fixture. The actual Steam launch and in-game callback remain unverified on PZ 42.21. There is no machine-wide JAR scan, no default trust for unknown code, and no claim that Java modules are sandboxed.

## Build and local verification

```powershell
./gradlew verify
./gradlew :runtime-core:jar :test-module:jar
```

The agent artifact is under `runtime-core/build/libs/`; the public compile-time API is under `runtime-api/build/libs/`; the native preloader is under `bootstrap-windows/build/`; the independent module JAR is under `test-module/build/libs/`. `build/distributions/knoxbridge-runtime-0.1.0-alpha1.zip` contains these, checksums, scripts, docs, and the staged example PZ mod. `scripts/verify-installer.ps1` exercises install, repeat install, verification, restoration, and preservation of later user edits against a temporary fixture. `scripts/verify-windows-bootstrap.ps1` tests the copied PZ launcher executable with an isolated smoke application.

See [Architecture](docs/ARCHITECTURE.md), [Installation](docs/INSTALLATION.md), [Module API](docs/MODULE_API.md), [Patch API](docs/PATCH_API.md), [Trust and security](docs/SECURITY_AND_TRUST.md), [Compatibility](docs/COMPATIBILITY.md), and [Development testing](docs/DEVELOPMENT_TESTING.md).
