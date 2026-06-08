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

import com.androidsync.app.android.HttpFileUploader;
import com.androidsync.app.android.MediaStoreScanner;
import com.androidsync.app.android.RemoteManifestClient;
import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.TaskWindow;

import java.text.DateFormat;
import java.text.DecimalFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final String TAG = "AndroidSync";
    private static final int REQUEST_MEDIA_PERMISSION = 40;
    private static final int QUEUE_PAGE_SIZE = 80;
    private static final int RECENT_GRID_LIMIT = 50;
    private static final String PREFS = "android_sync";
    private static final String KEY_TARGET_URL = "target_url";

    private final SyncQueue queue = new SyncQueue();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final ExecutorService thumbnailExecutor = Executors.newFixedThreadPool(2);
    private final HttpFileUploader uploader = new HttpFileUploader();
    private final RemoteManifestClient manifestClient = new RemoteManifestClient();

    private LinearLayout root;
    private MediaStoreScanner scanner;
    private String screen = "home";
    private String filter = "all";
    private String targetUrl;
    private String selectedTaskId;
    private boolean syncing;
    private boolean scanning;
    private boolean queueAutoLoading;
    private String scanMessage = "等待扫描";
    private int queueVisibleLimit = QUEUE_PAGE_SIZE;
    private int queueScrollY;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        scanner = new MediaStoreScanner(getContentResolver());
        targetUrl = prefs().getString(KEY_TARGET_URL, "http://192.168.1.20:8765/uploads/");
        render();
        ensureMediaPermissionThenScan();
    }

    @Override
    protected void onDestroy() {
        executor.shutdownNow();
        thumbnailExecutor.shutdownNow();
        super.onDestroy();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_MEDIA_PERMISSION && hasMediaPermission()) {
            scanMedia();
        } else if (requestCode == REQUEST_MEDIA_PERMISSION) {
            Toast.makeText(this, "需要相册权限才能同步照片和视频", Toast.LENGTH_LONG).show();
        }
    }

    private void ensureMediaPermissionThenScan() {
        if (hasMediaPermission()) {
            scanMedia();
            return;
        }
        if (Build.VERSION.SDK_INT >= 33) {
            requestPermissions(new String[] { Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO }, REQUEST_MEDIA_PERMISSION);
        } else {
            requestPermissions(new String[] { Manifest.permission.READ_EXTERNAL_STORAGE }, REQUEST_MEDIA_PERMISSION);
        }
    }

    private boolean hasMediaPermission() {
        if (Build.VERSION.SDK_INT >= 33) {
            return checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED
                    || checkSelfPermission(Manifest.permission.READ_MEDIA_VIDEO) == PackageManager.PERMISSION_GRANTED;
        }
        return checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
    }

    private void scanMedia() {
        if (!hasMediaPermission()) {
            ensureMediaPermissionThenScan();
            return;
        }
        scanning = true;
        scanMessage = "正在扫描本机相册...";
        render();
        executor.execute(new Runnable() {
            @Override
            public void run() {
                final List<MediaItem> media = scanner.scanAll();
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
                mainHandler.post(new Runnable() {
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
    }

    private void startSync() {
        if (syncing) {
            syncing = false;
            render();
            return;
        }
        syncing = true;
        render();
        executor.execute(new Runnable() {
            @Override
            public void run() {
                List<SyncTask> snapshot = queue.tasks();
                for (SyncTask task : snapshot) {
                    if (!syncing) {
                        break;
                    }
                    if (task.status() != SyncStatus.WAITING && task.status() != SyncStatus.FAILED) {
                        continue;
                    }
                    queue.markUploading(task.id());
                    postRender();
                    try {
                        uploader.upload(getContentResolver(), task.media(), targetUrl);
                        queue.markDone(task.id());
                    } catch (Exception error) {
                        queue.markFailed(task.id(), cleanError(error));
                    }
                    postRender();
                }
                syncing = false;
                postRender();
            }
        });
    }

    private void retryFailed() {
        for (SyncTask task : queue.tasks()) {
            if (task.status() == SyncStatus.FAILED) {
                queue.retry(task.id());
            }
        }
        screen = "queue";
        filter = "failed";
        render();
    }

    private void postRender() {
        mainHandler.post(new Runnable() {
            @Override
            public void run() {
                render();
            }
        });
    }

    private void render() {
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(color("#F4F1EA"));
        setContentView(root);

        FrameLayout content = new FrameLayout(this);
        root.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        if ("detail".equals(screen)) {
            content.addView(detailView());
        } else if ("settings".equals(screen)) {
            content.addView(settingsView());
        } else if ("queue".equals(screen)) {
            content.addView(queueView());
        } else {
            content.addView(homeView());
        }
        if (showsBottomNav()) {
            root.addView(navBar(), new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(76)));
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
        super.onBackPressed();
    }

    private View homeView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = pageLayout();
        scroll.addView(page);

        page.addView(homeHeader());
        page.addView(targetCard());

        if (scanning) {
            LinearLayout scanningCard = card();
            scanningCard.addView(title("正在扫描相册", 20));
            scanningCard.addView(label(scanMessage, 13, "#6B6257"));
            page.addView(scanningCard);
            return scroll;
        }

        SyncQueue.Summary summary = queue.summary();
        float progress = summary.total() == 0 ? 0f : (float) summary.done() / (float) summary.total();
        LinearLayout hero = card();
        hero.setGravity(Gravity.CENTER_HORIZONTAL);
        ProgressRing ring = new ProgressRing(this);
        ring.setProgress(progress);
        LinearLayout.LayoutParams ringParams = new LinearLayout.LayoutParams(dp(176), dp(176));
        ringParams.topMargin = dp(10);
        hero.addView(ring, ringParams);
        TextView center = label(percent(progress), 34, "#182B28");
        center.setGravity(Gravity.CENTER);
        hero.addView(center);
        hero.addView(label("已同步 " + summary.done() + " / " + summary.total() + " 个文件", 14, "#6B6257"));
        hero.addView(statRow("待传", String.valueOf(summary.waiting()), "上传中", String.valueOf(summary.uploading()), "失败", String.valueOf(summary.failed())));
        page.addView(hero);

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER);
        actions.addView(actionButton(syncing ? "暂停" : "开始同步", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                startSync();
            }
        }), weightParams());
        actions.addView(actionButton("重新扫描", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                scanMedia();
            }
        }), weightParams());
        page.addView(actions);
        page.addView(label(scanning ? "扫描中..." : scanMessage, 12, "#7C7367"));

        page.addView(sectionHeader("最近任务"));
        page.addView(recentGrid(queue.recentWindow(RECENT_GRID_LIMIT).visibleTasks()));
        return scroll;
    }

    private View queueView() {
        final FrameLayout frame = new FrameLayout(this);
        final ScrollView scroll = new ScrollView(this);
        scroll.setVerticalScrollBarEnabled(true);
        scroll.setScrollbarFadingEnabled(false);
        LinearLayout page = pageLayout();
        scroll.addView(page);
        page.addView(label("任务队列", 12, "#7E7565"));
        page.addView(title("同步明细", 30));
        if (scanning) {
            LinearLayout scanningCard = card();
            scanningCard.addView(title("正在扫描相册", 20));
            scanningCard.addView(label("扫描完成后会自动显示队列", 13, "#6B6257"));
            page.addView(scanningCard);
            frame.addView(scroll);
            return frame;
        }
        page.addView(filterStrip());
        page.addView(queueSummary());
        page.addView(queueTaskList(queue.window(filter, queueVisibleLimit)));
        frame.addView(scroll);

        final Button backTop = smallButton("回顶部");
        backTop.setTextColor(Color.WHITE);
        backTop.setBackground(rounded("#182B28", "#182B28", 0, 22));
        backTop.setVisibility(queueScrollY > dp(240) ? View.VISIBLE : View.GONE);
        backTop.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                queueScrollY = 0;
                scroll.smoothScrollTo(0, 0);
                backTop.setVisibility(View.GONE);
            }
        });
        FrameLayout.LayoutParams topParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(44));
        topParams.gravity = Gravity.BOTTOM | Gravity.RIGHT;
        topParams.setMargins(0, 0, dp(18), dp(18));
        frame.addView(backTop, topParams);

        scroll.setOnScrollChangeListener(new View.OnScrollChangeListener() {
            @Override
            public void onScrollChange(View view, int scrollX, int scrollY, int oldScrollX, int oldScrollY) {
                queueScrollY = scrollY;
                backTop.setVisibility(scrollY > dp(240) ? View.VISIBLE : View.GONE);
                if (shouldLoadMore(scroll)) {
                    queueAutoLoading = true;
                    queueVisibleLimit += QUEUE_PAGE_SIZE;
                    render();
                }
            }
        });
        scroll.post(new Runnable() {
            @Override
            public void run() {
                scroll.scrollTo(0, queueScrollY);
                queueAutoLoading = false;
            }
        });
        return frame;
    }

    private View detailView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = pageLayout();
        scroll.addView(page);

        SyncTask task = selectedTaskId == null ? null : queue.findById(selectedTaskId);
        page.addView(backHeader("任务详情", "同步详情", "queue"));
        if (task == null) {
            LinearLayout missing = card();
            missing.addView(title("任务不存在", 20));
            missing.addView(label("这个任务可能已经从队列里移除，请返回队列重新选择。", 13, "#6B6257"));
            page.addView(missing);
            return scroll;
        }

        MediaItem media = task.media();
        LinearLayout previewCard = card();
        previewCard.setPadding(0, 0, 0, dp(12));
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
            final TextView playToggle = textButton("播放 / 暂停", "#182B28", "#EFE8DA");
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
            previewCard.addView(videoFrame, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(340)));
            LinearLayout.LayoutParams playParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(42));
            playParams.setMargins(dp(16), dp(12), dp(16), 0);
            previewCard.addView(playToggle, playParams);
        } else {
            final FrameLayout preview = new FrameLayout(this);
            preview.setBackgroundColor(Color.BLACK);
            final ImageView image = new ImageView(this);
            image.setScaleType(ImageView.ScaleType.FIT_CENTER);
            final TextView loading = label("加载预览...", 14, "#FFFFFF");
            loading.setGravity(Gravity.CENTER);
            preview.addView(image, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            preview.addView(loading, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            previewCard.addView(preview, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(340)));
            loadPreviewAsync(image, loading, media.uri());
        }
        previewCard.addView(label(media.displayName(), 18, "#182B28"), paddedTextParams());
        previewCard.addView(label(statusText(task), 13, statusColor(task.status())), paddedTextParams());
        page.addView(previewCard);

        LinearLayout meta = card();
        meta.addView(title("文件信息", 20));
        meta.addView(metaRow("类型", media.isVideo() ? "视频" : "照片"));
        meta.addView(metaRow("MIME", media.mimeType()));
        meta.addView(metaRow("大小", formatBytes(media.sizeBytes())));
        meta.addView(metaRow("同步状态", statusText(task)));
        meta.addView(metaRow("拍摄时间", formatDate(media.dateTakenMillis())));
        meta.addView(metaRow("添加时间", formatDate(media.dateAddedMillis())));
        meta.addView(metaRow("修改时间", formatDate(media.dateModifiedMillis())));
        if (task.errorMessage() != null) {
            meta.addView(metaRow("错误", task.errorMessage()));
        }
        page.addView(meta);

        Button external = actionButton("用其他应用打开", new View.OnClickListener() {
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
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = pageLayout();
        scroll.addView(page);
        page.addView(backHeader("设置", "同步设置", "home"));

        LinearLayout target = card();
        target.addView(title("接收端服务", 20));
        target.addView(label(networkLabel(), 13, "#6E665A"));
        target.addView(label(targetUrl, 14, "#1F332F"));
        Button edit = smallButton("修改接收端地址");
        edit.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                editTarget();
            }
        });
        target.addView(edit);
        page.addView(target);

        LinearLayout maintenance = card();
        maintenance.addView(title("本机相册", 20));
        maintenance.addView(label(scanMessage, 13, "#6B6257"));
        Button rescan = actionButton(scanning ? "扫描中..." : "重新扫描", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                scanMedia();
            }
        });
        rescan.setEnabled(!scanning);
        maintenance.addView(rescan);
        page.addView(maintenance);

        LinearLayout about = card();
        about.addView(title("版本", 20));
        about.addView(label(appVersionText(), 13, "#6B6257"));
        page.addView(about);
        return scroll;
    }

    private View homeHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.addView(label("图库自动同步", 12, "#7E7565"));
        copy.addView(title("Android Sync", 30));
        header.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button settings = smallButton("设置");
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
        TextView back = textButton("‹", "#FFFFFF", "#182B28");
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
        header.addView(back, new LinearLayout.LayoutParams(dp(44), dp(44)));
        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.setPadding(dp(12), 0, 0, 0);
        copy.addView(label(labelText, 12, "#7E7565"));
        copy.addView(title(titleText, 28));
        header.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        return header;
    }

    private View recentGrid(List<SyncTask> tasks) {
        LinearLayout grid = card();
        grid.setPadding(dp(10), dp(10), dp(10), dp(10));
        if (tasks.isEmpty()) {
            grid.addView(label("还没有任务", 14, "#6B6257"));
            return grid;
        }
        int width = getResources().getDisplayMetrics().widthPixels;
        final int columns = 10;
        final int gap = dp(4);
        final int cellSize = Math.max(dp(24), (width - dp(40) - dp(20) - gap * (columns - 1)) / columns);
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
        border.setColor(color("#F7F5EF"));
        border.setCornerRadius(dp(8));
        border.setStroke(dp(2), statusBorderColor(task.status()));
        tile.setBackground(border);
        tile.setPadding(dp(2), dp(2), dp(2), dp(2));
        tile.addView(thumbnail(task), new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        TextView strip = new TextView(this);
        strip.setBackgroundColor(statusBorderColor(task.status()));
        strip.setText(task.status() == SyncStatus.UPLOADING ? "..." : "");
        strip.setTextColor(Color.WHITE);
        strip.setGravity(Gravity.CENTER);
        strip.setTextSize(8);
        FrameLayout.LayoutParams stripParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(5));
        stripParams.gravity = Gravity.BOTTOM;
        tile.addView(strip, stripParams);
        return tile;
    }

    private boolean shouldLoadMore(ScrollView scroll) {
        if (queueAutoLoading || !"queue".equals(screen)) {
            return false;
        }
        TaskWindow window = queue.window(filter, queueVisibleLimit);
        if (!window.hasMore() || scroll.getChildCount() == 0) {
            return false;
        }
        View child = scroll.getChildAt(0);
        int distanceToBottom = child.getBottom() - (scroll.getHeight() + scroll.getScrollY());
        return distanceToBottom < dp(220);
    }

    private void loadPreviewAsync(final ImageView image, final TextView loading, final String mediaUri) {
        image.setTag(mediaUri);
        thumbnailExecutor.execute(new Runnable() {
            @Override
            public void run() {
                final Bitmap bitmap = loadPreviewBitmap(mediaUri);
                mainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        if (!mediaUri.equals(image.getTag())) {
                            return;
                        }
                        if (bitmap == null) {
                            loading.setText("无法加载预览");
                            return;
                        }
                        image.setImageBitmap(bitmap);
                        loading.setVisibility(View.GONE);
                    }
                });
            }
        });
    }

    private Bitmap loadPreviewBitmap(String mediaUri) {
        if (Build.VERSION.SDK_INT < 29) {
            return null;
        }
        try {
            return getContentResolver().loadThumbnail(Uri.parse(mediaUri), new Size(dp(1200), dp(1200)), null);
        } catch (Exception ignored) {
            return null;
        }
    }

    private View metaRow(String name, String value) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(0, dp(8), 0, 0);
        TextView key = label(name, 13, "#7C7367");
        TextView val = label(value == null || value.length() == 0 ? "-" : value, 13, "#182B28");
        val.setGravity(Gravity.RIGHT);
        row.addView(key, new LinearLayout.LayoutParams(dp(86), ViewGroup.LayoutParams.WRAP_CONTENT));
        row.addView(val, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        return row;
    }

    private LinearLayout.LayoutParams paddedTextParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(dp(16), dp(10), dp(16), 0);
        return params;
    }

    private View targetCard() {
        LinearLayout card = card();
        card.setOrientation(LinearLayout.VERTICAL);
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        TextView icon = icon("NAS");
        row.addView(icon, new LinearLayout.LayoutParams(dp(54), dp(54)));
        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.setPadding(dp(12), 0, 0, 0);
        copy.addView(label(networkLabel(), 13, "#6E665A"));
        copy.addView(label(targetUrl, 14, "#1F332F"));
        row.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button edit = smallButton("编辑");
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
        LinearLayout card = card();
        card.addView(statRow("总数", String.valueOf(summary.total()), "完成", String.valueOf(summary.done()), "容量", formatBytes(summary.totalBytes())));
        if (summary.failed() > 0) {
            Button retry = smallButton("重试失败项");
            retry.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    retryFailed();
                }
            });
            card.addView(retry);
        }
        return card;
    }

    private View filterStrip() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.addView(filterButton("all", "全部"), weightParams());
        row.addView(filterButton("photo", "照片"), weightParams());
        row.addView(filterButton("video", "视频"), weightParams());
        row.addView(filterButton("failed", "失败"), weightParams());
        return row;
    }

    private Button filterButton(final String value, String text) {
        Button button = smallButton(text);
        button.setTextColor(value.equals(filter) ? Color.WHITE : color("#2F3D38"));
        button.setBackground(value.equals(filter)
                ? rounded("#2F6B5F", "#2F6B5F", 0, 12)
                : rounded("#E9E2D5", "#DDD3C4", 1, 12));
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
        container.addView(taskList(window.visibleTasks(), true));
        if (window.hasMore()) {
            TextView hint = label("继续向下滑动加载后续 " + window.hiddenCount() + " 条", 12, "#7C7367");
            hint.setGravity(Gravity.CENTER);
            hint.setPadding(0, dp(10), 0, dp(18));
            container.addView(hint);
        }
        return container;
    }

    private View taskList(List<SyncTask> tasks, boolean showEmpty) {
        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        if (tasks.isEmpty() && showEmpty) {
            LinearLayout empty = card();
            empty.addView(label("当前筛选没有任务", 15, "#6B6257"));
            list.addView(empty);
            return list;
        }
        for (SyncTask task : tasks) {
            list.addView(taskRow(task));
        }
        return list;
    }

    private View taskRow(final SyncTask task) {
        LinearLayout row = card();
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);

        row.addView(thumbnail(task), new LinearLayout.LayoutParams(dp(54), dp(54)));

        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.setPadding(dp(12), 0, 0, 0);
        copy.addView(label(task.media().displayName(), 15, "#182B28"));
        copy.addView(label(formatBytes(task.media().sizeBytes()) + " · " + statusText(task), 12, "#786F63"));
        if (task.status() == SyncStatus.UPLOADING) {
            ProgressBar bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
            bar.setIndeterminate(true);
            copy.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(18)));
        }
        if (task.status() == SyncStatus.FAILED && task.errorMessage() != null) {
            copy.addView(label(task.errorMessage(), 12, "#A54135"));
        }
        row.addView(copy, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        if (task.status() == SyncStatus.FAILED) {
            Button retry = smallButton("重试");
            retry.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    queue.retry(task.id());
                    render();
                }
            });
            row.addView(retry);
        }
        row.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                selectedTaskId = task.id();
                screen = "detail";
                render();
            }
        });
        return row;
    }

    private View thumbnail(SyncTask task) {
        final FrameLayout frame = new FrameLayout(this);
        frame.setBackgroundColor(color("#D9D0C2"));

        ImageView image = new ImageView(this);
        image.setScaleType(ImageView.ScaleType.CENTER_CROP);
        image.setContentDescription(task.media().displayName());
        frame.addView(image, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        final TextView placeholder = icon(task.media().isVideo() ? "VID" : "IMG");
        frame.addView(placeholder, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        final String mediaUri = task.media().uri();
        image.setTag(mediaUri);
        loadThumbnailAsync(image, placeholder, mediaUri);
        return frame;
    }

    private void loadThumbnailAsync(final ImageView image, final TextView placeholder, final String mediaUri) {
        thumbnailExecutor.execute(new Runnable() {
            @Override
            public void run() {
                final Bitmap bitmap = loadThumbnailBitmap(mediaUri);
                if (bitmap == null) {
                    return;
                }
                mainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        if (!mediaUri.equals(image.getTag())) {
                            return;
                        }
                        image.setImageBitmap(bitmap);
                        placeholder.setVisibility(View.GONE);
                    }
                });
            }
        });
    }

    private Bitmap loadThumbnailBitmap(String mediaUri) {
        if (Build.VERSION.SDK_INT < 29) {
            return null;
        }
        try {
            return getContentResolver().loadThumbnail(Uri.parse(mediaUri), new Size(dp(96), dp(96)), null);
        } catch (Exception ignored) {
            return null;
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
        nav.setPadding(dp(18), dp(8), dp(18), dp(12));
        nav.setGravity(Gravity.CENTER);
        nav.setBackgroundColor(color("#EFE8DA"));
        nav.addView(navButton("首页", "home"), weightParams());
        nav.addView(navButton("队列", "queue"), weightParams());
        return nav;
    }

    private Button navButton(String text, final String nextScreen) {
        Button button = smallButton(text);
        button.setTextColor(nextScreen.equals(navSelection()) ? Color.WHITE : color("#2E3B37"));
        button.setBackground(nextScreen.equals(navSelection())
                ? rounded("#182B28", "#182B28", 0, 14)
                : rounded("#E4DAC9", "#D8CCB9", 1, 14));
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

    private LinearLayout pageLayout() {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(20), statusBarHeight() + dp(18), dp(20), dp(28));
        return page;
    }

    private LinearLayout card() {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(14), dp(16), dp(14));
        card.setBackground(rounded("#FFFFFF", "#E8E0D4", 1, 12));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(8), 0, dp(8));
        card.setLayoutParams(params);
        return card;
    }

    private TextView title(String text, int sp) {
        TextView view = label(text, sp, "#182B28");
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        return view;
    }

    private TextView sectionHeader(String text) {
        TextView view = label(text, 16, "#2F3D38");
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(0, dp(12), 0, dp(2));
        return view;
    }

    private TextView label(String text, int sp, String color) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(sp);
        view.setTextColor(color(color));
        view.setIncludeFontPadding(true);
        return view;
    }

    private TextView icon(String text) {
        TextView view = label(text, 13, "#FFFFFF");
        view.setGravity(Gravity.CENTER);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setBackground(rounded("#2F6B5F", "#2F6B5F", 0, 12));
        return view;
    }

    private Button actionButton(String text, View.OnClickListener listener) {
        Button button = smallButton(text);
        button.setTextColor(Color.WHITE);
        button.setBackground(rounded("#182B28", "#182B28", 0, 12));
        button.setOnClickListener(listener);
        return button;
    }

    private Button smallButton(String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setTextSize(13);
        button.setTextColor(color("#2E3B37"));
        button.setAllCaps(false);
        button.setMinHeight(dp(40));
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setBackground(rounded("#EEE7DB", "#DDD3C4", 1, 12));
        return button;
    }

    private TextView textButton(String text, String textColor, String backgroundColor) {
        TextView view = label(text, 14, textColor);
        view.setGravity(Gravity.CENTER);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(dp(14), 0, dp(14), 0);
        view.setBackground(rounded(backgroundColor, backgroundColor, 0, 21));
        view.setClickable(true);
        view.setFocusable(true);
        return view;
    }

    private View statRow(String aLabel, String aValue, String bLabel, String bValue, String cLabel, String cValue) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(0, dp(12), 0, 0);
        row.addView(stat(aLabel, aValue), weightParams());
        row.addView(stat(bLabel, bValue), weightParams());
        row.addView(stat(cLabel, cValue), weightParams());
        return row;
    }

    private View stat(String label, String value) {
        LinearLayout item = new LinearLayout(this);
        item.setOrientation(LinearLayout.VERTICAL);
        item.setGravity(Gravity.CENTER);
        item.addView(label(value, 18, "#182B28"));
        item.addView(label(label, 11, "#7C7367"));
        return item;
    }

    private LinearLayout.LayoutParams weightParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        params.setMargins(dp(4), 0, dp(4), 0);
        return params;
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
                return color("#B8AEA1");
            case UPLOADING:
                return color("#2F6B5F");
            case DONE:
                return color("#3D7A46");
            case FAILED:
                return color("#A54135");
            default:
                return color("#B8AEA1");
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

    private String formatBytes(long bytes) {
        DecimalFormat df = new DecimalFormat("0.#");
        if (bytes >= 1024L * 1024L * 1024L) {
            return df.format(bytes / 1024f / 1024f / 1024f) + " GB";
        }
        if (bytes >= 1024L * 1024L) {
            return df.format(bytes / 1024f / 1024f) + " MB";
        }
        if (bytes >= 1024L) {
            return df.format(bytes / 1024f) + " KB";
        }
        return bytes + " B";
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

    private int color(String value) {
        return Color.parseColor(value);
    }

    private GradientDrawable rounded(String fillColor, String strokeColor, int strokeDp, int radiusDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color(fillColor));
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeDp > 0) {
            drawable.setStroke(dp(strokeDp), color(strokeColor));
        }
        return drawable;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private int statusBarHeight() {
        int resourceId = getResources().getIdentifier("status_bar_height", "dimen", "android");
        if (resourceId <= 0) {
            return 0;
        }
        return getResources().getDimensionPixelSize(resourceId);
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
