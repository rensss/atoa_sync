# Android Sync MVP

This is a dependency-free Android MVP built with the local Android SDK tools, not Gradle.

## Build

```bash
./android/run_tests.sh
./android/build.sh
```

The signed debug APK is written to:

```text
android/build/AndroidSync-debug.apk
```

## Runtime behavior

- Scans the phone media library through `MediaStore`.
- Queues photos and videos with stable de-duplication.
- Uploads waiting or failed tasks with HTTP/WebDAV-style `PUT`.
- Lets the user edit the LAN/NAS target URL inside the app.
- Shows a native home dashboard and queue detail screen.

For local computer receiving, start:

```bash
./receiver/start.sh
```

Then set the Android target URL to the LAN address printed by the receiver, for example:

```text
http://192.168.1.10:8765/uploads/
```

For Synology/QNAP/NAS use, enable WebDAV or run any receiver that accepts HTTP `PUT` at the configured target URL.
