package com.androidsync.app.ui;

/** Applies system-bar insets to a captured view-padding baseline. */
public final class UiInsetsPadding {
    private UiInsetsPadding() {
    }

    /**
     * Returns left, top, right, bottom padding with the supplied insets added.
     * Neither input array is modified, so repeated inset dispatches never accumulate.
     */
    public static int[] apply(int[] baseline, int[] systemInsets) {
        if (baseline == null || systemInsets == null || baseline.length != 4 || systemInsets.length != 4) {
            throw new IllegalArgumentException("padding and insets must each contain four values");
        }
        return new int[] {
                baseline[0] + systemInsets[0],
                baseline[1] + systemInsets[1],
                baseline[2] + systemInsets[2],
                baseline[3] + systemInsets[3]
        };
    }
}
