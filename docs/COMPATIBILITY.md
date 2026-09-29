# Compatibility boundaries

KnoxBridge targets the Project Zomboid Java runtime and mod loader. It reads the active mod IDs after Project Zomboid resolves them, then discovers Bridge modules only within those enabled mod roots.

The current adapter binds the observed `ZomboidFileSystem.loadMods(List)` method descriptor. If a future game build changes that method contract, the runtime must fail closed and be updated against that build rather than guessing at another method.

## Java module requirements

A Java mod must provide a valid `knoxbridge.properties` descriptor, use the versioned KnoxBridge API, and declare an entrypoint implementing `KnoxModule`. Arbitrary JARs are inventoried for player visibility but are not loaded just because they are present. Mod authors must explicitly integrate and test their modules against the target Project Zomboid build.

Unknown or changed JAR hashes remain blocked by default. Allow/deny choices apply to the exact SHA-256 digest and are imported before module startup on the next full game launch. The Bridge Workshop menu, file handoff, and Linux/macOS startup still require live platform acceptance.

## Current verification boundary

- Windows live evidence is limited to the dated Build 42/runtime scenario recorded in the release notes; it does not establish full gameplay or save compatibility.
- The new Bridge Workshop menu and its allow/deny file handoff have offline coverage only until a disposable Build 42 replay passes.
- Linux/macOS Steam setup and module startup are not live-verified.
