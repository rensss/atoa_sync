package com.androidsync.app.ui;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.GridView;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.androidsync.app.android.MediaStoreScanner;
import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncStatus;

import java.util.List;
import java.util.Map;
import java.util.Set;

/** Media library page with in-place album filtering and a recycling thumbnail grid. */
public final class LibraryPageView {
    public interface LibraryHost {
        List<MediaStoreScanner.Album> whitelistAlbums();
        Set<String> activeChipFilter();
        void toggleChip(String bucketId);
        void openAlbumPicker();
        List<MediaItem> visibleItems();
        Map<String, SyncStatus> statusByStableId();
        void openPreview(MediaItem item);
        void startConfirm();
        View transferCard();
    }

    private final Activity activity;
    private final Widgets widgets;
    private final ThumbnailLoader thumbnails;

    private HorizontalScrollView chipScroll;
    private LinearLayout chipRow;
    private GridView grid;
    private TextView visibleCount;
    private MediaGridAdapter adapter;

    public LibraryPageView(Activity activity, Widgets widgets, ThumbnailLoader thumbnails) {
        this.activity = activity;
        this.widgets = widgets;
        this.thumbnails = thumbnails;
    }

    public View build(final LibraryHost host) {
        LinearLayout page = new LinearLayout(activity);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(widgets.color(Theme.BG));
        page.setPadding(widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_M),
                widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_S));

        LinearLayout heading = new LinearLayout(activity);
        heading.setOrientation(LinearLayout.HORIZONTAL);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        TextView title = widgets.title("媒体库", 23);
        heading.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        List<MediaItem> visibleItems = host.visibleItems();
        visibleCount = widgets.label(visibleItems.size() + " 项", 13, Theme.TEXT_SECONDARY);
        heading.addView(visibleCount);
        page.addView(heading);
        page.addView(widgets.label("浏览本机照片与视频", 12, Theme.TEXT_MUTED));

        chipScroll = new HorizontalScrollView(activity);
        chipScroll.setHorizontalScrollBarEnabled(false);
        chipScroll.setClipToPadding(false);
        chipRow = new LinearLayout(activity);
        chipRow.setOrientation(LinearLayout.HORIZONTAL);
        chipScroll.addView(chipRow, new HorizontalScrollView.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        rebuildChipButtons(host);
        LinearLayout.LayoutParams chipParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        chipParams.topMargin = widgets.dp(Theme.SPACE_S);
        chipParams.bottomMargin = widgets.dp(Theme.SPACE_XS);
        page.addView(chipScroll, chipParams);

        page.addView(host.transferCard());
        page.addView(buildGridArea(host, visibleItems), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        return page;
    }

    public int firstVisiblePosition() {
        return grid == null ? 0 : grid.getFirstVisiblePosition();
    }

    public int firstChildTop() {
        if (grid == null || grid.getChildCount() == 0) {
            return 0;
        }
        View firstChild = grid.getChildAt(0);
        return firstChild == null ? 0 : firstChild.getTop();
    }

    public void restorePosition(int firstVisiblePosition, int firstChildTop) {
        if (grid != null && adapter != null) {
            grid.setSelectionFromTop(adapter.clampPosition(firstVisiblePosition), firstChildTop);
        }
    }

    public boolean canCaptureViewport() {
        return grid != null && LibraryViewportPolicy.shouldCapture(grid.isLaidOut(), grid.getChildCount());
    }

    public void replaceStatuses(Map<String, SyncStatus> statuses) {
        if (adapter != null) {
            adapter.replaceStatuses(statuses);
        }
    }

    private void rebuildChipButtons(final LibraryHost host) {
        chipRow.removeAllViews();
        Set<String> active = host.activeChipFilter();
        for (final MediaStoreScanner.Album album : host.whitelistAlbums()) {
            TextView chip = widgets.chip(
                    album.name + " · " + album.count,
                    active.contains(album.bucketId),
                    new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            updateFilter(host, album.bucketId);
                        }
                    });
            addChip(chip);
        }

        Button manage = widgets.secondaryButton("管理相册", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.openAlbumPicker();
            }
        });
        manage.setTextSize(13);
        addChip(manage);
    }

    private void addChip(View chip) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, 0, widgets.dp(Theme.SPACE_S), 0);
        chipRow.addView(chip, params);
    }

    private void updateFilter(final LibraryHost host, String bucketId) {
        final int firstPosition = firstVisiblePosition();
        final int firstTop = firstChildTop();
        final int chipOffset = chipScroll.getScrollX();
        host.toggleChip(bucketId);
        List<MediaItem> visible = host.visibleItems();
        adapter.replaceItems(visible);
        adapter.replaceStatuses(host.statusByStableId());
        visibleCount.setText(visible.size() + " 项");
        grid.setSelectionFromTop(adapter.clampPosition(firstPosition), firstTop);
        rebuildChipButtons(host);
        chipScroll.post(new Runnable() {
            @Override
            public void run() {
                chipScroll.scrollTo(chipOffset, 0);
            }
        });
    }

    private View buildGridArea(final LibraryHost host, List<MediaItem> visibleItems) {
        FrameLayout area = new FrameLayout(activity);
        TextView empty = widgets.label("没有可显示的照片或视频\n请检查媒体权限和相册筛选。", 14, Theme.TEXT_SECONDARY);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(widgets.dp(Theme.SPACE_XL), widgets.dp(Theme.SPACE_L),
                widgets.dp(Theme.SPACE_XL), widgets.dp(Theme.SPACE_L));
        area.addView(empty, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        grid = new GridView(activity);
        grid.setNumColumns(3);
        grid.setHorizontalSpacing(widgets.dp(2));
        grid.setVerticalSpacing(widgets.dp(2));
        grid.setStretchMode(GridView.STRETCH_COLUMN_WIDTH);
        grid.setSelector(new ColorDrawable(Color.TRANSPARENT));
        grid.setCacheColorHint(widgets.color(Theme.BG));
        grid.setClipToPadding(false);
        grid.setPadding(0, 0, 0, widgets.dp(88));
        grid.setVerticalScrollBarEnabled(false);
        adapter = new MediaGridAdapter(activity, widgets, thumbnails, new MediaGridAdapter.ItemClickListener() {
            @Override
            public void onItemClick(MediaItem item) {
                host.openPreview(item);
            }
        });
        adapter.replaceItems(visibleItems);
        adapter.replaceStatuses(host.statusByStableId());
        grid.setAdapter(adapter);
        grid.setEmptyView(empty);
        area.addView(grid, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        Button sync = widgets.primaryButton("同步", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.startConfirm();
            }
        });
        FrameLayout.LayoutParams syncParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        syncParams.gravity = Gravity.BOTTOM | Gravity.END;
        syncParams.setMargins(0, 0, widgets.dp(Theme.SPACE_L), widgets.dp(Theme.SPACE_L));
        area.addView(sync, syncParams);
        return area;
    }
}
