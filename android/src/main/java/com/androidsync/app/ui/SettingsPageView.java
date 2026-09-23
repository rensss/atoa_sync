package com.androidsync.app.ui;

import android.app.Activity;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

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
        page.addView(widgets.title("设置", 24));
        TextView intro = widgets.label("管理自动同步范围与接收位置", 13, Theme.TEXT_SECONDARY);
        intro.setPadding(0, widgets.dp(Theme.SPACE_XS), 0, widgets.dp(Theme.SPACE_M));
        page.addView(intro);

        page.addView(widgets.sectionTitle("同步相册"));
        LinearLayout albums = widgets.card();
        albums.setOrientation(LinearLayout.HORIZONTAL);
        albums.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout albumInfo = new LinearLayout(activity);
        albumInfo.setOrientation(LinearLayout.VERTICAL);
        albumInfo.addView(widgets.label("自动同步范围", 14, Theme.TEXT_PRIMARY));
        TextView albumCount = widgets.label(host.whitelistCount() + " 个相册已选择", 12, Theme.TEXT_SECONDARY);
        albumCount.setPadding(0, widgets.dp(Theme.SPACE_XS), 0, 0);
        albumInfo.addView(albumCount);
        albums.addView(albumInfo, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button manage = widgets.secondaryButton("管理相册", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.openAlbumPicker();
            }
        });
        albums.addView(manage);
        page.addView(albums);

        page.addView(widgets.sectionTitle("接收端"));
        LinearLayout target = widgets.card();
        target.setOrientation(LinearLayout.VERTICAL);
        target.addView(widgets.label("当前接收地址", 12, Theme.TEXT_MUTED));
        LinearLayout targetRow = new LinearLayout(activity);
        targetRow.setOrientation(LinearLayout.HORIZONTAL);
        targetRow.setGravity(Gravity.CENTER_VERTICAL);
        TextView address = widgets.label(host.targetUrl(), 13, Theme.TEXT_SECONDARY);
        address.setMaxLines(3);
        address.setEllipsize(TextUtils.TruncateAt.END);
        LinearLayout.LayoutParams addressParams = new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        addressParams.setMargins(0, widgets.dp(Theme.SPACE_XS), widgets.dp(Theme.SPACE_S), 0);
        targetRow.addView(address, addressParams);
        Button edit = widgets.secondaryButton("修改", new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                host.editTarget();
            }
        });
        edit.setMinWidth(widgets.dp(72));
        targetRow.addView(edit);
        target.addView(targetRow);
        page.addView(target);

        page.addView(widgets.sectionTitle("关于"));
        LinearLayout about = widgets.card();
        about.setOrientation(LinearLayout.HORIZONTAL);
        about.setGravity(Gravity.CENTER_VERTICAL);
        about.addView(widgets.label("Android Sync", 14, Theme.TEXT_PRIMARY),
                new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView version = widgets.label(host.appVersionText(), 13, Theme.TEXT_SECONDARY);
        version.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        about.addView(version);
        page.addView(about);

        ScrollView scroll = new ScrollView(activity);
        scroll.setFillViewport(true);
        scroll.setClipToPadding(false);
        scroll.addView(page);
        return scroll;
    }
}
