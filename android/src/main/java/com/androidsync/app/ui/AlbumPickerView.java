package com.androidsync.app.ui;

import android.app.Activity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

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
        breadcrumb.setPadding(widgets.dp(2), widgets.dp(8), widgets.dp(2), widgets.dp(10));
        content.addView(breadcrumb);

        LinearLayout list = new LinearLayout(activity);
        list.setOrientation(LinearLayout.VERTICAL);
        if (!path.isEmpty()) {
            TextView up = widgets.textButton("‹ 返回上级", Theme.TEXT_PRIMARY, Theme.BG_RAISED);
            up.setGravity(android.view.Gravity.CENTER_VERTICAL);
            up.setContentDescription("返回上级目录");
            up.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    int separator = path.lastIndexOf('/');
                    onNavigate.onNavigate(separator < 0 ? "" : path.substring(0, separator));
                }
            });
            LinearLayout.LayoutParams upParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, widgets.dp(44));
            upParams.setMargins(0, 0, 0, widgets.dp(6));
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
            empty.setPadding(widgets.dp(8), widgets.dp(16), widgets.dp(8), widgets.dp(16));
            list.addView(empty);
        }

        ScrollView scroll = new ScrollView(activity);
        scroll.setBackgroundColor(widgets.color(Theme.BG));
        scroll.addView(list);
        content.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        return content;
    }

    private void addFolderRow(LinearLayout list, final AlbumTree.Node folder,
                              final Set<String> selected, final OnNavigateListener onNavigate,
                              final Runnable onChanged) {
        LinearLayout row = widgets.card();
        row.setOrientation(LinearLayout.HORIZONTAL);
        final CheckBox box = new CheckBox(activity);
        updateFolderCheckBox(box, folder, selected);
        TextView name = widgets.label(folder.name + "  ·  " + folder.totalCount + " 项"
                + (folder.checkState(selected) == AlbumTree.CheckState.PARTIAL ? "  ·  部分选择" : ""),
                15, Theme.TEXT_PRIMARY);
        row.addView(box);
        row.addView(name, widgets.weightParams());
        TextView enter = widgets.label("›", 24, Theme.TEXT_SECONDARY);
        enter.setGravity(android.view.Gravity.CENTER);
        row.addView(enter, new LinearLayout.LayoutParams(widgets.dp(28), ViewGroup.LayoutParams.WRAP_CONTENT));

        View.OnClickListener navigate = new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                onNavigate.onNavigate(folder.path);
            }
        };
        row.setOnClickListener(navigate);
        name.setOnClickListener(navigate);
        enter.setOnClickListener(navigate);
        box.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                folder.toggle(selected);
                updateFolderCheckBox(box, folder, selected);
                name.setText(folder.name + "  ·  " + folder.totalCount + " 项"
                        + (folder.checkState(selected) == AlbumTree.CheckState.PARTIAL ? "  ·  部分选择" : ""));
                onChanged.run();
            }
        });
        list.addView(row);
    }

    private void addAlbumRow(LinearLayout list, final AlbumTree.Node owner, final AlbumTree.Album album,
                             final Set<String> selected, final Runnable onChanged) {
        LinearLayout row = widgets.card();
        row.setOrientation(LinearLayout.HORIZONTAL);
        final CheckBox box = new CheckBox(activity);
        box.setChecked(selected.contains(album.bucketId));
        box.setContentDescription(selectionDescription(album.name, selected.contains(album.bucketId)));
        TextView name = widgets.label(album.name + "  ·  " + album.count + " 项", 15, Theme.TEXT_PRIMARY);
        row.addView(box);
        row.addView(name, widgets.weightParams());
        View.OnClickListener toggle = new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                owner.toggle(album, selected);
                box.setChecked(selected.contains(album.bucketId));
                box.setContentDescription(selectionDescription(album.name, selected.contains(album.bucketId)));
                onChanged.run();
            }
        };
        row.setOnClickListener(toggle);
        box.setOnClickListener(toggle);
        list.addView(row);
    }

    private void updateFolderCheckBox(CheckBox box, AlbumTree.Node folder, Set<String> selected) {
        AlbumTree.CheckState state = folder.checkState(selected);
        box.setChecked(state == AlbumTree.CheckState.ALL);
        box.setContentDescription(folder.name + (state == AlbumTree.CheckState.PARTIAL
                ? "，部分选择" : state == AlbumTree.CheckState.ALL ? "，已全选" : "，未选择"));
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
