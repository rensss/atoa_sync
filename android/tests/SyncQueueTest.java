import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.TaskWindow;

import java.util.List;
import java.util.Set;

public final class SyncQueueTest {
    public static void main(String[] args) {
        enqueuesNewMediaOnlyOnce();
        retryMovesFailedTaskBackToWaiting();
        summaryCountsTasksByStatus();
        marksRemoteExistingMediaAsDone();
        marksRemoteExistingMediaByFingerprintAsDone();
        taskWindowLimitsRowsAndReportsMore();
    }

    private static void enqueuesNewMediaOnlyOnce() {
        SyncQueue queue = new SyncQueue();
        MediaItem first = item("1", "content://media/1", "IMG_0001.jpg", 2048L);
        MediaItem sameAgain = item("1", "content://media/1", "IMG_0001.jpg", 2048L);
        MediaItem second = item("2", "content://media/2", "VID_0002.mp4", 8192L);

        queue.enqueueAll(List.of(first, sameAgain, second));

        assertEquals(2, queue.tasks().size(), "queue should dedupe media by stable key");
        assertEquals("IMG_0001.jpg", queue.tasks().get(0).media().displayName(), "first task should preserve media metadata");
    }

    private static void retryMovesFailedTaskBackToWaiting() {
        SyncQueue queue = new SyncQueue();
        MediaItem media = item("3", "content://media/3", "IMG_0003.jpg", 4096L);
        queue.enqueueAll(List.of(media));
        SyncTask task = queue.tasks().get(0);

        queue.markUploading(task.id());
        queue.markFailed(task.id(), "network timeout");
        queue.retry(task.id());

        SyncTask retried = queue.tasks().get(0);
        assertEquals(SyncStatus.WAITING, retried.status(), "retry should put failed task back into waiting");
        assertEquals(1, retried.attemptCount(), "retry should keep failure attempt history");
        assertEquals(null, retried.errorMessage(), "retry should clear the visible error");
    }

    private static void summaryCountsTasksByStatus() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(List.of(
                item("4", "content://media/4", "IMG_0004.jpg", 100L),
                item("5", "content://media/5", "IMG_0005.jpg", 200L),
                item("6", "content://media/6", "VID_0006.mp4", 300L),
                item("7", "content://media/7", "IMG_0007.jpg", 400L)
        ));

        List<SyncTask> tasks = queue.tasks();
        queue.markUploading(tasks.get(0).id());
        queue.markDone(tasks.get(1).id());
        queue.markFailed(tasks.get(2).id(), "server rejected upload");

        SyncQueue.Summary summary = queue.summary();
        assertEquals(4, summary.total(), "summary total");
        assertEquals(1, summary.waiting(), "summary waiting");
        assertEquals(1, summary.uploading(), "summary uploading");
        assertEquals(1, summary.done(), "summary done");
        assertEquals(1, summary.failed(), "summary failed");
        assertEquals(200L, summary.syncedBytes(), "summary synced bytes should count completed tasks only");
    }

    private static void marksRemoteExistingMediaAsDone() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(List.of(
                item("8", "content://media/8", "IMG_0008.jpg", 800L),
                item("9", "content://media/9", "IMG_0009.jpg", 900L)
        ));

        queue.markRemoteExisting(Set.of("8"));

        SyncQueue.Summary summary = queue.summary();
        assertEquals(1, summary.done(), "remote existing items should be counted as done");
        assertEquals(1, summary.waiting(), "missing remote items should remain waiting");
        assertEquals(SyncStatus.DONE, queue.tasks().get(0).status(), "matching stable id should be done");
        assertEquals(SyncStatus.WAITING, queue.tasks().get(1).status(), "non-matching stable id should stay waiting");
    }

    private static void marksRemoteExistingMediaByFingerprintAsDone() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(List.of(
                item("10", "content://media/10", "IMG_0010.jpg", 1000L),
                item("11", "content://media/11", "IMG_0011.jpg", 1100L)
        ));

        queue.markRemoteExistingByFingerprint(Set.of("IMG_0010.jpg:1000"));

        SyncQueue.Summary summary = queue.summary();
        assertEquals(1, summary.done(), "remote existing fingerprint should be counted as done");
        assertEquals(1, summary.waiting(), "missing fingerprint should remain waiting");
    }

    private static void taskWindowLimitsRowsAndReportsMore() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(List.of(
                item("12", "content://media/12", "IMG_0012.jpg", 1200L),
                item("13", "content://media/13", "IMG_0013.jpg", 1300L),
                item("14", "content://media/14", "IMG_0014.jpg", 1400L)
        ));

        TaskWindow window = TaskWindow.from(queue.tasks(), 2);

        assertEquals(2, window.visibleTasks().size(), "task window should cap visible rows");
        assertEquals(true, window.hasMore(), "task window should report hidden rows");
        assertEquals(3, window.totalCount(), "task window should preserve total count");
    }

    private static MediaItem item(String stableId, String uri, String displayName, long sizeBytes) {
        return new MediaItem(stableId, uri, displayName, sizeBytes, System.currentTimeMillis(), displayName.endsWith(".mp4"));
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(message + ": expected <" + expected + "> but was <" + actual + ">");
        }
    }
}
