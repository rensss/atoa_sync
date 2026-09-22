package com.androidsync.app.android;

import android.content.ContentResolver;

import com.androidsync.app.core.MediaItem;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.concurrent.atomic.AtomicReference;

public final class HttpFileUploader {
    private final AtomicReference<HttpURLConnection> activeConnection = new AtomicReference<>();
    private static final long UNKNOWN_BATCH_TOTAL_BYTES = -1L;

    public interface CancellationSignal {
        boolean isCancelled();
    }

    private static final CancellationSignal NEVER_CANCELLED = new CancellationSignal() {
        @Override
        public boolean isCancelled() {
            return false;
        }
    };

    public void upload(ContentResolver resolver, MediaItem item, String targetBaseUrl) throws IOException {
        upload(resolver, item, targetBaseUrl, 0, 0, UNKNOWN_BATCH_TOTAL_BYTES);
    }

    public void upload(
            ContentResolver resolver,
            MediaItem item,
            String targetBaseUrl,
            int batchIndex,
            int batchTotal
    ) throws IOException {
        upload(resolver, item, targetBaseUrl, batchIndex, batchTotal, UNKNOWN_BATCH_TOTAL_BYTES);
    }

    public void upload(
            ContentResolver resolver,
            MediaItem item,
            String targetBaseUrl,
            int batchIndex,
            int batchTotal,
            long batchTotalBytes
    ) throws IOException {
        upload(resolver, item, targetBaseUrl, batchIndex, batchTotal, batchTotalBytes, NEVER_CANCELLED);
    }

    public void upload(
            ContentResolver resolver,
            MediaItem item,
            String targetBaseUrl,
            int batchIndex,
            int batchTotal,
            CancellationSignal cancellation
    ) throws IOException {
        upload(resolver, item, targetBaseUrl, batchIndex, batchTotal, UNKNOWN_BATCH_TOTAL_BYTES, cancellation);
    }

    public void upload(
            ContentResolver resolver,
            MediaItem item,
            String targetBaseUrl,
            int batchIndex,
            int batchTotal,
            long batchTotalBytes,
            CancellationSignal cancellation
    ) throws IOException {
        String normalizedBase = targetBaseUrl.endsWith("/") ? targetBaseUrl : targetBaseUrl + "/";
        String encodedName = URLEncoder.encode(item.displayName(), "UTF-8").replace("+", "%20");
        HttpURLConnection connection = (HttpURLConnection) new URL(normalizedBase + encodedName).openConnection();
        activeConnection.set(connection);
        try {
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
                if (batchTotalBytes >= 0L) {
                    connection.setRequestProperty(
                            "X-Android-Sync-Batch-Total-Bytes",
                            String.valueOf(batchTotalBytes)
                    );
                }
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

            throwIfCancelled(cancellation);
            InputStream rawInput = resolver.openInputStream(android.net.Uri.parse(item.uri()));
            if (rawInput == null) {
                throw new IOException("Cannot open media stream: " + item.displayName());
            }

            try (InputStream input = new BufferedInputStream(rawInput);
                 OutputStream output = new BufferedOutputStream(connection.getOutputStream())) {
                byte[] buffer = new byte[64 * 1024];
                int read;
                while (true) {
                    throwIfCancelled(cancellation);
                    read = input.read(buffer);
                    if (read == -1) {
                        break;
                    }
                    throwIfCancelled(cancellation);
                    output.write(buffer, 0, read);
                }
            }

            int responseCode = connection.getResponseCode();
            if (responseCode < 200 || responseCode >= 300) {
                throw new IOException("Upload failed with HTTP " + responseCode);
            }
        } finally {
            connection.disconnect();
            activeConnection.compareAndSet(connection, null);
        }
    }

    public void cancelActive() {
        HttpURLConnection connection = activeConnection.getAndSet(null);
        if (connection != null) {
            connection.disconnect();
        }
    }

    private static void throwIfCancelled(CancellationSignal cancellation) throws InterruptedIOException {
        if (cancellation != null && cancellation.isCancelled()) {
            throw new InterruptedIOException("同步已停止");
        }
    }
}
