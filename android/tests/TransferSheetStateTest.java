import com.androidsync.app.ui.TransferSheetState;

public final class TransferSheetStateTest {
    public static void main(String[] args) {
        TransferSheetState state = new TransferSheetState();
        assertEquals(true, state.canStop(true));

        state.requestStop();
        assertEquals(true, state.stopRequested());
        assertEquals(false, state.canStop(true));

        state.beginRun();
        assertEquals(false, state.stopRequested());
        assertEquals(true, state.canStop(true));

        state.requestStop();
        state.clearIfIdle(false);
        assertEquals(false, state.stopRequested());
        System.out.println("TransferSheetStateTest passed");
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
