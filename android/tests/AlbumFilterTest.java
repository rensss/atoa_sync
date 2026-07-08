import com.androidsync.app.core.AlbumFilter;
import com.androidsync.app.core.MediaItem;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class AlbumFilterTest {
    public static void main(String[] args) {
        testPendingFiltersSyncedAndExcluded();
        testWhitelistNullMeansNotConfigured();
        System.out.println("AlbumFilterTest passed");
    }

    private static MediaItem item(String id, long size, String bucket) {
        return new MediaItem(id, "content://" + id, id + ".jpg", size, 0L, 0L, 0L, false, "image/jpeg", bucket, bucket);
    }

    private static void testPendingFiltersSyncedAndExcluded() {
        List<MediaItem> scanned = Arrays.asList(
                item("a", 10, "cam"), item("b", 20, "cam"), item("c", 30, "cam"));
        Set<String> synced = new HashSet<>(Collections.singletonList("a"));
        Set<String> excluded = new HashSet<>(Collections.singletonList("c"));
        AlbumFilter.Selection sel = AlbumFilter.pending(scanned, synced, excluded);
        assertEquals(1, sel.pending.size());
        assertEquals("b", sel.pending.get(0).stableId());
        assertEquals(20L, sel.totalBytes);
    }

    private static void testWhitelistNullMeansNotConfigured() {
        assertEquals(false, AlbumFilter.inWhitelist(item("a", 1, "cam"), null));
        Set<String> allow = new HashSet<>(Collections.singletonList("cam"));
        assertEquals(true, AlbumFilter.inWhitelist(item("a", 1, "cam"), allow));
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }

    private static void assertEquals(long expected, long actual) {
        if (expected != actual) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
