package com.androidsync.app.core;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class SyncQueue {
    private final Map<String, SyncTask> tasksByMediaId = new LinkedHashMap<>();

    public synchronized void enqueueAll(List<MediaItem> mediaItems) {
        for (MediaItem item : mediaItems) {
            if (!tasksByMediaId.containsKey(item.stableId())) {
                tasksByMediaId.put(item.stableId(), SyncTask.waiting(item));
            }
        }
    }

    public synchronized List<SyncTask> tasks() {
        return Collections.unmodifiableList(new ArrayList<>(tasksByMediaId.values()));
    }

    public synchronized void markUploading(String taskId) {
        replace(taskId, SyncStatus.UPLOADING, null, 0L, false);
    }

    public synchronized void markDone(String taskId) {
        SyncTask task = find(taskId);
        if (task != null) {
            replace(taskId, SyncStatus.DONE, null, task.media().sizeBytes(), false);
        }
    }

    public synchronized void markFailed(String taskId, String errorMessage) {
        replace(taskId, SyncStatus.FAILED, errorMessage, 0L, true);
    }

    public synchronized void retry(String taskId) {
        replace(taskId, SyncStatus.WAITING, null, 0L, false);
    }

    public synchronized void markRemoteExisting(Set<String> stableIds) {
        for (String stableId : stableIds) {
            SyncTask task = tasksByMediaId.get(stableId);
            if (task != null && task.status() != SyncStatus.UPLOADING) {
                tasksByMediaId.put(stableId, task.withStatus(SyncStatus.DONE, null, task.media().sizeBytes(), false));
            }
        }
    }

    public synchronized void markRemoteExistingByFingerprint(Set<String> fingerprints) {
        for (Map.Entry<String, SyncTask> entry : tasksByMediaId.entrySet()) {
            SyncTask task = entry.getValue();
            if (fingerprints.contains(task.media().fingerprint()) && task.status() != SyncStatus.UPLOADING) {
                tasksByMediaId.put(entry.getKey(), task.withStatus(SyncStatus.DONE, null, task.media().sizeBytes(), false));
            }
        }
    }

    public synchronized Summary summary() {
        int waiting = 0;
        int uploading = 0;
        int done = 0;
        int failed = 0;
        long syncedBytes = 0L;
        long totalBytes = 0L;

        for (SyncTask task : tasksByMediaId.values()) {
            totalBytes += task.media().sizeBytes();
            switch (task.status()) {
                case WAITING:
                    waiting++;
                    break;
                case UPLOADING:
                    uploading++;
                    break;
                case DONE:
                    done++;
                    syncedBytes += task.media().sizeBytes();
                    break;
                case FAILED:
                    failed++;
                    break;
                default:
                    throw new IllegalStateException("Unknown status " + task.status());
            }
        }
        return new Summary(tasksByMediaId.size(), waiting, uploading, done, failed, syncedBytes, totalBytes);
    }

    private void replace(String taskId, SyncStatus status, String errorMessage, long uploadedBytes, boolean incrementAttempt) {
        String key = keyForTask(taskId);
        if (key == null) {
            return;
        }
        SyncTask task = tasksByMediaId.get(key);
        tasksByMediaId.put(key, task.withStatus(status, errorMessage, uploadedBytes, incrementAttempt));
    }

    private SyncTask find(String taskId) {
        String key = keyForTask(taskId);
        return key == null ? null : tasksByMediaId.get(key);
    }

    private String keyForTask(String taskId) {
        for (Map.Entry<String, SyncTask> entry : tasksByMediaId.entrySet()) {
            if (entry.getValue().id().equals(taskId)) {
                return entry.getKey();
            }
        }
        return null;
    }

    public static final class Summary {
        private final int total;
        private final int waiting;
        private final int uploading;
        private final int done;
        private final int failed;
        private final long syncedBytes;
        private final long totalBytes;

        private Summary(int total, int waiting, int uploading, int done, int failed, long syncedBytes, long totalBytes) {
            this.total = total;
            this.waiting = waiting;
            this.uploading = uploading;
            this.done = done;
            this.failed = failed;
            this.syncedBytes = syncedBytes;
            this.totalBytes = totalBytes;
        }

        public int total() {
            return total;
        }

        public int waiting() {
            return waiting;
        }

        public int uploading() {
            return uploading;
        }

        public int done() {
            return done;
        }

        public int failed() {
            return failed;
        }

        public long syncedBytes() {
            return syncedBytes;
        }

        public long totalBytes() {
            return totalBytes;
        }
    }
}
