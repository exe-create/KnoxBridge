package com.knoxbridge.runtime;

import java.nio.file.Path;

/** Offline exact-hash approval utility; it never approves by module name or publisher metadata. */
public final class TrustCtl {
    public static void main(String[] args) throws Exception {
        if (args.length != 2 || !args[0].matches("(?i)[0-9a-f]{64}")
                || !(args[1].equals("allow") || args[1].equals("deny")
                    || args[1].equals("allow-once") || args[1].equals("deny-once"))) {
            System.err.println("Usage: TrustCtl <64-character-sha256> <allow|deny|allow-once|deny-once>");
            System.exit(2);
        }
        Path storePath = Path.of(System.getProperty("user.home"), "Zomboid", "KnoxBridge", "trust.properties");
        TrustStore store = new TrustStore(storePath);
        TrustStore.Decision decision = switch (args[1]) {
            case "allow" -> TrustStore.Decision.ALLOW_EXACT;
            case "deny" -> TrustStore.Decision.DENY_EXACT;
            case "allow-once" -> TrustStore.Decision.ALLOW_ONCE;
            default -> TrustStore.Decision.DENY_ONCE;
        };
        if (args[1].endsWith("-once")) store.decideNextLaunch(args[0].toLowerCase(), decision);
        else store.decide(args[0].toLowerCase(), decision);
        System.out.println("KnoxBridge trust saved decision=" + args[1] + " sha256=" + args[0].toLowerCase());
    }
}
