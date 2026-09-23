import com.androidsync.app.ui.TransferSheetLayout;

public final class TransferSheetLayoutTest {
    public static void main(String[] args) {
        assertEquals(720, TransferSheetLayout.bodyMaxHeight(800, 80));
        assertEquals(800, TransferSheetLayout.bodyMaxHeight(800, -10));
        assertEquals(0, TransferSheetLayout.bodyMaxHeight(80, 800));
        assertEquals(0, TransferSheetLayout.bodyMaxHeight(0, 0));
        System.out.println("TransferSheetLayoutTest passed");
    }

    private static void assertEquals(int expected, int actual) {
        if (expected != actual) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
