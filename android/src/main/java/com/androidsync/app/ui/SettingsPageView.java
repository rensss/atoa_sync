// android/src/main/java/com/androidsync/app/ui/SettingsPageView.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;

public final class SettingsPageView {
    public interface SettingsHost {
        String targetUrl();
        void editTarget();
        void openAlbumPicker();
        String appVersionText();
        int whitelistCount();
    }

    private final Activity activity;
    private final Widgets widgets;

    public SettingsPageView(Activity activity, Widgets widgets) {
        this.activity = activity;
        this.widgets = widgets;
    }

    public View build(final SettingsHost host) {
        LinearLayout page = widgets.pageLayout();
        page.setBackgroundColor(widgets.color(Theme.BG));

        page.addView(widgets.sectionHeader("同步相册"));
        LinearLayout albums = widgets.card();
        albums.setOrientation(LinearLayout.HORIZONTAL);
        albums.addView(widgets.label("已选 " + host.whitelistCount() + " 个相册", 14, Theme.TEXT_PRIMARY), widgets.weightParams());
        Button manage = widgets.smallButton("管理");
        manage.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.openAlbumPicker();
            }
        });
        albums.addView(manage);
        page.addView(albums);

        page.addView(widgets.sectionHeader("接收端"));
        LinearLayout target = widgets.card();
        target.setOrientation(LinearLayout.HORIZONTAL);
        target.addView(widgets.label(host.targetUrl(), 13, Theme.TEXT_SECONDARY), widgets.weightParams());
        Button edit = widgets.smallButton("修改");
        edit.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.editTarget();
            }
        });
        target.addView(edit);
        page.addView(target);

        page.addView(widgets.sectionHeader("关于"));
        LinearLayout about = widgets.card();
        about.addView(widgets.label(host.appVersionText(), 13, Theme.TEXT_SECONDARY));
        page.addView(about);
        return page;
    }
}
