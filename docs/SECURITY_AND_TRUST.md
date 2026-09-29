# Security and trust

Java modules execute with the game's JVM permissions. KnoxBridge is not a Java sandbox. Approval informs the player and keys trust to the actual JAR's SHA-256 digest; it cannot make malicious Java code safe.

Unknown and changed JAR hashes receive `APPROVAL_REQUIRED` and are not loaded. During startup, KnoxBridge now presents a modal approval dialog before loading each unknown module. Allow and deny choices are persisted in `%USERPROFILE%\Zomboid\KnoxBridge\trust.properties`, keyed by lowercase SHA-256. Skip or closing the dialog leaves the module blocked and undecided. If the process is headless or the UI cannot be shown, the module remains blocked; the setup tool's trust menu is the fallback. A changed binary has a different key and requires a new decision.

The dialog may display the module's PZ mod name and declared `author` from `mod.info`, explicitly labeled unverified. Workshop author metadata is not cryptographic identity and KnoxBridge cannot prove who built a JAR. Author signing, signature verification, in-game trust revocation UI, and changed-signed-build policy are not implemented. Never distribute private signing keys in this project or a module.
