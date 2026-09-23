// android/src/main/java/com/androidsync/app/ui/Theme.java
package com.androidsync.app.ui;

/** Shared visual tokens for the Android phone UI. */
public final class Theme {
    public static final String BG = "#11151A";
    public static final String BG_SURFACE = "#1A2027";
    public static final String BG_RAISED = "#242D36";
    public static final String STROKE = "#35414B";
    public static final String TEXT_PRIMARY = "#F2F5F7";
    public static final String TEXT_SECONDARY = "#B3BEC6";
    public static final String TEXT_MUTED = "#85939D";
    public static final String ACCENT = "#59C3D4";
    public static final String STATUS_RUNNING = "#57CB91";
    public static final String STATUS_WARNING = "#E8B85E";
    public static final String STATUS_FAILED = "#F07578";

    public static final int SPACE_XS = 4;
    public static final int SPACE_S = 8;
    public static final int SPACE_M = 12;
    public static final int SPACE_L = 16;
    public static final int SPACE_XL = 24;
    public static final int MIN_TOUCH_TARGET_DP = 48;
    public static final int RADIUS_S = 6;
    public static final int RADIUS_L = 10;

    // Compatibility alias for the existing navigation surface.
    public static final String BG_SIDEBAR = BG_SURFACE;

    private Theme() {
    }
}
