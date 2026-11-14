import java.io.File;
import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import java.util.Arrays;
import java.util.Locale;
import java.util.Properties;

/** Local, read-only signing gate. Passwords are never command-line arguments. */
public final class KeyStoreProbe {
    public static void main(String[] args) {
        char[] storePassword = null;
        char[] keyPassword = null;
        Properties properties = new Properties();
        int exitCode = 0;
        try {
            if (args.length != 1) throw new IllegalArgumentException();
            try (FileInputStream input = new FileInputStream(args[0])) {
                properties.load(input);
            }
            String alias = properties.getProperty("keyAlias");
            storePassword = properties.getProperty("storePassword").toCharArray();
            keyPassword = properties.getProperty("keyPassword").toCharArray();
            KeyStore store = KeyStore.getInstance(
                new File(properties.getProperty("storeFile")), storePassword);
            KeyStore.Entry entry = store.getEntry(
                alias, new KeyStore.PasswordProtection(keyPassword));
            if (!(entry instanceof KeyStore.PrivateKeyEntry)) {
                throw new IllegalArgumentException();
            }
            X509Certificate certificate = (X509Certificate)
                ((KeyStore.PrivateKeyEntry) entry).getCertificate();
            String subject = certificate.getSubjectX500Principal().getName();
            boolean debug = Arrays.stream(subject.split(","))
                .map(String::trim).map(value -> value.toLowerCase(Locale.ROOT))
                .anyMatch(value -> value.equals("cn=android debug") || value.equals("cn=ci"));
            if (debug || "androiddebugkey".equalsIgnoreCase(alias)) {
                throw new IllegalArgumentException();
            }
            StringBuilder digest = new StringBuilder();
            for (byte value : MessageDigest.getInstance("SHA-256").digest(certificate.getEncoded())) {
                digest.append(String.format("%02x", value & 0xff));
            }
            System.out.println("{\"privateKeyUnlocked\":true,\"debugCertificate\":false,"
                + "\"certificateSha256\":\"" + digest + "\"}");
        } catch (Exception error) {
            // Exception messages can contain aliases, paths or input values.
            System.err.println("SIGNING_PROBE_FAILED");
            exitCode = 2;
        } finally {
            if (storePassword != null) Arrays.fill(storePassword, '\0');
            if (keyPassword != null) Arrays.fill(keyPassword, '\0');
            properties.clear();
        }
        if (exitCode != 0) System.exit(exitCode);
    }
}
