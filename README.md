# Android Sync

Android Sync transfers photos and videos from an Android device to a macOS
computer or another HTTP/WebDAV-compatible destination on the local network.

## Repository layout

- `android/` contains the dependency-free Android app, tests, build scripts,
  and the browser UI prototype.
- `macos/` contains the native Swift receiver, media library, tests, SwiftPM
  manifest, and packaging script.
- `releases/` contains versioned APKs and historical release notes.

## Android

```bash
./android/run_tests.sh
./android/build.sh
```

The signed debug APK is written to
`android/build/AndroidSync-debug.apk`.

## macOS

```bash
swift test --package-path macos
./macos/build_and_run.sh
```

The packaging script writes the app bundle to `dist/Android Sync.app`.

See `android/README.md` and `macos/README.md` for platform-specific details.
