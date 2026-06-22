# Architecture

## System Context

Android Sync transfers media from an Android device to a native macOS receiver
or another HTTP/WebDAV-compatible destination on a trusted local network.

```text
Android MediaStore
        |
        v
MediaStoreScanner -> SyncQueue -> HttpFileUploader
        |               ^               |
        |               |               | HTTP PUT
        |       RemoteManifestClient    v
        +---------- reconciliation  macOS ReceiverService
                                         |
                                         v
                                  LibraryRepository
                                         |
                 +-----------------------+----------------------+
                 v                       v                      v
          media directories       metadata sidecars      uploads.jsonl
```

## Android Boundary

The Android app is dependency-free Java built directly with local Android SDK
tools.

- `MainActivity`: UI composition, navigation, scan/upload orchestration, and
  asynchronous thumbnail presentation.
- `MediaStoreScanner`: reads photos and videos from Android `MediaStore`.
- `SyncQueue`: synchronized in-memory task ownership, status transitions,
  filtering, summaries, and bounded visible windows.
- `RemoteManifestClient`: reads receiver history and identifies media already
  stored remotely.
- `HttpFileUploader`: streams media using HTTP `PUT` and Android Sync metadata
  headers.

The queue is the authoritative task state during a process lifetime. UI code
must consume queue snapshots or bounded windows and must not create a second,
independently mutable task model.

## macOS Boundary

The macOS app is a Swift 6 package targeting macOS 14+, split into:

- `AndroidSyncCore`: protocol parsing, network access policy, upload models,
  file policy, storage, manifest history, and the receiver.
- `AndroidSyncMac`: SwiftUI/SwiftData application state, views, settings,
  directory access, Quick Look, and menu bar lifecycle.

`ReceiverService` owns the `NWListener` and serial receiver queue. It accepts a
maximum of four concurrent connections. Each connection streams request bytes
into repository-managed temporary storage.

`LibraryRepository` is an actor and is the only owner of durable media-library
mutation. It validates size, chooses storage paths, atomically moves completed
temporary files, writes sidecar metadata, and appends manifest history.

## Protocol

Supported native receiver endpoints:

- `GET /`
- `GET /health`
- `GET /manifest.json`
- `PUT /uploads/<filename>`

Uploads include stable ID, size, MIME type, and available Android media
timestamps in headers. The receiver stores content without transcoding.

## Storage Model

```text
<selected-root>/
|-- .incoming/*.part
|-- photos/YYYY-MM/
|-- videos/YYYY-MM/
|-- files/YYYY-MM/
`-- uploads.jsonl
```

Each stored file may have a `.metadata.json` sidecar. `uploads.jsonl` is an
append-only event history used to construct the current manifest, including
deletion tombstones.

## Concurrency Model

- Android scanning, thumbnail decoding, and uploads must remain off the main
  thread. UI updates return to the Android main thread.
- `SyncQueue` synchronizes task-map access. Long I/O and bitmap decoding must
  never occur while holding its monitor.
- macOS listener and connection state run on one serial dispatch queue.
- macOS storage mutations run through the `LibraryRepository` actor.
- SwiftUI state belongs to the main actor through `AppModel`; receiver events
  must cross explicitly into UI state.

## Ownership Rules

- Platform code stays in its platform directory.
- Core network and storage behavior stays testable in `AndroidSyncCore`.
- SwiftUI views do not directly mutate files or parse HTTP.
- Android UI code does not directly own durable receiver history.
- Generated output belongs in ignored build directories or `dist/`.
