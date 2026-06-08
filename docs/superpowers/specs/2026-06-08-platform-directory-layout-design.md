# Platform Directory Layout Design

## Goal

Make the repository root describe the product as a whole while keeping all
platform-specific source, build configuration, scripts, and prototypes inside
`android/` or `macos/`.

## Target Layout

```text
.
|-- android/
|   |-- prototype/
|   |-- src/
|   |-- tests/
|   |-- build.sh
|   `-- run_tests.sh
|-- macos/
|   |-- Package.swift
|   |-- Resources/
|   |-- Sources/
|   |-- Tests/
|   `-- build_and_run.sh
|-- releases/
|-- CHANGELOG.md
|-- VERSION
`-- README.md
```

The Android browser prototype moves from the repository root to
`android/prototype/`, including its local image assets and QA report.

The Swift package manifest and packaging script move into `macos/`. SwiftPM
paths become relative to that directory, and the packaging script writes to
the repository-level `dist/` directory so existing packaged app output remains
in the same place.

## Receiver Removal

Delete the standalone Python `receiver/` implementation. It is not imported or
invoked by the Android or macOS applications, and the native macOS
`ReceiverService` provides the supported computer-side receiver.

Update current Android documentation to direct users to the macOS app or a
generic HTTP/WebDAV receiver. Historical release notes remain unchanged because
they document commands and capabilities that were valid for those releases.

## Repository Documentation

Add a root README that identifies the two platform directories and gives the
current test/build commands. Update platform READMEs so commands work from the
repository root and clearly state platform ownership.

## Verification

- Run Android unit tests with `./android/run_tests.sh`.
- Build and verify the Android debug APK with `./android/build.sh`.
- Run macOS tests with `swift test --package-path macos`.
- Build the macOS package with `swift build --package-path macos`.
- Check that active files contain no stale `receiver/`, root `Package.swift`,
  root prototype, or root build-script references.
