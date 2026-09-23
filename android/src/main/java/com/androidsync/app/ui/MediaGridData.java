package com.androidsync.app.ui;

import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.SyncStatus;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Immutable snapshots consumed by the recycling media adapter. */
public final class MediaGridData {
    private List<MediaItem> items = Collections.emptyList();
    private Map<String, SyncStatus> statuses = Collections.emptyMap();

    public void replaceItems(List<MediaItem> nextItems) {
        items = nextItems == null || nextItems.isEmpty()
                ? Collections.<MediaItem>emptyList()
                : Collections.unmodifiableList(new ArrayList<>(nextItems));
    }

    public void replaceStatuses(Map<String, SyncStatus> nextStatuses) {
        statuses = nextStatuses == null || nextStatuses.isEmpty()
                ? Collections.<String, SyncStatus>emptyMap()
                : Collections.unmodifiableMap(new HashMap<>(nextStatuses));
    }

    public int getCount() {
        return items.size();
    }

    public MediaItem getItem(int position) {
        return items.get(position);
    }

    public SyncStatus statusFor(MediaItem item) {
        if (item == null) {
            return SyncStatus.WAITING;
        }
        SyncStatus status = statuses.get(item.stableId());
        return status == null ? SyncStatus.WAITING : status;
    }

    public int clampPosition(int position) {
        if (items.isEmpty()) {
            return 0;
        }
        return Math.max(0, Math.min(position, items.size() - 1));
    }
}
