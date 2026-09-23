import com.androidsync.app.core.MediaItem;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class SelectionSummaryTest {
    public static void main(String[] args) throws Exception {
        List<MediaItem> pending = Arrays.asList(
                item("a", 10L), item("b", 20L), item("c", 30L));

        Object all = summarize(pending, Collections.<String>emptySet());
        assertEquals(3, number(all, "selectedCount"));
        assertEquals(60L, numberLong(all, "selectedBytes"));

        Set<String> oneExcluded = new HashSet<>(Collections.singleton("b"));
        Object partial = summarize(pending, oneExcluded);
        assertEquals(2, number(partial, "selectedCount"));
        assertEquals(40L, numberLong(partial, "selectedBytes"));

        Set<String> allExcluded = new HashSet<>(Arrays.asList("a", "b", "c"));
        Object none = summarize(pending, allExcluded);
        assertEquals(0, number(none, "selectedCount"));
        assertEquals(0L, numberLong(none, "selectedBytes"));

        Object empty = summarize(Collections.<MediaItem>emptyList(), Collections.<String>emptySet());
        assertEquals(0, number(empty, "selectedCount"));
        assertEquals(0L, numberLong(empty, "selectedBytes"));
        System.out.println("SelectionSummaryTest passed");
    }

    private static MediaItem item(String id, long bytes) {
        return new MediaItem(id, "content://media/" + id, id + ".jpg", bytes, 0L, false);
    }

    private static Object summarize(List<MediaItem> pending, Set<String> excluded) throws Exception {
        try {
            Class<?> type = Class.forName("com.androidsync.app.ui.SelectionSummary");
            Method from = type.getMethod("from", List.class, Set.class);
            return from.invoke(null, pending, excluded);
        } catch (ClassNotFoundException error) {
            throw new AssertionError("SelectionSummary must calculate selected count and bytes", error);
        } catch (NoSuchMethodException error) {
            throw new AssertionError("missing SelectionSummary.from(List, Set)", error);
        }
    }

    private static int number(Object target, String name) throws Exception {
        return ((Number) target.getClass().getMethod(name).invoke(target)).intValue();
    }

    private static long numberLong(Object target, String name) throws Exception {
        return ((Number) target.getClass().getMethod(name).invoke(target)).longValue();
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
