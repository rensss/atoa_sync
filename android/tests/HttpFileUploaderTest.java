import android.content.ContentResolver;
import android.net.Uri;

import com.androidsync.app.android.HttpFileUploader;
import com.androidsync.app.android.ReceiverControlClient;
import com.androidsync.app.core.ReceiverPausedException;
import com.androidsync.app.core.MediaItem;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

public final class HttpFileUploaderTest {
    public static void main(String[] args) throws Exception {
        legacyBatchOverloadOmitsUnknownBatchBytesHeader();
        legacyCancellationOverloadOmitsUnknownBatchBytesHeader();
        explicitZeroBatchBytesAreSent();
        testUnknownReceiverKeepsSingleAttempt();
        testHealthFailureDoesNotProvePause();
        testPausedPreflightSendsNoPut();
        testEpochChangeClassifiesFastPauseResumeAsPaused();
        testUnchangedEpochKeepsOriginalUploadError();
        System.out.println("HttpFileUploaderTest passed");
    }

    private static void legacyBatchOverloadOmitsUnknownBatchBytesHeader() throws Exception {
        Map<String, String> headers = uploadAndCaptureHeaders(false, false);
        assertEquals(null, headers.get("x-android-sync-batch-total-bytes"),
                "legacy overload must not claim an unknown batch total is zero");
    }

    private static void legacyCancellationOverloadOmitsUnknownBatchBytesHeader() throws Exception {
        Map<String, String> headers = uploadAndCaptureHeaders(true, false);
        assertEquals(null, headers.get("x-android-sync-batch-total-bytes"),
                "legacy cancellation overload must not claim an unknown batch total is zero");
    }

    private static void explicitZeroBatchBytesAreSent() throws Exception {
        Map<String, String> headers = uploadAndCaptureHeaders(false, true);
        assertEquals("0", headers.get("x-android-sync-batch-total-bytes"),
                "an explicitly known zero-byte batch total must be sent");
    }

    private static void testUnknownReceiverKeepsSingleAttempt() throws Exception {
        AtomicInteger putCount = new AtomicInteger();
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(200, "{\"service\":\"Other\"}");
            }
            if ("PUT".equals(request.method)) {
                putCount.incrementAndGet();
                return ReceiverTestHttpServer.Response.empty(201);
            }
            return ReceiverTestHttpServer.Response.empty(404);
        })) {
            String target = server.uploadUrl();
            ReceiverControlClient.Session session = ReceiverControlClient.discover(target);
            assertEquals(false, session.isSupported(), "unknown service must not enable pause control");
            new HttpFileUploader().upload(
                    resolverFor(new byte[] { 1, 2, 3 }, new AtomicInteger()),
                    testItem(3), target, 1, 1, 3L, session, neverCancelled()
            );
            assertEquals(1, putCount.get(), "unknown receiver must keep the ordinary single attempt");
        }
    }

    private static void testHealthFailureDoesNotProvePause() throws Exception {
        AtomicInteger healthCount = new AtomicInteger();
        AtomicInteger putCount = new AtomicInteger();
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(200, nativeRoot());
            }
            if ("/health".equals(request.path)) {
                healthCount.incrementAndGet();
                return ReceiverTestHttpServer.Response.json(503, "{}");
            }
            if ("PUT".equals(request.method)) {
                putCount.incrementAndGet();
                return ReceiverTestHttpServer.Response.json(500, "{}");
            }
            return ReceiverTestHttpServer.Response.empty(404);
        })) {
            String target = server.uploadUrl();
            ReceiverControlClient.Session session = ReceiverControlClient.discover(target);
            IOException failure = captureUploadFailure(target, session);
            assertEquals(false, failure instanceof ReceiverPausedException,
                    "unavailable health is not positive pause evidence");
            assertEquals(1, putCount.get(), "health failures must not trigger a second PUT");
            assertEquals(2, healthCount.get(), "preflight and post-error health checks should be attempted");
        }
    }

    private static void testPausedPreflightSendsNoPut() throws Exception {
        AtomicInteger putCount = new AtomicInteger();
        AtomicInteger streamOpens = new AtomicInteger();
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(200, nativeRoot());
            }
            if ("/health".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(200, health("paused", 4));
            }
            if ("PUT".equals(request.method)) {
                putCount.incrementAndGet();
            }
            return ReceiverTestHttpServer.Response.empty(404);
        })) {
            String target = server.uploadUrl();
            ReceiverControlClient.Session session = ReceiverControlClient.discover(target);
            try {
                new HttpFileUploader().upload(
                        resolverFor(new byte[] { 1, 2, 3 }, streamOpens), testItem(3),
                        target, 1, 1, 3L, session, neverCancelled()
                );
                throw new AssertionError("paused receiver should stop before opening the media stream");
            } catch (ReceiverPausedException expected) {
                // expected
            }
            assertEquals(0, putCount.get(), "preflight pause must not issue PUT");
            assertEquals(0, streamOpens.get(), "preflight pause must not open media content");
        }
    }

    private static void testEpochChangeClassifiesFastPauseResumeAsPaused() throws Exception {
        AtomicInteger healthCount = new AtomicInteger();
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(200, nativeRoot());
            }
            if ("/health".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(
                        200,
                        health("running", healthCount.incrementAndGet() == 1 ? 4 : 5)
                );
            }
            if ("PUT".equals(request.method)) {
                return ReceiverTestHttpServer.Response.json(500, "{}");
            }
            return ReceiverTestHttpServer.Response.empty(404);
        })) {
            ReceiverControlClient.Session session = ReceiverControlClient.discover(server.uploadUrl());
            try {
                upload(server.uploadUrl(), session);
                throw new AssertionError("an epoch change must classify the interrupted PUT as paused");
            } catch (ReceiverPausedException expected) {
                assertEquals(2, healthCount.get(), "preflight and post-error snapshots should be used");
            }
        }
    }

    private static void testUnchangedEpochKeepsOriginalUploadError() throws Exception {
        AtomicInteger healthCount = new AtomicInteger();
        AtomicInteger putCount = new AtomicInteger();
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(200, nativeRoot());
            }
            if ("/health".equals(request.path)) {
                healthCount.incrementAndGet();
                return ReceiverTestHttpServer.Response.json(200, health("running", 9));
            }
            if ("PUT".equals(request.method)) {
                putCount.incrementAndGet();
                return ReceiverTestHttpServer.Response.json(500, "{}");
            }
            return ReceiverTestHttpServer.Response.empty(404);
        })) {
            ReceiverControlClient.Session session = ReceiverControlClient.discover(server.uploadUrl());
            IOException failure = captureUploadFailure(server.uploadUrl(), session);
            assertEquals(false, failure instanceof ReceiverPausedException,
                    "unchanged epoch must preserve the ordinary upload error");
            assertEquals(true, failure.getMessage().contains("500"), "original HTTP error should be preserved");
            assertEquals(1, putCount.get(), "ordinary upload error must not be retried");
            assertEquals(2, healthCount.get(), "classification should compare both snapshots");
        }
    }

    private static IOException captureUploadFailure(
            String target,
            ReceiverControlClient.Session session
    ) throws Exception {
        try {
            upload(target, session);
        } catch (IOException error) {
            return error;
        }
        throw new AssertionError("expected the test receiver to fail the upload");
    }

    private static void upload(String target, ReceiverControlClient.Session session) throws IOException {
        new HttpFileUploader().upload(
                resolverFor(new byte[] { 1, 2, 3 }, new AtomicInteger()), testItem(3),
                target, 1, 1, 3L, session, neverCancelled()
        );
    }

    private static ContentResolver resolverFor(byte[] body, AtomicInteger opens) {
        return new ContentResolver() {
            @Override
            public InputStream openInputStream(Uri uri) {
                opens.incrementAndGet();
                return new ByteArrayInputStream(body);
            }
        };
    }

    private static MediaItem testItem(long size) {
        return new MediaItem("pause-test", "content://media/pause-test", "probe.bin", size, 0L, false);
    }

    private static HttpFileUploader.CancellationSignal neverCancelled() {
        return new HttpFileUploader.CancellationSignal() {
            @Override
            public boolean isCancelled() {
                return false;
            }
        };
    }

    private static String nativeRoot() {
        return "{\"service\":\"Android Sync Receiver\",\"status\":\"ok\"}";
    }

    private static String health(String state, long epoch) {
        return "{\"status\":\"ok\",\"receiver_state\":\"" + state
                + "\",\"pause_epoch\":" + epoch + "}";
    }

    private static Map<String, String> uploadAndCaptureHeaders(
            boolean legacyCancellationOverload,
            boolean explicitZeroBatchBytes
    ) throws Exception {
        byte[] body = explicitZeroBatchBytes ? new byte[0] : new byte[] { 1, 2, 3 };
        MediaItem item = new MediaItem(
                "uploader-test",
                "content://media/uploader-test",
                "probe.bin",
                body.length,
                0L,
                false
        );
        ContentResolver resolver = new ContentResolver() {
            @Override
            public InputStream openInputStream(Uri uri) {
                return new ByteArrayInputStream(body);
            }
        };

        try (ServerSocket server = new ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))) {
            ExecutorService executor = Executors.newSingleThreadExecutor();
            try {
                Future<Map<String, String>> captured = executor.submit(() -> receiveRequest(server));
                String target = "http://127.0.0.1:" + server.getLocalPort() + "/uploads/";
                HttpFileUploader uploader = new HttpFileUploader();
                if (explicitZeroBatchBytes) {
                    uploader.upload(resolver, item, target, 1, 2, 0L);
                } else if (legacyCancellationOverload) {
                    uploader.upload(
                            resolver,
                            item,
                            target,
                            1,
                            2,
                            new HttpFileUploader.CancellationSignal() {
                                @Override
                                public boolean isCancelled() {
                                    return false;
                                }
                            }
                    );
                } else {
                    uploader.upload(resolver, item, target, 1, 2);
                }
                return captured.get(5, TimeUnit.SECONDS);
            } finally {
                executor.shutdownNow();
            }
        }
    }

    private static Map<String, String> receiveRequest(ServerSocket server) throws IOException {
        try (Socket socket = server.accept()) {
            socket.setSoTimeout(5_000);
            InputStream input = socket.getInputStream();
            ByteArrayOutputStream rawHeaders = new ByteArrayOutputStream();
            int matched = 0;
            byte[] terminator = { '\r', '\n', '\r', '\n' };
            while (matched < terminator.length) {
                int value = input.read();
                if (value < 0) {
                    throw new IOException("request ended before HTTP headers were complete");
                }
                rawHeaders.write(value);
                if (value == (terminator[matched] & 0xff)) {
                    matched++;
                } else {
                    matched = value == (terminator[0] & 0xff) ? 1 : 0;
                }
            }

            String[] lines = new String(rawHeaders.toByteArray(), StandardCharsets.UTF_8).split("\\r\\n");
            Map<String, String> headers = new HashMap<>();
            for (int i = 1; i < lines.length; i++) {
                int colon = lines[i].indexOf(':');
                if (colon > 0) {
                    headers.put(
                            lines[i].substring(0, colon).trim().toLowerCase(Locale.ROOT),
                            lines[i].substring(colon + 1).trim()
                    );
                }
            }

            int contentLength = Integer.parseInt(headers.getOrDefault("content-length", "0"));
            byte[] buffer = new byte[1024];
            int remaining = contentLength;
            while (remaining > 0) {
                int read = input.read(buffer, 0, Math.min(buffer.length, remaining));
                if (read < 0) {
                    throw new IOException("request body ended early");
                }
                remaining -= read;
            }

            OutputStream output = socket.getOutputStream();
            output.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    .getBytes(StandardCharsets.US_ASCII));
            output.flush();
            return headers;
        }
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(message + ": expected <" + expected + "> but was <" + actual + ">");
        }
    }
}
