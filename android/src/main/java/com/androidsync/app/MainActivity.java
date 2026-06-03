package com.androidsync.app;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.net.Uri;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import com.androidsync.app.android.HttpFileUploader;
import com.androidsync.app.android.MediaStoreScanner;
import com.androidsync.app.android.RemoteManifestClient;
import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.TaskWindow;

import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final int REQUEST_MEDIA_PERMISSION = 40;
    private static final int QUEUE_PAGE_SIZE = 80;
    private static final String PREFS = "android_sync";
    private static final String KEY_TARGET_URL = "target_url";

    private final SyncQueue queue = new SyncQueue();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final HttpFileUploader uploader = new HttpFileUploader();
    private final RemoteManifestClient manifestClient = new RemoteManifestClient();

    private LinearLayout root;
    private MediaStoreScanner scanner;
    private String screen = "home";
    private String filter = "all";
    private String targetUrl;
    private boolean syncing;
    private boolean scanning;
    private String scanMessage = "等待扫描";
    private int queueVisibleLimit = QUEUE_PAGE_SIZE;

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
        root.setBackgroundColor(color("#F7F5EF"));
        setContentView(root);

        FrameLayout content = new FrameLayout(this);
        root.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        if ("queue".equals(screen)) {
            content.addView(queueView());
        } else {
            content.addView(homeView());
        }
        root.addView(navBar(), new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(76)));
    }

    private View homeView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = pageLayout();
        scroll.addView(page);

        page.addView(label("图库自动同步", 12, "#7E7565"));
        page.addView(title("Android Sync", 30));
        page.addView(targetCard());

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
        page.addView(taskList(recentTasks(5), false));
        return scroll;
    }

    private View queueView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout page = pageLayout();
        scroll.addView(page);
        page.addView(label("任务队列", 12, "#7E7565"));
        page.addView(title("同步明细", 30));
        page.addView(filterStrip());
        page.addView(queueSummary());
        page.addView(queueTaskList(filteredTasks()));
        return scroll;
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
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.addView(filterButton("all", "全部"));
        row.addView(filterButton("photo", "照片"));
        row.addView(filterButton("video", "视频"));
        row.addView(filterButton("failed", "失败"));
        scroll.addView(row);
        return scroll;
    }

    private Button filterButton(final String value, String text) {
        Button button = smallButton(text);
        button.setTextColor(value.equals(filter) ? Color.WHITE : color("#2F3D38"));
        button.setBackgroundColor(value.equals(filter) ? color("#2F6B5F") : color("#E9E2D5"));
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                filter = value;
                queueVisibleLimit = QUEUE_PAGE_SIZE;
                render();
            }
        });
        return button;
    }

    private View queueTaskList(List<SyncTask> tasks) {
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        TaskWindow window = TaskWindow.from(tasks, queueVisibleLimit);
        container.addView(taskList(window.visibleTasks(), true));
        if (window.hasMore()) {
            Button more = smallButton("再显示 " + Math.min(QUEUE_PAGE_SIZE, window.hiddenCount()) + " 条，还剩 " + window.hiddenCount() + " 条");
            more.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    queueVisibleLimit += QUEUE_PAGE_SIZE;
                    render();
                }
            });
            container.addView(more);
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

        TextView thumb = icon(task.media().isVideo() ? "VID" : "IMG");
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
                openMedia(task.media());
            }
        });
        return row;
    }

    private View thumbnail(SyncTask task) {
        ImageView image = new ImageView(this);
        image.setScaleType(ImageView.ScaleType.CENTER_CROP);
        image.setBackgroundColor(color("#D9D0C2"));
        image.setContentDescription(task.media().displayName());
        try {
            image.setImageURI(Uri.parse(task.media().uri()));
        } catch (Exception ignored) {
            image.setImageDrawable(null);
        }
        return image;
    }

    private void openMedia(MediaItem media) {
        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(Uri.parse(media.uri()), media.mimeType());
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try {
            startActivity(intent);
        } catch (Exception error) {
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
        button.setTextColor(nextScreen.equals(screen) ? Color.WHITE : color("#2E3B37"));
        button.setBackgroundColor(nextScreen.equals(screen) ? color("#182B28") : color("#E4DAC9"));
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                screen = nextScreen;
                render();
            }
        });
        return button;
    }

    private List<SyncTask> filteredTasks() {
        List<SyncTask> result = new ArrayList<>();
        for (SyncTask task : queue.tasks()) {
            if ("photo".equals(filter) && task.media().isVideo()) {
                continue;
            }
            if ("video".equals(filter) && !task.media().isVideo()) {
                continue;
            }
            if ("failed".equals(filter) && task.status() != SyncStatus.FAILED) {
                continue;
            }
            result.add(task);
        }
        return result;
    }

    private List<SyncTask> recentTasks(int limit) {
        List<SyncTask> tasks = queue.tasks();
        if (tasks.size() <= limit) {
            return tasks;
        }
        return new ArrayList<>(tasks.subList(0, limit));
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
        page.setPadding(dp(20), dp(18), dp(20), dp(28));
        return page;
    }

    private LinearLayout card() {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(14), dp(16), dp(14));
        card.setBackgroundColor(Color.WHITE);
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
        view.setBackgroundColor(color("#2F6B5F"));
        return view;
    }

    private Button actionButton(String text, View.OnClickListener listener) {
        Button button = smallButton(text);
        button.setTextColor(Color.WHITE);
        button.setBackgroundColor(color("#182B28"));
        button.setOnClickListener(listener);
        return button;
    }

    private Button smallButton(String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setTextSize(13);
        button.setAllCaps(false);
        button.setMinHeight(dp(40));
        button.setPadding(dp(10), 0, dp(10), 0);
        return button;
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

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
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
