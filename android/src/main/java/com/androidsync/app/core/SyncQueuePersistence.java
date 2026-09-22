package com.androidsync.app.core;

import java.util.List;

/** 持久化同步队列的最小适配接口；Android 实现位于 android 包。 */
public interface SyncQueuePersistence {
    List<SyncTask> load();

    void save(SyncTask task);

    void replaceAll(List<SyncTask> tasks);
}
