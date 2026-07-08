// android/src/main/java/com/androidsync/app/ui/Theme.java
package com.androidsync.app.ui;

/**
 * 深色工作台主题 token，数值与 macOS 端 Theme.swift 一致
 * （docs/superpowers/specs/2026-07-08-android-ui-redesign-design.md）。
 * 本批次只定义，不接线；各页在 B18–B20 重画时改用这里的值。
 */
public final class Theme {
    public static final String BG = "#1E1E23";
    public static final String BG_RAISED = "#2B2B31";
    public static final String BG_SIDEBAR = "#1C1C21";
    public static final String STROKE = "#38383F";
    public static final String TEXT_PRIMARY = "#EEEEF0";
    public static final String TEXT_SECONDARY = "#9A9AA3";
    public static final String ACCENT = "#E8A33D";
    public static final String GRADIENT_START = "#4F7CF0";
    public static final String GRADIENT_END = "#6A5CD8";
    public static final String STATUS_RUNNING = "#4CD964";
    public static final String STATUS_FAILED = "#FF5F57";

    public static final int SPACE_XS = 4;
    public static final int SPACE_S = 8;
    public static final int SPACE_M = 12;
    public static final int SPACE_L = 16;
    public static final int RADIUS_S = 6;
    public static final int RADIUS_L = 10;

    private Theme() {
    }
}
