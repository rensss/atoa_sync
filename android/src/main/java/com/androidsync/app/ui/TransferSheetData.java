package com.androidsync.app.ui;

import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.TaskWindow;

import java.util.List;

/** Presentation snapshot for the transfer-details sheet. */
public final class TransferSheetData {
    private final SyncQueue.Summary summary;
    private final TaskWindow taskWindow;
    private final boolean runActive;

    public TransferSheetData(SyncQueue.Summary summary, TaskWindow taskWindow, boolean runActive) {
        if (summary == null || taskWindow == null) {
            throw new IllegalArgumentException("summary and task window are required");
        }
        this.summary = summary;
        this.taskWindow = taskWindow;
        this.runActive = runActive;
    }

    public SyncQueue.Summary summary() {
        return summary;
    }

    public List<SyncTask> visibleTasks() {
        return taskWindow.visibleTasks();
    }

    public int visibleTaskCount() {
        return taskWindow.visibleTasks().size();
    }

    public boolean hasMore() {
        return taskWindow.hasMore();
    }

    public int hiddenCount() {
        return taskWindow.hiddenCount();
    }

    public boolean showStop() {
        return runActive;
    }

    public long remainingBytes() {
        return Math.max(0L, summary.totalBytes() - summary.syncedBytes());
    }
}
