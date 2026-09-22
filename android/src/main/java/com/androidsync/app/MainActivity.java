package com.androidsync.app;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.BroadcastReceiver;
import android.content.ClipData;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsetsController;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.androidsync.app.android.AlbumPrefs;
import com.androidsync.app.android.MediaStoreScanner;
import com.androidsync.app.android.RemoteManifestClient;
import com.androidsync.app.android.SyncDatabase;
import com.androidsync.app.core.AddressConfiguration;
import com.androidsync.app.core.AlbumFilter;
import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncRun;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.TaskWindow;
import com.androidsync.app.ui.AlbumPickerView;
import com.androidsync.app.ui.ConfirmSelectionView;
import com.androidsync.app.ui.LibraryPageView;
import com.androidsync.app.ui.SettingsPageView;
import com.androidsync.app.ui.Theme;
import com.androidsync.app.ui.ThumbnailLoader;
import com.androidsync.app.ui.TransferCardView;
import com.androidsync.app.ui.Widgets;

import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;

public final class MainActivity extends Activity {
    private static final String TAG = "AndroidSync";
    private static final int REQUEST_MEDIA_PERMISSION = 40;
    private static final int REQUEST_NOTIFICATION_PERMISSION = 41;
    private static final String PREFS = "android_sync";
    private static final String KEY_TARGET_URL = "target_url";

    private SyncQueue queue;
    private SyncDatabase database;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final RemoteManifestClient manifestClient = new RemoteManifestClient();

    private final Set<String> albumSelection = new HashSet<>();
    private final Set<String> confirmExcluded = new HashSet<>();
    private final Set<String> chipFilter = new HashSet<>();

    private LinearLayout root;
    private MediaStoreScanner scanner;
    private Widgets widgets;
    private ThumbnailLoader thumbnailLoader;
    private TransferCardView transferCard;
    private List<MediaStoreScanner.Album> albums = Collections.emptyList();
    private List<MediaItem> scannedMedia = Collections.emptyList();
    private Button albumDoneButton;
    private String albumPickerReturn = "library";
    private String screen = "library";
    private String targetUrl;
    private boolean scanning;
    private String scanMessage = "等待扫描";
    private int todayCompleted;
    private long todayBytes;
    private volatile boolean destroyed;
    private String pendingRunId;
    private boolean syncReceiverRegistered;
    private final Set<String> countedDoneTaskIds = new HashSet<>();
    private final BroadcastReceiver syncStateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(android.content.Context context, Intent intent) {
            if (destroyed || !SyncForegroundService.ACTION_STATE_CHANGED.equals(intent.getAction())) {
                return;
            }
            driveTransferProgress();
            String status = intent.getStringExtra(SyncForegroundService.EXTRA_STATUS);
            if (status != null && !"RUNNING".equals(status) && "library".equals(screen)) {
                render();
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureSystemBars();
        AndroidSyncApplication application = (AndroidSyncApplication) getApplication();
        queue = application.queue();
        database = application.database();
        for (SyncTask task : queue.tasks()) {
            if (task.status() == SyncStatus.DONE) {
                countedDoneTaskIds.add(task.id());
            }
        }
        scanner = new MediaStoreScanner(getContentResolver());
        widgets = new Widgets(this);
        thumbnailLoader = new ThumbnailLoader(this, getContentResolver());
        transferCard = new TransferCardView(this, widgets, new TransferCardView.RetryHandler() {
            @Override
            public void retry(String taskId) {
                SyncTask task = queue.findById(taskId);
                if (task != null && task.status() == SyncStatus.FAILED) {
                    if (database.findRunningRun() != null) {
                        Toast.makeText(MainActivity.this, "当前同步完成后再重试", Toast.LENGTH_SHORT).show();
                        return;
                    }
                    queue.retry(taskId);
                    startSync(Collections.singleton(task.media().stableId()));
                }
            }
        }, new TransferCardView.StopHandler() {
            @Override
            public void stop() {
                stopSync();
            }
        });
        targetUrl = prefs().getString(KEY_TARGET_URL, "http://192.168.1.20:8765/uploads/");
        applyAddressConfiguration(getIntent());
        render();
        ensureMediaPermissionThenScan();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (applyAddressConfiguration(intent)) {
            render();
        }
    }

    @Override
    protected void onStart() {
        super.onStart();
        registerSyncReceiver();
        ensureActiveService();
        driveTransferProgress();
    }

    @Override
    protected void onStop() {
        unregisterSyncReceiver();
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        destroyed = true;
        unregisterSyncReceiver();
        mainHandler.removeCallbacksAndMessages(null);
        thumbnailLoader.shutdown();
        executor.shutdownNow();
        super.onDestroy();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_NOTIFICATION_PERMISSION) {
            String runId = pendingRunId;
            pendingRunId = null;
            if (runId != null) {
                startServiceForRun(runId);
            }
        } else if (requestCode == REQUEST_MEDIA_PERMISSION && hasMediaPermission()) {
            onPermissionReady();
        } else if (requestCode == REQUEST_MEDIA_PERMISSION) {
            Toast.makeText(this, "需要相册权限才能同步照片和视频", Toast.LENGTH_LONG).show();
        }
    }

    private void ensureMediaPermissionThenScan() {
        if (hasMediaPermission()) {
            onPermissionReady();
            return;
        }
        if (Build.VERSION.SDK_INT >= 33) {
            requestPermissions(new String[] { Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO }, REQUEST_MEDIA_PERMISSION);
        } else {
            requestPermissions(new String[] { Manifest.permission.READ_EXTERNAL_STORAGE }, REQUEST_MEDIA_PERMISSION);
        }
    }

    private void onPermissionReady() {
        if (!AlbumPrefs.isConfigured(prefs())) {
            openAlbumPicker(true);
        } else {
            scanMedia();
        }
    }

    /** 打开相册白名单选择页；{@code initialSetup} 为首启强制引导（预勾 Camera）。 */
    private void openAlbumPicker(final boolean initialSetup) {
        albumPickerReturn = initialSetup ? "library" : screen;
        screen = "albumPicker";
        scanMessage = "正在读取相册...";
        render();
        submitTask(new Runnable() {
            @Override
            public void run() {
                if (destroyed) {
                    return;
                }
                final List<MediaStoreScanner.Album> loaded = scanner.listAlbums();
                postTask(new Runnable() {
                    @Override
                    public void run() {
                        albums = loaded;
                        Set<String> existing = AlbumPrefs.load(prefs());
                        albumSelection.clear();
                        if (existing != null) {
                            albumSelection.addAll(existing);
                        } else if (initialSetup) {
                            for (MediaStoreScanner.Album album : loaded) {
                                if ("Camera".equals(album.name)) {
                                    albumSelection.add(album.bucketId);
                                }
                            }
                        }
                        if ("albumPicker".equals(screen)) {
                            render();
                        }
                    }
                });
            }
        });
    }

    private boolean hasMediaPermission() {
        if (Build.VERSION.SDK_INT >= 33) {
            return checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED
                    || checkSelfPermission(Manifest.permission.READ_MEDIA_VIDEO) == PackageManager.PERMISSION_GRANTED;
        }
        return checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
    }

    private void scanMedia() {
        if (destroyed) {
            return;
        }
        if (!hasMediaPermission()) {
            ensureMediaPermissionThenScan();
            return;
        }
        final Set<String> whitelist = AlbumPrefs.load(prefs());
        if (whitelist == null) {
            scanning = false;
            scanMessage = "请先选择同步相册";
            render();
            return;
        }
        scanning = true;
        scanMessage = "正在扫描本机相册...";
        render();
        boolean submitted = submitTask(new Runnable() {
            @Override
            public void run() {
                if (destroyed) {
                    return;
                }
                final List<MediaItem> media = scanner.scanAll(whitelist);
                if (destroyed) {
                    return;
                }
                SyncRun activeRun = database.findRunningRun();
                if (activeRun == null) {
                    queue.reconcile(media);
                }
                int remoteMatches = 0;
                String remoteMessage = "";
                if (activeRun == null) {
                    try {
                        RemoteManifestClient.Snapshot snapshot = manifestClient.fetch(targetUrl);
                        remoteMatches = snapshot.stableIds().size() + snapshot.fingerprints().size();
                        queue.markRemoteExisting(snapshot.stableIds());
                        queue.markRemoteExistingByFingerprint(snapshot.fingerprints());
                    } catch (Exception error) {
                        remoteMessage = "，接收端记录读取失败：" + cleanError(error);
                    }
                } else {
                    remoteMessage = "，后台同步进行中，保留本次任务范围";
                }
                final int scannedCount = media.size();
                final int matchedCount = remoteMatches;
                final String suffix = remoteMessage;
                postTask(new Runnable() {
                    @Override
                    public void run() {
                        scanning = false;
                        scannedMedia = media;
                        scanMessage = "已扫描 " + scannedCount + " 个媒体文件，接收端已有 " + matchedCount + " 个记录" + suffix;
                        Toast.makeText(MainActivity.this, scanMessage, Toast.LENGTH_SHORT).show();
                        render();
                    }
                });
            }
        });
        if (!submitted && !destroyed) {
            scanning = false;
            render();
        }
    }

    private void startSync(Set<String> selectedStableIds) {
        if (destroyed) {
            return;
        }
        final Set<String> uploadSelection = new HashSet<>(selectedStableIds);
        if (uploadSelection.isEmpty()) {
            return;
        }
        if (database.findRunningRun() != null) {
            stopSync();
            return;
        }
        if (transferCard != null) {
            transferCard.clearFailure();
        }
        List<String> selectedTaskIds = new ArrayList<>();
        for (SyncTask task : queue.tasks()) {
            if ((task.status() == SyncStatus.WAITING || task.status() == SyncStatus.FAILED)
                    && uploadSelection.contains(task.media().stableId())) {
                selectedTaskIds.add(task.id());
            }
        }
        if (selectedTaskIds.isEmpty()) {
            return;
        }
        final SyncRun run;
        try {
            run = database.createRun(targetUrl, selectedTaskIds);
        } catch (IllegalStateException error) {
            Toast.makeText(this, "已有同步任务正在进行", Toast.LENGTH_SHORT).show();
            ensureActiveService();
            return;
        }
        driveTransferProgress();
        requestNotificationAndStart(run.id());
    }

    private void stopSync() {
        if (database.findRunningRun() == null) {
            return;
        }
        if (transferCard != null) {
            transferCard.showStopping();
        }
        SyncForegroundService.stop(this);
        Toast.makeText(this, "同步已停止", Toast.LENGTH_SHORT).show();
        mainHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (!destroyed && database.findRunningRun() == null && "library".equals(screen)) {
                    render();
                }
            }
        }, 250L);
    }

    private void requestNotificationAndStart(String runId) {
        if (Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            pendingRunId = runId;
            requestPermissions(new String[] { Manifest.permission.POST_NOTIFICATIONS }, REQUEST_NOTIFICATION_PERMISSION);
            return;
        }
        startServiceForRun(runId);
    }

    private void startServiceForRun(String runId) {
        if (destroyed || runId == null || runId.trim().isEmpty()) {
            return;
        }
        SyncForegroundService.start(this, runId);
        driveTransferProgress();
    }

    private void ensureActiveService() {
        SyncRun run = database.findRunningRun();
        if (run != null) {
            startServiceForRun(run.id());
        }
    }

    private void registerSyncReceiver() {
        if (syncReceiverRegistered) {
            return;
        }
        IntentFilter filter = new IntentFilter(SyncForegroundService.ACTION_STATE_CHANGED);
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(syncStateReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(syncStateReceiver, filter);
        }
        syncReceiverRegistered = true;
    }

    private void unregisterSyncReceiver() {
        if (!syncReceiverRegistered) {
            return;
        }
        unregisterReceiver(syncStateReceiver);
        syncReceiverRegistered = false;
    }

    private boolean submitTask(Runnable task) {
        if (destroyed) {
            return false;
        }
        try {
            executor.execute(task);
            return true;
        } catch (RejectedExecutionException error) {
            return false;
        }
    }

    private void postTask(final Runnable task) {
        if (destroyed) {
            return;
        }
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                if (!destroyed) {
                    task.run();
                }
            }
        });
    }

    private void render() {
        if (destroyed) {
            return;
        }
        thumbnailLoader.bumpGeneration();
        albumDoneButton = null;
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(widgets.color(Theme.BG));
        setContentView(root);

        FrameLayout content = new FrameLayout(this);
        root.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        if ("albumPicker".equals(screen)) {
            content.addView(albumPickerView());
        } else if ("confirm".equals(screen)) {
            content.addView(confirmView());
        } else if ("settings".equals(screen)) {
            content.addView(settingsView());
        } else {
            content.addView(libraryView());
        }
        if (showsBottomNav()) {
            root.addView(navBar(), new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(76)));
        }
    }

    private boolean showsBottomNav() {
        return "library".equals(screen) || "settings".equals(screen);
    }

    @Override
    public void onBackPressed() {
        if ("settings".equals(screen)) {
            screen = "library";
            render();
            return;
        }
        if ("albumPicker".equals(screen)) {
            screen = albumPickerReturn;
            render();
            return;
        }
        if ("confirm".equals(screen)) {
            screen = "library";
            render();
            return;
        }
        super.onBackPressed();
    }

    private View libraryView() {
        final View transferRoot = transferCard.build();
        final Map<String, SyncStatus> statusByStableId = taskStatusByStableId();
        LibraryPageView.LibraryHost host = new LibraryPageView.LibraryHost() {
            @Override
            public List<MediaStoreScanner.Album> whitelistAlbums() {
                return computeWhitelistAlbums();
            }

            @Override
            public Set<String> activeChipFilter() {
                return chipFilter;
            }

            @Override
            public void toggleChip(String bucketId) {
                if (chipFilter.contains(bucketId)) {
                    chipFilter.remove(bucketId);
                } else {
                    chipFilter.add(bucketId);
                }
                render();
            }

            @Override
            public void openAlbumPicker() {
                MainActivity.this.openAlbumPicker(false);
            }

            @Override
            public List<MediaItem> visibleItems() {
                return computeVisibleItems();
            }

            @Override
            public SyncStatus statusFor(MediaItem item) {
                SyncStatus status = statusByStableId.get(item.stableId());
                return status == null ? SyncStatus.WAITING : status;
            }

            @Override
            public void openPreview(MediaItem item) {
                showPreview(item);
            }

            @Override
            public void startConfirm() {
                confirmExcluded.clear();
                screen = "confirm";
                render();
            }

            @Override
            public View transferCard() {
                return transferRoot;
            }
        };
        View page = new LibraryPageView(this, widgets, thumbnailLoader).build(host);
        if (database.findRunningRun() != null || queue.summary().failed() > 0) {
            driveTransferProgress();
        }
        return page;
    }

    private void driveTransferProgress() {
        if (transferCard == null) {
            return;
        }
        SyncQueue.Summary summary = queue.summary();
        if (database.findRunningRun() == null && summary.failed() == 0) {
            transferCard.hide();
            return;
        }
        TaskWindow active = queue.activeWindow(40);
        long bytesRemaining = Math.max(0L, summary.totalBytes() - summary.syncedBytes());
        recordCompletedTasks();
        transferCard.showProgress(summary.done(), summary.total(), bytesRemaining, null);
        transferCard.bindTasks(active.visibleTasks(), active.totalCount());
        transferCard.showTodayStats(todayCompleted, todayBytes);
        for (SyncTask task : active.visibleTasks()) {
            if (task.status() == SyncStatus.FAILED) {
                transferCard.showFailure(task.errorMessage() == null ? "上传失败" : task.errorMessage());
                break;
            }
        }
    }

    private void recordCompletedTasks() {
        for (SyncTask task : queue.tasks()) {
            if (task.status() == SyncStatus.DONE && countedDoneTaskIds.add(task.id())) {
                todayCompleted++;
                todayBytes += task.media().sizeBytes();
            }
        }
    }

    private List<MediaItem> computeVisibleItems() {
        List<MediaItem> out = new ArrayList<>();
        for (MediaItem item : scannedMedia) {
            if (chipFilter.isEmpty() || (item.bucketId() != null && chipFilter.contains(item.bucketId()))) {
                out.add(item);
            }
        }
        return out;
    }

    private List<MediaStoreScanner.Album> computeWhitelistAlbums() {
        LinkedHashMap<String, int[]> counts = new LinkedHashMap<>();
        LinkedHashMap<String, String> names = new LinkedHashMap<>();
        for (MediaItem item : scannedMedia) {
            String id = item.bucketId();
            if (id == null) {
                continue;
            }
            int[] count = counts.get(id);
            if (count == null) {
                counts.put(id, new int[] { 1 });
                names.put(id, item.bucketName() == null ? id : item.bucketName());
            } else {
                count[0]++;
            }
        }
        List<MediaStoreScanner.Album> out = new ArrayList<>();
        for (Map.Entry<String, int[]> entry : counts.entrySet()) {
            out.add(new MediaStoreScanner.Album(entry.getKey(), names.get(entry.getKey()), entry.getValue()[0]));
        }
        return out;
    }

    private Map<String, SyncStatus> taskStatusByStableId() {
        Map<String, SyncStatus> out = new LinkedHashMap<>();
        for (SyncTask task : queue.tasks()) {
            out.put(task.media().stableId(), task.status());
        }
        return out;
    }

    private View albumPickerView() {
        LinearLayout page = widgets.pageLayout();
        page.setBackgroundColor(widgets.color(Theme.BG));
        page.addView(widgets.title("选择同步相册", 24));
        page.addView(widgets.label("勾选要自动同步的相册，可随时在设置中调整", 13, Theme.TEXT_SECONDARY));

        if (albums.isEmpty()) {
            page.addView(widgets.label(scanMessage, 14, Theme.TEXT_SECONDARY));
        } else {
            Runnable onChanged = new Runnable() {
                @Override
                public void run() {
                    if (albumDoneButton != null) {
                        albumDoneButton.setEnabled(!albumSelection.isEmpty());
                    }
                }
            };
            View list = new AlbumPickerView(this, widgets).build(albums, albumSelection, onChanged);
            page.addView(list, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        }

        albumDoneButton = widgets.actionButton("完成", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (albumSelection.isEmpty()) {
                    return;
                }
                AlbumPrefs.save(prefs(), albumSelection);
                screen = albumPickerReturn;
                render();
                scanMedia();
            }
        });
        albumDoneButton.setEnabled(!albumSelection.isEmpty());
        page.addView(albumDoneButton);
        return page;
    }

    private List<MediaItem> pendingMedia() {
        List<MediaItem> all = new ArrayList<>();
        Set<String> synced = new HashSet<>();
        Map<String, SyncStatus> statuses = taskStatusByStableId();
        for (MediaItem item : scannedMedia) {
            all.add(item);
            SyncStatus status = statuses.get(item.stableId());
            if (status == SyncStatus.DONE) {
                synced.add(item.stableId());
            }
        }
        for (SyncTask task : queue.tasks()) {
            if (task.status() == SyncStatus.DONE) {
                synced.add(task.media().stableId());
            }
        }
        return AlbumFilter.pending(all, synced, Collections.<String>emptySet()).pending;
    }

    private View confirmView() {
        final List<MediaItem> pending = pendingMedia();
        return new ConfirmSelectionView(this, widgets, thumbnailLoader).build(pending, confirmExcluded, new ConfirmSelectionView.ConfirmHost() {
            @Override
            public void onConfirm() {
                Set<String> selected = new HashSet<>();
                for (MediaItem item : pending) {
                    if (!confirmExcluded.contains(item.stableId())) {
                        selected.add(item.stableId());
                    }
                }
                screen = "library";
                render();
                startSync(selected);
            }

            @Override
            public void onCancel() {
                screen = "library";
                render();
            }

            @Override
            public void onSelectionChanged(int count, long bytes) {
            }
        });
    }

    private View settingsView() {
        return new SettingsPageView(this, widgets).build(new SettingsPageView.SettingsHost() {
            @Override
            public String targetUrl() {
                return targetUrl;
            }

            @Override
            public void editTarget() {
                MainActivity.this.editTarget();
            }

            @Override
            public void openAlbumPicker() {
                MainActivity.this.openAlbumPicker(false);
            }

            @Override
            public String appVersionText() {
                return MainActivity.this.appVersionText();
            }

            @Override
            public int whitelistCount() {
                Set<String> whitelist = AlbumPrefs.load(prefs());
                return whitelist == null ? 0 : whitelist.size();
            }
        });
    }

    private void showPreview(final MediaItem item) {
        Dialog dialog = new Dialog(this);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(widgets.color(Theme.BG));
        page.setPadding(widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_L));

        FrameLayout preview = new FrameLayout(this);
        preview.setBackgroundColor(widgets.color(Theme.BG_RAISED));
        ImageView image = new ImageView(this);
        image.setScaleType(ImageView.ScaleType.FIT_CENTER);
        TextView loading = widgets.label("加载预览...", 14, Theme.TEXT_SECONDARY);
        loading.setGravity(Gravity.CENTER);
        preview.addView(image, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        preview.addView(loading, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        page.addView(preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        page.addView(widgets.label(item.displayName(), 16, Theme.TEXT_PRIMARY));
        page.addView(widgets.label(Widgets.formatBytes(item.sizeBytes()) + " · " + formatDate(item.dateModifiedMillis()), 13, Theme.TEXT_SECONDARY));
        if (item.isVideo()) {
            page.addView(widgets.actionButton("用系统播放器打开", new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    openMedia(item);
                }
            }));
        }

        dialog.setContentView(page);
        dialog.show();
        if (dialog.getWindow() != null) {
            dialog.getWindow().setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        }
        thumbnailLoader.loadPreviewAsync(image, loading, item.uri());
    }

    private View navBar() {
        LinearLayout nav = new LinearLayout(this);
        nav.setOrientation(LinearLayout.HORIZONTAL);
        nav.setPadding(widgets.dp(18), widgets.dp(8), widgets.dp(18), widgets.dp(12));
        nav.setGravity(Gravity.CENTER);
        nav.setBackgroundColor(widgets.color(Theme.BG_SIDEBAR));
        nav.addView(navButton("媒体库", "library"), widgets.weightParams());
        nav.addView(navButton("设置", "settings"), widgets.weightParams());
        return nav;
    }

    private Button navButton(String text, final String nextScreen) {
        Button button = widgets.smallButton(text);
        boolean selected = nextScreen.equals(navSelection());
        button.setTextColor(widgets.color(selected ? Theme.TEXT_PRIMARY : Theme.TEXT_SECONDARY));
        button.setBackground(selected
                ? widgets.rounded(Theme.BG_RAISED, Theme.ACCENT, 1, 14)
                : widgets.rounded(Theme.BG_RAISED, Theme.STROKE, 1, 14));
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                screen = nextScreen;
                render();
            }
        });
        return button;
    }

    private String navSelection() {
        if ("settings".equals(screen)) {
            return "settings";
        }
        return "library";
    }

    private void editTarget() {
        final EditText input = new EditText(this);
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_TEXT_VARIATION_URI);
        input.setText(targetUrl);
        input.setSelectAllOnFocus(true);
        new AlertDialog.Builder(this)
                .setTitle("同步目标")
                .setMessage("填写 WebDAV 或 HTTP PUT 接收地址")
                .setView(input)
                .setNegativeButton("取消", null)
                .setPositiveButton("保存", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        targetUrl = input.getText().toString().trim();
                        prefs().edit().putString(KEY_TARGET_URL, targetUrl).apply();
                        if (transferCard != null) {
                            transferCard.clearFailure();
                        }
                        render();
                    }
                })
                .show();
    }

    private boolean applyAddressConfiguration(Intent intent) {
        if (intent == null || !Intent.ACTION_VIEW.equals(intent.getAction())) {
            return false;
        }
        String configuredTarget = AddressConfiguration.targetUrlFromDeepLink(
                intent.getDataString()
        );
        if (configuredTarget == null) {
            Toast.makeText(this, "二维码中的接收地址无效", Toast.LENGTH_LONG).show();
            return false;
        }
        targetUrl = configuredTarget;
        prefs().edit().putString(KEY_TARGET_URL, targetUrl).apply();
        screen = "settings";
        Toast.makeText(this, "接收地址已更新", Toast.LENGTH_SHORT).show();
        return true;
    }

    private void openMedia(MediaItem media) {
        Uri uri = Uri.parse(media.uri());
        String mimeType = media.mimeType();
        if (mimeType == null || mimeType.trim().isEmpty()) {
            mimeType = getContentResolver().getType(uri);
        }
        if (mimeType == null || mimeType.trim().isEmpty()) {
            mimeType = media.isVideo() ? "video/*" : "image/*";
        }

        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(uri, mimeType);
        intent.setClipData(ClipData.newUri(getContentResolver(), media.displayName(), uri));
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try {
            Log.i(TAG, "Opening media " + media.displayName() + " as " + mimeType);
            startActivity(intent);
        } catch (Exception error) {
            Log.w(TAG, "Unable to open media " + media.displayName(), error);
            Toast.makeText(this, "无法打开：" + cleanError(error), Toast.LENGTH_SHORT).show();
        }
    }

    private String formatDate(long millis) {
        if (millis <= 0L) {
            return "-";
        }
        return DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT, Locale.getDefault()).format(new Date(millis));
    }

    private String appVersionText() {
        try {
            PackageInfo info = getPackageManager().getPackageInfo(getPackageName(), 0);
            if (Build.VERSION.SDK_INT >= 28) {
                return info.versionName + " (" + info.getLongVersionCode() + ")";
            }
            return info.versionName + " (" + info.versionCode + ")";
        } catch (Exception error) {
            return "未知版本";
        }
    }

    private String cleanError(Exception error) {
        String message = error.getMessage();
        if (message == null || message.length() == 0) {
            return error.getClass().getSimpleName();
        }
        return message.length() > 80 ? message.substring(0, 80) : message;
    }

    private SharedPreferences prefs() {
        return getSharedPreferences(PREFS, MODE_PRIVATE);
    }

    private void configureSystemBars() {
        Window window = getWindow();
        window.setStatusBarColor(widgets == null ? android.graphics.Color.parseColor(Theme.BG) : widgets.color(Theme.BG));
        window.setNavigationBarColor(widgets == null ? android.graphics.Color.parseColor(Theme.BG_SIDEBAR) : widgets.color(Theme.BG_SIDEBAR));
        View decor = window.getDecorView();
        int flags = decor.getSystemUiVisibility();
        if (Build.VERSION.SDK_INT >= 23) {
            flags &= ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
        }
        if (Build.VERSION.SDK_INT >= 26) {
            flags &= ~View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        }
        decor.setSystemUiVisibility(flags);
        if (Build.VERSION.SDK_INT >= 30 && window.getInsetsController() != null) {
            window.getInsetsController().setSystemBarsAppearance(
                    0,
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                            | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS);
        }
    }
}
