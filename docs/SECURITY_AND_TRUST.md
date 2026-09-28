# Security and trust

Java modules execute with the game's JVM permissions. KnoxBridge is not a Java sandbox. Approval informs the player and keys trust to the actual JAR's SHA-256 digest; it cannot make malicious Java code safe.

Unknown and changed JAR hashes receive `APPROVAL_REQUIRED` and are not loaded. Persistent decisions are stored in `%USERPROFILE%\Zomboid\KnoxBridge\trust.properties`, keyed by lowercase SHA-256. `TrustCtl <sha256> allow|deny|allow-once|deny-once` records a choice; one-time decisions are consumed on the next game launch. The current workflow is: read the required hash and module ID from the runtime log, close the game, record the choice, then relaunch. There is no in-game prompt yet. A changed binary has a different key and requires a new decision.

Workshop author metadata is not cryptographic identity. Author signing, signature verification, trust revocation UI, and changed-signed-build policy are not implemented. Never distribute private signing keys in this project or a module.
