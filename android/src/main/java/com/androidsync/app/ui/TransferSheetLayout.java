package com.androidsync.app.ui;

/** Measurement helpers for the weighted task list in the transfer sheet. */
public final class TransferSheetLayout {
    private TransferSheetLayout() {
    }

    public static int bodyMaxHeight(int sheetMaxHeight, int fixedHeight) {
        if (sheetMaxHeight <= 0) {
            return 0;
        }
        return Math.max(0, sheetMaxHeight - Math.max(0, fixedHeight));
    }
}
