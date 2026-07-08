// android/src/main/java/com/androidsync/app/ui/AlbumPickerView.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.view.View;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.androidsync.app.android.MediaStoreScanner;

import java.util.List;
import java.util.Set;

public final class AlbumPickerView {
    private final Activity activity;
    private final Widgets widgets;

    public AlbumPickerView(Activity activity, Widgets widgets) {
        this.activity = activity;
        this.widgets = widgets;
    }

    public View build(List<MediaStoreScanner.Album> albums, final Set<String> selected, final Runnable onChanged) {
        LinearLayout list = new LinearLayout(activity);
        list.setOrientation(LinearLayout.VERTICAL);
        for (final MediaStoreScanner.Album album : albums) {
            LinearLayout row = widgets.card();
            row.setOrientation(LinearLayout.HORIZONTAL);
            final CheckBox box = new CheckBox(activity);
            box.setChecked(selected.contains(album.bucketId));
            TextView name = widgets.label(album.name + "  ·  " + album.count + " 项", 15, Theme.TEXT_PRIMARY);
            row.addView(box);
            row.addView(name, widgets.weightParams());
            View.OnClickListener toggle = new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    if (selected.contains(album.bucketId)) {
                        selected.remove(album.bucketId);
                    } else {
                        selected.add(album.bucketId);
                    }
                    box.setChecked(selected.contains(album.bucketId));
                    onChanged.run();
                }
            };
            row.setOnClickListener(toggle);
            box.setOnClickListener(toggle);
            list.addView(row);
        }
        ScrollView scroll = new ScrollView(activity);
        scroll.setBackgroundColor(widgets.color(Theme.BG));
        scroll.addView(list);
        return scroll;
    }
}
