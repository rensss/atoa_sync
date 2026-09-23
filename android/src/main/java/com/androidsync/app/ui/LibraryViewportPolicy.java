package com.androidsync.app.ui;

/** Guards saved-grid capture until the replacement GridView has real children. */
public final class LibraryViewportPolicy {
    private LibraryViewportPolicy() {
    }

    public static boolean shouldCapture(boolean laidOut, int childCount) {
        return laidOut && childCount > 0;
    }
}
