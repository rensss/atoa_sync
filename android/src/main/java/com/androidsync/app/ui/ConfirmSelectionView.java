// android/src/main/java/com/androidsync/app/ui/ConfirmSelectionView.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

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
        page.setPadding(widgets.dp(Theme.SPACE_L), widgets.statusBarHeight() + widgets.dp(Theme.SPACE_M),
                widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_M));

        page.addView(widgets.label("待传 " + pending.size() + " 项 · 点击排除", 13, Theme.TEXT_SECONDARY));

        final Button confirm = widgets.actionButton("", null);

        GridLayout grid = new GridLayout(activity);
        grid.setColumnCount(3);
        int cellSize = (activity.getResources().getDisplayMetrics().widthPixels
                - widgets.dp(Theme.SPACE_L) * 2) / 3 - widgets.dp(2);
        for (final MediaItem item : pending) {
            final FrameLayout cell = new FrameLayout(activity);
            GridLayout.LayoutParams params = new GridLayout.LayoutParams();
            params.width = cellSize;
            params.height = cellSize;
            params.setMargins(widgets.dp(1), widgets.dp(1), widgets.dp(1), widgets.dp(1));
            ImageView image = new ImageView(activity);
            image.setScaleType(ImageView.ScaleType.CENTER_CROP);
            image.setBackgroundColor(widgets.color(Theme.BG_RAISED));
            TextView placeholder = widgets.label("…", 12, Theme.TEXT_SECONDARY);
            placeholder.setGravity(Gravity.CENTER);
            cell.addView(image, new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
            cell.addView(placeholder, new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
            final TextView mark = widgets.label("✕", 18, Theme.TEXT_PRIMARY);
            mark.setGravity(Gravity.CENTER);
            boolean off = excluded.contains(item.stableId());
            mark.setVisibility(off ? View.VISIBLE : View.GONE);
            cell.setAlpha(off ? 0.35f : 1f);
            cell.addView(mark);
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
                    cell.setAlpha(nowOff ? 0.35f : 1f);
                    mark.setVisibility(nowOff ? View.VISIBLE : View.GONE);
                    long bytes = 0L;
                    int count = 0;
                    for (MediaItem m : pending) {
                        if (!excluded.contains(m.stableId())) {
                            count++;
                            bytes += m.sizeBytes();
                        }
                    }
                    confirm.setText("开始同步（" + count + " 项 · " + Widgets.formatBytes(bytes) + "）");
                    confirm.setEnabled(count > 0);
                    host.onSelectionChanged(count, bytes);
                }
            });
            grid.addView(cell, params);
        }

        ScrollView scroll = new ScrollView(activity);
        scroll.addView(grid);
        page.addView(scroll, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));

        LinearLayout bar = new LinearLayout(activity);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        Button cancel = widgets.smallButton("取消");
        cancel.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.onCancel();
            }
        });
        long total = 0L;
        for (MediaItem m : pending) {
            if (!excluded.contains(m.stableId())) {
                total += m.sizeBytes();
            }
        }
        confirm.setText("开始同步（" + pending.size() + " 项 · " + Widgets.formatBytes(total) + "）");
        confirm.setEnabled(!pending.isEmpty());
        confirm.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.onConfirm();
            }
        });
        bar.addView(cancel);
        bar.addView(confirm, widgets.weightParams());
        page.addView(bar);
        return page;
    }
}
