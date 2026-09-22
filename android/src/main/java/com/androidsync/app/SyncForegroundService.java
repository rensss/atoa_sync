package com.androidsync.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import com.androidsync.app.android.HttpFileUploader;
import com.androidsync.app.android.RemoteManifestClient;
import com.androidsync.app.android.SyncDatabase;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncRun;
import com.androidsync.app.core.SyncRunStatus;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.SyncTransferRunner;

import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public final class SyncForegroundService extends Service {
    public static final String ACTION_START = "com.androidsync.app.action.START_SYNC";
    public static final String ACTION_STOP = "com.androidsync.app.action.STOP_SYNC";
    public static final String ACTION_STATE_CHANGED = "com.androidsync.app.action.STATE_CHANGED";
    public static final String EXTRA_RUN_ID = "run_id";
    public static final String EXTRA_STATUS = "status";

    private static final String TAG = "AndroidSyncService";
    private static final String CHANNEL_ID = "sync_transfer";
    private static final int NOTIFICATION_ID = 4101;

    private final Object workerLock = new Object();
    private ExecutorService executor;
    private Future<?> worker;
    private SyncDatabase database;
    private SyncQueue queue;
    private HttpFileUploader uploader;
    private RemoteManifestClient manifestClient;
    private volatile boolean userStopRequested;
    private volatile String activeRunId;
    private volatile int totalTasks;
    private volatile String currentFile;

    public static void start(Context context, String runId) {
        Intent intent = new Intent(context, SyncForegroundService.class);
        intent.setAction(ACTION_START);
        intent.putExtra(EXTRA_RUN_ID, runId);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    public static void stop(Context context) {
        Intent intent = new Intent(context, SyncForegroundService.class);
        intent.setAction(ACTION_STOP);
        context.startService(intent);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        AndroidSyncApplication application = (AndroidSyncApplication) getApplication();
        database = application.database();
        queue = application.queue();
        uploader = new HttpFileUploader();
        manifestClient = new RemoteManifestClient();
        executor = Executors.newSingleThreadExecutor();
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        startForegroundIfNeeded();
        String action = intent == null ? ACTION_START : intent.getAction();
        if (ACTION_STOP.equals(action)) {
            requestStop();
            return START_STICKY;
        }

        String runId = intent == null ? null : intent.getStringExtra(EXTRA_RUN_ID);
        if (runId == null || runId.trim().isEmpty()) {
            SyncRun running = database.findRunningRun();
            runId = running == null ? null : running.id();
        }
        if (runId != null) {
            startRun(runId);
        } else {
            stopServiceAfterBroadcast(null, null);
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        if (uploader != null) {
            uploader.cancelActive();
        }
        if (executor != null) {
            executor.shutdownNow();
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void startRun(final String runId) {
        synchronized (workerLock) {
            if (worker != null && !worker.isDone()) {
                if (runId.equals(activeRunId)) {
                    return;
                }
                return;
            }
            SyncRun run = database.findRun(runId);
            if (run == null || run.status() != SyncRunStatus.RUNNING) {
                stopServiceAfterBroadcast(runId, run == null ? null : run.status().name());
                return;
            }
            userStopRequested = false;
            activeRunId = run.id();
            worker = executor.submit(new Runnable() {
                @Override
                public void run() {
                    runSync(runId);
                }
            });
        }
    }

    private void runSync(final String runId) {
        final SyncRun run = database.findRun(runId);
        if (run == null || run.status() != SyncRunStatus.RUNNING) {
            stopServiceAfterBroadcast(runId, run == null ? null : run.status().name());
            return;
        }

        final List<String> taskIds = database.taskIdsForRun(runId);
        queue.resetUploadingTasks(taskIds);
        database.resetUploadingTasks(runId);
        try {
            RemoteManifestClient.Snapshot snapshot = manifestClient.fetch(run.targetUrl());
            queue.markRemoteExisting(snapshot.stableIds());
            queue.markRemoteExistingByFingerprint(snapshot.fingerprints());
        } catch (Exception error) {
            Log.w(TAG, "Remote manifest unavailable; continuing with local task state", error);
        }

        totalTasks = taskIds.size();
        currentFile = null;
        sendStateChanged(runId, run.status());
        new SyncTransferRunner(queue).run(
                taskIds,
                run.targetUrl(),
                new SyncTransferRunner.Uploader() {
                    @Override
                    public void upload(
                            SyncTask task,
                            String targetUrl,
                            int batchIndex,
                            int batchTotal,
                            SyncTransferRunner.CancellationSignal cancellation
                    ) throws Exception {
                        currentFile = task.media().displayName();
                        updateNotification();
                        uploader.upload(
                                getContentResolver(),
                                task.media(),
                                targetUrl,
                                batchIndex,
                                batchTotal,
                                new HttpFileUploader.CancellationSignal() {
                                    @Override
                                    public boolean isCancelled() {
                                        return cancellation.isCancelled();
                                    }
                                }
                        );
                    }
                },
                new SyncTransferRunner.CancellationSignal() {
                    @Override
                    public boolean isCancelled() {
                        return userStopRequested || Thread.currentThread().isInterrupted();
                    }
                },
                new SyncTransferRunner.Listener() {
                    @Override
                    public void onTaskStateChanged(String taskId, SyncStatus previousStatus, SyncStatus currentStatus) {
                        SyncTask task = queue.findById(taskId);
                        currentFile = currentStatus == SyncStatus.UPLOADING && task != null
                                ? task.media().displayName()
                                : null;
                        updateNotification();
                        sendStateChanged(runId, run.status());
                    }

                    @Override
                    public void onFinished(boolean cancelled) {
                        queue.resetUploadingTasks(taskIds);
                        database.resetUploadingTasks(runId);
                        if (cancelled) {
                            if (userStopRequested) {
                                database.markRunStopped(runId);
                                sendStateChanged(runId, SyncRunStatus.STOPPED);
                                stopServiceAfterBroadcast(runId, SyncRunStatus.STOPPED.name());
                            } else {
                                // System interruption: leave RUNNING so a restarted service can resume it.
                                sendStateChanged(runId, SyncRunStatus.RUNNING);
                            }
                        } else {
                            database.markRunFinished(runId);
                            sendStateChanged(runId, SyncRunStatus.FINISHED);
                            stopServiceAfterBroadcast(runId, SyncRunStatus.FINISHED.name());
                        }
                    }
                }
        );
    }

    private void requestStop() {
        userStopRequested = true;
        if (uploader != null) {
            uploader.cancelActive();
        }
        SyncRun running = database.findRunningRun();
        if (running != null) {
            List<String> taskIds = database.taskIdsForRun(running.id());
            queue.resetUploadingTasks(taskIds);
            database.resetUploadingTasks(running.id());
            database.markRunStopped(running.id());
            activeRunId = running.id();
            sendStateChanged(running.id(), SyncRunStatus.STOPPED);
        }
        synchronized (workerLock) {
            if (worker == null || worker.isDone()) {
                stopServiceAfterBroadcast(activeRunId, SyncRunStatus.STOPPED.name());
            } else {
                worker.cancel(true);
                stopServiceAfterBroadcast(activeRunId, SyncRunStatus.STOPPED.name());
            }
        }
    }

    private void stopServiceAfterBroadcast(String runId, String status) {
        if (runId != null && status != null) {
            sendStateChanged(runId, status);
        }
        stopForeground(true);
        stopSelf();
    }

    private void sendStateChanged(String runId, SyncRunStatus status) {
        sendStateChanged(runId, status == null ? null : status.name());
    }

    private void sendStateChanged(String runId, String status) {
        Intent intent = new Intent(ACTION_STATE_CHANGED);
        intent.setPackage(getPackageName());
        if (runId != null) {
            intent.putExtra(EXTRA_RUN_ID, runId);
        }
        if (status != null) {
            intent.putExtra(EXTRA_STATUS, status);
        }
        sendBroadcast(intent);
    }

    private void startForegroundIfNeeded() {
        Notification notification = buildNotification();
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    private void updateNotification() {
        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (manager != null) {
            manager.notify(NOTIFICATION_ID, buildNotification());
        }
        sendStateChanged(activeRunId, (String) null);
    }

    private Notification buildNotification() {
        int done = 0;
        if (activeRunId != null) {
            for (String taskId : database.taskIdsForRun(activeRunId)) {
                SyncTask task = queue.findById(taskId);
                if (task != null && task.status() == SyncStatus.DONE) {
                    done++;
                }
            }
        }
        String text = totalTasks <= 0
                ? "准备同步"
                : "已完成 " + done + "/" + totalTasks + (currentFile == null ? "" : " · " + currentFile);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);
        return builder
                .setSmallIcon(com.androidsync.app.R.drawable.ic_stat_sync)
                .setContentTitle("Android Sync")
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setProgress(Math.max(1, totalTasks), done, false)
                .build();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < 26) {
            return;
        }
        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (manager == null) {
            return;
        }
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "同步传输",
                NotificationManager.IMPORTANCE_LOW
        );
        channel.setDescription("Android Sync 后台传输进度");
        manager.createNotificationChannel(channel);
    }
}
