import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.TaskWindow;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

public final class TransferSheetDataTest {
    public static void main(String[] args) throws Exception {
        SyncQueue empty = queueWith(0);
        Object emptyData = snapshot(empty, false);
        assertEquals(0, number(emptyData, "visibleTaskCount"));
        assertEquals(false, bool(emptyData, "showStop"));
        assertEquals(0, number(emptyData, "hiddenCount"));

        SyncQueue one = queueWith(1);
        Object oneData = snapshot(one, true);
        assertEquals(1, number(oneData, "visibleTaskCount"));
        assertEquals(true, bool(oneData, "showStop"));
        assertEquals(false, bool(oneData, "hasMore"));

        SyncQueue forty = queueWith(40);
        Object fortyData = snapshot(forty, true);
        assertEquals(40, number(fortyData, "visibleTaskCount"));
        assertEquals(0, number(fortyData, "hiddenCount"));

        SyncQueue fortyOne = queueWith(41);
        Object fortyOneData = snapshot(fortyOne, true);
        assertEquals(40, number(fortyOneData, "visibleTaskCount"));
        assertEquals(true, bool(fortyOneData, "hasMore"));
        assertEquals(1, number(fortyOneData, "hiddenCount"));

        SyncQueue completed = queueWith(2);
        completed.markDone(completed.tasks().get(0).id());
        Object terminalData = snapshot(completed, false);
        assertEquals(false, bool(terminalData, "showStop"));
        assertEquals(20L, longNumber(terminalData, "remainingBytes"));
        System.out.println("TransferSheetDataTest passed");
    }

    private static SyncQueue queueWith(int count) {
        SyncQueue queue = new SyncQueue();
        List<MediaItem> items = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            items.add(new MediaItem("media-" + i, "content://media-" + i,
                    "media-" + i + ".jpg", 20L, 0L, false));
        }
        queue.enqueueAll(items);
        return queue;
    }

    private static Object snapshot(SyncQueue queue, boolean runActive) throws Exception {
        try {
            Class<?> type = Class.forName("com.androidsync.app.ui.TransferSheetData");
            Constructor<?> constructor = type.getConstructor(SyncQueue.Summary.class, TaskWindow.class, boolean.class);
            return constructor.newInstance(queue.summary(), queue.activeWindow(40), runActive);
        } catch (ClassNotFoundException error) {
            throw new AssertionError("TransferSheetData must project the bounded queue snapshot", error);
        }
    }

    private static Object invoke(Object target, String name) throws Exception {
        Method method;
        try {
            method = target.getClass().getMethod(name);
        } catch (NoSuchMethodException error) {
            throw new AssertionError("missing TransferSheetData." + name, error);
        }
        return method.invoke(target);
    }

    private static int number(Object target, String name) throws Exception {
        return ((Number) invoke(target, name)).intValue();
    }

    private static long longNumber(Object target, String name) throws Exception {
        return ((Number) invoke(target, name)).longValue();
    }

    private static boolean bool(Object target, String name) throws Exception {
        return (Boolean) invoke(target, name);
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " got " + actual);
        }
    }
}
