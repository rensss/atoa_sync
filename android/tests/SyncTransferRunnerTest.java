import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.SyncTransferRunner;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public final class SyncTransferRunnerTest {
    public static void main(String[] args) {
        failedTaskDoesNotStopLaterTasks();
        cancellationReturnsCurrentTaskToWaiting();
        recoveryReturnsUploadingTaskToWaiting();
    }

    private static void failedTaskDoesNotStopLaterTasks() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(Arrays.asList(
                item("runner-1", "first.jpg"),
                item("runner-2", "second.jpg")
        ));
        List<SyncTask> tasks = queue.tasks();
        List<String> uploaded = new ArrayList<>();

        new SyncTransferRunner(queue).run(
                Arrays.asList(tasks.get(0).id(), tasks.get(1).id()),
                "http://receiver/uploads/",
                new SyncTransferRunner.Uploader() {
                    @Override
                    public void upload(
                            SyncTask task,
                            String targetUrl,
                            int batchIndex,
                            int batchTotal,
                            SyncTransferRunner.CancellationSignal cancellation
                    ) throws Exception {
                        uploaded.add(task.media().displayName());
                        if (task.media().displayName().equals("first.jpg")) {
                            throw new IOException("network timeout");
                        }
                    }
                },
                new SyncTransferRunner.CancellationSignal() {
                    @Override
                    public boolean isCancelled() {
                        return false;
                    }
                },
                SyncTransferRunner.NOOP_LISTENER
        );

        assertEquals(Arrays.asList("first.jpg", "second.jpg"), uploaded, "runner should continue after one failed task");
        assertEquals(SyncStatus.FAILED, queue.tasks().get(0).status(), "failed task should be marked failed");
        assertEquals(SyncStatus.DONE, queue.tasks().get(1).status(), "later task should be marked done");
    }

    private static void cancellationReturnsCurrentTaskToWaiting() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(Arrays.asList(
                item("runner-3", "cancelled.jpg"),
                item("runner-4", "untouched.jpg")
        ));
        List<SyncTask> tasks = queue.tasks();
        final boolean[] cancelled = { false };

        new SyncTransferRunner(queue).run(
                Arrays.asList(tasks.get(0).id(), tasks.get(1).id()),
                "http://receiver/uploads/",
                new SyncTransferRunner.Uploader() {
                    @Override
                    public void upload(
                            SyncTask task,
                            String targetUrl,
                            int batchIndex,
                            int batchTotal,
                            SyncTransferRunner.CancellationSignal cancellation
                    ) throws Exception {
                        cancelled[0] = true;
                        throw new IOException("sync stopped");
                    }
                },
                new SyncTransferRunner.CancellationSignal() {
                    @Override
                    public boolean isCancelled() {
                        return cancelled[0];
                    }
                },
                SyncTransferRunner.NOOP_LISTENER
        );

        assertEquals(SyncStatus.WAITING, queue.tasks().get(0).status(), "cancelled task should return to waiting");
        assertEquals(SyncStatus.WAITING, queue.tasks().get(1).status(), "tasks after cancellation should remain waiting");
    }

    private static void recoveryReturnsUploadingTaskToWaiting() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(Arrays.asList(item("runner-5", "recovered.jpg")));
        SyncTask task = queue.tasks().get(0);

        queue.markUploading(task.id());
        queue.resetUploadingTasks(Arrays.asList(task.id()));

        assertEquals(SyncStatus.WAITING, queue.findById(task.id()).status(), "recovery should reset an uploading task");
    }

    private static MediaItem item(String stableId, String displayName) {
        return new MediaItem(stableId, "content://media/" + stableId, displayName, 100L, 1L, false);
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(message + ": expected <" + expected + "> but was <" + actual + ">");
        }
    }
}
