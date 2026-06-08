# Changelog

## 0.1.2 - 2026-06-08

- Fixed queue ANR by avoiding full queue copies and filtering on the UI thread.
- Changed queue access to use queue-owned visible windows.
- Avoided summary and queue rendering while a full media scan is still indexing.
- Reduced queue lock contention during bulk media enqueue.
- Moved media thumbnail decoding off the UI thread and kept queue/home rows on lightweight placeholders until thumbnails load.
- Added automatic queue pagination, aligned filters, and a one-tap return-to-top control.
- Added an in-app photo/video detail screen with metadata, playback controls, and external-app fallback.
- Added a settings screen for receiver configuration, rescanning, connection status, and version information.
- Replaced the home recent-task list with a non-clickable 10-column status grid capped at 50 items.
- Added status-bar safe spacing, consistent rounded controls, and removed bottom navigation from secondary screens.

## 0.1.1 - 2026-06-03

- Fixed queue tab crash risk by limiting queue rendering to a paged window instead of creating all scanned media rows and thumbnails at once.
- Added a tested `TaskWindow` helper for capped queue display.

## 0.1.0 - 2026-06-03

- Added Android MVP for scanning phone photos/videos, queueing sync tasks, showing thumbnails, opening local media, retrying failures, and uploading over HTTP/WebDAV-style `PUT`.
- Added computer receiver service with `PUT /uploads/<filename>`, `GET /health`, `GET /manifest.json`, upload logging, sidecar metadata, and file mtime preservation from phone metadata.
- Added reconciliation so the Android app reads receiver history and marks already received items as complete.
- Added static web prototype and design QA notes used to shape the Android MVP.
- Added offline Android SDK build script and pure Java/Python tests.
