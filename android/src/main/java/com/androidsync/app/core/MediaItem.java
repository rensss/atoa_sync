package com.androidsync.app.core;

import java.util.Objects;

public final class MediaItem {
    private final String stableId;
    private final String uri;
    private final String displayName;
    private final long sizeBytes;
    private final long dateModifiedMillis;
    private final long dateTakenMillis;
    private final long dateAddedMillis;
    private final boolean video;
    private final String mimeType;

    public MediaItem(String stableId, String uri, String displayName, long sizeBytes, long dateModifiedMillis, boolean video) {
        this(stableId, uri, displayName, sizeBytes, dateModifiedMillis, 0L, 0L, video, video ? "video/mp4" : "image/jpeg");
    }

    public MediaItem(
            String stableId,
            String uri,
            String displayName,
            long sizeBytes,
            long dateModifiedMillis,
            long dateTakenMillis,
            long dateAddedMillis,
            boolean video,
            String mimeType
    ) {
        this.stableId = requireText(stableId, "stableId");
        this.uri = requireText(uri, "uri");
        this.displayName = requireText(displayName, "displayName");
        this.sizeBytes = Math.max(0L, sizeBytes);
        this.dateModifiedMillis = dateModifiedMillis;
        this.dateTakenMillis = dateTakenMillis;
        this.dateAddedMillis = dateAddedMillis;
        this.video = video;
        this.mimeType = mimeType == null || mimeType.trim().isEmpty() ? (video ? "video/mp4" : "image/jpeg") : mimeType;
    }

    public String stableId() {
        return stableId;
    }

    public String uri() {
        return uri;
    }

    public String displayName() {
        return displayName;
    }

    public long sizeBytes() {
        return sizeBytes;
    }

    public long dateModifiedMillis() {
        return dateModifiedMillis;
    }

    public long dateTakenMillis() {
        return dateTakenMillis;
    }

    public long dateAddedMillis() {
        return dateAddedMillis;
    }

    public boolean isVideo() {
        return video;
    }

    public String mimeType() {
        return mimeType;
    }

    public String fingerprint() {
        return displayName + ":" + sizeBytes;
    }

    private static String requireText(String value, String name) {
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException(name + " is required");
        }
        return value;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof MediaItem)) {
            return false;
        }
        MediaItem that = (MediaItem) other;
        return stableId.equals(that.stableId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(stableId);
    }
}
