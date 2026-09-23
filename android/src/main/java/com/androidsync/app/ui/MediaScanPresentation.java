package com.androidsync.app.ui;

import com.androidsync.app.core.MediaItem;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** UI snapshot that lets local media appear before remote manifest reconciliation finishes. */
public final class MediaScanPresentation {
    private final List<MediaItem> media;
    private final String message;
    private final boolean remotePending;

    private MediaScanPresentation(List<MediaItem> media, String message, boolean remotePending) {
        if (media == null) {
            throw new IllegalArgumentException("media is required");
        }
        this.media = Collections.unmodifiableList(new ArrayList<>(media));
        this.message = message;
        this.remotePending = remotePending;
    }

    public static MediaScanPresentation localReady(List<MediaItem> media) {
        return new MediaScanPresentation(media,
                "已扫描 " + media.size() + " 个媒体文件，正在核对接收端…", true);
    }

    public static MediaScanPresentation complete(List<MediaItem> media, int remoteMatches, String suffix) {
        String extra = suffix == null ? "" : suffix;
        return new MediaScanPresentation(media,
                "已扫描 " + media.size() + " 个媒体文件，接收端已有 " + remoteMatches + " 个记录" + extra,
                false);
    }

    public List<MediaItem> media() {
        return media;
    }

    public int mediaCount() {
        return media.size();
    }

    public String message() {
        return message;
    }

    public boolean remotePending() {
        return remotePending;
    }
}
