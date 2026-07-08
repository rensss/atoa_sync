package com.androidsync.app.android;

import android.content.ContentResolver;

import com.androidsync.app.core.MediaItem;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;

public final class HttpFileUploader {
    public void upload(ContentResolver resolver, MediaItem item, String targetBaseUrl) throws IOException {
        upload(resolver, item, targetBaseUrl, 0, 0);
    }

    public void upload(
            ContentResolver resolver,
            MediaItem item,
            String targetBaseUrl,
            int batchIndex,
            int batchTotal
    ) throws IOException {
        String normalizedBase = targetBaseUrl.endsWith("/") ? targetBaseUrl : targetBaseUrl + "/";
        String encodedName = URLEncoder.encode(item.displayName(), "UTF-8").replace("+", "%20");
        HttpURLConnection connection = (HttpURLConnection) new URL(normalizedBase + encodedName).openConnection();
        connection.setRequestMethod("PUT");
        connection.setConnectTimeout(8000);
        connection.setReadTimeout(15000);
        connection.setDoOutput(true);
        if (item.sizeBytes() > 0L) {
            // 定长流式模式：不设置时 HttpURLConnection 会把整个请求体缓冲在内存里
            // 计算 Content-Length，大文件（如视频）必然 OutOfMemoryError。
            connection.setFixedLengthStreamingMode(item.sizeBytes());
        }
        connection.setRequestProperty("Content-Type", item.mimeType());
        connection.setRequestProperty("X-Android-Sync-Id", item.stableId());
        connection.setRequestProperty("X-Android-Sync-Size", String.valueOf(item.sizeBytes()));
        connection.setRequestProperty("X-Android-Sync-Device", android.os.Build.MODEL);
        if (batchIndex > 0 && batchTotal > 0) {
            connection.setRequestProperty("X-Android-Sync-Batch-Index", String.valueOf(batchIndex));
            connection.setRequestProperty("X-Android-Sync-Batch-Total", String.valueOf(batchTotal));
        }
        if (item.dateModifiedMillis() > 0L) {
            connection.setRequestProperty("X-Android-Sync-Date-Modified", String.valueOf(item.dateModifiedMillis()));
        }
        if (item.dateTakenMillis() > 0L) {
            connection.setRequestProperty("X-Android-Sync-Date-Taken", String.valueOf(item.dateTakenMillis()));
        }
        if (item.dateAddedMillis() > 0L) {
            connection.setRequestProperty("X-Android-Sync-Date-Added", String.valueOf(item.dateAddedMillis()));
        }

        InputStream rawInput = resolver.openInputStream(android.net.Uri.parse(item.uri()));
        if (rawInput == null) {
            throw new IOException("Cannot open media stream: " + item.displayName());
        }

        try (InputStream input = new BufferedInputStream(rawInput);
             OutputStream output = new BufferedOutputStream(connection.getOutputStream())) {
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
        }

        int responseCode = connection.getResponseCode();
        connection.disconnect();
        if (responseCode < 200 || responseCode >= 300) {
            throw new IOException("Upload failed with HTTP " + responseCode);
        }
    }
}
