package com.androidsync.app.ui;

import android.app.Activity;
import android.app.Dialog;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import com.androidsync.app.R;
import com.androidsync.app.core.SyncQueue;
import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;
import com.androidsync.app.core.TaskWindow;

/** Bounded, dismissible bottom drawer for the current transfer snapshot. */
public final class TransferDetailsSheet {
    public interface Actions {
        void stop();
        void retry(String taskId);
    }

    private final Activity activity;
    private final Widgets widgets;
    private final Actions actions;

    private Dialog dialog;
    private SheetLayout sheetRoot;
    private TextView completedText;
    private TextView remainingText;
    private TextView countsText;
    private ProgressBar progressBar;
    private BoundedScrollView taskScroll;
    private LinearLayout taskList;
    private Button stopButton;
    private boolean insetsInstalled;
    private boolean stopRequested;

    public TransferDetailsSheet(Activity activity, Widgets widgets, Actions actions) {
        this.activity = activity;
        this.widgets = widgets;
        this.actions = actions;
    }

    public void show(SyncQueue.Summary summary, TaskWindow window, boolean runActive) {
        if (dialog == null) {
            createDialog();
        }
        render(new TransferSheetData(summary, window, runActive));
        if (!dialog.isShowing()) {
            dialog.show();
            configureWindow();
            if (!insetsInstalled) {
                widgets.installDialogInsets(dialog, null, sheetRoot);
                insetsInstalled = true;
            } else if (dialog.getWindow() != null) {
                dialog.getWindow().getDecorView().requestApplyInsets();
            }
        }
    }

    public void update(SyncQueue.Summary summary, TaskWindow window, boolean runActive) {
        if (isShowing()) {
            render(new TransferSheetData(summary, window, runActive));
        }
    }

    public boolean isShowing() {
        return dialog != null && dialog.isShowing();
    }

    public void showStopping() {
        if (stopButton != null && isShowing()) {
            stopRequested = true;
            stopButton.setText("正在停止…");
            stopButton.setEnabled(false);
        }
    }

    public void dismiss() {
        if (dialog != null) {
            dialog.dismiss();
        }
    }

    private void createDialog() {
        dialog = new Dialog(activity);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        dialog.setCancelable(true);
        dialog.setCanceledOnTouchOutside(true);

        int maxHeight = Math.max(1, activity.getResources().getDisplayMetrics().heightPixels * 4 / 5);
        sheetRoot = new SheetLayout(activity, maxHeight);
        sheetRoot.setOrientation(LinearLayout.VERTICAL);
        sheetRoot.setPadding(widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_S),
                widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_S));
        GradientDrawable surface = new GradientDrawable();
        surface.setColor(widgets.color(Theme.BG_SURFACE));
        float radius = widgets.dp(Theme.RADIUS_L);
        surface.setCornerRadii(new float[] { radius, radius, radius, radius, 0f, 0f, 0f, 0f });
        surface.setStroke(widgets.dp(1), widgets.color(Theme.STROKE));
        sheetRoot.setBackground(surface);

        FrameLayout dragArea = new FrameLayout(activity);
        LinearLayout.LayoutParams dragParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(32));
        View handle = new View(activity);
        handle.setBackground(widgets.rounded(Theme.TEXT_MUTED, Theme.TEXT_MUTED, 0, 3));
        FrameLayout.LayoutParams handleParams = new FrameLayout.LayoutParams(widgets.dp(36), widgets.dp(4));
        handleParams.gravity = Gravity.CENTER;
        dragArea.addView(handle, handleParams);
        dragArea.setContentDescription("向下拖动关闭传输详情");
        installDragDismiss(dragArea);
        sheetRoot.addView(dragArea, dragParams);

        LinearLayout heading = new LinearLayout(activity);
        heading.setOrientation(LinearLayout.HORIZONTAL);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        TextView title = widgets.title("传输详情", 20);
        heading.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        ImageButton close = widgets.iconButton(R.drawable.ic_close, "关闭传输详情", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                dismiss();
            }
        });
        heading.addView(close);
        sheetRoot.addView(heading);

        LinearLayout overview = widgets.card();
        completedText = widgets.title("已完成 0/0", 18);
        overview.addView(completedText);
        remainingText = widgets.label("剩余 0 B", 13, Theme.TEXT_SECONDARY);
        remainingText.setPadding(0, widgets.dp(Theme.SPACE_XS), 0, widgets.dp(Theme.SPACE_S));
        overview.addView(remainingText);
        progressBar = new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setProgressTintList(android.content.res.ColorStateList.valueOf(widgets.color(Theme.ACCENT)));
        overview.addView(progressBar, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(5)));
        countsText = widgets.label("上传中 0 · 等待 0 · 失败 0", 12, Theme.TEXT_SECONDARY);
        countsText.setPadding(0, widgets.dp(Theme.SPACE_S), 0, 0);
        overview.addView(countsText);
        sheetRoot.addView(overview);

        TextView taskHeading = widgets.sectionTitle("任务");
        sheetRoot.addView(taskHeading);
        int maxBodyHeight = Math.min(maxHeight, Math.max(widgets.dp(72), maxHeight - widgets.dp(280)));
        taskScroll = new BoundedScrollView(activity, maxBodyHeight);
        taskScroll.setFillViewport(false);
        taskScroll.setVerticalScrollBarEnabled(true);
        taskList = new LinearLayout(activity);
        taskList.setOrientation(LinearLayout.VERTICAL);
        taskScroll.addView(taskList, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        sheetRoot.addView(taskScroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        stopButton = widgets.secondaryButton("停止同步", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                actions.stop();
            }
        });
        stopButton.setTextColor(widgets.color(Theme.STATUS_FAILED));
        LinearLayout.LayoutParams stopParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        stopParams.topMargin = widgets.dp(Theme.SPACE_S);
        sheetRoot.addView(stopButton, stopParams);

        dialog.setContentView(sheetRoot);
    }

    private void configureWindow() {
        Window window = dialog.getWindow();
        if (window == null) {
            return;
        }
        window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
        WindowManager.LayoutParams attributes = window.getAttributes();
        attributes.gravity = Gravity.BOTTOM;
        attributes.width = ViewGroup.LayoutParams.MATCH_PARENT;
        attributes.height = ViewGroup.LayoutParams.WRAP_CONTENT;
        attributes.dimAmount = 0.42f;
        window.setAttributes(attributes);
        window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        window.setStatusBarColor(Color.TRANSPARENT);
        window.setNavigationBarColor(Color.TRANSPARENT);
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false);
            if (window.getInsetsController() != null) {
                window.getInsetsController().setSystemBarsAppearance(
                        0,
                        android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                                | android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS);
            }
        }
    }

    private void render(TransferSheetData data) {
        SyncQueue.Summary summary = data.summary();
        completedText.setText("已完成 " + summary.done() + "/" + summary.total());
        remainingText.setText("剩余 " + Widgets.formatBytes(data.remainingBytes()));
        countsText.setText("上传中 " + summary.uploading() + " · 等待 " + summary.waiting()
                + " · 失败 " + summary.failed());
        progressBar.setMax(Math.max(1, summary.total()));
        progressBar.setProgress(summary.done());
        stopButton.setVisibility(data.showStop() ? View.VISIBLE : View.GONE);
        if (data.showStop() && !stopRequested) {
            stopButton.setText("停止同步");
            stopButton.setEnabled(true);
        } else if (!data.showStop()) {
            stopRequested = false;
        }

        final int scrollY = taskScroll.getScrollY();
        taskList.removeAllViews();
        if (data.visibleTasks().isEmpty()) {
            TextView empty = widgets.label("当前没有待传任务。", 13, Theme.TEXT_MUTED);
            empty.setGravity(Gravity.CENTER_VERTICAL);
            empty.setMinHeight(widgets.dp(48));
            taskList.addView(empty);
        } else {
            for (SyncTask task : data.visibleTasks()) {
                taskList.addView(taskRow(task));
                taskList.addView(widgets.divider());
            }
        }
        if (data.hasMore()) {
            TextView more = widgets.label("另有 " + data.hiddenCount() + " 项未显示", 12, Theme.TEXT_SECONDARY);
            more.setGravity(Gravity.CENTER_VERTICAL);
            more.setMinHeight(widgets.dp(48));
            taskList.addView(more);
        }
        taskScroll.post(new Runnable() {
            @Override
            public void run() {
                taskScroll.scrollTo(0, scrollY);
            }
        });
    }

    private View taskRow(final SyncTask task) {
        LinearLayout row = new LinearLayout(activity);
        row.setOrientation(LinearLayout.VERTICAL);
        row.setPadding(0, widgets.dp(Theme.SPACE_S), 0, widgets.dp(Theme.SPACE_S));
        row.setMinimumHeight(widgets.dp(56));

        LinearLayout heading = new LinearLayout(activity);
        heading.setOrientation(LinearLayout.HORIZONTAL);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        TextView name = widgets.label(task.media().displayName(), 13, Theme.TEXT_PRIMARY);
        name.setMaxLines(2);
        name.setEllipsize(TextUtils.TruncateAt.END);
        name.setContentDescription(task.media().displayName());
        heading.addView(name, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView state = widgets.label(statusText(task.status()), 12, statusColor(task.status()));
        heading.addView(state);

        if (task.status() == SyncStatus.FAILED) {
            ImageButton retry = widgets.iconButton(R.drawable.ic_retry, "重试 " + task.media().displayName(),
                    new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            actions.retry(task.id());
                        }
                    });
            LinearLayout.LayoutParams retryParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            retryParams.leftMargin = widgets.dp(Theme.SPACE_S);
            heading.addView(retry, retryParams);
        }
        row.addView(heading);

        String error = task.errorMessage();
        if (task.status() == SyncStatus.FAILED && error != null && !error.trim().isEmpty()) {
            TextView errorText = widgets.label(error, 12, Theme.STATUS_FAILED);
            errorText.setMaxLines(2);
            errorText.setEllipsize(TextUtils.TruncateAt.END);
            row.addView(errorText);
        }
        return row;
    }

    private String statusText(SyncStatus status) {
        switch (status) {
            case UPLOADING:
                return "上传中";
            case DONE:
                return "已完成";
            case FAILED:
                return "失败";
            case WAITING:
            default:
                return "等待中";
        }
    }

    private String statusColor(SyncStatus status) {
        switch (status) {
            case UPLOADING:
                return Theme.ACCENT;
            case DONE:
                return Theme.STATUS_RUNNING;
            case FAILED:
                return Theme.STATUS_FAILED;
            case WAITING:
            default:
                return Theme.TEXT_SECONDARY;
        }
    }

    private void installDragDismiss(final View dragArea) {
        final float[] downY = new float[1];
        final boolean[] dragging = new boolean[1];
        dragArea.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View view, MotionEvent event) {
                switch (event.getActionMasked()) {
                    case MotionEvent.ACTION_DOWN:
                        downY[0] = event.getRawY();
                        dragging[0] = true;
                        return true;
                    case MotionEvent.ACTION_MOVE:
                        if (dragging[0]) {
                            float delta = Math.max(0f, event.getRawY() - downY[0]);
                            sheetRoot.setTranslationY(delta);
                        }
                        return true;
                    case MotionEvent.ACTION_UP:
                        if (dragging[0]) {
                            float delta = event.getRawY() - downY[0];
                            dragging[0] = false;
                            if (delta >= widgets.dp(72)) {
                                dismiss();
                            } else {
                                sheetRoot.setTranslationY(0f);
                            }
                        }
                        return true;
                    case MotionEvent.ACTION_CANCEL:
                        dragging[0] = false;
                        sheetRoot.setTranslationY(0f);
                        return true;
                    default:
                        return true;
                }
            }
        });
    }

    private static final class SheetLayout extends LinearLayout {
        private final int maxHeight;

        SheetLayout(Activity activity, int maxHeight) {
            super(activity);
            this.maxHeight = maxHeight;
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int available = MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.UNSPECIFIED
                    ? maxHeight : Math.min(maxHeight, MeasureSpec.getSize(heightMeasureSpec));
            super.onMeasure(widthMeasureSpec, MeasureSpec.makeMeasureSpec(available, MeasureSpec.AT_MOST));
        }
    }

    private static final class BoundedScrollView extends ScrollView {
        private final int maxHeight;

        BoundedScrollView(Activity activity, int maxHeight) {
            super(activity);
            this.maxHeight = maxHeight;
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int available = MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.UNSPECIFIED
                    ? maxHeight : Math.min(maxHeight, MeasureSpec.getSize(heightMeasureSpec));
            super.onMeasure(widthMeasureSpec, MeasureSpec.makeMeasureSpec(available, MeasureSpec.AT_MOST));
        }
    }
}
