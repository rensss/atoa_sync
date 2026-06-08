# Android Sync for macOS

Native macOS 14+ receiver and media library for the Android Sync app.

## Run

```bash
./macos/build_and_run.sh
```

The packaged app is written to:

```text
dist/Android Sync.app
```

Run tests without opening the app:

```bash
swift test --package-path macos
```

## First launch

1. Choose a receive folder.
2. Allow incoming network connections if macOS asks.
3. Copy the upload address shown in the app.
4. Set that address as the target URL in the Android app.

The app starts receiving automatically after a folder is selected. Closing the
main window leaves the receiver running in the menu bar. Use **Quit Android
Sync** in the menu bar to stop the process.

## Storage compatibility

The macOS app keeps the existing receiver layout:

```text
photos/YYYY-MM/
videos/YYYY-MM/
files/YYYY-MM/
uploads.jsonl
```

Files are streamed to a temporary `.part` file and moved into place only after
the complete `Content-Length` has arrived. Media bytes are not transcoded or
compressed. The app preserves Android Sync timestamps, stable IDs, MIME type,
source IP, JSONL history, and `.metadata.json` sidecars.

Selecting an existing Python receiver directory imports its `uploads.jsonl`
history automatically.

## Receiver endpoints

- `GET /`
- `GET /health`
- `GET /manifest.json`
- `PUT /uploads/<filename>`

The receiver accepts loopback, IPv4 private/link-local, and IPv6 link-local or
unique-local source addresses. It does not use an authentication token, so it
should only be used on a trusted LAN.

## File management

The main window provides category filters, search, grid/list layouts, Quick
Look, Finder reveal, metadata inspection, rename, multiple selection, and Move
to Trash. Deleted items retain a manifest tombstone so the Android app does not
upload the same media again.
