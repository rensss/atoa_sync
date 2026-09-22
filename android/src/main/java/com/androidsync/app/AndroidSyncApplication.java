package com.androidsync.app;

import android.app.Application;

import com.androidsync.app.android.SyncDatabase;
import com.androidsync.app.core.SyncQueue;

public final class AndroidSyncApplication extends Application {
    private SyncDatabase database;
    private SyncQueue queue;

    @Override
    public void onCreate() {
        super.onCreate();
        database = new SyncDatabase(this);
        queue = new SyncQueue(database);
    }

    public SyncDatabase database() {
        return database;
    }

    public SyncQueue queue() {
        return queue;
    }
}
