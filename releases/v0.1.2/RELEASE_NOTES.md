# Android Sync v0.1.2

Stability and workflow update for large phone libraries.

## Queue and performance

- Queue tab no longer builds a full filtered list on the UI thread before paging.
- Home and queue screens do not calculate full queue summaries while the scanner is still indexing media.
- Bulk scan enqueue no longer holds the queue lock for the whole media library.
- Home and queue thumbnails no longer call `ImageView.setImageURI()` on the main thread; they load small system thumbnails on a background pool.
- Scrolling near the bottom automatically loads the next queue window.
- Queue filters use equal widths, and a floating control returns the list to the top.

## Media details

- Tapping a queue row opens an in-app detail screen.
- Photo and video previews use the original media URI with display-size decoding.
- Video details include explicit play/pause controls and an external-app fallback.
- File type, MIME type, size, sync state, and captured/added/modified timestamps are shown.

## Home and settings

- Recent tasks are displayed as a non-clickable 10-column status grid, capped at 50 items.
- A settings screen exposes receiver URL editing, connection status, rescanning, and app version.
- Secondary screens hide the bottom navigation and use status-bar safe spacing.
- Cards and controls use consistent rounded styling.

## Why

Version `0.1.1` limited visible queue rows, but the UI still copied and filtered the whole queue before applying that limit. On a large photo library this could block the main thread and trigger Android's input timeout ANR.

Device logs also showed full media decode work happening inside `MainActivity.thumbnail()` on the main thread, including 3000x4000 image decode and `Skipped 141 frames`. This release keeps placeholders visible immediately and swaps in thumbnails after background loading completes, while adding the missing queue, detail, and settings workflows.

## Verification

- `android/run_tests.sh`
- `python3 -m unittest receiver.tests.test_receiver`
- `android/build.sh`
- Device install via `adb install -r`
