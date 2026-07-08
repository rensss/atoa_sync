package com.androidsync.app;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaPlayer;
import android.net.Uri;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.util.Log;
import android.util.LruCache;
import android.util.Size;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.MediaController;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.VideoView;

import com.androidsync.app.android.AlbumPrefs;
import com.androidsync.app.android.HttpFileUploader;
import com.androidsync.app.android.MediaStoreScanner;
import com.androidsync.app.android.RemoteManifestClient;
import com.androidsync.app.core.AlbumFilter;
import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncRunGate;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.TaskWindow;
import com.androidsync.app.core.ThumbnailPolicy;
import com.androidsync.app.ui.AlbumPickerView;
import com.androidsync.app.ui.ConfirmSelectionView;
import com.androidsync.app.ui.SettingsPageView;
import com.androidsync.app.ui.Theme;
import com.androidsync.app.ui.ThumbnailLoader;
import com.androidsync.app.ui.Widgets;

import java.lang.ref.WeakReference;
import java.text.DateFormat;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
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
    private static final int QUEUE_PAGE_SIZE = 80;
    private static final int RECENT_GRID_LIMIT = 50;
    private static final String PREFS = "android_sync";
    private static final String KEY_TARGET_URL = "target_url";

    private final SyncQueue queue = new SyncQueue();
    private final SyncRunGate syncRuns = new SyncRunGate();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final HttpFileUploader uploader = new HttpFileUploader();
    private final RemoteManifestClient manifestClient = new RemoteManifestClient();
    private final Map<String, QueueRowViews> queueRows = new HashMap<>();
    private final Map<String, RecentTaskTileViews> homeRecentTaskTiles = new HashMap<>();

    private LinearLayout root;
    private ProgressRing homeProgressRing;
    private TextView homePercentView;
    private TextView homeSyncedView;
    private TextView homeWaitingView;
    private TextView homeUploadingView;
    private TextView homeFailedView;
    private Button homeSyncButton;
    private TextView queueSummaryTotalView;
    private TextView queueSummaryDoneView;
    private TextView queueSummaryCapacityView;
    private Button queueRetryFailedButton;
    private LinearLayout queueTaskContainer;
    private TextView queueLoadMoreHint;
    private ScrollView queueScrollView;
    private Button queueBackTopButton;
    private TextView detailStatusView;
    private TextView detailMetadataStatusView;
    private TextView detailErrorView;
    private View detailErrorRow;
    private MediaStoreScanner scanner;
    private Widgets widgets;
    private ThumbnailLoader thumbnailLoader;
    private final Set<String> albumSelection = new HashSet<>();
    private final Set<String> confirmExcluded = new HashSet<>();
    private List<MediaStoreScanner.Album> albums = Collections.emptyList();
    private Button albumDoneButton;
    private String albumPickerReturn = "home";
    private String screen = "home";
    private String filter = "all";
    private String targetUrl;
    private String selectedTaskId;
    private boolean scanning;
    private boolean queueAutoLoading;
    private String scanMessage = "等待扫描";
    private int queueVisibleLimit = QUEUE_PAGE_SIZE;
    private int queueScrollY;
    private volatile boolean destroyed;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        scanner = new MediaStoreScanner(getContentResolver());
        widgets = new Widgets(this);
        thumbnailLoader = new ThumbnailLoader(this, getContentResolver());
        targetUrl = prefs().getString(KEY_TARGET_URL, "http://192.168.1.20:8765/uploads/");
        render();
        ensureMediaPermissionThenScan();
    }

    @Override
    protected void onDestroy() {
        destroyed = true;
        syncRuns.cancel();
        mainHandler.removeCallbacksAndMessages(null);
        thumbnailLoader.shutdown();
        executor.shutdownNow();
        super.onDestroy();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_MEDIA_PERMISSION && hasMediaPermission()) {
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
        albumPickerReturn = initialSetup ? "home" : screen;
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
                queue.enqueueAll(media);
                int remoteMatches = 0;
                String remoteMessage = "";
                try {
                    RemoteManifestClient.Snapshot snapshot = manifestClient.fetch(targetUrl);
                    remoteMatches = snapshot.stableIds().size() + snapshot.fingerprints().size();
                    queue.markRemoteExisting(snapshot.stableIds());
                    queue.markRemoteExistingByFingerprint(snapshot.fingerprints());
                } catch (Exception error) {
                    remoteMessage = "，接收端记录读取失败：" + cleanError(error);
                }
                final int scannedCount = media.size();
                final int matchedCount = remoteMatches;
                final String suffix = remoteMessage;
                postTask(new Runnable() {
                    @Override
                    public void run() {
                        scanning = false;
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

    private void startSync() {
        if (destroyed) {
            return;
        }
        if (syncRuns.isActive()) {
            syncRuns.cancel();
            refreshCurrentScreenSyncState(null);
            return;
        }
        final long syncRun = syncRuns.start();
        refreshCurrentScreenSyncState(null);
        boolean submitted = submitTask(new Runnable() {
            @Override
            public void run() {
                if (destroyed || !syncRuns.isActive(syncRun)) {
                    return;
                }
                List<SyncTask> snapshot = queue.tasks();
                for (SyncTask task : snapshot) {
                    if (destroyed || !syncRuns.isActive(syncRun)) {
                        break;
                    }
                    SyncTask currentTask = queue.findById(task.id());
                    if (currentTask == null
                            || (currentTask.status() != SyncStatus.WAITING
                            && currentTask.status() != SyncStatus.FAILED)) {
                        continue;
                    }
                    if (confirmExcluded.contains(currentTask.media().stableId())) {
                        continue;
                    }
                    final SyncStatus previousStatus = currentTask.status();
                    queue.markUploading(currentTask.id());
                    postTaskUpdate(currentTask.id(), previousStatus, SyncStatus.UPLOADING);
                    Exception uploadError = null;
                    try {
                        uploader.upload(getContentResolver(), currentTask.media(), targetUrl);
                    } catch (Exception error) {
                        uploadError = error;
                    }
                    SyncTask liveTask = queue.findById(currentTask.id());
                    if (liveTask == null) {
                        continue;
                    }
                    SyncStatus previousTerminalStatus = liveTask.status();
                    if (uploadError == null) {
                        queue.markDone(currentTask.id());
                    } else {
                        queue.markFailed(currentTask.id(), cleanError(uploadError));
                    }
                    SyncTask finalTask = queue.findById(currentTask.id());
                    if (finalTask == null) {
                        continue;
                    }
                    postTaskUpdate(currentTask.id(), previousTerminalStatus, finalTask.status());
                }
                postSyncFinished(syncRun);
            }
        });
        if (!submitted && !destroyed) {
            syncRuns.finish(syncRun);
            refreshCurrentScreenSyncState(null);
        }
    }

    private void retryFailed() {
        for (SyncTask task : queue.tasks()) {
            SyncTask currentTask = queue.findById(task.id());
            if (currentTask != null && currentTask.status() == SyncStatus.FAILED) {
                queue.retry(currentTask.id());
            }
        }
        screen = "queue";
        filter = "failed";
        render();
    }

    private void postTaskUpdate(
            final String taskId,
            final SyncStatus previousStatus,
            final SyncStatus currentStatus
    ) {
        postTask(new Runnable() {
            @Override
            public void run() {
                if ("queue".equals(screen)) {
                    refreshQueueSummary();
                    refreshQueueRow(taskId, previousStatus, currentStatus);
                } else if ("home".equals(screen)) {
                    refreshHomeSyncState();
                    refreshHomeRecentTaskTile(taskId);
                } else if ("detail".equals(screen)) {
                    refreshDetailSyncState(taskId);
                }
            }
        });
    }

    private void postSyncFinished(final long syncRun) {
        if (!syncRuns.finish(syncRun)) {
            return;
        }
        postTask(new Runnable() {
            @Override
            public void run() {
                refreshCurrentScreenSyncState(null);
            }
        });
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
        clearScreenViewReferences();
        thumbnailLoader.bumpGeneration();
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(widgets.color("#F4F1EA"));
        setContentView(root);

        FrameLayout content = new FrameLayout(this);
        root.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        if ("detail".equals(screen)) {
            content.addView(detailView());
        } else if ("albumPicker".equals(screen)) {
            content.addView(albumPickerView());
        } else if ("confirm".equals(screen)) {
            content.addView(confirmView());
        } else if ("settings".equals(screen)) {
            content.addView(settingsView());
        } else if ("queue".equals(screen)) {
            content.addView(queueView());
        } else {
            content.addView(homeView());
        }
        if (showsBottomNav()) {
            root.addView(navBar(), new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(76)));
        }
    }

    private boolean showsBottomNav() {
        return "home".equals(screen) || "queue".equals(screen);
    }

    @Override
    public void onBackPressed() {
        if ("detail".equals(screen)) {
            selectedTaskId = null;
            screen = "queue";
            render();
            return;
        }
        if ("settings".equals(screen)) {
            screen = "home";
            render();
            return;
        }
        if ("albumPicker".equals(screen)) {
            screen = albumPickerReturn;
            render();
            return;
        }
        if ("confirm".equals(screen)) {
            screen = "home";
            render();
            return;
        }
        super.onBackPressed();
    }

    private View homeView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = widgets.pageLayout();
        scroll.addView(page);

        page.addView(homeHeader());
        page.addView(targetCard());

        if (scanning) {
            LinearLayout scanningCard = widgets.card();
            scanningCard.addView(widgets.title("正在扫描相册", 20));
            scanningCard.addView(widgets.label(scanMessage, 13, "#6B6257"));
            page.addView(scanningCard);
            return scroll;
        }

        SyncQueue.Summary summary = queue.summary();
        float progress = summary.total() == 0 ? 0f : (float) summary.done() / (float) summary.total();
        LinearLayout hero = widgets.card();
        hero.setGravity(Gravity.CENTER_HORIZONTAL);
        homeProgressRing = new ProgressRing(this);
        homeProgressRing.setProgress(progress);
        LinearLayout.LayoutParams ringParams = new LinearLayout.LayoutParams(widgets.dp(176), widgets.dp(176));
        ringParams.topMargin = widgets.dp(10);
        hero.addView(homeProgressRing, ringParams);
        homePercentView = widgets.label(percent(progress), 34, "#182B28");
        homePercentView.setGravity(Gravity.CENTER);
        hero.addView(homePercentView);
        homeSyncedView = widgets.label("已同步 " + summary.done() + " / " + summary.total() + " 个文件", 14, "#6B6257");
        hero.addView(homeSyncedView);
        LinearLayout stats = new LinearLayout(this);
        stats.setOrientation(LinearLayout.HORIZONTAL);
        stats.setPadding(0, widgets.dp(12), 0, 0);
        homeWaitingView = widgets.label(String.valueOf(summary.waiting()), 18, "#182B28");
        homeUploadingView = widgets.label(String.valueOf(summary.uploading()), 18, "#182B28");
        homeFailedView = widgets.label(String.valueOf(summary.failed()), 18, "#182B28");
        stats.addView(stat("待传", homeWaitingView), widgets.weightParams());
        stats.addView(stat("上传中", homeUploadingView), widgets.weightParams());
        stats.addView(stat("失败", homeFailedView), widgets.weightParams());
        hero.addView(stats);
        page.addView(hero);

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER);
        homeSyncButton = widgets.actionButton(syncRuns.isActive() ? "暂停" : "开始同步", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (syncRuns.isActive()) {
                    startSync();
                } else {
                    confirmExcluded.clear();
                    screen = "confirm";
                    render();
                }
            }
        });
        actions.addView(homeSyncButton, widgets.weightParams());
        actions.addView(widgets.actionButton("重新扫描", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                scanMedia();
            }
        }), widgets.weightParams());
        page.addView(actions);
        page.addView(widgets.label(scanning ? "扫描中..." : scanMessage, 12, "#7C7367"));

        page.addView(widgets.sectionHeader("最近任务"));
        page.addView(recentGrid(queue.recentWindow(RECENT_GRID_LIMIT).visibleTasks()));
        return scroll;
    }

    private View queueView() {
        final FrameLayout frame = new FrameLayout(this);
        final ScrollView scroll = new ScrollView(this);
        queueScrollView = scroll;
        scroll.setVerticalScrollBarEnabled(true);
        scroll.setScrollbarFadingEnabled(false);
        LinearLayout page = widgets.pageLayout();
        scroll.addView(page);
        page.addView(widgets.label("任务队列", 12, "#7E7565"));
        page.addView(widgets.title("同步明细", 30));
        if (scanning) {
            LinearLayout scanningCard = widgets.card();
            scanningCard.addView(widgets.title("正在扫描相册", 20));
            scanningCard.addView(widgets.label("扫描完成后会自动显示队列", 13, "#6B6257"));
            page.addView(scanningCard);
            frame.addView(scroll);
            return frame;
        }
        page.addView(filterStrip());
        page.addView(queueSummary());
        page.addView(queueTaskList(queue.window(filter, queueVisibleLimit)));
        frame.addView(scroll);

        final Button backTop = widgets.smallButton("回顶部");
        queueBackTopButton = backTop;
        backTop.setTextColor(Color.WHITE);
        backTop.setBackground(widgets.rounded("#182B28", "#182B28", 0, 22));
        backTop.setVisibility(queueScrollY > widgets.dp(240) ? View.VISIBLE : View.GONE);
        backTop.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                queueScrollY = 0;
                scroll.smoothScrollTo(0, 0);
                backTop.setVisibility(View.GONE);
            }
        });
        FrameLayout.LayoutParams topParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, widgets.dp(44));
        topParams.gravity = Gravity.BOTTOM | Gravity.RIGHT;
        topParams.setMargins(0, 0, widgets.dp(18), widgets.dp(18));
        frame.addView(backTop, topParams);

        scroll.setOnScrollChangeListener(new View.OnScrollChangeListener() {
            @Override
            public void onScrollChange(View view, int scrollX, int scrollY, int oldScrollX, int oldScrollY) {
                if (scroll != queueScrollView) {
                    return;
                }
                queueScrollY = scrollY;
                backTop.setVisibility(scrollY > widgets.dp(240) ? View.VISIBLE : View.GONE);
                if (shouldLoadMore(scroll)) {
                    loadMoreQueueRows();
                }
            }
        });
        scroll.post(new Runnable() {
            @Override
            public void run() {
                if (destroyed || scroll != queueScrollView || !"queue".equals(screen)) {
                    return;
                }
                scroll.scrollTo(0, queueScrollY);
                queueAutoLoading = false;
            }
        });
        return frame;
    }

    private View detailView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = widgets.pageLayout();
        scroll.addView(page);

        SyncTask task = selectedTaskId == null ? null : queue.findById(selectedTaskId);
        page.addView(backHeader("任务详情", "同步详情", "queue"));
        if (task == null) {
            LinearLayout missing = widgets.card();
            missing.addView(widgets.title("任务不存在", 20));
            missing.addView(widgets.label("这个任务可能已经从队列里移除，请返回队列重新选择。", 13, "#6B6257"));
            page.addView(missing);
            return scroll;
        }

        MediaItem media = task.media();
        LinearLayout previewCard = widgets.card();
        previewCard.setPadding(0, 0, 0, widgets.dp(12));
        if (media.isVideo()) {
            FrameLayout videoFrame = new FrameLayout(this);
            videoFrame.setBackgroundColor(Color.BLACK);
            final VideoView video = new VideoView(this);
            video.setBackgroundColor(Color.BLACK);
            video.setVideoURI(Uri.parse(media.uri()));
            final MediaController controller = new MediaController(this);
            controller.setAnchorView(videoFrame);
            video.setMediaController(controller);
            FrameLayout.LayoutParams videoParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
            videoParams.gravity = Gravity.CENTER;
            videoFrame.addView(video, videoParams);
            final TextView playToggle = widgets.textButton("播放 / 暂停", "#182B28", "#EFE8DA");
            playToggle.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    if (video.isPlaying()) {
                        video.pause();
                    } else {
                        video.start();
                        controller.show(3000);
                    }
                }
            });
            video.setOnPreparedListener(new MediaPlayer.OnPreparedListener() {
                @Override
                public void onPrepared(MediaPlayer player) {
                    video.requestFocus();
                    video.start();
                    controller.show(3000);
                    playToggle.setText("播放 / 暂停");
                }
            });
            video.setOnErrorListener(new MediaPlayer.OnErrorListener() {
                @Override
                public boolean onError(MediaPlayer player, int what, int extra) {
                    Toast.makeText(MainActivity.this, "视频无法播放，可用其他应用打开", Toast.LENGTH_SHORT).show();
                    return true;
                }
            });
            previewCard.addView(videoFrame, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(340)));
            LinearLayout.LayoutParams playParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(42));
            playParams.setMargins(widgets.dp(16), widgets.dp(12), widgets.dp(16), 0);
            previewCard.addView(playToggle, playParams);
        } else {
            final FrameLayout preview = new FrameLayout(this);
            preview.setBackgroundColor(Color.BLACK);
            final ImageView image = new ImageView(this);
            image.setScaleType(ImageView.ScaleType.FIT_CENTER);
            final TextView loading = widgets.label("加载预览...", 14, "#FFFFFF");
            loading.setGravity(Gravity.CENTER);
            preview.addView(image, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            preview.addView(loading, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            previewCard.addView(preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(340)));
            thumbnailLoader.loadPreviewAsync(image, loading, media.uri());
        }
        previewCard.addView(widgets.label(media.displayName(), 18, "#182B28"), paddedTextParams());
        detailStatusView = widgets.label(statusText(task), 13, statusColor(task.status()));
        previewCard.addView(detailStatusView, paddedTextParams());
        page.addView(previewCard);

        LinearLayout meta = widgets.card();
        meta.addView(widgets.title("文件信息", 20));
        meta.addView(metaRow("类型", media.isVideo() ? "视频" : "照片"));
        meta.addView(metaRow("MIME", media.mimeType()));
        meta.addView(metaRow("大小", Widgets.formatBytes(media.sizeBytes())));
        detailMetadataStatusView = widgets.label(statusText(task), 13, "#182B28");
        meta.addView(metaRow("同步状态", detailMetadataStatusView));
        meta.addView(metaRow("拍摄时间", formatDate(media.dateTakenMillis())));
        meta.addView(metaRow("添加时间", formatDate(media.dateAddedMillis())));
        meta.addView(metaRow("修改时间", formatDate(media.dateModifiedMillis())));
        detailErrorView = widgets.label(task.errorMessage(), 13, "#182B28");
        detailErrorRow = metaRow("错误", detailErrorView);
        detailErrorRow.setVisibility(task.errorMessage() == null ? View.GONE : View.VISIBLE);
        meta.addView(detailErrorRow);
        page.addView(meta);

        Button external = widgets.actionButton("用其他应用打开", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                SyncTask current = selectedTaskId == null ? null : queue.findById(selectedTaskId);
                if (current != null) {
                    openMedia(current.media());
                }
            }
        });
        page.addView(external);
        return scroll;
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
        for (SyncTask task : queue.tasks()) {
            all.add(task.media());
            if (task.status() == SyncStatus.DONE) {
                synced.add(task.media().stableId());
            }
        }
        return AlbumFilter.pending(all, synced, Collections.<String>emptySet()).pending;
    }

    private View confirmView() {
        List<MediaItem> pending = pendingMedia();
        return new ConfirmSelectionView(this, widgets, thumbnailLoader).build(pending, confirmExcluded, new ConfirmSelectionView.ConfirmHost() {
            @Override
            public void onConfirm() {
                screen = "home";
                render();
                startSync();
            }

            @Override
            public void onCancel() {
                screen = "home";
                render();
            }

            @Override
            public void onSelectionChanged(int count, long bytes) {
            }
        });
    }

    private View homeHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.addView(widgets.label("图库自动同步", 12, "#7E7565"));
        copy.addView(widgets.title("Android Sync", 30));
        header.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button settings = widgets.smallButton("设置");
        settings.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                screen = "settings";
                render();
            }
        });
        header.addView(settings);
        return header;
    }

    private View backHeader(String labelText, String titleText, final String backScreen) {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        TextView back = widgets.textButton("‹", "#FFFFFF", "#182B28");
        back.setTextSize(28);
        back.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if ("queue".equals(backScreen)) {
                    selectedTaskId = null;
                }
                screen = backScreen;
                render();
            }
        });
        header.addView(back, new LinearLayout.LayoutParams(widgets.dp(44), widgets.dp(44)));
        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.setPadding(widgets.dp(12), 0, 0, 0);
        copy.addView(widgets.label(labelText, 12, "#7E7565"));
        copy.addView(widgets.title(titleText, 28));
        header.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        return header;
    }

    private View recentGrid(List<SyncTask> tasks) {
        homeRecentTaskTiles.clear();
        LinearLayout grid = widgets.card();
        grid.setPadding(widgets.dp(10), widgets.dp(10), widgets.dp(10), widgets.dp(10));
        if (tasks.isEmpty()) {
            grid.addView(widgets.label("还没有任务", 14, "#6B6257"));
            return grid;
        }
        int width = getResources().getDisplayMetrics().widthPixels;
        final int columns = 10;
        final int gap = widgets.dp(4);
        final int cellSize = Math.max(widgets.dp(24), (width - widgets.dp(40) - widgets.dp(20) - gap * (columns - 1)) / columns);
        LinearLayout row = null;
        for (int index = 0; index < tasks.size(); index++) {
            if (index % columns == 0) {
                row = new LinearLayout(this);
                row.setOrientation(LinearLayout.HORIZONTAL);
                LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                rowParams.setMargins(0, index == 0 ? 0 : gap, 0, 0);
                grid.addView(row, rowParams);
            }
            LinearLayout.LayoutParams cellParams = new LinearLayout.LayoutParams(cellSize, cellSize);
            if (index % columns != columns - 1) {
                cellParams.setMargins(0, 0, gap, 0);
            }
            row.addView(recentTaskTile(tasks.get(index)), cellParams);
        }
        return grid;
    }

    private View recentTaskTile(SyncTask task) {
        FrameLayout tile = new FrameLayout(this);
        GradientDrawable border = new GradientDrawable();
        border.setColor(widgets.color("#F7F5EF"));
        border.setCornerRadius(widgets.dp(8));
        border.setStroke(widgets.dp(2), statusBorderColor(task.status()));
        tile.setBackground(border);
        tile.setClipToOutline(true);
        tile.setPadding(widgets.dp(2), widgets.dp(2), widgets.dp(2), widgets.dp(2));
        tile.addView(thumbnail(task), new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        TextView strip = new TextView(this);
        strip.setBackgroundColor(statusBorderColor(task.status()));
        strip.setText(task.status() == SyncStatus.UPLOADING ? "..." : "");
        strip.setTextColor(Color.WHITE);
        strip.setGravity(Gravity.CENTER);
        strip.setTextSize(8);
        FrameLayout.LayoutParams stripParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(5));
        stripParams.gravity = Gravity.BOTTOM;
        strip.setVisibility(View.VISIBLE);
        tile.addView(strip, stripParams);
        homeRecentTaskTiles.put(task.id(), new RecentTaskTileViews(tile, strip));
        return tile;
    }

    private boolean shouldLoadMore(ScrollView scroll) {
        if (queueAutoLoading || !"queue".equals(screen) || scroll != queueScrollView) {
            return false;
        }
        TaskWindow window = queue.window(filter, queueVisibleLimit);
        if (!window.hasMore() || scroll.getChildCount() == 0) {
            return false;
        }
        View child = scroll.getChildAt(0);
        int distanceToBottom = child.getBottom() - (scroll.getHeight() + scroll.getScrollY());
        return distanceToBottom < widgets.dp(220);
    }

    private void loadMoreQueueRows() {
        if (queueAutoLoading || queueTaskContainer == null || queueLoadMoreHint == null) {
            return;
        }
        queueAutoLoading = true;
        try {
            int oldLimit = queueVisibleLimit;
            TaskWindow oldWindow = queue.window(filter, oldLimit);
            int oldVisibleCount = oldWindow.visibleTasks().size();
            int newLimit = oldLimit + QUEUE_PAGE_SIZE;
            TaskWindow newWindow = queue.window(filter, newLimit);
            queueVisibleLimit = newLimit;
            List<SyncTask> visibleTasks = newWindow.visibleTasks();
            for (int index = oldVisibleCount; index < visibleTasks.size(); index++) {
                queueTaskContainer.addView(taskRow(visibleTasks.get(index)));
            }
            updateQueueLoadMoreHint(newWindow);
        } finally {
            queueAutoLoading = false;
        }
    }

    private void refreshQueueSummary() {
        if (!"queue".equals(screen)
                || queueSummaryTotalView == null
                || queueSummaryDoneView == null
                || queueSummaryCapacityView == null
                || queueRetryFailedButton == null) {
            return;
        }
        SyncQueue.Summary summary = queue.summary();
        queueSummaryTotalView.setText(String.valueOf(summary.total()));
        queueSummaryDoneView.setText(String.valueOf(summary.done()));
        queueSummaryCapacityView.setText(Widgets.formatBytes(summary.totalBytes()));
        queueRetryFailedButton.setVisibility(summary.failed() > 0 ? View.VISIBLE : View.GONE);
    }

    private void refreshHomeSyncState() {
        if (!"home".equals(screen)
                || homeProgressRing == null
                || homePercentView == null
                || homeSyncedView == null
                || homeWaitingView == null
                || homeUploadingView == null
                || homeFailedView == null
                || homeSyncButton == null) {
            return;
        }
        SyncQueue.Summary summary = queue.summary();
        float progress = summary.total() == 0 ? 0f : (float) summary.done() / (float) summary.total();
        homeProgressRing.setProgress(progress);
        homePercentView.setText(percent(progress));
        homeSyncedView.setText("已同步 " + summary.done() + " / " + summary.total() + " 个文件");
        homeWaitingView.setText(String.valueOf(summary.waiting()));
        homeUploadingView.setText(String.valueOf(summary.uploading()));
        homeFailedView.setText(String.valueOf(summary.failed()));
        homeSyncButton.setText(syncRuns.isActive() ? "暂停" : "开始同步");
    }

    private void refreshHomeRecentTaskTile(String taskId) {
        if (!"home".equals(screen) || taskId == null) {
            return;
        }
        RecentTaskTileViews views = homeRecentTaskTiles.get(taskId);
        SyncTask task = queue.findById(taskId);
        if (views == null || task == null) {
            return;
        }
        int statusColor = statusBorderColor(task.status());
        GradientDrawable border = new GradientDrawable();
        border.setColor(widgets.color("#F7F5EF"));
        border.setCornerRadius(widgets.dp(8));
        border.setStroke(widgets.dp(2), statusColor);
        views.root.setBackground(border);
        views.strip.setBackgroundColor(statusColor);
        views.strip.setText(task.status() == SyncStatus.UPLOADING ? "..." : "");
    }

    private void refreshDetailSyncState(String taskId) {
        if (!"detail".equals(screen)
                || selectedTaskId == null
                || !selectedTaskId.equals(taskId)
                || detailStatusView == null
                || detailMetadataStatusView == null
                || detailErrorView == null
                || detailErrorRow == null) {
            return;
        }
        SyncTask task = queue.findById(taskId);
        if (task == null) {
            return;
        }
        detailStatusView.setText(statusText(task));
        detailStatusView.setTextColor(widgets.color(statusColor(task.status())));
        detailMetadataStatusView.setText(statusText(task));
        String errorMessage = task.errorMessage();
        detailErrorView.setText(errorMessage == null ? "" : errorMessage);
        detailErrorRow.setVisibility(errorMessage == null ? View.GONE : View.VISIBLE);
    }

    private void refreshCurrentScreenSyncState(String taskId) {
        if ("home".equals(screen)) {
            refreshHomeSyncState();
        } else if ("queue".equals(screen)) {
            refreshQueueSummary();
        } else if ("detail".equals(screen)) {
            refreshDetailSyncState(taskId == null ? selectedTaskId : taskId);
        }
    }

    private void refreshQueueRow(String taskId, SyncStatus previousStatus, SyncStatus currentStatus) {
        if (!"queue".equals(screen) || queueTaskContainer == null) {
            return;
        }
        SyncTask task = queue.findById(taskId);
        QueueRowViews views = queueRows.get(taskId);
        if ("failed".equals(filter)) {
            boolean previousFailed = previousStatus == SyncStatus.FAILED;
            boolean currentFailed = currentStatus == SyncStatus.FAILED;
            if (previousFailed != currentFailed) {
                rebuildQueueTaskContainerPreservingScroll();
            } else if (currentFailed && task != null && views != null) {
                bindQueueRow(task, views);
            }
            return;
        }
        if (task != null && views != null) {
            bindQueueRow(task, views);
        }
    }

    private void rebuildQueueTaskContainerPreservingScroll() {
        if (queueTaskContainer == null) {
            return;
        }
        final ScrollView scroll = queueScrollView;
        final int scrollY = scroll == null ? queueScrollY : scroll.getScrollY();
        TaskWindow window = queue.window(filter, queueVisibleLimit);
        queueRows.clear();
        queueTaskContainer.removeAllViews();
        populateQueueTaskContainer(window.visibleTasks());
        updateQueueLoadMoreHint(window);
        queueScrollY = scrollY;
        if (scroll != null) {
            scroll.post(new Runnable() {
                @Override
                public void run() {
                    if (!destroyed && scroll == queueScrollView && "queue".equals(screen)) {
                        scroll.scrollTo(0, scrollY);
                    }
                }
            });
        }
    }

    private void populateQueueTaskContainer(List<SyncTask> tasks) {
        if (tasks.isEmpty()) {
            LinearLayout empty = widgets.card();
            empty.addView(widgets.label("当前筛选没有任务", 15, "#6B6257"));
            queueTaskContainer.addView(empty);
            return;
        }
        for (SyncTask task : tasks) {
            queueTaskContainer.addView(taskRow(task));
        }
    }

    private void updateQueueLoadMoreHint(TaskWindow window) {
        if (queueLoadMoreHint == null) {
            return;
        }
        if (window.hasMore()) {
            queueLoadMoreHint.setText("继续向下滑动加载后续 " + window.hiddenCount() + " 条");
            queueLoadMoreHint.setVisibility(View.VISIBLE);
        } else {
            queueLoadMoreHint.setText("");
            queueLoadMoreHint.setVisibility(View.GONE);
        }
    }

    private void clearScreenViewReferences() {
        homeProgressRing = null;
        homePercentView = null;
        homeSyncedView = null;
        homeWaitingView = null;
        homeUploadingView = null;
        homeFailedView = null;
        homeSyncButton = null;
        homeRecentTaskTiles.clear();
        queueRows.clear();
        queueSummaryTotalView = null;
        queueSummaryDoneView = null;
        queueSummaryCapacityView = null;
        queueRetryFailedButton = null;
        queueTaskContainer = null;
        queueLoadMoreHint = null;
        queueScrollView = null;
        queueBackTopButton = null;
        queueAutoLoading = false;
        detailStatusView = null;
        detailMetadataStatusView = null;
        detailErrorView = null;
        detailErrorRow = null;
        albumDoneButton = null;
    }

    private View metaRow(String name, String value) {
        return metaRow(name, widgets.label(value == null || value.length() == 0 ? "-" : value, 13, "#182B28"));
    }

    private View metaRow(String name, TextView valueView) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(0, widgets.dp(8), 0, 0);
        TextView key = widgets.label(name, 13, "#7C7367");
        valueView.setGravity(Gravity.RIGHT);
        row.addView(key, new LinearLayout.LayoutParams(widgets.dp(86), ViewGroup.LayoutParams.WRAP_CONTENT));
        row.addView(valueView, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        return row;
    }

    private LinearLayout.LayoutParams paddedTextParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(widgets.dp(16), widgets.dp(10), widgets.dp(16), 0);
        return params;
    }

    private View targetCard() {
        LinearLayout card = widgets.card();
        card.setOrientation(LinearLayout.VERTICAL);
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        TextView icon = widgets.icon("NAS");
        row.addView(icon, new LinearLayout.LayoutParams(widgets.dp(54), widgets.dp(54)));
        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.setPadding(widgets.dp(12), 0, 0, 0);
        copy.addView(widgets.label(networkLabel(), 13, "#6E665A"));
        copy.addView(widgets.label(targetUrl, 14, "#1F332F"));
        row.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button edit = widgets.smallButton("编辑");
        edit.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                editTarget();
            }
        });
        row.addView(edit);
        card.addView(row);
        return card;
    }

    private View queueSummary() {
        SyncQueue.Summary summary = queue.summary();
        LinearLayout card = widgets.card();
        LinearLayout stats = new LinearLayout(this);
        stats.setOrientation(LinearLayout.HORIZONTAL);
        stats.setPadding(0, widgets.dp(12), 0, 0);
        queueSummaryTotalView = widgets.label(String.valueOf(summary.total()), 18, "#182B28");
        queueSummaryDoneView = widgets.label(String.valueOf(summary.done()), 18, "#182B28");
        queueSummaryCapacityView = widgets.label(Widgets.formatBytes(summary.totalBytes()), 18, "#182B28");
        stats.addView(stat("总数", queueSummaryTotalView), widgets.weightParams());
        stats.addView(stat("完成", queueSummaryDoneView), widgets.weightParams());
        stats.addView(stat("容量", queueSummaryCapacityView), widgets.weightParams());
        card.addView(stats);

        queueRetryFailedButton = widgets.smallButton("重试失败项");
        queueRetryFailedButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                retryFailed();
            }
        });
        queueRetryFailedButton.setVisibility(summary.failed() > 0 ? View.VISIBLE : View.GONE);
        card.addView(queueRetryFailedButton);
        return card;
    }

    private View filterStrip() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.addView(filterButton("all", "全部"), widgets.weightParams());
        row.addView(filterButton("photo", "照片"), widgets.weightParams());
        row.addView(filterButton("video", "视频"), widgets.weightParams());
        row.addView(filterButton("failed", "失败"), widgets.weightParams());
        return row;
    }

    private Button filterButton(final String value, String text) {
        Button button = widgets.smallButton(text);
        button.setTextColor(value.equals(filter) ? Color.WHITE : widgets.color("#2F3D38"));
        button.setBackground(value.equals(filter)
                ? widgets.rounded("#2F6B5F", "#2F6B5F", 0, 12)
                : widgets.rounded("#E9E2D5", "#DDD3C4", 1, 12));
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                filter = value;
                queueVisibleLimit = QUEUE_PAGE_SIZE;
                queueScrollY = 0;
                render();
            }
        });
        return button;
    }

    private View queueTaskList(TaskWindow window) {
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        queueTaskContainer = new LinearLayout(this);
        queueTaskContainer.setOrientation(LinearLayout.VERTICAL);
        populateQueueTaskContainer(window.visibleTasks());
        container.addView(queueTaskContainer);

        queueLoadMoreHint = widgets.label("", 12, "#7C7367");
        queueLoadMoreHint.setGravity(Gravity.CENTER);
        queueLoadMoreHint.setPadding(0, widgets.dp(10), 0, widgets.dp(18));
        container.addView(queueLoadMoreHint);
        updateQueueLoadMoreHint(window);
        return container;
    }

    private View taskList(List<SyncTask> tasks, boolean showEmpty) {
        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        if (tasks.isEmpty() && showEmpty) {
            LinearLayout empty = widgets.card();
            empty.addView(widgets.label("当前筛选没有任务", 15, "#6B6257"));
            list.addView(empty);
            return list;
        }
        for (SyncTask task : tasks) {
            list.addView(taskRow(task));
        }
        return list;
    }

    private View taskRow(final SyncTask task) {
        LinearLayout row = widgets.card();
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);

        row.addView(thumbnail(task), new LinearLayout.LayoutParams(widgets.dp(54), widgets.dp(54)));

        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.setPadding(widgets.dp(12), 0, 0, 0);
        TextView fileName = widgets.label(task.media().displayName(), 15, "#182B28");
        TextView statusCapacity = widgets.label("", 12, "#786F63");
        ProgressBar progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setIndeterminate(true);
        TextView error = widgets.label("", 12, "#A54135");
        copy.addView(fileName);
        copy.addView(statusCapacity);
        copy.addView(progress, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(18)));
        copy.addView(error);
        row.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        Button retry = widgets.smallButton("重试");
        retry.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                SyncTask currentTask = queue.findById(task.id());
                if (currentTask == null || currentTask.status() != SyncStatus.FAILED) {
                    return;
                }
                SyncStatus previousStatus = currentTask.status();
                queue.retry(currentTask.id());
                refreshQueueSummary();
                refreshQueueRow(currentTask.id(), previousStatus, SyncStatus.WAITING);
            }
        });
        row.addView(retry);
        row.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                selectedTaskId = task.id();
                screen = "detail";
                render();
            }
        });

        QueueRowViews views = new QueueRowViews(row, fileName, statusCapacity, error, progress, retry);
        queueRows.put(task.id(), views);
        bindQueueRow(task, views);
        return row;
    }

    private void bindQueueRow(SyncTask task, QueueRowViews views) {
        views.fileName.setText(task.media().displayName());
        views.statusCapacity.setText(Widgets.formatBytes(task.media().sizeBytes()) + " · " + statusText(task));
        views.statusCapacity.setTextColor(widgets.color(statusColor(task.status())));

        boolean uploading = task.status() == SyncStatus.UPLOADING;
        views.progress.setVisibility(uploading ? View.VISIBLE : View.GONE);

        boolean failed = task.status() == SyncStatus.FAILED;
        views.retry.setVisibility(failed ? View.VISIBLE : View.GONE);
        String errorMessage = task.errorMessage();
        views.error.setText(errorMessage == null ? "" : errorMessage);
        views.error.setVisibility(failed && errorMessage != null ? View.VISIBLE : View.GONE);
    }

    private View thumbnail(SyncTask task) {
        final FrameLayout frame = new FrameLayout(this);
        frame.setBackgroundColor(widgets.color("#D9D0C2"));

        ImageView image = new ImageView(this);
        image.setScaleType(ImageView.ScaleType.CENTER_CROP);
        image.setContentDescription(task.media().displayName());
        frame.addView(image, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        final TextView placeholder = widgets.icon(task.media().isVideo() ? "VID" : "IMG");
        frame.addView(placeholder, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        final String mediaUri = task.media().uri();
        image.setTag(mediaUri);
        final int requestPixels = ThumbnailPolicy.gridRequestPixels(96);
        thumbnailLoader.loadThumbnailInto(image, placeholder, mediaUri, requestPixels);
        return frame;
    }

    private static final class QueueRowViews {
        private final LinearLayout root;
        private final TextView fileName;
        private final TextView statusCapacity;
        private final TextView error;
        private final ProgressBar progress;
        private final Button retry;

        private QueueRowViews(
            LinearLayout root,
            TextView fileName,
            TextView statusCapacity,
            TextView error,
            ProgressBar progress,
            Button retry
        ) {
            this.root = root;
            this.fileName = fileName;
            this.statusCapacity = statusCapacity;
            this.error = error;
            this.progress = progress;
            this.retry = retry;
        }
    }

    private static final class RecentTaskTileViews {
        private final FrameLayout root;
        private final TextView strip;

        private RecentTaskTileViews(FrameLayout root, TextView strip) {
            this.root = root;
            this.strip = strip;
        }
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

    private View navBar() {
        LinearLayout nav = new LinearLayout(this);
        nav.setOrientation(LinearLayout.HORIZONTAL);
        nav.setPadding(widgets.dp(18), widgets.dp(8), widgets.dp(18), widgets.dp(12));
        nav.setGravity(Gravity.CENTER);
        nav.setBackgroundColor(widgets.color("#EFE8DA"));
        nav.addView(navButton("首页", "home"), widgets.weightParams());
        nav.addView(navButton("队列", "queue"), widgets.weightParams());
        return nav;
    }

    private Button navButton(String text, final String nextScreen) {
        Button button = widgets.smallButton(text);
        button.setTextColor(nextScreen.equals(navSelection()) ? Color.WHITE : widgets.color("#2E3B37"));
        button.setBackground(nextScreen.equals(navSelection())
                ? widgets.rounded("#182B28", "#182B28", 0, 14)
                : widgets.rounded("#E4DAC9", "#D8CCB9", 1, 14));
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                selectedTaskId = null;
                screen = nextScreen;
                render();
            }
        });
        return button;
    }

    private String navSelection() {
        if ("detail".equals(screen)) {
            return "queue";
        }
        if ("settings".equals(screen)) {
            return "home";
        }
        return screen;
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
                        render();
                    }
                })
                .show();
    }

    private View statRow(String aLabel, String aValue, String bLabel, String bValue, String cLabel, String cValue) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(0, widgets.dp(12), 0, 0);
        row.addView(stat(aLabel, aValue), widgets.weightParams());
        row.addView(stat(bLabel, bValue), widgets.weightParams());
        row.addView(stat(cLabel, cValue), widgets.weightParams());
        return row;
    }

    private View stat(String label, String value) {
        return stat(label, widgets.label(value, 18, "#182B28"));
    }

    private View stat(String labelText, TextView valueView) {
        LinearLayout item = new LinearLayout(this);
        item.setOrientation(LinearLayout.VERTICAL);
        item.setGravity(Gravity.CENTER);
        item.addView(valueView);
        item.addView(widgets.label(labelText, 11, "#7C7367"));
        return item;
    }

    private String networkLabel() {
        ConnectivityManager connectivity = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        if (connectivity == null) {
            return "等待网络";
        }
        Network network = connectivity.getActiveNetwork();
        NetworkCapabilities capabilities = network == null ? null : connectivity.getNetworkCapabilities(network);
        return capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                ? "局域网在线"
                : "等待网络";
    }

    private String statusText(SyncTask task) {
        switch (task.status()) {
            case WAITING:
                return "等待";
            case UPLOADING:
                return "上传中";
            case DONE:
                return "完成";
            case FAILED:
                return "失败";
            default:
                return "";
        }
    }

    private int statusBorderColor(SyncStatus status) {
        switch (status) {
            case WAITING:
                return widgets.color("#B8AEA1");
            case UPLOADING:
                return widgets.color("#2F6B5F");
            case DONE:
                return widgets.color("#3D7A46");
            case FAILED:
                return widgets.color("#A54135");
            default:
                return widgets.color("#B8AEA1");
        }
    }

    private String statusColor(SyncStatus status) {
        switch (status) {
            case WAITING:
                return "#786F63";
            case UPLOADING:
                return "#2F6B5F";
            case DONE:
                return "#3D7A46";
            case FAILED:
                return "#A54135";
            default:
                return "#786F63";
        }
    }

    private String percent(float progress) {
        return String.valueOf(Math.round(progress * 100f)) + "%";
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

    public static final class ProgressRing extends View {
        private final Paint trackPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint progressPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private float progress;

        public ProgressRing(android.content.Context context) {
            super(context);
            trackPaint.setStyle(Paint.Style.STROKE);
            trackPaint.setStrokeWidth(20f);
            trackPaint.setStrokeCap(Paint.Cap.ROUND);
            trackPaint.setColor(Color.parseColor("#E6DDCF"));
            progressPaint.setStyle(Paint.Style.STROKE);
            progressPaint.setStrokeWidth(20f);
            progressPaint.setStrokeCap(Paint.Cap.ROUND);
            progressPaint.setColor(Color.parseColor("#2F6B5F"));
        }

        public void setProgress(float progress) {
            this.progress = Math.max(0f, Math.min(1f, progress));
            invalidate();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            float inset = 22f;
            RectF rect = new RectF(inset, inset, getWidth() - inset, getHeight() - inset);
            canvas.drawArc(rect, 0f, 360f, false, trackPaint);
            canvas.drawArc(rect, -90f, 360f * progress, false, progressPaint);
        }
    }
}
