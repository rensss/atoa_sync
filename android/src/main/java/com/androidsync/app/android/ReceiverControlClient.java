package com.androidsync.app.android;

import com.androidsync.app.core.SyncTransferRunner;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.math.BigDecimal;
import java.net.HttpURLConnection;
import java.net.URL;

/** Optional pause-control protocol supported only by the native macOS receiver. */
public final class ReceiverControlClient {
    private static final String SERVICE_ID = "Android Sync Receiver";
    private static final int CONNECT_TIMEOUT_MILLIS = 3000;
    private static final int READ_TIMEOUT_MILLIS = 5000;
    private static final int MAX_RESPONSE_BYTES = 64 * 1024;
    private static final long POLL_INTERVAL_MILLIS = 1000L;
    private static final long CANCELLATION_CHECK_MILLIS = 100L;

    private ReceiverControlClient() {
    }

    public static Session discover(String uploadBaseUrl) {
        try {
            URL rootUrl = rootUrl(uploadBaseUrl);
            JSONObject root = getJson(rootUrl);
            return new Session(
                    rootUrl,
                    SERVICE_ID.equals(root.optString("service", ""))
            );
        } catch (IOException error) {
            return new Session(null, false);
        }
    }

    public static final class Snapshot {
        private final String state;
        private final long pauseEpoch;

        private Snapshot(String state, long pauseEpoch) {
            this.state = state;
            this.pauseEpoch = pauseEpoch;
        }

        public String state() {
            return state;
        }

        public long pauseEpoch() {
            return pauseEpoch;
        }
    }

    public static final class Session {
        private final URL rootUrl;
        private final boolean supported;

        private Session(URL rootUrl, boolean supported) {
            this.rootUrl = rootUrl;
            this.supported = supported;
        }

        public boolean isSupported() {
            return supported;
        }

        public Snapshot readHealth() throws IOException {
            if (!supported || rootUrl == null) {
                throw new IOException("Native receiver pause health is unavailable");
            }
            JSONObject health = getJson(healthUrl(rootUrl));
            String status = health.optString("status", "");
            String state = health.optString("receiver_state", "");
            Object epochValue = health.opt("pause_epoch");
            if (!"ok".equals(status)
                    || !("running".equals(state)
                    || "pausing".equals(state)
                    || "paused".equals(state))
                    || !(epochValue instanceof Number)) {
                throw new IOException("Invalid receiver health response");
            }
            long epoch;
            try {
                epoch = new BigDecimal(epochValue.toString()).longValueExact();
            } catch (ArithmeticException | NumberFormatException error) {
                throw new IOException("Invalid receiver health pause_epoch", error);
            }
            if (epoch < 0L) {
                throw new IOException("Invalid receiver health pause_epoch");
            }
            return new Snapshot(state, epoch);
        }

        public void awaitRunning(SyncTransferRunner.CancellationSignal cancellation)
                throws IOException {
            if (!supported) {
                return;
            }
            while (true) {
                throwIfCancelled(cancellation);
                Snapshot snapshot = null;
                try {
                    snapshot = readHealth();
                } catch (IOException ignored) {
                    // A temporary control-channel outage is not confirmation that the receiver resumed.
                }
                throwIfCancelled(cancellation);
                if (snapshot != null && "running".equals(snapshot.state())) {
                    return;
                }
                waitBeforeNextPoll(cancellation);
            }
        }
    }

    private static URL rootUrl(String uploadBaseUrl) throws IOException {
        URL uploadUrl = new URL(uploadBaseUrl);
        String path = uploadUrl.getPath();
        int uploadsIndex = path.indexOf("/uploads/");
        if (uploadsIndex < 0 && path.endsWith("/uploads")) {
            uploadsIndex = path.length() - "/uploads".length();
        }
        String rootPath = uploadsIndex >= 0 ? path.substring(0, uploadsIndex + 1) : "/";
        if (rootPath.isEmpty()) {
            rootPath = "/";
        }
        return new URL(
                uploadUrl.getProtocol(),
                uploadUrl.getHost(),
                uploadUrl.getPort(),
                rootPath
        );
    }

    private static URL healthUrl(URL rootUrl) throws IOException {
        String rootPath = rootUrl.getPath();
        if (!rootPath.endsWith("/")) {
            rootPath += "/";
        }
        return new URL(
                rootUrl.getProtocol(),
                rootUrl.getHost(),
                rootUrl.getPort(),
                rootPath + "health"
        );
    }

    private static JSONObject getJson(URL url) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setRequestMethod("GET");
        connection.setConnectTimeout(CONNECT_TIMEOUT_MILLIS);
        connection.setReadTimeout(READ_TIMEOUT_MILLIS);
        try {
            int responseCode = connection.getResponseCode();
            if (responseCode < 200 || responseCode >= 300) {
                throw new IOException("Receiver control request failed with HTTP " + responseCode);
            }
            try (InputStream input = new BufferedInputStream(connection.getInputStream())) {
                String body = readUtf8(input);
                try {
                    return new JSONObject(body);
                } catch (JSONException error) {
                    throw new IOException("Invalid receiver control JSON", error);
                }
            }
        } finally {
            connection.disconnect();
        }
    }

    private static String readUtf8(InputStream input) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        int read;
        while ((read = input.read(buffer)) != -1) {
            if (output.size() + read > MAX_RESPONSE_BYTES) {
                throw new IOException("Receiver control response is too large");
            }
            output.write(buffer, 0, read);
        }
        return output.toString("UTF-8");
    }

    private static void throwIfCancelled(SyncTransferRunner.CancellationSignal cancellation)
            throws InterruptedIOException {
        if (cancellation != null && cancellation.isCancelled()) {
            throw new InterruptedIOException("同步已停止");
        }
    }

    private static void waitBeforeNextPoll(
            SyncTransferRunner.CancellationSignal cancellation
    ) throws InterruptedIOException {
        long deadline = System.nanoTime() + POLL_INTERVAL_MILLIS * 1_000_000L;
        while (true) {
            throwIfCancelled(cancellation);
            long remainingNanos = deadline - System.nanoTime();
            if (remainingNanos <= 0L) {
                return;
            }
            long sleepMillis = Math.min(
                    CANCELLATION_CHECK_MILLIS,
                    Math.max(1L, remainingNanos / 1_000_000L)
            );
            try {
                Thread.sleep(sleepMillis);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                InterruptedIOException interrupted = new InterruptedIOException("同步已停止");
                interrupted.initCause(error);
                throw interrupted;
            }
        }
    }
}
