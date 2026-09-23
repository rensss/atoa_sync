import com.androidsync.app.ui.LibraryViewportPolicy;

public final class LibraryViewportPolicyTest {
    public static void main(String[] args) {
        assertEquals(true, LibraryViewportPolicy.shouldCapture(true, 1));
        assertEquals(false, LibraryViewportPolicy.shouldCapture(false, 1));
        assertEquals(false, LibraryViewportPolicy.shouldCapture(true, 0));
        System.out.println("LibraryViewportPolicyTest passed");
    }

    private static void assertEquals(boolean expected, boolean actual) {
        if (expected != actual) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
