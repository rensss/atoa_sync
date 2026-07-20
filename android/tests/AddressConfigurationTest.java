import com.androidsync.app.core.AddressConfiguration;

public final class AddressConfigurationTest {
    public static void main(String[] args) {
        parsesReceiverAddressFromConfigurationLink();
        preservesEncodedTargetQueryValues();
        rejectsUnsupportedOrMalformedLinks();
        System.out.println("AddressConfigurationTest passed");
    }

    private static void parsesReceiverAddressFromConfigurationLink() {
        String target = AddressConfiguration.targetUrlFromDeepLink(
                "androidsync://configure?url=http%3A%2F%2F192.168.1.6%3A8765%2Fuploads%2F"
        );
        assertEquals("http://192.168.1.6:8765/uploads/", target, "should decode receiver URL");
    }

    private static void preservesEncodedTargetQueryValues() {
        String target = AddressConfiguration.targetUrlFromDeepLink(
                "androidsync://configure?url=https%3A%2F%2Fnas.local%2Fwebdav%2F%3Ftoken%3Da%252Bb"
        );
        assertEquals("https://nas.local/webdav/?token=a%2Bb", target, "should preserve nested URL encoding");
    }

    private static void rejectsUnsupportedOrMalformedLinks() {
        assertEquals(null, AddressConfiguration.targetUrlFromDeepLink(
                "https://example.com/?url=http%3A%2F%2F192.168.1.6%2Fuploads%2F"
        ), "should require app scheme");
        assertEquals(null, AddressConfiguration.targetUrlFromDeepLink(
                "androidsync://configure?url=file%3A%2F%2F%2Ftmp%2Fuploads"
        ), "should reject non-HTTP targets");
        assertEquals(null, AddressConfiguration.targetUrlFromDeepLink(
                "androidsync://configure?url=http%3A%2F%2F"
        ), "should reject targets without a host");
        assertEquals(null, AddressConfiguration.targetUrlFromDeepLink("not a URL"), "should reject malformed input");
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(message + " (expected=" + expected + ", actual=" + actual + ")");
        }
    }
}
