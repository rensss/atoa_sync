import com.androidsync.app.android.ReceiverControlClient;
import com.androidsync.app.core.SyncTransferRunner;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

public final class ReceiverControlClientTest {
    public static void main(String[] args) throws Exception {
        testDiscoveryAndHealthSnapshot();
        testMalformedHealthIsRejected();
        testFractionalPauseEpochIsRejected();
        testWaitRetriesHealthOutage();
        testCancellationDuringAwaitRunning();
        System.out.println("ReceiverControlClientTest passed");
    }

    private static void testDiscoveryAndHealthSnapshot() throws Exception {
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(
                        200,
                        "{\"service\":\"Android Sync Receiver\",\"status\":\"ok\"}"
                );
            }
            if ("/health".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(200, health("paused", 4));
            }
            return ReceiverTestHttpServer.Response.empty(404);
        })) {
            ReceiverControlClient.Session session = ReceiverControlClient.discover(server.uploadUrl());
            assertEquals(true, session.isSupported(), "exact service identity enables receiver control");
            ReceiverControlClient.Snapshot paused = session.readHealth();
            assertEquals("paused", paused.state(), "health should expose receiver pause state");
            assertEquals(4L, paused.pauseEpoch(), "health should expose pause epoch");
        }
    }

    private static void testMalformedHealthIsRejected() throws Exception {
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(
                        200,
                        "{\"service\":\"Android Sync Receiver\"}"
                );
            }
            return ReceiverTestHttpServer.Response.json(
                    200,
                    "{\"status\":\"ok\",\"receiver_state\":\"paused\",\"pause_epoch\":-1}"
            );
        })) {
            ReceiverControlClient.Session session = ReceiverControlClient.discover(server.uploadUrl());
            try {
                session.readHealth();
                throw new AssertionError("negative pause epoch must be rejected as malformed health");
            } catch (IOException expected) {
                assertEquals(true, expected.getMessage().contains("health"),
                        "invalid response should be reported as a health protocol error");
            }
        }
    }

    private static void testFractionalPauseEpochIsRejected() throws Exception {
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(
                        200,
                        "{\"service\":\"Android Sync Receiver\"}"
                );
            }
            return ReceiverTestHttpServer.Response.json(
                    200,
                    "{\"status\":\"ok\",\"receiver_state\":\"paused\",\"pause_epoch\":1.5}"
            );
        })) {
            ReceiverControlClient.Session session = ReceiverControlClient.discover(server.uploadUrl());
            try {
                session.readHealth();
                throw new AssertionError("fractional pause epoch must be rejected as malformed health");
            } catch (IOException expected) {
                assertEquals(true, expected.getMessage().contains("health"),
                        "fractional epoch should be reported as a health protocol error");
            }
        }
    }

    private static void testWaitRetriesHealthOutage() throws Exception {
        AtomicInteger healthRequests = new AtomicInteger();
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(
                        200,
                        "{\"service\":\"Android Sync Receiver\"}"
                );
            }
            int requestNumber = healthRequests.incrementAndGet();
            if (requestNumber == 1) {
                return ReceiverTestHttpServer.Response.json(503, "{}");
            }
            if (requestNumber == 2) {
                return ReceiverTestHttpServer.Response.json(200, health("paused", 2));
            }
            return ReceiverTestHttpServer.Response.json(200, health("running", 2));
        })) {
            ReceiverControlClient.Session session = ReceiverControlClient.discover(server.uploadUrl());
            session.awaitRunning(neverCancelled());
            assertEquals(3, healthRequests.get(), "wait must retry an outage and remain waiting while paused");
        }
    }

    private static void testCancellationDuringAwaitRunning() throws Exception {
        AtomicBoolean cancelled = new AtomicBoolean(false);
        try (ReceiverTestHttpServer server = new ReceiverTestHttpServer(request -> {
            if ("/".equals(request.path)) {
                return ReceiverTestHttpServer.Response.json(
                        200,
                        "{\"service\":\"Android Sync Receiver\"}"
                );
            }
            return ReceiverTestHttpServer.Response.json(200, health("paused", 2));
        })) {
            ReceiverControlClient.Session session = ReceiverControlClient.discover(server.uploadUrl());
            Thread canceller = new Thread(() -> {
                try {
                    Thread.sleep(150L);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
                cancelled.set(true);
            });
            canceller.setDaemon(true);
            canceller.start();

            try {
                session.awaitRunning(new SyncTransferRunner.CancellationSignal() {
                    @Override
                    public boolean isCancelled() {
                        return cancelled.get();
                    }
                });
                throw new AssertionError("pause wait should be cancelled promptly");
            } catch (InterruptedIOException expected) {
                assertEquals(true, cancelled.get(), "cancellation must remain distinct from receiver state");
            }
            canceller.join(1000L);
        }
    }

    private static SyncTransferRunner.CancellationSignal neverCancelled() {
        return new SyncTransferRunner.CancellationSignal() {
            @Override
            public boolean isCancelled() {
                return false;
            }
        };
    }

    private static String health(String state, long epoch) {
        return "{\"status\":\"ok\",\"receiver_state\":\"" + state
                + "\",\"pause_epoch\":" + epoch + "}";
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            throw new AssertionError(message + ": expected <" + expected + "> but was <" + actual + ">");
        }
    }
}

final class ReceiverTestHttpServer implements AutoCloseable {
    interface Handler {
        Response handle(Request request) throws Exception;
    }

    static final class Request {
        final String method;
        final String path;
        final Map<String, String> headers;
        final byte[] body;

        Request(String method, String path, Map<String, String> headers, byte[] body) {
            this.method = method;
            this.path = path;
            this.headers = headers;
            this.body = body;
        }
    }

    static final class Response {
        final int status;
        final byte[] body;
        final String contentType;

        private Response(int status, String body, String contentType) {
            this.status = status;
            this.body = body.getBytes(StandardCharsets.UTF_8);
            this.contentType = contentType;
        }

        static Response json(int status, String body) {
            return new Response(status, body, "application/json");
        }

        static Response empty(int status) {
            return new Response(status, "", "text/plain");
        }
    }

    private final ServerSocket server;
    private final Handler handler;
    private final Thread worker;

    ReceiverTestHttpServer(Handler handler) throws IOException {
        this.handler = handler;
        server = new ServerSocket(0, 16, InetAddress.getByName("127.0.0.1"));
        worker = new Thread(this::serve, "receiver-control-test-server");
        worker.setDaemon(true);
        worker.start();
    }

    String uploadUrl() {
        return "http://127.0.0.1:" + server.getLocalPort() + "/uploads/";
    }

    @Override
    public void close() throws IOException {
        server.close();
        try {
            worker.join(1000L);
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
        }
    }

    private void serve() {
        while (!server.isClosed()) {
            try (Socket socket = server.accept()) {
                socket.setSoTimeout(5000);
                Request request = readRequest(socket.getInputStream());
                Response response = handler.handle(request);
                writeResponse(socket.getOutputStream(), response);
            } catch (IOException error) {
                if (!server.isClosed()) {
                    error.printStackTrace();
                }
            } catch (Exception error) {
                error.printStackTrace();
            }
        }
    }

    private static Request readRequest(InputStream input) throws IOException {
        ByteArrayOutputStream headerBytes = new ByteArrayOutputStream();
        int matched = 0;
        byte[] separator = { '\r', '\n', '\r', '\n' };
        while (matched < separator.length) {
            int value = input.read();
            if (value < 0) {
                throw new IOException("request ended before headers were complete");
            }
            headerBytes.write(value);
            if (value == (separator[matched] & 0xff)) {
                matched++;
            } else {
                matched = value == (separator[0] & 0xff) ? 1 : 0;
            }
        }
        String[] lines = new String(headerBytes.toByteArray(), StandardCharsets.UTF_8).split("\\r\\n");
        String[] requestLine = lines[0].split(" ");
        Map<String, String> headers = new HashMap<>();
        for (int index = 1; index < lines.length; index++) {
            int colon = lines[index].indexOf(':');
            if (colon > 0) {
                headers.put(
                        lines[index].substring(0, colon).trim().toLowerCase(Locale.ROOT),
                        lines[index].substring(colon + 1).trim()
                );
            }
        }
        int remaining = Integer.parseInt(headers.getOrDefault("content-length", "0"));
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        byte[] buffer = new byte[1024];
        while (remaining > 0) {
            int read = input.read(buffer, 0, Math.min(buffer.length, remaining));
            if (read < 0) {
                throw new IOException("request body ended early");
            }
            body.write(buffer, 0, read);
            remaining -= read;
        }
        return new Request(requestLine[0], requestLine[1], headers, body.toByteArray());
    }

    private static void writeResponse(OutputStream output, Response response) throws IOException {
        String reason = response.status == 200 ? "OK"
                : response.status == 201 ? "Created"
                : response.status == 503 ? "Service Unavailable"
                : response.status == 500 ? "Internal Server Error"
                : response.status == 404 ? "Not Found" : "Response";
        output.write(("HTTP/1.1 " + response.status + " " + reason + "\r\n"
                + "Content-Type: " + response.contentType + "\r\n"
                + "Content-Length: " + response.body.length + "\r\n"
                + "Connection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));
        output.write(response.body);
        output.flush();
    }
}
