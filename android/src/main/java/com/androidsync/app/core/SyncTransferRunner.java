package com.androidsync.app.core;

import java.util.List;

/** 不依赖 Android 生命周期的单线程同步状态机。 */
public final class SyncTransferRunner {
    public interface CancellationSignal {
        boolean isCancelled();
    }

    public interface Uploader {
        void upload(
                SyncTask task,
                String targetUrl,
                int batchIndex,
                int batchTotal,
                CancellationSignal cancellation
        ) throws Exception;
    }

    public interface Listener {
        void onTaskStateChanged(String taskId, SyncStatus previousStatus, SyncStatus currentStatus);

        void onFinished(boolean cancelled);
    }

    public static final Listener NOOP_LISTENER = new Listener() {
        @Override
        public void onTaskStateChanged(String taskId, SyncStatus previousStatus, SyncStatus currentStatus) {
        }

        @Override
        public void onFinished(boolean cancelled) {
        }
    };

    private final SyncQueue queue;

    public SyncTransferRunner(SyncQueue queue) {
        if (queue == null) {
            throw new IllegalArgumentException("queue is required");
        }
        this.queue = queue;
    }

    public void run(
            List<String> taskIds,
            String targetUrl,
            Uploader uploader,
            CancellationSignal cancellation,
            Listener listener
    ) {
        if (taskIds == null) {
            throw new IllegalArgumentException("taskIds is required");
        }
        if (uploader == null) {
            throw new IllegalArgumentException("uploader is required");
        }
        CancellationSignal effectiveCancellation = cancellation == null
                ? new CancellationSignal() {
                    @Override
                    public boolean isCancelled() {
                        return false;
                    }
                }
                : cancellation;
        Listener effectiveListener = listener == null ? NOOP_LISTENER : listener;
        boolean cancelled = false;
        int batchTotal = taskIds.size();
        int batchIndex = 0;

        for (String taskId : taskIds) {
            if (effectiveCancellation.isCancelled()) {
                cancelled = true;
                break;
            }
            SyncTask task = queue.findById(taskId);
            if (task == null || (task.status() != SyncStatus.WAITING && task.status() != SyncStatus.FAILED)) {
                continue;
            }

            batchIndex++;
            SyncStatus previousStatus = task.status();
            queue.markUploading(task.id());
            effectiveListener.onTaskStateChanged(task.id(), previousStatus, SyncStatus.UPLOADING);

            Exception uploadError = null;
            try {
                uploader.upload(task, targetUrl, batchIndex, batchTotal, effectiveCancellation);
            } catch (Exception error) {
                uploadError = error;
            }

            SyncTask liveTask = queue.findById(task.id());
            if (liveTask == null) {
                continue;
            }
            SyncStatus previousTerminalStatus = liveTask.status();
            if (effectiveCancellation.isCancelled()) {
                queue.retry(task.id());
                cancelled = true;
            } else if (uploadError == null) {
                queue.markDone(task.id());
            } else {
                queue.markFailed(task.id(), cleanError(uploadError));
            }
            SyncTask finalTask = queue.findById(task.id());
            if (finalTask != null) {
                effectiveListener.onTaskStateChanged(task.id(), previousTerminalStatus, finalTask.status());
            }
            if (cancelled) {
                break;
            }
        }
        effectiveListener.onFinished(cancelled);
    }

    private static String cleanError(Exception error) {
        String message = error.getMessage();
        return message == null || message.trim().isEmpty() ? error.getClass().getSimpleName() : message;
    }
}
