package com.androidsync.app.core;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class TaskWindow {
    private final List<SyncTask> visibleTasks;
    private final int totalCount;

    private TaskWindow(List<SyncTask> visibleTasks, int totalCount) {
        this.visibleTasks = visibleTasks;
        this.totalCount = totalCount;
    }

    public static TaskWindow from(List<SyncTask> tasks, int maxVisibleCount) {
        int safeLimit = Math.max(0, maxVisibleCount);
        int end = Math.min(tasks.size(), safeLimit);
        return new TaskWindow(Collections.unmodifiableList(new ArrayList<>(tasks.subList(0, end))), tasks.size());
    }

    public List<SyncTask> visibleTasks() {
        return visibleTasks;
    }

    public int totalCount() {
        return totalCount;
    }

    public boolean hasMore() {
        return visibleTasks.size() < totalCount;
    }

    public int hiddenCount() {
        return totalCount - visibleTasks.size();
    }
}
