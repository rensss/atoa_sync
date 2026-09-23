package com.androidsync.app.ui;

import android.app.Activity;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.androidsync.app.R;

/** Compact, tappable transfer summary on the media library page. */
public final class TransferCardView {
    public interface DetailsHandler {
        void open();
    }

    private final Activity activity;
    private final Widgets widgets;
    private final DetailsHandler detailsHandler;

    private LinearLayout root;
    private LinearLayout progressCard;
    private TextView failureBanner;
    private TextView progressText;
    private ProgressBar progressBar;
    private TextView statsText;
    private int failureGeneration;

    public TransferCardView(Activity activity, Widgets widgets, DetailsHandler detailsHandler) {
        this.activity = activity;
        this.widgets = widgets;
        this.detailsHandler = detailsHandler;
    }

    public View build() {
        root = new LinearLayout(activity);
        root.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams rootParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        rootParams.setMargins(0, widgets.dp(Theme.SPACE_S), 0, widgets.dp(Theme.SPACE_S));
        root.setLayoutParams(rootParams);

        failureBanner = widgets.label("", 13, Theme.STATUS_FAILED);
        failureBanner.setPadding(widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_S),
                widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_S));
        GradientDrawable failBackground = widgets.rounded("#333B2326", Theme.STATUS_FAILED, 1, Theme.RADIUS_S);
        failureBanner.setBackground(failBackground);
        failureBanner.setVisibility(View.GONE);
        LinearLayout.LayoutParams bannerParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        bannerParams.bottomMargin = widgets.dp(Theme.SPACE_S);
        root.addView(failureBanner, bannerParams);

        progressCard = new LinearLayout(activity);
        progressCard.setOrientation(LinearLayout.VERTICAL);
        progressCard.setPadding(widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_M),
                widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_M));
        progressCard.setMinimumHeight(widgets.dp(88));
        progressCard.setBackground(widgets.clickableSurface());
        progressCard.setClickable(true);
        progressCard.setFocusable(true);
        progressCard.setContentDescription("传输状态，点击查看详细任务");
        progressCard.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (detailsHandler != null) {
                    detailsHandler.open();
                }
            }
        });

        LinearLayout heading = new LinearLayout(activity);
        heading.setOrientation(LinearLayout.HORIZONTAL);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        ImageView icon = new ImageView(activity);
        icon.setImageResource(R.drawable.ic_sync);
        icon.setImageTintList(android.content.res.ColorStateList.valueOf(widgets.color(Theme.ACCENT)));
        LinearLayout.LayoutParams iconParams = new LinearLayout.LayoutParams(widgets.dp(22), widgets.dp(22));
        iconParams.rightMargin = widgets.dp(Theme.SPACE_S);
        heading.addView(icon, iconParams);
        progressText = widgets.label("传输进行中", 14, Theme.TEXT_PRIMARY);
        progressText.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        heading.addView(progressText, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView actionHint = widgets.label("详情", 12, Theme.TEXT_SECONDARY);
        heading.addView(actionHint);
        progressCard.addView(heading);

        progressBar = new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setProgressTintList(android.content.res.ColorStateList.valueOf(widgets.color(Theme.ACCENT)));
        LinearLayout.LayoutParams barParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(4));
        barParams.topMargin = widgets.dp(Theme.SPACE_S);
        progressCard.addView(progressBar, barParams);

        statsText = widgets.label("今天已同步 0 项", 12, Theme.TEXT_SECONDARY);
        LinearLayout.LayoutParams statsParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        statsParams.topMargin = widgets.dp(Theme.SPACE_S);
        progressCard.addView(statsText, statsParams);
        root.addView(progressCard);

        root.setVisibility(View.GONE);
        return root;
    }

    public void showProgress(int done, int total, long bytesRemaining, String speedText, boolean runActive, int failed) {
        root.setVisibility(View.VISIBLE);
        String state = runActive ? "接收中" : (failed > 0 ? "有失败项" : "同步已完成");
        String text = state + " " + done + "/" + total + " · 剩 " + Widgets.formatBytes(bytesRemaining);
        if (speedText != null) {
            text += " · " + speedText;
        }
        progressText.setText(text);
        progressBar.setMax(Math.max(1, total));
        progressBar.setProgress(done);
        progressCard.setContentDescription(state + "，" + done + " 项已完成，共 " + total + " 项，点击查看传输详情");
    }

    public void showTodayStats(int count, long bytes) {
        statsText.setText("今天已同步 " + count + " 项 · " + Widgets.formatBytes(bytes));
    }

    public void showFailure(String message) {
        root.setVisibility(View.VISIBLE);
        failureBanner.setText(message);
        failureBanner.setVisibility(View.VISIBLE);
        final int generation = ++failureGeneration;
        failureBanner.postDelayed(new Runnable() {
            @Override
            public void run() {
                if (generation == failureGeneration && failureBanner != null) {
                    failureBanner.setVisibility(View.GONE);
                }
            }
        }, 5000L);
    }

    public void clearFailure() {
        failureGeneration++;
        if (failureBanner != null) {
            failureBanner.setVisibility(View.GONE);
        }
    }

    public void showStopping() {
        if (progressText != null) {
            progressText.setText("正在停止…");
        }
    }

    public void hide() {
        if (root != null) {
            root.setVisibility(View.GONE);
        }
    }
}
