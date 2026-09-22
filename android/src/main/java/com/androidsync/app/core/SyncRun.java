package com.androidsync.app.core;

public final class SyncRun {
    private final String id;
    private final String targetUrl;
    private final SyncRunStatus status;
    private final long createdAtMillis;
    private final long updatedAtMillis;

    private SyncRun(
            String id,
            String targetUrl,
            SyncRunStatus status,
            long createdAtMillis,
            long updatedAtMillis
    ) {
        if (id == null || id.trim().isEmpty()) {
            throw new IllegalArgumentException("id is required");
        }
        if (targetUrl == null || targetUrl.trim().isEmpty()) {
            throw new IllegalArgumentException("targetUrl is required");
        }
        if (status == null) {
            throw new IllegalArgumentException("status is required");
        }
        this.id = id;
        this.targetUrl = targetUrl;
        this.status = status;
        this.createdAtMillis = createdAtMillis;
        this.updatedAtMillis = updatedAtMillis;
    }

    public static SyncRun start(String id, String targetUrl, long nowMillis) {
        return new SyncRun(id, targetUrl, SyncRunStatus.RUNNING, nowMillis, nowMillis);
    }

    public static SyncRun restore(
            String id,
            String targetUrl,
            SyncRunStatus status,
            long createdAtMillis,
            long updatedAtMillis
    ) {
        return new SyncRun(id, targetUrl, status, createdAtMillis, updatedAtMillis);
    }

    public String id() {
        return id;
    }

    public String targetUrl() {
        return targetUrl;
    }

    public SyncRunStatus status() {
        return status;
    }

    public long createdAtMillis() {
        return createdAtMillis;
    }

    public long updatedAtMillis() {
        return updatedAtMillis;
    }

    public SyncRun withStatus(SyncRunStatus nextStatus, long nextUpdatedAtMillis) {
        return new SyncRun(id, targetUrl, nextStatus, createdAtMillis, nextUpdatedAtMillis);
    }
}
