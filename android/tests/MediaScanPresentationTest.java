import com.androidsync.app.core.MediaItem;
import com.androidsync.app.ui.MediaScanPresentation;

import java.util.ArrayList;
import java.util.List;

public final class MediaScanPresentationTest {
    public static void main(String[] args) {
        List<MediaItem> media = new ArrayList<>();
        for (int index = 0; index < 3; index++) {
            media.add(new MediaItem("media-" + index, "content://media-" + index,
                    "media-" + index + ".jpg", 20L, 0L, false));
        }
        MediaScanPresentation local = MediaScanPresentation.localReady(media);
        assertEquals(3, local.mediaCount());
        assertEquals(true, local.remotePending());
        assertContains("正在核对接收端", local.message());

        MediaScanPresentation complete = MediaScanPresentation.complete(media, 2, "");
        assertEquals(3, complete.mediaCount());
        assertEquals(false, complete.remotePending());
        assertContains("接收端已有 2 个记录", complete.message());
        System.out.println("MediaScanPresentationTest passed");
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }

    private static void assertContains(String expected, String actual) {
        if (!actual.contains(expected)) {
            throw new AssertionError("expected '" + actual + "' to contain '" + expected + "'");
        }
    }
}
