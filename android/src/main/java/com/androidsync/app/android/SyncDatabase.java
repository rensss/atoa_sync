package com.androidsync.app.android;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueuePersistence;
import com.androidsync.app.core.SyncRun;
import com.androidsync.app.core.SyncRunStatus;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public final class SyncDatabase extends SQLiteOpenHelper implements SyncQueuePersistence {
    private static final String DATABASE_NAME = "android_sync.db";
    private static final int DATABASE_VERSION = 1;
    private static final String TASKS = "sync_tasks";
    private static final String RUNS = "sync_runs";
    private static final String RUN_TASKS = "sync_run_tasks";

    public SyncDatabase(Context context) {
        super(context.getApplicationContext(), DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onConfigure(SQLiteDatabase db) {
        super.onConfigure(db);
        db.setForeignKeyConstraintsEnabled(true);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE " + TASKS + " ("
                + "task_id TEXT PRIMARY KEY NOT NULL,"
                + "stable_id TEXT NOT NULL UNIQUE,"
                + "uri TEXT NOT NULL,"
                + "display_name TEXT NOT NULL,"
                + "size_bytes INTEGER NOT NULL,"
                + "date_modified_millis INTEGER NOT NULL,"
                + "date_taken_millis INTEGER NOT NULL,"
                + "date_added_millis INTEGER NOT NULL,"
                + "is_video INTEGER NOT NULL,"
                + "mime_type TEXT NOT NULL,"
                + "bucket_id TEXT,"
                + "bucket_name TEXT,"
                + "status TEXT NOT NULL,"
                + "attempt_count INTEGER NOT NULL,"
                + "error_message TEXT,"
                + "uploaded_bytes INTEGER NOT NULL,"
                + "updated_at_millis INTEGER NOT NULL"
                + ")");
        db.execSQL("CREATE TABLE " + RUNS + " ("
                + "run_id TEXT PRIMARY KEY NOT NULL,"
                + "target_url TEXT NOT NULL,"
                + "status TEXT NOT NULL,"
                + "created_at_millis INTEGER NOT NULL,"
                + "updated_at_millis INTEGER NOT NULL"
                + ")");
        db.execSQL("CREATE TABLE " + RUN_TASKS + " ("
                + "run_id TEXT NOT NULL,"
                + "task_id TEXT NOT NULL,"
                + "selection_order INTEGER NOT NULL,"
                + "PRIMARY KEY (run_id, task_id),"
                + "FOREIGN KEY (run_id) REFERENCES " + RUNS + "(run_id) ON DELETE CASCADE,"
                + "FOREIGN KEY (task_id) REFERENCES " + TASKS + "(task_id) ON DELETE CASCADE"
                + ")");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        // Version 1 is the initial schema. Future versions must add explicit migrations.
    }

    @Override
    public synchronized List<SyncTask> load() {
        List<SyncTask> tasks = new ArrayList<>();
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query(
                TASKS,
                null,
                null,
                null,
                null,
                null,
                "rowid ASC"
        )) {
            while (cursor.moveToNext()) {
                tasks.add(readTask(cursor));
            }
        }
        return tasks;
    }

    @Override
    public synchronized void save(SyncTask task) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = taskValues(task, System.currentTimeMillis());
        db.beginTransaction();
        try {
            int updated = db.update(TASKS, values, "task_id = ?", new String[] { task.id() });
            if (updated == 0) {
                db.insertOrThrow(TASKS, null, values);
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    @Override
    public synchronized void replaceAll(List<SyncTask> tasks) {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete(TASKS, null, null);
            for (SyncTask task : tasks) {
                db.insertOrThrow(TASKS, null, taskValues(task, System.currentTimeMillis()));
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    public synchronized SyncRun createRun(String targetUrl, List<String> taskIds) {
        if (targetUrl == null || targetUrl.trim().isEmpty()) {
            throw new IllegalArgumentException("targetUrl is required");
        }
        if (taskIds == null || taskIds.isEmpty()) {
            throw new IllegalArgumentException("taskIds are required");
        }
        if (findRunningRun() != null) {
            throw new IllegalStateException("A sync run is already active");
        }
        String runId = UUID.randomUUID().toString();
        long now = System.currentTimeMillis();
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            ContentValues runValues = new ContentValues();
            runValues.put("run_id", runId);
            runValues.put("target_url", targetUrl);
            runValues.put("status", SyncRunStatus.RUNNING.name());
            runValues.put("created_at_millis", now);
            runValues.put("updated_at_millis", now);
            db.insertOrThrow(RUNS, null, runValues);

            int selectionOrder = 0;
            for (String taskId : taskIds) {
                if (taskId == null || taskId.trim().isEmpty()) {
                    continue;
                }
                Cursor cursor = db.query(
                        TASKS,
                        new String[] { "task_id" },
                        "task_id = ?",
                        new String[] { taskId },
                        null,
                        null,
                        null
                );
                boolean exists;
                try {
                    exists = cursor.moveToFirst();
                } finally {
                    cursor.close();
                }
                if (!exists) {
                    continue;
                }
                ContentValues link = new ContentValues();
                link.put("run_id", runId);
                link.put("task_id", taskId);
                link.put("selection_order", selectionOrder++);
                db.insertOrThrow(RUN_TASKS, null, link);
            }
            if (selectionOrder == 0) {
                throw new IllegalArgumentException("No persisted tasks matched the run");
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return SyncRun.start(runId, targetUrl, now);
    }

    public synchronized SyncRun findRunningRun() {
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query(
                RUNS,
                null,
                "status = ?",
                new String[] { SyncRunStatus.RUNNING.name() },
                null,
                null,
                "created_at_millis DESC",
                "1"
        )) {
            return cursor.moveToFirst() ? readRun(cursor) : null;
        }
    }

    public synchronized SyncRun findRun(String runId) {
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query(
                RUNS,
                null,
                "run_id = ?",
                new String[] { runId },
                null,
                null,
                null,
                "1"
        )) {
            return cursor.moveToFirst() ? readRun(cursor) : null;
        }
    }

    public synchronized List<String> taskIdsForRun(String runId) {
        List<String> taskIds = new ArrayList<>();
        SQLiteDatabase db = getReadableDatabase();
        try (Cursor cursor = db.query(
                RUN_TASKS,
                new String[] { "task_id" },
                "run_id = ?",
                new String[] { runId },
                null,
                null,
                "selection_order ASC"
        )) {
            while (cursor.moveToNext()) {
                taskIds.add(cursor.getString(0));
            }
        }
        return taskIds;
    }

    public synchronized void resetUploadingTasks(String runId) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put("status", SyncStatus.WAITING.name());
        values.putNull("error_message");
        values.put("uploaded_bytes", 0L);
        values.put("updated_at_millis", System.currentTimeMillis());
        db.update(
                TASKS,
                values,
                "task_id IN (SELECT task_id FROM " + RUN_TASKS + " WHERE run_id = ?) AND status = ?",
                new String[] { runId, SyncStatus.UPLOADING.name() }
        );
    }

    public synchronized void markRunStopped(String runId) {
        updateRunStatus(runId, SyncRunStatus.STOPPED);
    }

    public synchronized void markRunFinished(String runId) {
        updateRunStatus(runId, SyncRunStatus.FINISHED);
    }

    private void updateRunStatus(String runId, SyncRunStatus status) {
        ContentValues values = new ContentValues();
        values.put("status", status.name());
        values.put("updated_at_millis", System.currentTimeMillis());
        getWritableDatabase().update(RUNS, values, "run_id = ?", new String[] { runId });
    }

    private ContentValues taskValues(SyncTask task, long updatedAtMillis) {
        MediaItem media = task.media();
        ContentValues values = new ContentValues();
        values.put("task_id", task.id());
        values.put("stable_id", media.stableId());
        values.put("uri", media.uri());
        values.put("display_name", media.displayName());
        values.put("size_bytes", media.sizeBytes());
        values.put("date_modified_millis", media.dateModifiedMillis());
        values.put("date_taken_millis", media.dateTakenMillis());
        values.put("date_added_millis", media.dateAddedMillis());
        values.put("is_video", media.isVideo() ? 1 : 0);
        values.put("mime_type", media.mimeType());
        if (media.bucketId() == null) {
            values.putNull("bucket_id");
        } else {
            values.put("bucket_id", media.bucketId());
        }
        if (media.bucketName() == null) {
            values.putNull("bucket_name");
        } else {
            values.put("bucket_name", media.bucketName());
        }
        values.put("status", task.status().name());
        values.put("attempt_count", task.attemptCount());
        if (task.errorMessage() == null) {
            values.putNull("error_message");
        } else {
            values.put("error_message", task.errorMessage());
        }
        values.put("uploaded_bytes", task.uploadedBytes());
        values.put("updated_at_millis", updatedAtMillis);
        return values;
    }

    private SyncTask readTask(Cursor cursor) {
        String bucketId = cursor.getString(cursor.getColumnIndexOrThrow("bucket_id"));
        String bucketName = cursor.getString(cursor.getColumnIndexOrThrow("bucket_name"));
        MediaItem media = new MediaItem(
                cursor.getString(cursor.getColumnIndexOrThrow("stable_id")),
                cursor.getString(cursor.getColumnIndexOrThrow("uri")),
                cursor.getString(cursor.getColumnIndexOrThrow("display_name")),
                cursor.getLong(cursor.getColumnIndexOrThrow("size_bytes")),
                cursor.getLong(cursor.getColumnIndexOrThrow("date_modified_millis")),
                cursor.getLong(cursor.getColumnIndexOrThrow("date_taken_millis")),
                cursor.getLong(cursor.getColumnIndexOrThrow("date_added_millis")),
                cursor.getInt(cursor.getColumnIndexOrThrow("is_video")) != 0,
                cursor.getString(cursor.getColumnIndexOrThrow("mime_type")),
                bucketId,
                bucketName
        );
        return SyncTask.restore(
                cursor.getString(cursor.getColumnIndexOrThrow("task_id")),
                media,
                SyncStatus.valueOf(cursor.getString(cursor.getColumnIndexOrThrow("status"))),
                cursor.getInt(cursor.getColumnIndexOrThrow("attempt_count")),
                cursor.getString(cursor.getColumnIndexOrThrow("error_message")),
                cursor.getLong(cursor.getColumnIndexOrThrow("uploaded_bytes"))
        );
    }

    private SyncRun readRun(Cursor cursor) {
        return SyncRun.restore(
                cursor.getString(cursor.getColumnIndexOrThrow("run_id")),
                cursor.getString(cursor.getColumnIndexOrThrow("target_url")),
                SyncRunStatus.valueOf(cursor.getString(cursor.getColumnIndexOrThrow("status"))),
                cursor.getLong(cursor.getColumnIndexOrThrow("created_at_millis")),
                cursor.getLong(cursor.getColumnIndexOrThrow("updated_at_millis"))
        );
    }
}
