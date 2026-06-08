package com.androidsync.app.core;

public final class ThumbnailPolicy {
    private static final int GRID_MAX_PIXELS = 96;
    private static final int PREVIEW_MAX_PIXELS = 1024;

    private ThumbnailPolicy() {
    }

    public static int gridRequestPixels(int requestedPixels) {
        return clamp(requestedPixels, GRID_MAX_PIXELS);
    }

    public static int previewRequestPixels(int requestedPixels) {
        return clamp(requestedPixels, PREVIEW_MAX_PIXELS);
    }

    private static int clamp(int requestedPixels, int maxPixels) {
        return Math.max(1, Math.min(requestedPixels, maxPixels));
    }
}
