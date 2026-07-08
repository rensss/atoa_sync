// android/src/main/java/com/androidsync/app/ui/LibraryPageView.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.HorizontalScrollView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.androidsync.app.android.MediaStoreScanner;
import com.androidsync.app.core.MediaItem;

import java.util.List;
import java.util.Set;

/**
 * 深色媒体库首页：相册 chips 过滤行 + 传输卡片 + 三列缩略图网格 + 同步 FAB。
 */
public final class LibraryPageView {
    public interface LibraryHost {
        List<MediaStoreScanner.Album> whitelistAlbums();
        Set<String> activeChipFilter();
        void toggleChip(String bucketId);
        void openAlbumPicker();
        List<MediaItem> visibleItems();
        void openPreview(MediaItem item);
        void startConfirm();
        View transferCard();
    }

    private final Activity activity;
    private final Widgets widgets;
    private final ThumbnailLoader thumbnails;

    public LibraryPageView(Activity activity, Widgets widgets, ThumbnailLoader thumbnails) {
        this.activity = activity;
        this.widgets = widgets;
        this.thumbnails = thumbnails;
    }

    public View build(final LibraryHost host) {
        LinearLayout page = new LinearLayout(activity);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(widgets.color(Theme.BG));
        page.setPadding(widgets.dp(Theme.SPACE_L), widgets.statusBarHeight() + widgets.dp(Theme.SPACE_M),
                widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_S));

        page.addView(buildChips(host));
        page.addView(host.transferCard());
        page.addView(buildGridArea(host), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));
        return page;
    }

    private View buildChips(final LibraryHost host) {
        HorizontalScrollView scroll = new HorizontalScrollView(activity);
        scroll.setHorizontalScrollBarEnabled(false);
        LinearLayout chips = new LinearLayout(activity);
        chips.setOrientation(LinearLayout.HORIZONTAL);
        Set<String> active = host.activeChipFilter();
        for (final MediaStoreScanner.Album album : host.whitelistAlbums()) {
            boolean selected = active.contains(album.bucketId);
            Button chip = chipButton(album.name + " " + album.count, selected);
            chip.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    host.toggleChip(album.bucketId);
                }
            });
            chips.addView(chip);
        }
        Button manage = chipButton("管理", false);
        manage.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.openAlbumPicker();
            }
        });
        chips.addView(manage);
        scroll.addView(chips);
        return scroll;
    }

    private Button chipButton(String text, boolean selected) {
        Button chip = widgets.smallButton(text);
        chip.setTextColor(widgets.color(selected ? Theme.ACCENT : Theme.TEXT_SECONDARY));
        chip.setBackground(selected
                ? widgets.rounded("#33E8A33D", Theme.ACCENT, 1, 10)
                : widgets.rounded(Theme.BG_RAISED, Theme.STROKE, 1, 10));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, 0, widgets.dp(Theme.SPACE_S), 0);
        chip.setLayoutParams(params);
        return chip;
    }

    private View buildGridArea(final LibraryHost host) {
        FrameLayout frame = new FrameLayout(activity);

        ScrollView scroll = new ScrollView(activity);
        GridLayout grid = new GridLayout(activity);
        grid.setColumnCount(3);
        int cellSize = (activity.getResources().getDisplayMetrics().widthPixels
                - widgets.dp(Theme.SPACE_L) * 2) / 3 - widgets.dp(2);
        for (final MediaItem item : host.visibleItems()) {
            FrameLayout cell = new FrameLayout(activity);
            GridLayout.LayoutParams params = new GridLayout.LayoutParams();
            params.width = cellSize;
            params.height = cellSize;
            params.setMargins(widgets.dp(1), widgets.dp(1), widgets.dp(1), widgets.dp(1));
            ImageView image = new ImageView(activity);
            image.setScaleType(ImageView.ScaleType.CENTER_CROP);
            image.setBackgroundColor(widgets.color(Theme.BG_RAISED));
            TextView placeholder = widgets.label(item.isVideo() ? "▶" : "…", 12, Theme.TEXT_SECONDARY);
            placeholder.setGravity(Gravity.CENTER);
            cell.addView(image);
            cell.addView(placeholder);
            thumbnails.loadThumbnailInto(image, placeholder, item.uri(), cellSize);
            cell.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    host.openPreview(item);
                }
            });
            grid.addView(cell, params);
        }
        scroll.addView(grid);
        frame.addView(scroll, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

        Button fab = widgets.smallButton("⇪ 同步");
        fab.setTextColor(widgets.color("#FFFFFF"));
        fab.setBackground(widgets.rounded(Theme.ACCENT, Theme.ACCENT, 0, 20));
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.startConfirm();
            }
        });
        FrameLayout.LayoutParams fabParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, widgets.dp(48));
        fabParams.gravity = Gravity.BOTTOM | Gravity.END;
        fabParams.setMargins(0, 0, widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_L));
        frame.addView(fab, fabParams);
        return frame;
    }
}
