package com.knoxbridge.runtime;

import java.io.IOException;
import java.awt.GraphicsEnvironment;
import java.lang.reflect.InvocationTargetException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;
import javax.swing.JDialog;
import javax.swing.JOptionPane;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.SwingUtilities;
import javax.swing.WindowConstants;

/** Startup-time, exact-JAR approval prompt. Missing UI always fails closed. */
final class ModuleApprovalDialog {
    private static final int ALLOW = 0;
    private static final int DENY = 1;
    private static final int SKIP = 2;
    private static final Object[] OPTIONS = {
        "Allow this exact JAR version",
        "Deny this exact JAR version",
        "Skip for now (keep blocked)"
    };

    private ModuleApprovalDialog() { }

    static TrustStore.Decision prompt(ModuleDescriptor descriptor, Path modRoot, String hash,
            Consumer<String> log) {
        if (GraphicsEnvironment.isHeadless()) {
            log.accept("module approval UI unavailable id=" + descriptor.id() + " reason=headless; remains blocked");
            return TrustStore.Decision.APPROVAL_REQUIRED;
        }

        AtomicReference<TrustStore.Decision> selected = new AtomicReference<>(TrustStore.Decision.APPROVAL_REQUIRED);
        Runnable show = () -> selected.set(showDialog(descriptor, modRoot, hash));
        try {
            if (SwingUtilities.isEventDispatchThread()) show.run();
            else SwingUtilities.invokeAndWait(show);
            log.accept("module approval UI completed id=" + descriptor.id() + " decision=" + selected.get());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.accept("module approval UI unavailable id=" + descriptor.id() + " reason=interrupted; remains blocked");
        } catch (InvocationTargetException | RuntimeException e) {
            log.accept("module approval UI unavailable id=" + descriptor.id() + " reason=" + e.getClass().getSimpleName()
                + "; remains blocked");
        }
        return selected.get();
    }

    static TrustStore.Decision decisionForSelection(int selection) {
        return switch (selection) {
            case ALLOW -> TrustStore.Decision.ALLOW_EXACT;
            case DENY -> TrustStore.Decision.DENY_EXACT;
            default -> TrustStore.Decision.APPROVAL_REQUIRED;
        };
    }

    static void persistDecision(TrustStore trust, String hash, TrustStore.Decision decision) throws IOException {
        if (decision == TrustStore.Decision.ALLOW_EXACT || decision == TrustStore.Decision.DENY_EXACT)
            trust.decide(hash, decision);
    }

    static String claimedModInfo(Path modRoot) {
        Properties info = new Properties();
        Path modInfo = modRoot.resolve("mod.info");
        if (Files.isRegularFile(modInfo)) {
            try (var input = Files.newInputStream(modInfo)) { info.load(input); }
            catch (Exception ignored) { }
        }
        String name = clean(info.getProperty("name"));
        String author = clean(info.getProperty("author"));
        if (name.isEmpty()) name = "Not provided";
        if (author.isEmpty()) author = "Not provided";
        return "PZ mod name: " + name + "\nDeclared author (not verified): " + author;
    }

    private static TrustStore.Decision showDialog(ModuleDescriptor descriptor, Path modRoot, String hash) {
        JTextArea details = new JTextArea(
            "KnoxBridge found a Java module enabled in Project Zomboid. It will remain blocked until you choose.\n\n"
                + claimedModInfo(modRoot) + "\nKnoxBridge module ID: " + descriptor.id()
                + "\nModule version: " + descriptor.version() + "\nJAR: " + descriptor.jar()
                + "\nSHA-256: " + hash
                + "\n\nJava modules have the same permissions as Project Zomboid and are not sandboxed."
                + " Only allow code you trust. Your choice applies only to this exact JAR hash.",
            12, 76);
        details.setEditable(false);
        details.setLineWrap(true);
        details.setWrapStyleWord(true);
        details.setCaretPosition(0);
        details.setFocusable(true);
        JOptionPane pane = new JOptionPane(new JScrollPane(details), JOptionPane.WARNING_MESSAGE,
            JOptionPane.DEFAULT_OPTION, null, OPTIONS, OPTIONS[SKIP]);
        JDialog dialog = pane.createDialog(null, "KnoxBridge — Java module approval");
        dialog.setModal(true);
        dialog.setAlwaysOnTop(true);
        dialog.setDefaultCloseOperation(WindowConstants.DISPOSE_ON_CLOSE);
        dialog.setLocationRelativeTo(null);
        dialog.setVisible(true);
        Object choice = pane.getValue();
        dialog.dispose();
        if (Objects.equals(choice, OPTIONS[ALLOW])) return decisionForSelection(ALLOW);
        if (Objects.equals(choice, OPTIONS[DENY])) return decisionForSelection(DENY);
        return decisionForSelection(SKIP);
    }

    private static String clean(String value) {
        if (value == null) return "";
        return value.replace('\r', ' ').replace('\n', ' ').trim();
    }
}
