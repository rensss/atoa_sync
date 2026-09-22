package com.androidsync.app.core;

import java.io.IOException;

/** Signals a PUT interruption positively attributed to the native receiver's pause state. */
public final class ReceiverPausedException extends IOException {
    public ReceiverPausedException(String message) {
        super(message);
    }

    public ReceiverPausedException(String message, Throwable cause) {
        super(message, cause);
    }
}
