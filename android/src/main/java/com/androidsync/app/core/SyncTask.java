package com.androidsync.app.core;

import java.util.UUID;

public final class SyncTask {
    private final String id;
    private final MediaItem media;
    private final SyncStatus status;
    private final int attemptCount;
    private final String errorMessage;
    private final long uploadedBytes;

    private SyncTask(String id, MediaItem media, SyncStatus status, int attemptCount, String errorMessage, long uploadedBytes) {
        this.id = id;
        this.media = media;
        this.status = status;
        this.attemptCount = Math.max(0, attemptCount);
        this.errorMessage = errorMessage;
        this.uploadedBytes = Math.max(0L, uploadedBytes);
    }

    public static SyncTask waiting(MediaItem media) {
        return new SyncTask(UUID.randomUUID().toString(), media, SyncStatus.WAITING, 0, null, 0L);
    }

    public String id() {
        return id;
    }

    public MediaItem media() {
        return media;
    }

    public SyncStatus status() {
        return status;
    }

    public int attemptCount() {
        return attemptCount;
    }

    public String errorMessage() {
        return errorMessage;
    }

    public long uploadedBytes() {
        return uploadedBytes;
    }

    SyncTask withStatus(SyncStatus nextStatus, String nextErrorMessage, long nextUploadedBytes, boolean incrementAttempt) {
        int nextAttemptCount = incrementAttempt ? attemptCount + 1 : attemptCount;
        return new SyncTask(id, media, nextStatus, nextAttemptCount, nextErrorMessage, nextUploadedBytes);
    }
}
