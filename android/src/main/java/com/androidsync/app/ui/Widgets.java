// android/src/main/java/com/androidsync/app/ui/Widgets.java
package com.androidsync.app.ui;

import android.app.Activity;
import android.app.Dialog;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.os.Build;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.text.DecimalFormat;

/** Shared native View factories and system-bar inset handling. */
public final class Widgets {
    private final Activity activity;

    public Widgets(Activity activity) {
        this.activity = activity;
    }

    public LinearLayout pageLayout() {
        LinearLayout page = new LinearLayout(activity);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(20), dp(18), dp(20), dp(28));
        return page;
    }

    public LinearLayout card() {
        LinearLayout card = new LinearLayout(activity);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(14), dp(16), dp(14));
        card.setBackground(rounded(Theme.BG_SURFACE, Theme.STROKE, 1, Theme.RADIUS_L));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(8), 0, dp(8));
        card.setLayoutParams(params);
        return card;
    }

    public TextView title(String text, int sp) {
        TextView view = label(text, sp, Theme.TEXT_PRIMARY);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        return view;
    }

    public TextView sectionHeader(String text) {
        return sectionTitle(text);
    }

    public TextView sectionTitle(String text) {
        TextView view = label(text, 16, Theme.TEXT_PRIMARY);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(0, dp(Theme.SPACE_M), 0, dp(2));
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
        view.setBackground(rounded(Theme.ACCENT, Theme.ACCENT, 0, 12));
        return view;
    }

    public Button actionButton(String text, View.OnClickListener listener) {
        return primaryButton(text, listener);
    }

    public Button primaryButton(String text, View.OnClickListener listener) {
        Button button = new Button(activity);
        button.setText(text);
        button.setTextSize(14);
        button.setTextColor(color(Theme.BG));
        button.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        button.setAllCaps(false);
        button.setMinHeight(dp(Theme.MIN_TOUCH_TARGET_DP));
        button.setPadding(dp(Theme.SPACE_L), 0, dp(Theme.SPACE_L), 0);
        button.setBackground(ripple(Theme.ACCENT, Theme.ACCENT, 0, Theme.RADIUS_L, "#55FFFFFF"));
        button.setOnClickListener(listener);
        return button;
    }

    public Button secondaryButton(String text, View.OnClickListener listener) {
        Button button = new Button(activity);
        button.setText(text);
        button.setTextSize(14);
        button.setTextColor(color(Theme.TEXT_PRIMARY));
        button.setAllCaps(false);
        button.setMinHeight(dp(Theme.MIN_TOUCH_TARGET_DP));
        button.setPadding(dp(Theme.SPACE_L), 0, dp(Theme.SPACE_L), 0);
        button.setBackground(ripple(Theme.BG_RAISED, Theme.STROKE, 1, Theme.RADIUS_L, "#33FFFFFF"));
        button.setOnClickListener(listener);
        return button;
    }

    public ImageButton iconButton(int drawableId, String contentDescription, View.OnClickListener listener) {
        ImageButton button = new ImageButton(activity);
        button.setImageResource(drawableId);
        button.setImageTintList(ColorStateList.valueOf(color(Theme.TEXT_SECONDARY)));
        button.setContentDescription(contentDescription);
        button.setScaleType(ImageView.ScaleType.CENTER);
        button.setPadding(dp(Theme.SPACE_S), dp(Theme.SPACE_S), dp(Theme.SPACE_S), dp(Theme.SPACE_S));
        button.setMinimumWidth(dp(Theme.MIN_TOUCH_TARGET_DP));
        button.setMinimumHeight(dp(Theme.MIN_TOUCH_TARGET_DP));
        button.setBackground(ripple(Theme.BG_RAISED, Theme.STROKE, 1, Theme.RADIUS_L, "#33FFFFFF"));
        button.setFocusable(true);
        button.setOnClickListener(listener);
        return button;
    }

    public TextView chip(String text, boolean selected, View.OnClickListener listener) {
        TextView chip = label(text, 13, selected ? Theme.ACCENT : Theme.TEXT_SECONDARY);
        chip.setGravity(Gravity.CENTER);
        chip.setMinHeight(dp(Theme.MIN_TOUCH_TARGET_DP));
        chip.setPadding(dp(Theme.SPACE_M), 0, dp(Theme.SPACE_M), 0);
        chip.setBackground(ripple(
                selected ? "#243943" : Theme.BG_RAISED,
                selected ? Theme.ACCENT : Theme.STROKE,
                1,
                Theme.RADIUS_L,
                "#33FFFFFF"));
        chip.setClickable(true);
        chip.setFocusable(true);
        chip.setOnClickListener(listener);
        return chip;
    }

    public View divider() {
        View divider = new View(activity);
        divider.setBackgroundColor(color(Theme.STROKE));
        divider.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, Math.max(1, dp(1))));
        return divider;
    }

    public Button smallButton(String text) {
        Button button = new Button(activity);
        button.setText(text);
        button.setTextSize(13);
        button.setTextColor(color(Theme.TEXT_PRIMARY));
        button.setAllCaps(false);
        button.setMinHeight(dp(Theme.MIN_TOUCH_TARGET_DP));
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setBackground(ripple(Theme.BG_RAISED, Theme.STROKE, 1, 12, "#33FFFFFF"));
        return button;
    }

    public TextView textButton(String text, String textColor, String backgroundColor) {
        TextView view = label(text, 14, textColor);
        view.setGravity(Gravity.CENTER);
        view.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        view.setPadding(dp(14), 0, dp(14), 0);
        view.setMinHeight(dp(Theme.MIN_TOUCH_TARGET_DP));
        view.setBackground(ripple(backgroundColor, backgroundColor, 0, 21, "#33FFFFFF"));
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

    private RippleDrawable ripple(String fillColor, String strokeColor, int strokeDp, int radiusDp, String rippleColor) {
        GradientDrawable content = rounded(fillColor, strokeColor, strokeDp, radiusDp);
        GradientDrawable mask = rounded("#FFFFFFFF", "#FFFFFFFF", 0, radiusDp);
        return new RippleDrawable(ColorStateList.valueOf(color(rippleColor)), content, mask);
    }

    public void installSystemInsets(final View insetHost, final View topTarget, final View bottomTarget) {
        if (insetHost == null) {
            return;
        }
        final int[] topBaseline = paddingOf(topTarget);
        final int[] bottomBaseline = topTarget == bottomTarget ? topBaseline : paddingOf(bottomTarget);
        insetHost.setOnApplyWindowInsetsListener(new View.OnApplyWindowInsetsListener() {
            @Override
            public WindowInsets onApplyWindowInsets(View view, WindowInsets insets) {
                int left;
                int top;
                int right;
                int bottom;
                if (Build.VERSION.SDK_INT >= 30) {
                    android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
                    left = bars.left;
                    top = bars.top;
                    right = bars.right;
                    bottom = bars.bottom;
                } else {
                    left = insets.getSystemWindowInsetLeft();
                    top = insets.getSystemWindowInsetTop();
                    right = insets.getSystemWindowInsetRight();
                    bottom = insets.getSystemWindowInsetBottom();
                }
                if (topTarget != null && topTarget == bottomTarget) {
                    setPadding(topTarget, UiInsetsPadding.apply(
                            topBaseline, new int[] { left, top, right, bottom }));
                } else {
                    if (topTarget != null) {
                        setPadding(topTarget, UiInsetsPadding.apply(
                                topBaseline, new int[] { left, top, right, 0 }));
                    }
                    if (bottomTarget != null) {
                        setPadding(bottomTarget, UiInsetsPadding.apply(
                                bottomBaseline, new int[] { left, 0, right, bottom }));
                    }
                }
                return insets;
            }
        });
        insetHost.requestApplyInsets();
    }

    public void installDialogInsets(Dialog dialog, View topTarget, View bottomTarget) {
        if (dialog == null) {
            return;
        }
        Window window = dialog.getWindow();
        if (window != null) {
            View decor = window.getDecorView();
            installSystemInsets(decor, topTarget, bottomTarget);
            decor.requestApplyInsets();
        }
    }

    private int[] paddingOf(View view) {
        if (view == null) {
            return new int[] { 0, 0, 0, 0 };
        }
        return new int[] { view.getPaddingLeft(), view.getPaddingTop(), view.getPaddingRight(), view.getPaddingBottom() };
    }

    private void setPadding(View view, int[] padding) {
        view.setPadding(padding[0], padding[1], padding[2], padding[3]);
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
