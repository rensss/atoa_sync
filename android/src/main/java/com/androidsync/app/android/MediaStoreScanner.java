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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class MediaStoreScanner {
    private static final String DATE_TAKEN = "datetaken";
    // BUCKET_ID/BUCKET_DISPLAY_NAME 自 API 29 起在 MediaColumns 公开；minSdk 26
    // 用字符串常量（26–28 与 29+ 列名一致）。
    private static final String BUCKET_ID = "bucket_id";
    private static final String BUCKET_NAME = "bucket_display_name";

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
        return scanAll(null);
    }

    /** {@code bucketIds} 为 null 不过滤（相册枚举用）；非 null 时按 bucket_id 白名单过滤，空集合返回空。 */
    public List<MediaItem> scanAll(Set<String> bucketIds) {
        List<MediaItem> items = new ArrayList<>();
        scanImages(items, bucketIds);
        scanVideos(items, bucketIds);
        Collections.sort(items, new Comparator<MediaItem>() {
            @Override
            public int compare(MediaItem left, MediaItem right) {
                return Long.compare(right.dateModifiedMillis(), left.dateModifiedMillis());
            }
        });
        return items;
    }

    /** 全库聚合去重、按 count 降序返回相册清单。 */
    public List<Album> listAlbums() {
        LinkedHashMap<String, int[]> counts = new LinkedHashMap<>();
        LinkedHashMap<String, String> names = new LinkedHashMap<>();
        countBuckets(imagesCollection(), counts, names);
        countBuckets(videosCollection(), counts, names);
        List<Album> albums = new ArrayList<>();
        for (Map.Entry<String, int[]> entry : counts.entrySet()) {
            albums.add(new Album(entry.getKey(), names.get(entry.getKey()), entry.getValue()[0]));
        }
        Collections.sort(albums, new Comparator<Album>() {
            @Override
            public int compare(Album left, Album right) {
                return Integer.compare(right.count, left.count);
            }
        });
        return albums;
    }

    private void countBuckets(Uri collection, Map<String, int[]> counts, Map<String, String> names) {
        String[] projection = new String[] { BUCKET_ID, BUCKET_NAME };
        Cursor cursor = resolver.query(collection, projection, null, null, null);
        if (cursor == null) {
            return;
        }
        try {
            int idColumn = cursor.getColumnIndexOrThrow(BUCKET_ID);
            int nameColumn = cursor.getColumnIndexOrThrow(BUCKET_NAME);
            while (cursor.moveToNext()) {
                String id = cursor.getString(idColumn);
                if (id == null) {
                    continue;
                }
                String name = cursor.getString(nameColumn);
                int[] count = counts.get(id);
                if (count == null) {
                    counts.put(id, new int[] { 1 });
                    names.put(id, name == null ? id : name);
                } else {
                    count[0]++;
                }
            }
        } finally {
            cursor.close();
        }
    }

    private Uri imagesCollection() {
        return Build.VERSION.SDK_INT >= 29
                ? MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                : MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
    }

    private Uri videosCollection() {
        return Build.VERSION.SDK_INT >= 29
                ? MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                : MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
    }

    private void scanImages(List<MediaItem> out, Set<String> bucketIds) {
        scan(imagesCollection(), false, "image", bucketIds, out);
    }

    private void scanVideos(List<MediaItem> out, Set<String> bucketIds) {
        scan(videosCollection(), true, "video", bucketIds, out);
    }

    private void scan(Uri collection, boolean video, String prefix, Set<String> bucketIds, List<MediaItem> out) {
        String[] projection = new String[] {
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.DATE_MODIFIED,
                MediaStore.MediaColumns.DATE_ADDED,
                MediaStore.MediaColumns.MIME_TYPE,
                DATE_TAKEN,
                BUCKET_ID,
                BUCKET_NAME
        };
        String selection = null;
        String[] selectionArgs = null;
        if (bucketIds != null) {
            if (bucketIds.isEmpty()) {
                return;
            }
            StringBuilder placeholders = new StringBuilder();
            selectionArgs = new String[bucketIds.size()];
            int index = 0;
            for (String bucketId : bucketIds) {
                if (index > 0) {
                    placeholders.append(",");
                }
                placeholders.append("?");
                selectionArgs[index] = bucketId;
                index++;
            }
            selection = BUCKET_ID + " IN (" + placeholders + ")";
        }
        Cursor cursor = resolver.query(collection, projection, selection, selectionArgs, MediaStore.MediaColumns.DATE_MODIFIED + " DESC");
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
            int bucketIdColumn = cursor.getColumnIndex(BUCKET_ID);
            int bucketNameColumn = cursor.getColumnIndex(BUCKET_NAME);
            while (cursor.moveToNext()) {
                long id = cursor.getLong(idColumn);
                String name = cursor.getString(nameColumn);
                long size = cursor.getLong(sizeColumn);
                long modifiedMillis = cursor.getLong(dateColumn) * 1000L;
                long addedMillis = dateAddedColumn >= 0 ? cursor.getLong(dateAddedColumn) * 1000L : 0L;
                long takenMillis = dateTakenColumn >= 0 ? cursor.getLong(dateTakenColumn) : 0L;
                String mimeType = mimeColumn >= 0 ? cursor.getString(mimeColumn) : null;
                String bucketId = bucketIdColumn >= 0 ? cursor.getString(bucketIdColumn) : null;
                String bucketName = bucketNameColumn >= 0 ? cursor.getString(bucketNameColumn) : null;
                Uri uri = ContentUris.withAppendedId(collection, id);
                out.add(new MediaItem(prefix + ":" + id, uri.toString(), name, size, modifiedMillis, takenMillis, addedMillis, video, mimeType, bucketId, bucketName));
            }
        } finally {
            cursor.close();
        }
    }

    public static final class Album {
        public final String bucketId;
        public final String name;
        public final int count;

        public Album(String bucketId, String name, int count) {
            this.bucketId = bucketId;
            this.name = name;
            this.count = count;
        }
    }
}
