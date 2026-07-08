// android/src/main/java/com/androidsync/app/ui/Widgets.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.text.DecimalFormat;

/**
 * 程序化 View 工厂，B17 自 MainActivity 原样搬移（行为零变化）。
 * 各方法体逐字保留，仅把对 Activity 的隐式引用改为字段 {@code activity}。
 */
public final class Widgets {
    private final Activity activity;

    public Widgets(Activity activity) {
        this.activity = activity;
    }

    public LinearLayout pageLayout() {
        LinearLayout page = new LinearLayout(activity);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(20), statusBarHeight() + dp(18), dp(20), dp(28));
        return page;
    }

    public LinearLayout card() {
        LinearLayout card = new LinearLayout(activity);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(14), dp(16), dp(14));
        card.setBackground(rounded("#FFFFFF", "#E8E0D4", 1, 12));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(8), 0, dp(8));
        card.setLayoutParams(params);
        return card;
    }

    public TextView title(String text, int sp) {
        TextView view = label(text, sp, "#182B28");
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        return view;
    }

    public TextView sectionHeader(String text) {
        TextView view = label(text, 16, "#2F3D38");
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(0, dp(12), 0, dp(2));
        return view;
    }

    public TextView label(String text, int sp, String color) {
        TextView view = new TextView(activity);
        view.setText(text);
        view.setTextSize(sp);
        view.setTextColor(color(color));
        view.setIncludeFontPadding(true);
        return view;
    }

    public TextView icon(String text) {
        TextView view = label(text, 13, "#FFFFFF");
        view.setGravity(Gravity.CENTER);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setBackground(rounded("#2F6B5F", "#2F6B5F", 0, 12));
        return view;
    }

    public Button actionButton(String text, View.OnClickListener listener) {
        Button button = smallButton(text);
        button.setTextColor(Color.WHITE);
        button.setBackground(rounded("#182B28", "#182B28", 0, 12));
        button.setOnClickListener(listener);
        return button;
    }

    public Button smallButton(String text) {
        Button button = new Button(activity);
        button.setText(text);
        button.setTextSize(13);
        button.setTextColor(color("#2E3B37"));
        button.setAllCaps(false);
        button.setMinHeight(dp(40));
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setBackground(rounded("#EEE7DB", "#DDD3C4", 1, 12));
        return button;
    }

    public TextView textButton(String text, String textColor, String backgroundColor) {
        TextView view = label(text, 14, textColor);
        view.setGravity(Gravity.CENTER);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(dp(14), 0, dp(14), 0);
        view.setBackground(rounded(backgroundColor, backgroundColor, 0, 21));
        view.setClickable(true);
        view.setFocusable(true);
        return view;
    }

    public LinearLayout.LayoutParams weightParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        params.setMargins(dp(4), 0, dp(4), 0);
        return params;
    }

    public int color(String value) {
        return Color.parseColor(value);
    }

    public GradientDrawable rounded(String fillColor, String strokeColor, int strokeDp, int radiusDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color(fillColor));
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeDp > 0) {
            drawable.setStroke(dp(strokeDp), color(strokeColor));
        }
        return drawable;
    }

    public int dp(int value) {
        return Math.round(value * activity.getResources().getDisplayMetrics().density);
    }

    public int statusBarHeight() {
        int resourceId = activity.getResources().getIdentifier("status_bar_height", "dimen", "android");
        if (resourceId <= 0) {
            return 0;
        }
        return activity.getResources().getDimensionPixelSize(resourceId);
    }

    public static String formatBytes(long bytes) {
        DecimalFormat df = new DecimalFormat("0.#");
        if (bytes >= 1024L * 1024L * 1024L) {
            return df.format(bytes / 1024f / 1024f / 1024f) + " GB";
        }
        if (bytes >= 1024L * 1024L) {
            return df.format(bytes / 1024f / 1024f) + " MB";
        }
        if (bytes >= 1024L) {
            return df.format(bytes / 1024f) + " KB";
        }
        return bytes + " B";
    }
}
