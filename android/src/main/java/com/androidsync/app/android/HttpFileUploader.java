package com.androidsync.app.android;

import android.content.ContentResolver;

import com.androidsync.app.core.MediaItem;
import com.androidsync.app.core.ReceiverPausedException;

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
        upload(resolver, item, targetBaseUrl, batchIndex, batchTotal, batchTotalBytes, null, cancellation);
    }

    public void upload(
            ContentResolver resolver,
            MediaItem item,
            String targetBaseUrl,
            int batchIndex,
            int batchTotal,
            long batchTotalBytes,
            ReceiverControlClient.Session receiverSession,
            CancellationSignal cancellation
    ) throws IOException {
        Long initialPauseEpoch = null;
        if (receiverSession != null && receiverSession.isSupported()) {
            throwIfCancelled(cancellation);
            try {
                ReceiverControlClient.Snapshot snapshot = receiverSession.readHealth();
                initialPauseEpoch = snapshot.pauseEpoch();
                if (!"running".equals(snapshot.state())) {
                    throw new ReceiverPausedException("Mac 接收端已暂停");
                }
            } catch (ReceiverPausedException error) {
                throw error;
            } catch (IOException unavailable) {
                // Health-check failure is not proof of pause; preserve the ordinary single PUT attempt.
                throwIfCancelled(cancellation);
            }
        }

        String normalizedBase = targetBaseUrl.endsWith("/") ? targetBaseUrl : targetBaseUrl + "/";
        HttpURLConnection connection = null;
        boolean uploadStarted = false;
        try {
            String encodedName = URLEncoder.encode(item.displayName(), "UTF-8").replace("+", "%20");
            connection = (HttpURLConnection) new URL(normalizedBase + encodedName).openConnection();
            activeConnection.set(connection);
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

            uploadStarted = true;
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
        } catch (IOException uploadError) {
            if (uploadStarted
                    && receiverSession != null
                    && receiverSession.isSupported()
                    && (cancellation == null || !cancellation.isCancelled())) {
                ReceiverPausedException pause = classifyPause(
                        receiverSession,
                        initialPauseEpoch,
                        uploadError
                );
                if (pause != null) {
                    throw pause;
                }
            }
            throw uploadError;
        } finally {
            if (connection != null) {
                connection.disconnect();
                activeConnection.compareAndSet(connection, null);
            }
        }
    }

    private static ReceiverPausedException classifyPause(
            ReceiverControlClient.Session receiverSession,
            Long initialPauseEpoch,
            IOException uploadError
    ) {
        try {
            ReceiverControlClient.Snapshot after = receiverSession.readHealth();
            boolean receiverPaused = !"running".equals(after.state());
            boolean epochChanged = initialPauseEpoch != null
                    && after.pauseEpoch() != initialPauseEpoch.longValue();
            if (receiverPaused || epochChanged) {
                return new ReceiverPausedException(
                        "Mac 接收端暂停导致当前文件上传中断",
                        uploadError
                );
            }
        } catch (IOException unavailable) {
            // Keep the original upload error when control status cannot be confirmed.
        }
        return null;
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
