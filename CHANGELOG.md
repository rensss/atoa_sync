# Changelog

## 0.1.0 - 2026-06-03

- Added Android MVP for scanning phone photos/videos, queueing sync tasks, showing thumbnails, opening local media, retrying failures, and uploading over HTTP/WebDAV-style `PUT`.
- Added computer receiver service with `PUT /uploads/<filename>`, `GET /health`, `GET /manifest.json`, upload logging, sidecar metadata, and file mtime preservation from phone metadata.
- Added reconciliation so the Android app reads receiver history and marks already received items as complete.
- Added static web prototype and design QA notes used to shape the Android MVP.
- Added offline Android SDK build script and pure Java/Python tests.
