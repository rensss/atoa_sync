package com.androidsync.app.core;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

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
                long batchTotalBytes,
                CancellationSignal cancellation
        ) throws Exception;
    }

    public interface PauseAwareUploader extends Uploader {
        void awaitReceiverRunning(String targetUrl, CancellationSignal cancellation) throws Exception;
    }

    public interface Listener {
        void onTaskStateChanged(String taskId, SyncStatus previousStatus, SyncStatus currentStatus);

        default void onReceiverPauseWaitChanged(boolean waiting) {
        }

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
        Map<String, SyncTask> uploadableTasks = new LinkedHashMap<>();
        for (String taskId : taskIds) {
            SyncTask task = queue.findById(taskId);
            if (task != null
                    && (task.status() == SyncStatus.WAITING || task.status() == SyncStatus.FAILED)) {
                uploadableTasks.put(taskId, task);
            }
        }
        int batchTotal = uploadableTasks.size();
        long batchTotalBytes = 0L;
        for (SyncTask task : uploadableTasks.values()) {
            batchTotalBytes = saturatedAdd(batchTotalBytes, Math.max(0L, task.media().sizeBytes()));
        }
        int batchIndex = 0;

        for (String taskId : taskIds) {
            if (effectiveCancellation.isCancelled()) {
                cancelled = true;
                break;
            }
            if (!uploadableTasks.containsKey(taskId)) {
                continue;
            }
            SyncTask task = queue.findById(taskId);
            if (task == null || (task.status() != SyncStatus.WAITING && task.status() != SyncStatus.FAILED)) {
                continue;
            }

            batchIndex++;
            SyncStatus previousStatus = task.status();
            queue.markUploading(task.id());
            effectiveListener.onTaskStateChanged(task.id(), previousStatus, SyncStatus.UPLOADING);

            boolean taskAttemptFinished = false;
            while (!taskAttemptFinished) {
                Exception uploadError = null;
                try {
                    uploader.upload(
                            task,
                            targetUrl,
                            batchIndex,
                            batchTotal,
                            batchTotalBytes,
                            effectiveCancellation
                    );
                } catch (ReceiverPausedException pause) {
                    if (uploader instanceof PauseAwareUploader) {
                        SyncTask interruptedTask = queue.findById(task.id());
                        if (interruptedTask == null) {
                            taskAttemptFinished = true;
                            continue;
                        }
                        SyncStatus interruptedStatus = interruptedTask.status();
                        queue.retry(task.id());
                        effectiveListener.onTaskStateChanged(
                                task.id(),
                                interruptedStatus,
                                SyncStatus.WAITING
                        );
                        effectiveListener.onReceiverPauseWaitChanged(true);
                        if (!effectiveCancellation.isCancelled()) {
                            try {
                                ((PauseAwareUploader) uploader).awaitReceiverRunning(
                                        targetUrl,
                                        effectiveCancellation
                                );
                            } catch (Exception waitError) {
                                if (!effectiveCancellation.isCancelled()) {
                                    uploadError = waitError;
                                }
                            }
                        }
                        effectiveListener.onReceiverPauseWaitChanged(false);
                        if (effectiveCancellation.isCancelled()) {
                            cancelled = true;
                            taskAttemptFinished = true;
                            continue;
                        }
                        if (uploadError == null) {
                            queue.markUploading(task.id());
                            effectiveListener.onTaskStateChanged(
                                    task.id(),
                                    SyncStatus.WAITING,
                                    SyncStatus.UPLOADING
                            );
                            continue;
                        }
                    } else {
                        uploadError = pause;
                    }
                } catch (Exception error) {
                    uploadError = error;
                }

                SyncTask liveTask = queue.findById(task.id());
                if (liveTask == null) {
                    taskAttemptFinished = true;
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
                    effectiveListener.onTaskStateChanged(
                            task.id(),
                            previousTerminalStatus,
                            finalTask.status()
                    );
                }
                taskAttemptFinished = true;
            }
            if (cancelled) {
                break;
            }
        }
        effectiveListener.onFinished(cancelled);
    }

    private static long saturatedAdd(long left, long right) {
        if (right > 0L && left > Long.MAX_VALUE - right) {
            return Long.MAX_VALUE;
        }
        return left + right;
    }

    private static String cleanError(Exception error) {
        String message = error.getMessage();
        return message == null || message.trim().isEmpty() ? error.getClass().getSimpleName() : message;
    }
}
