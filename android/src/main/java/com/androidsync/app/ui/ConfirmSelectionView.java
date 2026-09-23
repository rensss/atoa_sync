package com.androidsync.app.ui;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.androidsync.app.R;
import com.androidsync.app.core.MediaItem;

import java.util.List;
import java.util.Set;

public final class ConfirmSelectionView {
    public interface ConfirmHost {
        void onConfirm();
        void onCancel();
        void onSelectionChanged(int count, long bytes);
    }

    private final Activity activity;
    private final Widgets widgets;
    private final ThumbnailLoader thumbnails;

    public ConfirmSelectionView(Activity activity, Widgets widgets, ThumbnailLoader thumbnails) {
        this.activity = activity;
        this.widgets = widgets;
        this.thumbnails = thumbnails;
    }

    public View build(final List<MediaItem> pending, final Set<String> excluded, final ConfirmHost host) {
        LinearLayout page = new LinearLayout(activity);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(widgets.color(Theme.BG));
        page.setPadding(widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_M),
                widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_S));

        page.addView(widgets.title("确认本次同步", 21));
        TextView instructions = widgets.label("默认包含全部待传媒体，点击缩略图可排除", 13, Theme.TEXT_SECONDARY);
        instructions.setPadding(0, widgets.dp(Theme.SPACE_XS), 0, widgets.dp(Theme.SPACE_M));
        page.addView(instructions);

        final TextView summaryText = widgets.label("", 15, Theme.TEXT_PRIMARY);
        summaryText.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        final Button confirm = widgets.primaryButton("开始同步", null);

        GridLayout grid = new GridLayout(activity);
        grid.setColumnCount(3);
        grid.setUseDefaultMargins(false);
        int cellSize = (activity.getResources().getDisplayMetrics().widthPixels
                - widgets.dp(Theme.SPACE_L) * 2) / 3 - widgets.dp(2);
        for (final MediaItem item : pending) {
            final FrameLayout cell = new FrameLayout(activity);
            GridLayout.LayoutParams params = new GridLayout.LayoutParams();
            params.width = cellSize;
            params.height = cellSize;
            params.setMargins(widgets.dp(1), widgets.dp(1), widgets.dp(1), widgets.dp(1));
            cell.setBackground(widgets.rounded(Theme.BG_RAISED, Theme.STROKE, 1, Theme.RADIUS_L));
            cell.setClickable(true);
            cell.setFocusable(true);

            ImageView image = new ImageView(activity);
            image.setScaleType(ImageView.ScaleType.CENTER_CROP);
            image.setBackgroundColor(widgets.color(Theme.BG_RAISED));
            TextView placeholder = widgets.label("…", 12, Theme.TEXT_SECONDARY);
            placeholder.setGravity(Gravity.CENTER);
            cell.addView(image, new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
            cell.addView(placeholder, new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

            final ImageView mark = new ImageView(activity);
            mark.setImageResource(R.drawable.ic_exclude);
            mark.setImageTintList(ColorStateList.valueOf(widgets.color(Theme.STATUS_WARNING)));
            mark.setPadding(widgets.dp(Theme.SPACE_XS), widgets.dp(Theme.SPACE_XS),
                    widgets.dp(Theme.SPACE_XS), widgets.dp(Theme.SPACE_XS));
            mark.setBackground(widgets.rounded(Theme.BG_SURFACE, Theme.STROKE, 1, Theme.RADIUS_L));
            boolean off = excluded.contains(item.stableId());
            mark.setVisibility(off ? View.VISIBLE : View.GONE);
            FrameLayout.LayoutParams markParams = new FrameLayout.LayoutParams(
                    widgets.dp(32), widgets.dp(32), Gravity.RIGHT | Gravity.TOP);
            markParams.setMargins(0, widgets.dp(Theme.SPACE_S), widgets.dp(Theme.SPACE_S), 0);
            cell.addView(mark, markParams);
            cell.setAlpha(off ? 0.48f : 1f);
            cell.setContentDescription(item.displayName() + (off ? "，本次已排除" : "，本次将同步"));

            thumbnails.loadThumbnailInto(image, placeholder, item.uri(), cellSize);
            cell.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    if (excluded.contains(item.stableId())) {
                        excluded.remove(item.stableId());
                    } else {
                        excluded.add(item.stableId());
                    }
                    boolean nowOff = excluded.contains(item.stableId());
                    cell.setAlpha(nowOff ? 0.48f : 1f);
                    cell.setContentDescription(item.displayName() + (nowOff ? "，本次已排除" : "，本次将同步"));
                    mark.setVisibility(nowOff ? View.VISIBLE : View.GONE);
                    SelectionSummary summary = SelectionSummary.from(pending, excluded);
                    updateSelectionSummary(summaryText, confirm, summary);
                    host.onSelectionChanged(summary.selectedCount(), summary.selectedBytes());
                }
            });
            grid.addView(cell, params);
        }

        ScrollView scroll = new ScrollView(activity);
        scroll.setFillViewport(false);
        scroll.setClipToPadding(false);
        scroll.addView(grid);
        page.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        SelectionSummary initial = SelectionSummary.from(pending, excluded);
        updateSelectionSummary(summaryText, confirm, initial);
        LinearLayout footer = new LinearLayout(activity);
        footer.setOrientation(LinearLayout.VERTICAL);
        footer.setPadding(widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_M),
                widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_M));
        footer.setBackground(widgets.rounded(Theme.BG_SURFACE, Theme.STROKE, 1, Theme.RADIUS_L));
        TextView label = widgets.label("本次同步", 12, Theme.TEXT_MUTED);
        footer.addView(label);
        footer.addView(summaryText);

        LinearLayout actions = new LinearLayout(activity);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams actionsParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        actionsParams.setMargins(0, widgets.dp(Theme.SPACE_S), 0, 0);
        footer.addView(actions, actionsParams);

        Button cancel = widgets.secondaryButton("取消", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.onCancel();
            }
        });
        confirm.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.onConfirm();
            }
        });
        LinearLayout.LayoutParams cancelParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        cancelParams.setMargins(0, 0, widgets.dp(Theme.SPACE_S), 0);
        actions.addView(cancel, cancelParams);
        actions.addView(confirm, widgets.weightParams());
        LinearLayout.LayoutParams footerParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        footerParams.setMargins(0, widgets.dp(Theme.SPACE_M), 0, 0);
        page.addView(footer, footerParams);
        return page;
    }

    private void updateSelectionSummary(TextView summaryText, Button confirm, SelectionSummary summary) {
        summaryText.setText(summary.selectedCount() + " 项 · " + Widgets.formatBytes(summary.selectedBytes()));
        summaryText.setContentDescription(summary.selectedCount() + " 项，合计 "
                + Widgets.formatBytes(summary.selectedBytes()));
        confirm.setEnabled(summary.selectedCount() > 0);
        confirm.setAlpha(summary.selectedCount() > 0 ? 1f : 0.45f);
        confirm.setContentDescription(summary.selectedCount() > 0
                ? "开始同步 " + summary.selectedCount() + " 项"
                : "没有选中的媒体，开始同步不可用");
    }
}
