import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncStatus;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public final class MediaGridDataTest {
    public static void main(String[] args) throws Exception {
        Object data = newData();
        MediaItem first = item("first");
        MediaItem second = item("second");

        List<MediaItem> input = new ArrayList<>(Arrays.asList(first, second));
        call(data, "replaceItems", new Class<?>[] { List.class }, input);
        input.clear();
        assertEquals(2, (Integer) call(data, "getCount", new Class<?>[0]));
        assertEquals(second, call(data, "getItem", new Class<?>[] { int.class }, 1));

        Map<String, SyncStatus> statuses = new HashMap<>();
        statuses.put(first.stableId(), SyncStatus.UPLOADING);
        call(data, "replaceStatuses", new Class<?>[] { Map.class }, statuses);
        statuses.clear();
        assertEquals(SyncStatus.UPLOADING, call(
                data, "statusFor", new Class<?>[] { MediaItem.class }, first));
        assertEquals(SyncStatus.WAITING, call(
                data, "statusFor", new Class<?>[] { MediaItem.class }, second));

        assertEquals(0, (Integer) call(data, "clampPosition", new Class<?>[] { int.class }, -4));
        assertEquals(1, (Integer) call(data, "clampPosition", new Class<?>[] { int.class }, 1));
        assertEquals(1, (Integer) call(data, "clampPosition", new Class<?>[] { int.class }, 99));
        call(data, "replaceItems", new Class<?>[] { List.class }, new ArrayList<MediaItem>());
        assertEquals(0, (Integer) call(data, "clampPosition", new Class<?>[] { int.class }, 99));
        System.out.println("MediaGridDataTest passed");
    }

    private static Object newData() {
        try {
            return Class.forName("com.androidsync.app.ui.MediaGridData").getConstructor().newInstance();
        } catch (Exception error) {
            throw new AssertionError("MediaGridData must hold replaceable media and status snapshots", error);
        }
    }

    private static Object call(Object target, String name, Class<?>[] parameterTypes, Object... arguments) throws Exception {
        Method method;
        try {
            method = target.getClass().getMethod(name, parameterTypes);
        } catch (NoSuchMethodException error) {
            throw new AssertionError("missing MediaGridData." + name, error);
        }
        return method.invoke(target, arguments);
    }

    private static MediaItem item(String id) {
        return new MediaItem(id, "content://" + id, id + ".jpg", 32L, 0L, false);
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
