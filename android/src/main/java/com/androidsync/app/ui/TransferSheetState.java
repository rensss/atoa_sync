package com.androidsync.app.ui;

/** Lifecycle state that keeps the stop control scoped to one sync run. */
public final class TransferSheetState {
    private boolean stopRequested;

    public void beginRun() {
        stopRequested = false;
    }

    public void requestStop() {
        stopRequested = true;
    }

    public void clearIfIdle(boolean runActive) {
        if (!runActive) {
            stopRequested = false;
        }
    }

    public boolean stopRequested() {
        return stopRequested;
    }

    public boolean canStop(boolean runActive) {
        return runActive && !stopRequested;
    }
}
