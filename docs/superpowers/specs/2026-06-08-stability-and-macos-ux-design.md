# Android Sync Stability and macOS UX Design

## Scope

This change addresses the reported Android crash and queue flicker, then
standardizes the macOS media-library layout, controls, localization, version
display, Quick Look behavior, failed-upload cleanup, and sorting semantics.

The implementation keeps the current dependency-free Android application and
SwiftPM macOS application. It does not replace either UI stack or add an
external update framework.

## Android Stability

### Queue rendering

The queue screen must not rebuild the activity content tree for every upload
state transition or pagination event. The screen will retain its current view
hierarchy and update the affected summary and task row in place.

Pagination will append the next bounded task window without replacing the
`ScrollView`, preserving the current scroll position. Filter or navigation
changes may still perform a full screen render because those are explicit user
transitions rather than continuous background updates.

### Thumbnail memory use

Thumbnail requests will use the actual rendered pixel target instead of a
density-expanded `96dp` request. A bounded in-memory cache will reuse small
thumbnails across row updates and screen transitions. Async results must only
be applied when the target view still represents the same media URI.

The detail preview will request a size bounded to the visible preview area,
with `OutOfMemoryError` handled alongside normal decode failures. Detached
views must not retain newly decoded bitmaps.

### Home status grid

Each recent-task tile remains square. Its image fills the square with centered
cropping, the tile clips image content to the rounded shape, and the status
border/strip remains visible above the image.

## macOS Window Layout

The main window will use native toolbar placements instead of an additional
toolbar row inside the detail content.

The window toolbar contains:

- current category title and item count
- date filter
- sort selection
- grid/list layout selection
- filename search
- settings entry
- inspector toggle at the right edge

The library content contains only receiver status and the media grid/list.
Search must not overlay the inspector or media detail content.

Date and sort controls use one menu layer with direct actions and checkmarks.
They must not wrap a `Picker` inside a `Menu`, which currently causes the extra
intermediate menu action.

## macOS Thumbnail Layout

Grid items use a fixed thumbnail frame of 180 by 124 points. The media preview
uses aspect-fit scaling inside that frame so the complete image remains
visible. The frame clips to a consistent rounded rectangle and supplies a
neutral background for unused letterbox space.

Grid metadata appears below the fixed preview and must not change the height or
position of neighboring thumbnails. List and inspector thumbnails also use
explicit fixed frames with aspect-fit scaling.

## Localization

The macOS app supports Simplified Chinese and English. A language picker in
Settings provides manual selection:

- Simplified Chinese is the default when no preference exists.
- English can be selected explicitly.
- The selection persists in `UserDefaults`.
- Switching language updates the primary app UI without relaunching.

User-facing application strings use centralized localized keys rather than
view-local English literals. System-generated file, date, byte-size, and error
descriptions remain system localized where appropriate.

## Settings

The existing `Settings` scene remains the canonical settings window. A visible
gear button in the main window toolbar opens it through SwiftUI's settings
action.

Settings contain:

- language
- receive folder
- receiver port
- launch at login
- local-network security description
- application version and build number

## Version Control

The repository-root `VERSION` file remains the single source for the public
release version and must use `major.minor.patch`.

The packaging script writes:

- `CFBundleShortVersionString` from `VERSION`
- `CFBundleVersion` from the Git commit count, with a timestamp fallback when
  Git metadata is unavailable

The app reads these values from `Bundle.main` and displays both in Settings.
This scope does not include online update checking.

## Date Filtering and Sorting

The app sorts by the macOS receive timestamp (`receivedAt`):

- Newest First: descending receive time
- Oldest First: ascending receive time
- Filename: localized ascending filename
- Largest First: descending byte size

Date filters use the same receive timestamp and the current calendar. Unit tests
will lock the visible titles to their comparison direction so labels and output
cannot drift apart.

## Quick Look

When exactly one non-deleted item is selected:

- pressing Space opens Quick Look
- pressing Space again closes Quick Look
- double-click and context-menu Quick Look remain available

The space command is scoped to the library window and must not fire while a
text field or rename sheet is editing. Closing Quick Look clears its retained
preview URL.

## Failed Upload Cleanup

A failed incoming upload must:

- close its temporary file handle
- remove its `.incoming/*.part` file
- remove any temporary in-progress UI state
- avoid creating a SwiftData library entity
- avoid appending a successful manifest record

Upload failures are distinct from receiver lifecycle failures. A rejected or
interrupted single upload may surface a transient status message, but it must
not set the receiver service itself to failed or repeatedly present a global
alert. Existing successfully received files are never removed by this cleanup.

## Verification

Android verification includes:

- queue/core regression tests
- APK compilation and signature verification
- device log review for OOM, fatal exception, ANR, skipped-frame, and thumbnail
  errors
- manual queue scrolling and active-upload checks

macOS verification includes:

- Swift unit tests for repository cleanup, sort direction, date filtering, and
  version parsing
- SwiftPM build and test
- packaged app Info.plist validation and code-sign verification
- runtime UI checks for toolbar placement, fixed thumbnails, settings,
  localization, menu behavior, inspector placement, search, and Space Quick
  Look toggling

