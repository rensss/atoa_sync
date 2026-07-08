// android/src/main/java/com/androidsync/app/core/AlbumFilter.java
package com.androidsync.app.core;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public final class AlbumFilter {
    public static final class Selection {
        public final List<MediaItem> pending;
        public final long totalBytes;

        public Selection(List<MediaItem> pending, long totalBytes) {
            this.pending = pending;
            this.totalBytes = totalBytes;
        }
    }

    public static Selection pending(List<MediaItem> scanned, Set<String> syncedStableIds, Set<String> excludedStableIds) {
        List<MediaItem> pending = new ArrayList<>();
        long totalBytes = 0L;
        for (MediaItem item : scanned) {
            if (syncedStableIds.contains(item.stableId())) {
                continue;
            }
            if (excludedStableIds.contains(item.stableId())) {
                continue;
            }
            pending.add(item);
            totalBytes += item.sizeBytes();
        }
        return new Selection(pending, totalBytes);
    }

    public static boolean inWhitelist(MediaItem item, Set<String> bucketIds) {
        return bucketIds != null && bucketIds.contains(item.bucketId());
    }

    private AlbumFilter() {
    }
}
