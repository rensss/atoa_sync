package com.androidsync.app.android;

import android.content.ContentResolver;
import android.content.ContentUris;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;

import com.androidsync.app.core.MediaItem;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

public final class MediaStoreScanner {
    private static final String DATE_TAKEN = "datetaken";

    private final ContentResolver resolver;

    public MediaStoreScanner(ContentResolver resolver) {
        this.resolver = resolver;
    }

    public List<MediaItem> scanRecent(int limit) {
        List<MediaItem> items = scanAll();
        if (items.size() <= limit) {
            return items;
        }
        return new ArrayList<>(items.subList(0, limit));
    }

    public List<MediaItem> scanAll() {
        List<MediaItem> items = new ArrayList<>();
        scanImages(items);
        scanVideos(items);
        Collections.sort(items, new Comparator<MediaItem>() {
            @Override
            public int compare(MediaItem left, MediaItem right) {
                return Long.compare(right.dateModifiedMillis(), left.dateModifiedMillis());
            }
        });
        return items;
    }

    private void scanImages(List<MediaItem> out) {
        Uri collection = Build.VERSION.SDK_INT >= 29
                ? MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                : MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
        scan(collection, false, "image", out);
    }

    private void scanVideos(List<MediaItem> out) {
        Uri collection = Build.VERSION.SDK_INT >= 29
                ? MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                : MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
        scan(collection, true, "video", out);
    }

    private void scan(Uri collection, boolean video, String prefix, List<MediaItem> out) {
        String[] projection = new String[] {
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.DATE_MODIFIED,
                MediaStore.MediaColumns.DATE_ADDED,
                MediaStore.MediaColumns.MIME_TYPE,
                DATE_TAKEN
        };
        Cursor cursor = resolver.query(collection, projection, null, null, MediaStore.MediaColumns.DATE_MODIFIED + " DESC");
        if (cursor == null) {
            return;
        }
        try {
            int idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID);
            int nameColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME);
            int sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE);
            int dateColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED);
            int dateAddedColumn = cursor.getColumnIndex(MediaStore.MediaColumns.DATE_ADDED);
            int mimeColumn = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE);
            int dateTakenColumn = cursor.getColumnIndex(DATE_TAKEN);
            while (cursor.moveToNext()) {
                long id = cursor.getLong(idColumn);
                String name = cursor.getString(nameColumn);
                long size = cursor.getLong(sizeColumn);
                long modifiedMillis = cursor.getLong(dateColumn) * 1000L;
                long addedMillis = dateAddedColumn >= 0 ? cursor.getLong(dateAddedColumn) * 1000L : 0L;
                long takenMillis = dateTakenColumn >= 0 ? cursor.getLong(dateTakenColumn) : 0L;
                String mimeType = mimeColumn >= 0 ? cursor.getString(mimeColumn) : null;
                Uri uri = ContentUris.withAppendedId(collection, id);
                out.add(new MediaItem(prefix + ":" + id, uri.toString(), name, size, modifiedMillis, takenMillis, addedMillis, video, mimeType));
            }
        } finally {
            cursor.close();
        }
    }
}
