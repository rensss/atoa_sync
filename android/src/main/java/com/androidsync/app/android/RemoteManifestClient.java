package com.androidsync.app.android;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashSet;
import java.util.Set;

public final class RemoteManifestClient {
    public Snapshot fetch(String targetBaseUrl) throws IOException {
        URL manifestUrl = manifestUrl(targetBaseUrl);
        HttpURLConnection connection = (HttpURLConnection) manifestUrl.openConnection();
        connection.setRequestMethod("GET");
        connection.setConnectTimeout(5000);
        connection.setReadTimeout(8000);
        int responseCode = connection.getResponseCode();
        if (responseCode == 404) {
            connection.disconnect();
            return new Snapshot(new HashSet<String>(), new HashSet<String>());
        }
        if (responseCode < 200 || responseCode >= 300) {
            connection.disconnect();
            throw new IOException("Manifest failed with HTTP " + responseCode);
        }
        String body;
        try (InputStream input = new BufferedInputStream(connection.getInputStream())) {
            body = readUtf8(input);
        } finally {
            connection.disconnect();
        }
        JSONObject root;
        try {
            root = new JSONObject(body);
        } catch (JSONException error) {
            throw new IOException("Invalid manifest JSON", error);
        }
        JSONArray uploads = root.optJSONArray("uploads");
        Set<String> stableIds = new HashSet<>();
        Set<String> fingerprints = new HashSet<>();
        if (uploads == null) {
            return new Snapshot(stableIds, fingerprints);
        }
        for (int i = 0; i < uploads.length(); i++) {
            JSONObject entry = uploads.optJSONObject(i);
            if (entry == null) {
                continue;
            }
            String stableId = entry.optString("stable_id", "");
            if (!stableId.isEmpty()) {
                stableIds.add(stableId);
            }
            String filename = entry.optString("filename", "");
            long sizeBytes = entry.optLong("size_bytes", -1L);
            if (!filename.isEmpty() && sizeBytes >= 0L) {
                fingerprints.add(filename + ":" + sizeBytes);
            }
        }
        return new Snapshot(stableIds, fingerprints);
    }

    private URL manifestUrl(String targetBaseUrl) throws IOException {
        URL target = new URL(targetBaseUrl);
        String path = target.getPath();
        int uploadsIndex = path.indexOf("/uploads");
        String rootPath = uploadsIndex >= 0 ? path.substring(0, uploadsIndex + 1) : "/";
        return new URL(target.getProtocol(), target.getHost(), target.getPort(), rootPath + "manifest.json");
    }

    private String readUtf8(InputStream input) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[16 * 1024];
        int read;
        while ((read = input.read(buffer)) != -1) {
            output.write(buffer, 0, read);
        }
        return output.toString("UTF-8");
    }

    public static final class Snapshot {
        private final Set<String> stableIds;
        private final Set<String> fingerprints;

        private Snapshot(Set<String> stableIds, Set<String> fingerprints) {
            this.stableIds = stableIds;
            this.fingerprints = fingerprints;
        }

        public Set<String> stableIds() {
            return stableIds;
        }

        public Set<String> fingerprints() {
            return fingerprints;
        }
    }
}
