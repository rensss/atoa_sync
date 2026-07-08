// android/src/main/java/com/androidsync/app/ui/TransferCardView.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.androidsync.app.core.SyncStatus;
import com.androidsync.app.core.SyncTask;

import java.util.List;

/**
 * 传输态卡片行：渐变进度卡 + 今日统计卡 + 失败横幅 + 可展开逐文件列表。
 * 所有 showXxx 只操作已建 View，由调用方保证 UI 线程调用。
 */
public final class TransferCardView {
    public interface RetryHandler {
        void retry(String taskId);
    }

    private final Activity activity;
    private final Widgets widgets;
    private final RetryHandler retryHandler;

    private LinearLayout root;
    private TextView failureBanner;
    private LinearLayout progressCard;
    private TextView progressText;
    private ProgressBar progressBar;
    private TextView statsText;
    private LinearLayout expandList;
    private boolean expanded;

    public TransferCardView(Activity activity, Widgets widgets, RetryHandler retryHandler) {
        this.activity = activity;
        this.widgets = widgets;
        this.retryHandler = retryHandler;
    }

    public View build() {
        root = new LinearLayout(activity);
        root.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams rootParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        rootParams.setMargins(0, widgets.dp(Theme.SPACE_S), 0, widgets.dp(Theme.SPACE_S));
        root.setLayoutParams(rootParams);

        failureBanner = widgets.label("", 13, Theme.STATUS_FAILED);
        failureBanner.setPadding(widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_S), widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_S));
        GradientDrawable failBg = new GradientDrawable();
        failBg.setColor(widgets.color("#33FF5F57"));
        failBg.setCornerRadius(widgets.dp(Theme.RADIUS_S));
        failureBanner.setBackground(failBg);
        failureBanner.setVisibility(View.GONE);
        LinearLayout.LayoutParams bannerParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        bannerParams.setMargins(0, 0, 0, widgets.dp(Theme.SPACE_S));
        root.addView(failureBanner, bannerParams);

        LinearLayout row = new LinearLayout(activity);
        row.setOrientation(LinearLayout.HORIZONTAL);

        progressCard = new LinearLayout(activity);
        progressCard.setOrientation(LinearLayout.VERTICAL);
        progressCard.setPadding(widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_M));
        GradientDrawable gradient = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[] { widgets.color(Theme.GRADIENT_START), widgets.color(Theme.GRADIENT_END) });
        gradient.setCornerRadius(widgets.dp(Theme.RADIUS_L));
        progressCard.setBackground(gradient);
        progressText = widgets.label("接收中", 14, "#FFFFFF");
        progressCard.addView(progressText);
        progressBar = new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
        LinearLayout.LayoutParams barParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(6));
        barParams.setMargins(0, widgets.dp(Theme.SPACE_S), 0, 0);
        progressCard.addView(progressBar, barParams);
        progressCard.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                expanded = !expanded;
                expandList.setVisibility(expanded && expandList.getChildCount() > 0 ? View.VISIBLE : View.GONE);
            }
        });
        LinearLayout.LayoutParams progressParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        progressParams.setMargins(0, 0, widgets.dp(Theme.SPACE_S), 0);
        row.addView(progressCard, progressParams);

        LinearLayout statsCard = widgets.card();
        statsCard.setBackground(widgets.rounded(Theme.BG_RAISED, Theme.STROKE, 1, Theme.RADIUS_L));
        statsText = widgets.label("今天已同步 0 项", 12, Theme.TEXT_SECONDARY);
        statsCard.addView(statsText);
        row.addView(statsCard, new LinearLayout.LayoutParams(widgets.dp(120), ViewGroup.LayoutParams.MATCH_PARENT));
        root.addView(row);

        expandList = new LinearLayout(activity);
        expandList.setOrientation(LinearLayout.VERTICAL);
        expandList.setVisibility(View.GONE);
        LinearLayout.LayoutParams expandParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        expandParams.setMargins(0, widgets.dp(Theme.SPACE_S), 0, 0);
        root.addView(expandList, expandParams);

        root.setVisibility(View.GONE);
        return root;
    }

    public void showProgress(int done, int total, long bytesRemaining, String speedText) {
        root.setVisibility(View.VISIBLE);
        String text = "接收中 " + done + "/" + total + " · 剩 " + Widgets.formatBytes(bytesRemaining);
        if (speedText != null) {
            text = text + " · " + speedText;
        }
        progressText.setText(text);
        progressBar.setMax(Math.max(1, total));
        progressBar.setProgress(done);
    }

    public void showTodayStats(int count, long bytes) {
        statsText.setText("今天已同步 " + count + " 项 · " + Widgets.formatBytes(bytes));
    }

    public void showFailure(String message) {
        root.setVisibility(View.VISIBLE);
        failureBanner.setText(message);
        failureBanner.setVisibility(View.VISIBLE);
    }

    public void clearFailure() {
        failureBanner.setVisibility(View.GONE);
    }

    public void bindTasks(List<SyncTask> active) {
        expandList.removeAllViews();
        for (final SyncTask task : active) {
            LinearLayout item = new LinearLayout(activity);
            item.setOrientation(LinearLayout.HORIZONTAL);
            item.setGravity(Gravity.CENTER_VERTICAL);
            item.setPadding(widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_S), widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_S));
            item.setBackground(widgets.rounded(Theme.BG_RAISED, Theme.STROKE, 1, Theme.RADIUS_S));
            LinearLayout.LayoutParams itemParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            itemParams.setMargins(0, widgets.dp(2), 0, widgets.dp(2));
            item.setLayoutParams(itemParams);

            TextView name = widgets.label(task.media().displayName(), 13, Theme.TEXT_PRIMARY);
            item.addView(name, widgets.weightParams());

            boolean failed = task.status() == SyncStatus.FAILED;
            TextView state = widgets.label(statusText(task.status()), 12,
                    failed ? Theme.STATUS_FAILED : Theme.TEXT_SECONDARY);
            item.addView(state);

            if (failed) {
                Button retry = widgets.smallButton("重试");
                final String taskId = task.id();
                retry.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View view) {
                        retryHandler.retry(taskId);
                    }
                });
                item.addView(retry);
            }
            expandList.addView(item);
        }
        if (!expanded || expandList.getChildCount() == 0) {
            expandList.setVisibility(View.GONE);
        }
    }

    public void hide() {
        root.setVisibility(View.GONE);
        expanded = false;
        expandList.setVisibility(View.GONE);
    }

    private static String statusText(SyncStatus status) {
        switch (status) {
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
}
