package com.knoxbridge.runtime;

import java.util.Properties;

/** Publisher names are anchored in the trusted runtime, never in module-supplied metadata. */
final class PublisherIdentity {
    private static final Properties KNOWN = load();

    private static Properties load() {
        Properties known = new Properties();
        try (var in = PublisherIdentity.class.getResourceAsStream("publishers.properties")) {
            if (in != null) known.load(in);
        } catch (Exception ignored) {
            // Identity display fails closed; ordinary exact-hash review still works.
            known.clear();
        }
        return known;
    }

    static String name(String verifiedFingerprint) {
        if (!ModuleReviewFiles.isValidHash(verifiedFingerprint)) return "";
        return KNOWN.getProperty(verifiedFingerprint, "");
    }
}
