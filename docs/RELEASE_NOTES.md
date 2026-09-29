# KnoxBridge Runtime 0.1.0-alpha2

- Steam Workshop payload is reduced to the dependency marker and default ModTemplate images. Installer and runtime files are distributed separately.
- Added a numbered Linux/macOS setup helper that backs up and edits only the PZ Steam `LaunchOptions` entry, remembers its own argument, detects a competing Java runtime, and restores safely.
- Kept the established Windows native bootstrap and reversible startup JSON installer.
- Preserved the independent Java test module in the developer build and the existing exact-hash approval model.
- Windows remains the only platform with normal Steam/PZ live acceptance, from the pre-alpha2 runtime build. Alpha2 passed offline checks, Windows installer fixtures and copied-launcher smoke; the full game was not rerun after packaging/version changes. Unix setup has offline parser/restore checks but awaits Linux/macOS live validation.

Install from the [latest GitHub release](https://github.com/exe-create/KnoxBridgeRuntime/releases/latest). See [player setup](INSTALLATION.md) before installing.
