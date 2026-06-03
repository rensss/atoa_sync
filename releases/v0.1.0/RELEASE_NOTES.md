# Android Sync v0.1.0

Initial working MVP release.

## Included

- Android debug APK: `AndroidSync-v0.1.0-debug.apk`
- Phone media scan through Android `MediaStore`
- Sync queue with thumbnails, item open action, retry, and scan feedback
- HTTP/WebDAV-style upload to a local receiver
- Receiver-side upload manifest for reconciliation
- Metadata preservation through original file bytes, receiver mtime, `uploads.jsonl`, and `.metadata.json`

## Install

Start receiver:

```bash
./receiver/start.sh
```

Install APK on the phone, then set the app target URL to the receiver URL:

```text
http://<computer-lan-ip>:8765/uploads/
```

## Verification

- `python3 -m unittest receiver.tests.test_receiver`
- `android/run_tests.sh`
- `android/build.sh`
- `apksigner verify android/build/AndroidSync-debug.apk`

## Known Limits

- APK is debug-signed.
- Background automatic sync is not implemented yet.
- macOS file creation time is not rewritten; phone-side creation/taken/added/modified metadata is preserved in sidecar JSON and upload logs.
