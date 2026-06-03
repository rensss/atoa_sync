# Android Sync v0.1.1

Crash fix release.

## Fixed

- Queue tab no longer tries to render every scanned photo/video row at once.
- Queue display now shows a limited first page and a "show more" button for the next batch.

## Why

Version `0.1.0` scanned the full media library, then the queue tab built every row and thumbnail synchronously. Large photo libraries could crash or freeze the app when opening the queue.

## Verification

- `android/run_tests.sh`
- `python3 -m unittest receiver.tests.test_receiver`
- `android/build.sh`
- `apksigner verify`
