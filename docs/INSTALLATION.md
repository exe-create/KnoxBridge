# Windows installation

For a player-style install, extract the complete release ZIP and double-click `KnoxBridge Setup.cmd`. Choose **Install**; setup finds a standard Steam install or opens a folder picker, adds the runtime, and copies the independent test module into `%USERPROFILE%\Zomboid\mods`.

In Project Zomboid's Mods menu, enable **KnoxBridge Independent Test Module** and start a game. The first launch records the module's exact SHA-256 and refuses to load it until approved. Exit the game, reopen the setup menu, choose **Approve a module**, check the displayed module ID and hash, and type `ALLOW` to approve that exact file. Restart the game. Check `%USERPROFILE%\Zomboid\KnoxBridge\knoxbridge.log` for the module load result.

Choose **Uninstall** in the same setup menu to restore the original startup configuration and remove KnoxBridge's runtime files. It asks separately before removing the bundled test module. If you changed game launch settings after installing, uninstall preserves those edits while removing only KnoxBridge's arguments.

The setup modifies `ProjectZomboid64.json`, not Steam's launch-options database. It has now been exercised against the installed game and a normal Steam launch reached PZ 42.21.0; the test module and uninstall remain unverified live. The command-line install, verify, and uninstall scripts remain available for advanced use.

## Current installed 42.21 acceptance

On 2026-09-28 the installer was run against the installed game. `verify-installation.ps1` passed; the backed-up JSON hash exactly matched the pre-install hash, and the installed agent and native bootstrap matched their built artifact hashes. The existing historical `.bat.knox-bak` was not changed. A normal Steam AppID launch then logged KnoxBridge startup, Java 25.0.1, PZ 42.21.0, successful `loadMods(List)` transform application, and `runtime ready modules=0`. No active mods were present in that launch context. Test-module approval, module loading, and uninstall/restore acceptance are still pending.

The installer backs up the exact original JSON, adds the native preloader argument before the Java agent, writes an ownership record and copies both runtime artifacts under `.knoxbridge`. It refuses an unmanaged Java/native agent or ZombieBuddy configuration in the game JSON or batch launcher. At runtime, KnoxBridge also checks active JVM arguments so a ZombieBuddy Steam launch option is detected. Repeated install updates the owned files. If the JSON is unchanged since install, uninstall restores its original bytes; if user edits are detected, uninstall removes only the two owned arguments and preserves those edits. Trust data and logs remain in the user-writable Zomboid directory.

This changes `ProjectZomboid64.json`, not Steam's launch-options database. Whether the installed normal Steam route consumes this JSON as expected must be checked live. The current local installation has pre-existing Knox backup state; this project did not modify it.
