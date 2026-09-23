package com.androidsync.app.ui;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.androidsync.app.R;
import com.androidsync.app.android.MediaStoreScanner;
import com.androidsync.app.core.AlbumTree;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public final class AlbumPickerView {
    public interface OnNavigateListener {
        void onNavigate(String path);
    }

    private final Activity activity;
    private final Widgets widgets;

    public AlbumPickerView(Activity activity, Widgets widgets) {
        this.activity = activity;
        this.widgets = widgets;
    }

    public View build(List<MediaStoreScanner.Album> albums, final Set<String> selected,
                      String currentPath, final OnNavigateListener onNavigate,
                      final Runnable onChanged) {
        List<AlbumTree.Album> treeAlbums = new ArrayList<>();
        for (MediaStoreScanner.Album album : albums) {
            treeAlbums.add(new AlbumTree.Album(album.bucketId, album.name, album.count, album.path));
        }
        final AlbumTree.Node root = AlbumTree.build(treeAlbums);
        final String path = AlbumTree.normalizePath(currentPath);
        AlbumTree.Node current = root.find(path);
        if (current == null) {
            current = root;
        }

        LinearLayout content = new LinearLayout(activity);
        content.setOrientation(LinearLayout.VERTICAL);
        TextView breadcrumb = widgets.label(breadcrumb(path), 13, Theme.TEXT_SECONDARY);
        breadcrumb.setPadding(widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_S),
                widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_S));
        breadcrumb.setBackground(widgets.rounded(Theme.BG_SURFACE, Theme.STROKE, 1, Theme.RADIUS_L));
        LinearLayout.LayoutParams breadcrumbParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        breadcrumbParams.setMargins(0, 0, 0, widgets.dp(Theme.SPACE_S));
        content.addView(breadcrumb, breadcrumbParams);

        LinearLayout list = new LinearLayout(activity);
        list.setOrientation(LinearLayout.VERTICAL);
        if (!path.isEmpty()) {
            TextView up = widgets.secondaryButton("‹  返回上级", null);
            up.setGravity(Gravity.CENTER_VERTICAL);
            up.setContentDescription("返回上级目录");
            up.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    int separator = path.lastIndexOf('/');
                    onNavigate.onNavigate(separator < 0 ? "" : path.substring(0, separator));
                }
            });
            LinearLayout.LayoutParams upParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            upParams.setMargins(0, 0, 0, widgets.dp(Theme.SPACE_S));
            list.addView(up, upParams);
        }

        for (AlbumTree.Album album : current.directAlbums) {
            addAlbumRow(list, current, album, selected, onChanged);
        }
        if (path.isEmpty()) {
            for (AlbumTree.Album album : current.fallbackAlbums) {
                addAlbumRow(list, current, album, selected, onChanged);
            }
        }
        for (final AlbumTree.Node child : current.children) {
            addFolderRow(list, child, selected, onNavigate, onChanged);
        }
        if (current.directAlbums.isEmpty() && current.children.isEmpty()
                && (path.isEmpty() || current.fallbackAlbums.isEmpty())) {
            TextView empty = widgets.label("此目录没有可同步的媒体", 14, Theme.TEXT_SECONDARY);
            empty.setPadding(widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_L),
                    widgets.dp(Theme.SPACE_M), widgets.dp(Theme.SPACE_L));
            list.addView(empty);
        }

        ScrollView scroll = new ScrollView(activity);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(widgets.color(Theme.BG));
        scroll.addView(list);
        content.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        return content;
    }

    private void addFolderRow(LinearLayout list, final AlbumTree.Node folder,
                              final Set<String> selected, final OnNavigateListener onNavigate,
                              final Runnable onChanged) {
        final LinearLayout row = rowSurface();
        final CheckBox box = checkBox();
        updateFolderCheckBox(box, folder, selected);
        row.addView(box, checkParams());

        final TextView name = widgets.label(folder.name, 15, Theme.TEXT_PRIMARY);
        name.setMaxLines(2);
        name.setEllipsize(TextUtils.TruncateAt.END);
        final TextView detail = widgets.label(folderDetail(folder, selected), 12, Theme.TEXT_SECONDARY);
        LinearLayout labels = new LinearLayout(activity);
        labels.setOrientation(LinearLayout.VERTICAL);
        labels.addView(name);
        labels.addView(detail);
        row.addView(labels, widgets.weightParams());

        View.OnClickListener navigate = new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                onNavigate.onNavigate(folder.path);
            }
        };
        ImageButton enter = widgets.iconButton(R.drawable.ic_folder, "进入文件夹 " + folder.name, navigate);
        row.addView(enter, new LinearLayout.LayoutParams(
                widgets.dp(Theme.MIN_TOUCH_TARGET_DP), widgets.dp(Theme.MIN_TOUCH_TARGET_DP)));
        row.setOnClickListener(navigate);
        name.setOnClickListener(navigate);
        detail.setOnClickListener(navigate);

        box.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                folder.toggle(selected);
                updateFolderCheckBox(box, folder, selected);
                detail.setText(folderDetail(folder, selected));
                onChanged.run();
            }
        });
        list.addView(row);
    }

    private void addAlbumRow(LinearLayout list, final AlbumTree.Node owner, final AlbumTree.Album album,
                             final Set<String> selected, final Runnable onChanged) {
        final LinearLayout row = rowSurface();
        final CheckBox box = checkBox();
        updateAlbumCheckBox(box, album, selected);
        row.addView(box, checkParams());
        TextView name = widgets.label(album.name, 15, Theme.TEXT_PRIMARY);
        name.setMaxLines(2);
        name.setEllipsize(TextUtils.TruncateAt.END);
        TextView detail = widgets.label(album.count + " 项", 12, Theme.TEXT_SECONDARY);
        LinearLayout labels = new LinearLayout(activity);
        labels.setOrientation(LinearLayout.VERTICAL);
        labels.addView(name);
        labels.addView(detail);
        row.addView(labels, widgets.weightParams());

        View.OnClickListener toggle = new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                owner.toggle(album, selected);
                updateAlbumCheckBox(box, album, selected);
                onChanged.run();
            }
        };
        row.setOnClickListener(toggle);
        box.setOnClickListener(toggle);
        list.addView(row);
    }

    private LinearLayout rowSurface() {
        LinearLayout row = new LinearLayout(activity);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(widgets.dp(Theme.SPACE_S), widgets.dp(Theme.SPACE_S),
                widgets.dp(Theme.SPACE_S), widgets.dp(Theme.SPACE_S));
        row.setMinimumHeight(widgets.dp(Theme.MIN_TOUCH_TARGET_DP));
        row.setBackground(widgets.clickableSurface());
        row.setFocusable(true);
        row.setClickable(true);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, 0, 0, widgets.dp(Theme.SPACE_S));
        row.setLayoutParams(params);
        return row;
    }

    private CheckBox checkBox() {
        CheckBox box = new CheckBox(activity);
        box.setButtonTintList(ColorStateList.valueOf(widgets.color(Theme.ACCENT)));
        box.setMinWidth(widgets.dp(Theme.MIN_TOUCH_TARGET_DP));
        box.setMinHeight(widgets.dp(Theme.MIN_TOUCH_TARGET_DP));
        return box;
    }

    private LinearLayout.LayoutParams checkParams() {
        return new LinearLayout.LayoutParams(
                widgets.dp(Theme.MIN_TOUCH_TARGET_DP), widgets.dp(Theme.MIN_TOUCH_TARGET_DP));
    }

    private void updateFolderCheckBox(CheckBox box, AlbumTree.Node folder, Set<String> selected) {
        AlbumTree.CheckState state = folder.checkState(selected);
        box.setChecked(state == AlbumTree.CheckState.ALL);
        box.setContentDescription(folder.name + (state == AlbumTree.CheckState.PARTIAL
                ? "，部分选择" : state == AlbumTree.CheckState.ALL ? "，已全选" : "，未选择"));
    }

    private void updateAlbumCheckBox(CheckBox box, AlbumTree.Album album, Set<String> selected) {
        boolean checked = selected.contains(album.bucketId);
        box.setChecked(checked);
        box.setContentDescription(selectionDescription(album.name, checked));
    }

    private String folderDetail(AlbumTree.Node folder, Set<String> selected) {
        AlbumTree.CheckState state = folder.checkState(selected);
        String detail = folder.totalCount + " 项";
        if (state == AlbumTree.CheckState.PARTIAL) {
            return detail + " · 部分选择";
        }
        return detail + (state == AlbumTree.CheckState.ALL ? " · 已选择" : " · 未选择");
    }

    private String breadcrumb(String path) {
        if (path.isEmpty()) {
            return "全部相册";
        }
        return "全部相册  /  " + path.replace("/", "  /  ");
    }

    private String selectionDescription(String name, boolean selected) {
        return name + (selected ? "，已选择" : "，未选择");
    }
}
