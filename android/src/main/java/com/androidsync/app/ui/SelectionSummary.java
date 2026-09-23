package com.androidsync.app.ui;

import com.androidsync.app.core.MediaItem;

import java.util.List;
import java.util.Set;

/** Immutable count and byte total for the current confirmation selection. */
public final class SelectionSummary {
    private final int selectedCount;
    private final long selectedBytes;

    private SelectionSummary(int selectedCount, long selectedBytes) {
        this.selectedCount = selectedCount;
        this.selectedBytes = selectedBytes;
    }

    public static SelectionSummary from(List<MediaItem> pending, Set<String> excluded) {
        int count = 0;
        long bytes = 0L;
        if (pending != null) {
            for (MediaItem item : pending) {
                if (item == null || (excluded != null && excluded.contains(item.stableId()))) {
                    continue;
                }
                count++;
                bytes += item.sizeBytes();
            }
        }
        return new SelectionSummary(count, bytes);
    }

    public int selectedCount() {
        return selectedCount;
    }

    public long selectedBytes() {
        return selectedBytes;
    }
}
