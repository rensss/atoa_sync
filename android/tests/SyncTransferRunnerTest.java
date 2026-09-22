import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.SyncTransferRunner;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public final class SyncTransferRunnerTest {
    public static void main(String[] args) {
        failedTaskDoesNotStopLaterTasks();
        cancellationReturnsCurrentTaskToWaiting();
        recoveryReturnsUploadingTaskToWaiting();
        batchMetadataUsesOnlyUploadableTasks();
        batchTotalBytesSaturatesAtLongMaxValue();
        zeroByteBatchReportsZeroTotal();
        allRemoteExistingTasksFinishWithoutUpload();
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
                            long batchTotalBytes,
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
                            long batchTotalBytes,
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

    private static void batchMetadataUsesOnlyUploadableTasks() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(Arrays.asList(
                item("runner-batch-1", "first.jpg", 100L),
                item("runner-batch-2", "remote.jpg", 250L),
                item("runner-batch-3", "third.jpg", 300L),
                item("runner-batch-4", "failed.jpg", 350L)
        ));
        List<SyncTask> tasks = queue.tasks();
        queue.markRemoteExisting(Collections.singleton("runner-batch-2"));
        queue.markFailed(tasks.get(3).id(), "retry me");
        List<String> uploadedNames = new ArrayList<>();
        List<Integer> batchIndexes = new ArrayList<>();
        List<Integer> batchTotals = new ArrayList<>();
        List<Long> batchTotalBytes = new ArrayList<>();

        new SyncTransferRunner(queue).run(
                Arrays.asList(tasks.get(0).id(), tasks.get(1).id(), tasks.get(2).id(), tasks.get(3).id()),
                "http://receiver/uploads/",
                new SyncTransferRunner.Uploader() {
                    @Override
                    public void upload(
                            SyncTask task,
                            String targetUrl,
                            int batchIndex,
                            int batchTotal,
                            long totalBytes,
                            SyncTransferRunner.CancellationSignal cancellation
                    ) {
                        uploadedNames.add(task.media().displayName());
                        batchIndexes.add(batchIndex);
                        batchTotals.add(batchTotal);
                        batchTotalBytes.add(totalBytes);
                    }
                },
                neverCancelled(),
                SyncTransferRunner.NOOP_LISTENER
        );

        assertEquals(Arrays.asList("first.jpg", "third.jpg", "failed.jpg"), uploadedNames,
                "remote-existing task should be skipped and failed task should remain retryable");
        assertEquals(Arrays.asList(1, 2, 3), batchIndexes, "batch indexes should cover actual uploads only");
        assertEquals(Arrays.asList(3, 3, 3), batchTotals, "batch total should exclude remote-existing tasks");
        assertEquals(Arrays.asList(750L, 750L, 750L), batchTotalBytes,
                "batch bytes should include waiting and failed tasks but exclude remote-existing tasks");
    }

    private static void batchTotalBytesSaturatesAtLongMaxValue() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(Arrays.asList(
                item("runner-overflow-1", "large.bin", Long.MAX_VALUE),
                item("runner-overflow-2", "small.bin", 1L)
        ));
        List<Long> batchTotalBytes = new ArrayList<>();

        new SyncTransferRunner(queue).run(
                Arrays.asList(queue.tasks().get(0).id(), queue.tasks().get(1).id()),
                "http://receiver/uploads/",
                new SyncTransferRunner.Uploader() {
                    @Override
                    public void upload(
                            SyncTask task,
                            String targetUrl,
                            int batchIndex,
                            int batchTotal,
                            long totalBytes,
                            SyncTransferRunner.CancellationSignal cancellation
                    ) {
                        batchTotalBytes.add(totalBytes);
                    }
                },
                neverCancelled(),
                SyncTransferRunner.NOOP_LISTENER
        );

        assertEquals(Arrays.asList(Long.MAX_VALUE, Long.MAX_VALUE), batchTotalBytes,
                "batch byte sum should saturate rather than overflow");
    }

    private static void zeroByteBatchReportsZeroTotal() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(Arrays.asList(
                item("runner-zero-1", "empty-a.bin", 0L),
                item("runner-zero-2", "empty-b.bin", 0L)
        ));
        List<Integer> batchTotals = new ArrayList<>();
        List<Long> batchTotalBytes = new ArrayList<>();

        new SyncTransferRunner(queue).run(
                Arrays.asList(queue.tasks().get(0).id(), queue.tasks().get(1).id()),
                "http://receiver/uploads/",
                new SyncTransferRunner.Uploader() {
                    @Override
                    public void upload(
                            SyncTask task,
                            String targetUrl,
                            int batchIndex,
                            int batchTotal,
                            long totalBytes,
                            SyncTransferRunner.CancellationSignal cancellation
                    ) {
                        batchTotals.add(batchTotal);
                        batchTotalBytes.add(totalBytes);
                    }
                },
                neverCancelled(),
                SyncTransferRunner.NOOP_LISTENER
        );

        assertEquals(Arrays.asList(2, 2), batchTotals, "zero-byte tasks should remain part of the uploadable batch");
        assertEquals(Arrays.asList(0L, 0L), batchTotalBytes, "zero-byte batch total should remain zero");
    }

    private static void allRemoteExistingTasksFinishWithoutUpload() {
        SyncQueue queue = new SyncQueue();
        queue.enqueueAll(Arrays.asList(
                item("runner-skipped-1", "first.jpg"),
                item("runner-skipped-2", "second.jpg")
        ));
        List<SyncTask> tasks = queue.tasks();
        queue.markRemoteExisting(new java.util.HashSet<>(Arrays.asList("runner-skipped-1", "runner-skipped-2")));
        final boolean[] uploaded = { false };
        final boolean[] finished = { false };

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
                            long totalBytes,
                            SyncTransferRunner.CancellationSignal cancellation
                    ) {
                        uploaded[0] = true;
                    }
                },
                neverCancelled(),
                new SyncTransferRunner.Listener() {
                    @Override
                    public void onTaskStateChanged(String taskId, SyncStatus previousStatus, SyncStatus currentStatus) {
                    }

                    @Override
                    public void onFinished(boolean cancelled) {
                        finished[0] = true;
                    }
                }
        );

        assertEquals(false, uploaded[0], "all remote-existing tasks should result in no uploads");
        assertEquals(true, finished[0], "finish listener should run when all tasks are skipped");
    }

    private static SyncTransferRunner.CancellationSignal neverCancelled() {
        return new SyncTransferRunner.CancellationSignal() {
            @Override
            public boolean isCancelled() {
                return false;
            }
        };
    }

    private static MediaItem item(String stableId, String displayName) {
        return item(stableId, displayName, 100L);
    }

    private static MediaItem item(String stableId, String displayName, long sizeBytes) {
        return new MediaItem(stableId, "content://media/" + stableId, displayName, sizeBytes, 1L, false);
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(message + ": expected <" + expected + "> but was <" + actual + ">");
        }
    }
}
