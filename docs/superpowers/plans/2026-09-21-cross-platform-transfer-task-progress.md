# Cross-Platform Transfer Task Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make macOS show whole-task transfer remaining bytes and ETA, while keeping the single transfer header fixed at the top of every library state.

**Architecture:** Android computes the actual uploadable batch after remote-manifest filtering and sends an optional total-byte header with each upload. macOS carries that value through HTTP metadata and receiver events into `AppModel`, which derives whole-task remaining bytes and ETA from completed bytes, active bytes, and the existing speed window. `ContentView` owns one fixed vertical header above a full-size `LibraryView`, so empty categories cannot center the header.

**Tech Stack:** Java 8 Android core classes; Swift 6, SwiftUI, XCTest, Swift Package Manager; no new third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-09-21-cross-platform-transfer-task-progress-design.md`

## Global Constraints

- Keep Android Java 8, SDK 35, `minSdkVersion=26`, `targetSdkVersion=35`; do not add Gradle, AndroidX, or third-party dependencies.
- Keep macOS deployment at macOS 14+ and use the existing Swift Package Manager targets.
- The new `X-Android-Sync-Batch-Total-Bytes` header is optional and backward compatible.
- Existing Android overloads that lack the batch-byte total omit the header; an explicitly known zero-byte batch sends `0`.
- Calculate batch totals from actual `WAITING`/`FAILED` tasks after remote-manifest filtering; do not count skipped remote-existing tasks as remaining work.
- Preserve ReceiverService upload commit, `.part` handling, manifest, storage layout, delete behavior, and existing Android notification semantics.
- Do not commit or push in this shared worktree; preserve unrelated B32/B33/B35 changes.
- Project documentation is Chinese by default; API names, paths, and header names stay unchanged.

## Review Focus

- All selected tasks already exist remotely: the runner must send no upload and must not divide by zero or manufacture a macOS progress card. Test in Task 1.
- A batch contains zero-byte files or sums past `Int64.max`: totals must remain non-negative and saturate safely. Test in Task 1 and Task 2.
- A compatibility uploader overload has no byte total: omit the header; an explicit zero total remains valid. Verify over loopback HTTP in Task 1.
- A legacy Android client omits total bytes: a single file may use its own remaining bytes, but an old multi-file batch must not present one file's bytes or a false ETA as the whole task. Test in Task 3.
- Events arrive for multiple active uploads or after a stale/missing upload ID: aggregation and cleanup must not produce negative remaining bytes or retain stale state. Test in Task 3.
- An empty “其他文件”/“已删除” category uses `ContentUnavailableView`: the transfer header must remain at the outer top while only the empty-state content is centered below it. Verify in Task 4 UI checks.

---

### Task 1: Android actual-batch summary and request header

**Files:**
- Modify: `android/src/main/java/com/androidsync/app/core/SyncTransferRunner.java`
- Modify: `android/src/main/java/com/androidsync/app/android/HttpFileUploader.java`
- Modify: `android/src/main/java/com/androidsync/app/SyncForegroundService.java`
- Modify: `android/run_tests.sh`
- Create: `android/tests/stubs/android/content/ContentResolver.java`
- Create: `android/tests/stubs/android/net/Uri.java`
- Create: `android/tests/stubs/android/os/Build.java`
- Test: `android/tests/HttpFileUploaderTest.java`
- Test: `android/tests/SyncTransferRunnerTest.java`

**Interfaces:**
- Consumes: existing `SyncQueue.findById`, `SyncStatus.WAITING`, `SyncStatus.FAILED`, and `MediaItem.sizeBytes()`.
- Produces: `SyncTransferRunner.Uploader.upload(..., int batchIndex, int batchTotal, long batchTotalBytes, CancellationSignal cancellation)` and the HTTP request header `X-Android-Sync-Batch-Total-Bytes`.

- [x] **Step 1: Extend the runner test fixture to capture batch metadata**

Add a test uploader that records each task name, `batchIndex`, `batchTotal`, and `batchTotalBytes`. Add a scenario with four queued tasks, mark one with `queue.markRemoteExisting(...)` and another as `FAILED`, run all four IDs, and assert that only the waiting tasks and failed retry are uploaded.

Expected assertions:

```java
assertEquals(Arrays.asList("first.jpg", "third.jpg", "failed.jpg"), uploadedNames);
assertEquals(Arrays.asList(1, 2, 3), batchIndexes);
assertEquals(Arrays.asList(3, 3, 3), batchTotals);
assertEquals(Arrays.asList(750L, 750L, 750L), batchTotalBytes);
```

- [x] **Step 2: Run the focused Android test and verify it fails for the missing interface/data**

Run: `./android/run_tests.sh`

Expected: compilation failure because the test uploader does not yet receive `batchTotalBytes` and the runner still reports the original task-list total.

- [x] **Step 3: Add actual uploadable-task summary to `SyncTransferRunner`**

Before the upload loop, scan `taskIds` and retain IDs whose current task status is `WAITING` or `FAILED`. Compute:

```java
int batchTotal = uploadableTaskIds.size();
long batchTotalBytes = 0L;
for (String taskId : uploadableTaskIds) {
    SyncTask task = queue.findById(taskId);
    long size = Math.max(0L, task.media().sizeBytes());
    batchTotalBytes = saturatedAdd(batchTotalBytes, size);
}
```

Use an explicit `Set<String>` or equivalent lookup so the upload loop skips the already-filtered IDs without changing the existing cancellation and terminal-state behavior. Add a private `saturatedAdd(long left, long right)` that returns `Long.MAX_VALUE` on overflow. Pass `batchTotalBytes` to `Uploader.upload`; if `batchTotal == 0`, the loop emits no uploads and `onFinished` still runs normally.

- [x] **Step 4: Add the new uploader parameter and HTTP header**

Change the `Uploader` interface, the `SyncForegroundService` implementation, and the `HttpFileUploader` overloads to carry `long batchTotalBytes`. Preserve existing overloads with a negative “unknown” sentinel so they omit the optional byte-total header; reserve `0L` for a batch whose total is known to be zero. In the request setup, keep the existing index/total header condition and add:

```java
if (batchIndex > 0 && batchTotal > 0 && batchTotalBytes >= 0L) {
    connection.setRequestProperty(
            "X-Android-Sync-Batch-Total-Bytes",
            String.valueOf(batchTotalBytes)
    );
}
```

- [x] **Step 5: Add overflow and all-skipped test cases**

Add one runner test with two non-negative sizes whose sum would overflow `long`; assert every upload receives `Long.MAX_VALUE`. Add one test where all task IDs are remote-existing; assert the uploader is never called and the finish listener still runs.

- [x] **Step 6: Run the complete Android suite**

Run: `./android/run_tests.sh`

Expected: all existing Android tests and the new batch-summary tests pass with exit 0.

The JVM suite also runs `HttpFileUploaderTest` against a loopback HTTP server to verify that compatibility overloads omit unknown totals and the explicit zero-byte overload sends `0`.

---

### Task 2: macOS protocol and receiver metadata propagation

**Files:**
- Modify: `macos/Sources/AndroidSyncCore/UploadModels.swift`
- Modify: `macos/Sources/AndroidSyncCore/HTTPProtocol.swift`
- Modify: `macos/Sources/AndroidSyncCore/ReceiverService.swift`
- Test: `macos/Tests/AndroidSyncCoreTests/HTTPProtocolTests.swift`
- Test: `macos/Tests/AndroidSyncCoreTests/ReceiverServiceTests.swift`

**Interfaces:**
- Consumes: `X-Android-Sync-Batch-Total-Bytes` from Task 1, plus existing `Content-Length`, batch index, and batch total headers.
- Produces: `UploadMetadata.batchTotalBytes: Int64?` and `ReceiverServiceEvent.uploadStarted(..., batchTotalBytes: Int64? = nil)`.

- [x] **Step 1: Add failing HTTP routing assertions for the new metadata**

Extend the existing upload route test request with:

```text
X-Android-Sync-Batch-Total-Bytes: 123456
```

Assert the returned `.upload` metadata has `batchTotalBytes == 123456`. Add a second request with `-1` and a third with an overflowing integer; both must produce `nil` metadata rather than throw a routing error.

- [x] **Step 2: Run the focused Core tests and verify the new assertions fail**

Run: `swift test --package-path macos --filter 'HTTPProtocolTests|ReceiverServiceTests'`

Expected: the new metadata assertion fails because `UploadMetadata` and the router do not yet carry the header.

- [x] **Step 3: Extend the metadata and route parser**

Add `public let batchTotalBytes: Int64?` to `UploadMetadata` with a defaulted initializer argument. In `ReceiverRouter.route`, parse `x-android-sync-batch-total-bytes` with an `Int64` helper that returns `nil` for missing, invalid, negative, or overflowing values. Keep invalid optional metadata non-fatal and preserve all existing route validation.

- [x] **Step 4: Propagate the field through `ReceiverService`**

Add the defaulted `batchTotalBytes` argument to `ReceiverServiceEvent.uploadStarted`, and pass `metadata.batchTotalBytes` at the existing upload-start emission. Update only the event construction and related pattern matches required for compilation.

- [x] **Step 5: Verify Core tests are green**

Run: `swift test --package-path macos --filter 'HTTPProtocolTests|ReceiverServiceTests'`

Expected: all focused Core tests pass with exit 0, including positive, negative, and overflow header cases.

---

### Task 3: macOS whole-task remaining bytes and ETA state

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Stores/AppModel.swift`
- Test: `macos/Tests/AndroidSyncMacTests/TransferProgressTests.swift`
- Test: `macos/Tests/AndroidSyncMacTests/TransferCardStateTests.swift`

**Interfaces:**
- Consumes: `ReceiverServiceEvent.uploadStarted(..., batchTotalBytes:)` from Task 2 and the existing `transferSpeedBytesPerSecond` sliding-window calculation.
- Produces: `AppModel.transferRemainingBytes: Int64?`, `AppModel.transferEstimatedSeconds: TimeInterval?`, `AppModel.transferRemainingDescription`, `AppModel.transferETADescription`, and pure helper `AppModel.transferETA(remainingBytes:bytesPerSecond:)`.

- [x] **Step 1: Add failing tests for whole-task remaining bytes**

Add a two-file batch test: first upload has expected size 400 and batch total bytes 1000; after 100 bytes of progress, assert `transferRemainingBytes == 900`. Store the first upload, start the second upload with expected size 600 and the same batch total, and assert the remaining value is 600 before any second-file bytes arrive.

Add a concurrent-upload test with two active uploads and a batch total of 1000; assert remaining uses the sum of both active `bytesReceived` values, not either file's remaining value.

- [x] **Step 2: Add failing tests for ETA and legacy fallback**

Add pure-helper assertions:

```swift
XCTAssertEqual(
    AppModel.transferETA(remainingBytes: 1_000_000, bytesPerSecond: 500_000),
    2
)
XCTAssertNil(AppModel.transferETA(remainingBytes: 1, bytesPerSecond: 0))
```

Add state assertions that a new multi-file upload with batch count but no batch total bytes returns `nil` for `transferRemainingBytes` and `transferEstimatedSeconds`, while a single upload without batch headers returns its current-file remaining bytes and no ETA until speed is available. Assert `resetTransferCard()` clears both values.

- [x] **Step 3: Run the focused transfer tests and verify they fail**

Run: `swift test --package-path macos --filter 'TransferProgressTests|TransferCardStateTests'`

Expected: compilation or assertion failures because the new state properties and batch-byte accounting do not exist.

- [x] **Step 4: Add batch-byte accounting to `AppModel`**

Extend `ActiveUpload` with `batchTotalBytes: Int64?`. Add private burst state for optional total bytes, completed bytes, and terminal upload count. On `.uploadStarted`, initialize a fresh burst only when the card is not already receiving, or when a new first index follows an unfinished burst with no active upload; retain the optional batch total across sequential uploads. On `.uploadProgress`, keep the existing per-upload byte update and speed samples.

Implement:

```swift
var transferRemainingBytes: Int64? {
    if let total = burstTotalBytes {
        let activeReceived = activeUploads.values.reduce(0) {
            Self.saturatedAdd($0, max(0, $1.bytesReceived))
        }
        let received = Self.saturatedAdd(burstCompletedBytes, activeReceived)
        return max(0, total - received)
    }
    guard activeUploads.count == 1,
          activeUploads.values.first?.batchTotal == nil
    else { return nil }
    return activeUploadsRemainingBytes
}
```

For every stored upload in the burst, add its actual record size to `burstCompletedBytes` with saturated addition, even if that request omitted the optional batch-byte header; the burst may learn its total from another upload. Count both stored and failed uploads as terminal so out-of-order failures cannot leave a fully terminal batch stuck. Add the private/static `saturatedAdd(Int64, Int64) -> Int64` helper used by byte aggregation and overflow-safe received-byte calculation. Preserve the existing immediate reset for single/no-batch uploads and intermediate-batch visibility behavior.

- [x] **Step 5: Implement the ETA helper and descriptions**

Add:

```swift
static func transferETA(
    remainingBytes: Int64,
    bytesPerSecond: Double
) -> TimeInterval? {
    guard remainingBytes >= 0, bytesPerSecond > 0 else { return nil }
    return Double(remainingBytes) / bytesPerSecond
}
```

Make `transferEstimatedSeconds` call this helper with `transferRemainingBytes` and the existing speed property. Add model descriptions that return formatted bytes/duration when available and localized “计算中”/“calculating” otherwise. Format duration as rounded-up seconds, using `h:mm:ss` for an hour or more and `m:ss` below an hour.

- [x] **Step 6: Verify focused transfer tests are green**

Run: `swift test --package-path macos --filter 'TransferProgressTests|TransferCardStateTests'`

Expected: all focused progress/state tests pass with exit 0, including reset and legacy fallback behavior.

---

### Task 4: Fixed header layout and localized task-level copy

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Views/ContentView.swift`
- Modify: `macos/Sources/AndroidSyncMac/Views/LibraryView.swift`
- Modify: `macos/Sources/AndroidSyncMac/Views/TransferCardRow.swift`
- Modify: `macos/Sources/AndroidSyncMac/Support/Localization.swift`
- Test: `macos/Tests/AndroidSyncMacTests/LocalizationTests.swift`

**Interfaces:**
- Consumes: `AppModel.transferRemainingDescription` and `AppModel.transferETADescription` from Task 3.
- Produces: one detail-level `VStack` with `TransferCardRow` above a full-size `LibraryView`; localized progress copy with task-level remaining and ETA.

- [x] **Step 1: Add failing localization assertions**

Extend `LocalizationTests` to assert the new calculating/duration keys have explicit Chinese and English values and that the progress format contains four substitutions for completed count, total count, remaining description, and ETA description.

- [x] **Step 2: Run the focused localization test and verify it fails**

Run: `swift test --package-path macos --filter LocalizationTests`

Expected: failure because the new localization keys/copy are not present.

- [x] **Step 3: Move the transfer header outside `LibraryView`**

In the receive-directory branch of `ContentView`, replace the `LibraryView.safeAreaInset` composition with:

```swift
VStack(spacing: 0) {
    TransferCardRow(model: model)
    LibraryView(
        model: model,
        quickLookBlocked: renamePresented
    )
}
.background(Theme.bg)
```

In `LibraryView`, apply `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` to the outer content group so `ContentUnavailableView` receives the full area below the header. Keep the existing Inspector and toolbar behavior on the detail content. Do not put the progress row inside grid/list/empty-state branches.

- [x] **Step 4: Update the card copy to whole-task fields**

Change the progress format call in `TransferCardRow` to pass `transferCompletedCount`, `max(1, transferTotalCount)`, `transferRemainingDescription`, and `transferETADescription`. Keep the card's existing progress bar and speed line. Preserve zero-height idle behavior and the existing transient failure banner.

- [x] **Step 5: Add Chinese and English strings**

Change the progress format to:

```text
zh-CN: 同步进度 %d/%d · 剩余 %@ · 预计 %@
en:    Progress %d/%d · %@ left · ETA %@
```

Add explicit localized calculating and duration labels required by `AppModel` and remove no unrelated keys.

- [x] **Step 6: Verify UI-facing tests are green**

Run: `swift test --package-path macos --filter LocalizationTests`

Expected: all localization tests pass with exit 0.

---

### Task 5: Documentation, full verification, and UI acceptance

**Files:**
- Modify: `android/README.md`
- Modify: `macos/README.md`
- Modify: `PROJECT_MEMORY/01_ARCHITECTURE.md`
- Modify: `PROJECT_MEMORY/02_RISK_REGISTER.md` if protocol/ETA review identifies a new active risk
- Modify: `PROJECT_MEMORY/00_PROJECT_STATUS.md`
- Modify: `PROJECT_MEMORY/HANDOFF.md`
- Modify: `PROJECT_MEMORY/milestones/M3_macos_ux.md`
- Create: `PROJECT_MEMORY/batches/2026-09-22-B36-cross-platform-task-progress.md`

**Interfaces:**
- Consumes: completed implementation and test evidence from Tasks 1–4.
- Produces: Chinese documentation for the optional batch-byte header, task-level progress/ETA semantics, fixed header layout, and an auditable B36 record.

- [x] **Step 1: Document the protocol and UI semantics**

Add to the platform READMEs and `01_ARCHITECTURE.md`: the optional header name, actual-upload batch definition after manifest filtering, legacy fallback, ETA availability rule, and that the progress card is a single detail-level top header. Do not claim manual GUI acceptance before it runs.

- [x] **Step 2: Record verified risks and handoff state**

Create the B36 batch record with scope, non-goals, invariants, affected risk IDs, exact commands, results, current `git rev-parse --short HEAD`, and the remaining manual UI acceptance status. Update status/handoff/milestone/risk documents without overwriting existing B32–B35 entries.

- [x] **Step 3: Run all automated verification**

Run each command separately and read its result:

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

Expected: every command exits 0; Android tests and build pass; macOS reports all tests passing; the app builds, signs, and launches.

- [ ] **Step 4: Perform window-level UI acceptance**

Partial evidence on 2026-09-22 is recorded in the B36 batch and M3 milestone: grid, list, empty “其他文件”, populated “已删除”, non-empty search, and a local incomplete-PUT progress probe were checked. Empty “已删除”, a real Android-to-macOS successful transfer, and successful final-upload dismissal remain unverified; keep this acceptance step open.

With the built app running, inspect the main window in these states: grid with items, list with items, empty “其他文件”, empty “已删除”, and a non-empty search result. During an actual multi-file receive, verify the progress header stays at the top, shows batch-level remaining bytes/ETA after speed samples, and disappears immediately after the final upload. Record exactly which states were checked; if an actual receive cannot be safely executed, leave the GUI criterion open rather than claiming it passed.

- [x] **Step 5: Review the final scoped diff**

Run `git status --short --branch` and `git diff --stat -- android macos docs/superpowers PROJECT_MEMORY`. Confirm no generated files, credentials, or unrelated Android/B33/B35 changes were staged or overwritten. Do not commit or push.

Review follow-up: immediate cleanup after Android cancellation between two completed PUT requests, or isolation of interleaved sender batches, requires a batch identity plus an explicit end/cancel event. This version does not add that protocol extension; after cancellation mid-batch, progress can remain until the next batch starts or the receiver stops. The limitation is recorded as R-016 and does not alter successful final-upload cleanup.
