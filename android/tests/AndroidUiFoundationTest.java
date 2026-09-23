import com.androidsync.app.ui.Theme;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

public final class AndroidUiFoundationTest {
    public static void main(String[] args) throws Exception {
        testThemeTokens();
        testInsetsPaddingUsesOriginalBaseline();
        System.out.println("AndroidUiFoundationTest passed");
    }

    private static void testThemeTokens() throws Exception {
        assertTheme("BG", "#11151A");
        assertTheme("BG_SURFACE", "#1A2027");
        assertTheme("BG_RAISED", "#242D36");
        assertTheme("STROKE", "#35414B");
        assertTheme("TEXT_PRIMARY", "#F2F5F7");
        assertTheme("TEXT_SECONDARY", "#B3BEC6");
        assertTheme("TEXT_MUTED", "#85939D");
        assertTheme("ACCENT", "#59C3D4");
        assertTheme("STATUS_RUNNING", "#57CB91");
        assertTheme("STATUS_WARNING", "#E8B85E");
        assertTheme("STATUS_FAILED", "#F07578");
        assertEquals(48, Theme.class.getField("MIN_TOUCH_TARGET_DP").getInt(null));
        assertEquals(4, Theme.SPACE_XS);
        assertEquals(8, Theme.SPACE_S);
        assertEquals(12, Theme.SPACE_M);
        assertEquals(16, Theme.SPACE_L);
        assertEquals(24, Theme.class.getField("SPACE_XL").getInt(null));
    }

    private static void testInsetsPaddingUsesOriginalBaseline() throws Exception {
        Class<?> helper;
        try {
            helper = Class.forName("com.androidsync.app.ui.UiInsetsPadding");
        } catch (ClassNotFoundException error) {
            throw new AssertionError("UiInsetsPadding must add insets to the captured baseline", error);
        }
        Method apply = helper.getMethod("apply", int[].class, int[].class);
        int[] baseline = new int[] { 8, 12, 8, 4 };
        int[] insets = new int[] { 0, 24, 0, 34 };
        int[] result = (int[]) apply.invoke(null, baseline, insets);
        assertArrayEquals(new int[] { 8, 36, 8, 38 }, result);
        assertArrayEquals(new int[] { 8, 12, 8, 4 }, baseline);
        assertArrayEquals(new int[] { 8, 36, 8, 38 }, (int[]) apply.invoke(null, baseline, insets));
    }

    private static void assertTheme(String name, String expected) throws Exception {
        Field field;
        try {
            field = Theme.class.getField(name);
        } catch (NoSuchFieldException error) {
            throw new AssertionError("missing Theme." + name, error);
        }
        assertEquals(expected, field.get(null));
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }

    private static void assertEquals(int expected, int actual) {
        if (expected != actual) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }

    private static void assertArrayEquals(int[] expected, int[] actual) {
        if (actual == null || expected.length != actual.length) {
            throw new AssertionError("expected array length " + expected.length);
        }
        for (int i = 0; i < expected.length; i++) {
            if (expected[i] != actual[i]) {
                throw new AssertionError("expected " + expected[i] + " at " + i + " got " + actual[i]);
            }
        }
    }
}
