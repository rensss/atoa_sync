# 原生跨端暂停/恢复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mac 暂停接收后中断未完成 PUT、清理部分文件，让 Android 保留同一任务并在 Mac 恢复后从头重传；暂停不报普通错误，停止命令仍可取消等待。

**Architecture:** macOS `ReceiverService` 保持 listener 在线，以 `running/pausing/paused` 和 `pause_epoch` 暴露接收状态；只有已开始接收但尚未进入提交阶段的 PUT 会被中断。Android 只对识别出的原生接收端启用暂停协议，在普通上传异常后用状态/epoch 判定是否由暂停导致；`SyncTransferRunner` 对该特例暂存任务为 `WAITING`、等待恢复并重试同一文件。普通错误、通用 WebDAV 和用户停止继续走原有路径。

**Tech Stack:** Swift、SwiftUI、Network.framework、Java 8 source/target、Android `HttpURLConnection`、现有 Android 前台服务与纯 Java 测试脚本。

**Spec:** `docs/superpowers/specs/2026-09-22-native-pause-resume-design.md`

## Global Constraints

- `ReceiverService` 保持 listener 在线，拥有 `running`、`pausing`、`paused` 三态；暂停/恢复不销毁并重建 listener，也不改变端口。
- `pausing` 或 `paused` 时的新 PUT 在创建临时文件前以 HTTP 503 和稳定错误码 `receiver_paused` 拒绝。
- 若暂停到达时 PUT 请求体已完整接收、存储提交已经开始，则允许该提交完成并返回成功。
- 暂停导致的中断将当前任务从 `UPLOADING` 还原为 `WAITING`，不标记 `FAILED`、不计作完成，且不推进批次索引。
- 普通网络错误仍按现有规则标记 `FAILED` 并继续后续任务；不引入通用自动重试、字节级续传或修改其他错误策略。
- 仅对能通过根端点识别为原生 Android Sync Receiver 的目标启用暂停控制；通用 WebDAV/HTTP 目标保持现有行为。
- 暂停等待必须定期检查 Android 用户停止信号。用户停止后将 run 标记为 `STOPPED`，退出等待且不再重传。
- 不新增第三方依赖；Android 保持 Java 8 source/target，最低 API 26。

## Review Focus

1. 接收端中断正在写入的 PUT 时，`.incoming/*.part` 是否必定删除且不会进入 manifest？由 Task 1 的 `testPauseInterruptsUploadAndRemovesTemporaryFile` 覆盖。
2. 请求体已完整接收、提交 hook 暂停时，文件是否仍返回 201 且只落盘一次？由 Task 1 的 `testPauseAfterCommitStartsFinishesStoredUpload` 覆盖。
3. Mac 在 Android 处理 Broken pipe 前已经恢复时，Android 是否仍凭 `pause_epoch` 识别暂停并重传？由 Task 2 的 `testEpochChangeClassifiesFastPauseResumeAsPaused` 与 Task 3 的 runner 重传测试覆盖。
4. 用户在暂停等待期间点 Android 停止，当前任务是否回到 `WAITING`、runner 是否以 `cancelled=true` 结束且不再发 PUT？由 Task 3 的 `testStopDuringReceiverPauseWaitDoesNotRetry` 覆盖；`SyncForegroundService.onFinished` 继续负责把用户停止的 run 标记为 `STOPPED`。
5. 普通 WebDAV、暂停端点暂时不可用和普通 PUT 网络错误是否不会触发自动重传？由 Task 2 的 `testUnknownReceiverKeepsSingleAttempt`、`testHealthFailureDoesNotProvePause` 与 Task 3 的既有失败继续测试覆盖。

---

### Task 1: macOS 接收状态、暂停协议与部分上传清理

**Files:**
- Modify: `macos/Sources/AndroidSyncCore/HTTPProtocol.swift`
- Modify: `macos/Sources/AndroidSyncCore/ReceiverService.swift`
- Test: `macos/Tests/AndroidSyncCoreTests/HTTPProtocolTests.swift`
- Test: `macos/Tests/AndroidSyncCoreTests/ReceiverServiceTests.swift`

**Interfaces:**
- Add `public enum ReceiverAvailabilityState: String, Sendable { case running, pausing, paused }`.
- Add `public func pause() async` and `public func resume() async` to `ReceiverService`; both serialize transitions on its existing receiver queue and retain the current `NWListener`.
- Add `ReceiverServiceEvent.availabilityChanged(state: ReceiverAvailabilityState)` and `uploadInterrupted(id: UUID, filename: String)` for pause-cancelled, not-yet-committing PUT requests.
- `/` retains `service: "Android Sync Receiver"` for Android capability discovery. `/health` returns `status`, `receiver_state`, and integer `pause_epoch`. A PUT received outside `running` returns 503 JSON with `error_code: "receiver_paused"` before creating a temporary upload file.

- [x] **Step 1: Add failing protocol and service tests.** In `HTTPProtocolTests.swift`, assert the router still returns a normal `.upload` route independently of receiver availability. In `ReceiverServiceTests.swift`, add `testHealthReportsControlStateAndEpoch`, `testPauseKeepsHealthAvailableRejectsNewUploadsAndResumeKeepsPort`, `testPauseInterruptsUploadAndRemovesTemporaryFile`, and `testPauseAfterCommitStartsFinishesStoredUpload`. The partial-upload test must assert an `uploadInterrupted` event, no `uploadFailed`, empty `.incoming`, and empty manifest. The commit test must hold `LibraryRepositoryHooks.afterFileMove`, pause the service, release the hook, and assert one stored record plus HTTP 201.

  ```swift
  let health = try JSONSerialization.jsonObject(with: healthData) as! [String: Any]
  XCTAssertEqual(health["status"] as? String, "ok")
  XCTAssertEqual(health["receiver_state"] as? String, "running")
  XCTAssertEqual(health["pause_epoch"] as? Int, 0)
  ```
- [x] **Step 2: Run the focused tests and confirm they fail.** Run `swift test --package-path macos --filter ReceiverServiceTests`; expected failures should identify the absent service pause API/state and missing pause events/health fields.
- [x] **Step 3: Implement serialized pause/resume in `ReceiverService`.** Add receiver availability state and `pauseEpoch` on the receiver queue; pause increments the epoch, transitions through `pausing`, requests pause cancellation only from receiving-body sessions, and transitions to `paused` after those sessions clean up. Keep health/root/manifest available. Reject newly routed PUTs before `prepareUpload()`. On `resume()`, transition `paused` to `running` without recreating the listener.
- [x] **Step 4: Add a pause-specific connection lifecycle path.** `ReceiverConnection.requestPause()` must close and clean the temporary URL while receiving, emit `uploadInterrupted` once, and suppress generic cancellation failure. If the lifecycle is already committing, do not cancel or close it; let `commitTemporaryUpload` finish and send its 201 response. Leave `requestStop()` semantics unchanged.
- [x] **Step 5: Run the focused and full macOS suites.** Run `swift test --package-path macos --filter ReceiverServiceTests`, then `swift test --package-path macos`; all existing stop, peer-cancel, commit-race, and new pause tests must pass.
- [x] **Step 6: Commit the independently tested receiver protocol unit.** Stage only the four files in this task and commit as `feat: add native receiver pause control`.

### Task 2: Android 原生接收端识别与暂停证据

**Files:**
- Create: `android/src/main/java/com/androidsync/app/core/ReceiverPausedException.java`
- Create: `android/src/main/java/com/androidsync/app/android/ReceiverControlClient.java`
- Modify: `android/src/main/java/com/androidsync/app/android/HttpFileUploader.java`
- Modify: `android/run_tests.sh`
- Create: `android/tests/ReceiverControlClientTest.java`
- Modify: `android/tests/HttpFileUploaderTest.java`
- Create: `android/tests/stubs/org/json/JSONObject.java`
- Create: `android/tests/stubs/org/json/JSONException.java`

**Interfaces:**
- `ReceiverPausedException extends IOException` and carries the positive pause classification from the Android uploader to the pure-Java runner without reversing platform dependencies.
- `ReceiverControlClient.discover(String uploadBaseUrl)` performs one root GET; exact service identity `Android Sync Receiver` produces a supported `Session`, while any other response produces an unsupported session without failing the upload run.
- A supported `Session.readHealth()` returns `Snapshot(state, pauseEpoch)` from `/health`; malformed/unavailable control data is not positive pause evidence.
- Add an `HttpFileUploader.upload(..., ReceiverControlClient.Session session, CancellationSignal cancellation)` overload. Before PUT it checks the supported session and captures the starting epoch; if the receiver is pausing/paused it throws `ReceiverPausedException` without sending the file. A failed preflight does not suppress the PUT and is not pause evidence. After an `IOException`, it re-reads health and throws the pause exception only when the state is pausing/paused or the epoch changed; otherwise it rethrows the original upload error.
- `Session.awaitRunning(SyncTransferRunner.CancellationSignal)` polls at one-second intervals, exits only on confirmed `running` or cancellation, and does not issue a PUT while state is paused. Temporary health-request errors while already waiting keep the task waiting and retry the health request; they are never treated as a running state.

- [x] **Step 1: Add failing control-client and uploader tests.** Add `testUnknownReceiverKeepsSingleAttempt`, `testHealthFailureDoesNotProvePause`, `testPausedPreflightSendsNoPut`, `testEpochChangeClassifiesFastPauseResumeAsPaused`, `testUnchangedEpochKeepsOriginalUploadError`, `testWaitRetriesHealthOutage`, and `testCancellationDuringAwaitRunning`. Cover exact service identity, valid state/epoch parsing, and malformed health.

  ```java
  ReceiverControlClient.Session session = client.discover("http://127.0.0.1:8765/uploads/");
  assertEquals(true, session.isSupported(), "native receiver should enable pause control");
  ReceiverControlClient.Snapshot paused = session.readHealth();
  assertEquals("paused", paused.state(), "health should report receiver pause state");
  assertEquals(4L, paused.pauseEpoch(), "health should expose the pause epoch");
  ```
- [x] **Step 2: Run `./android/run_tests.sh` and confirm the new tests fail to compile or fail their assertions for missing behavior.** Keep test-server responses local and deterministic; do not require a physical device.
- [x] **Step 3: Implement `ReceiverControlClient`.** Resolve root and `/health` from the configured `/uploads/` URL, validate the root service field exactly, use bounded connect/read timeouts, parse the flat health JSON with Android `org.json`, and return an unsupported session on an unrecognized service. In wait mode, check cancellation before/after each health request and during the one-second interval.
- [x] **Step 4: Implement pause evidence in `HttpFileUploader`.** Preserve the existing overloads and generic-destination path. For a supported session, capture the initial epoch, preflight before opening the media stream, and classify only positive state/epoch evidence as `ReceiverPausedException`; if the status query itself fails after an upload error, preserve the original `IOException`.
- [x] **Step 5: Add the focused test source to `android/run_tests.sh` and run it.** Compile the new client and tests under the existing JDK harness; assert `HttpFileUploaderTest passed` and `ReceiverControlClientTest passed`.
- [x] **Step 6: Commit the independently tested control protocol unit.** Stage only the control client, uploader, test runner list, and related tests/stubs; commit as `feat: negotiate receiver pause state on Android`.

### Task 3: Android 同一任务等待恢复、重传与停止

**Files:**
- Modify: `android/src/main/java/com/androidsync/app/core/SyncTransferRunner.java`
- Modify: `android/src/main/java/com/androidsync/app/SyncForegroundService.java`
- Modify: `android/tests/SyncTransferRunnerTest.java`

**Interfaces:**
- Catch the top-level `com.androidsync.app.core.ReceiverPausedException extends IOException` before the generic exception branch.
- Add `SyncTransferRunner.PauseAwareUploader extends Uploader` with `void awaitReceiverRunning(String targetUrl, CancellationSignal cancellation) throws Exception`.
- Add default listener callback `onReceiverPauseWaitChanged(boolean waiting)` so the foreground service can show “等待 Mac 恢复接收” without changing ordinary task errors.
- Use the top-level `com.androidsync.app.core.ReceiverPausedException` created in Task 2; do not add a second exception class.
- The runner catches the pause exception only for `PauseAwareUploader`: it returns the task to `WAITING`, emits the transition, waits, restores `UPLOADING`, then retries that same task with the original `batchIndex`. Cancellation during wait leaves the task `WAITING`, ends the run as cancelled, and never retries. Other exceptions keep the existing `FAILED`-then-continue behavior.

- [x] **Step 1: Add failing runner tests.** `testReceiverPauseRetriesSameTaskWithoutFailure` uses a fake `PauseAwareUploader` that throws `ReceiverPausedException` once and then succeeds; assert the task reaches `DONE`, upload calls use the same task ID and batch index, and states include `UPLOADING -> WAITING -> UPLOADING -> DONE`. `testStopDuringReceiverPauseWaitDoesNotRetry` flips the cancellation signal inside `awaitReceiverRunning`, then asserts the task is `WAITING`, no second upload occurs, and `onFinished(true)` fires. Preserve `failedTaskDoesNotStopLaterTasks` unchanged.
- [x] **Step 2: Run `./android/run_tests.sh` and verify the two new tests fail before implementation.** Expected failure is the absent pause exception/interface or incorrect failed-task result.
- [x] **Step 3: Implement the pause branch as an inner retry loop in `SyncTransferRunner`.** Increment `batchIndex` once per task, not per paused attempt. Before waiting, call `queue.retry` and notify the listener; after the pause-aware uploader reports running, mark uploading and retry. If cancellation is set at any point, use the existing cancelled-run path and do not mark failure.

  ```java
  } catch (ReceiverPausedException pause) {
      queue.retry(task.id());
      effectiveListener.onTaskStateChanged(task.id(), SyncStatus.UPLOADING, SyncStatus.WAITING);
      effectiveListener.onReceiverPauseWaitChanged(true);
      pauseAwareUploader.awaitReceiverRunning(targetUrl, effectiveCancellation);
      if (effectiveCancellation.isCancelled()) {
          cancelled = true;
          break;
      }
      queue.markUploading(task.id());
      effectiveListener.onReceiverPauseWaitChanged(false);
      // Continue the inner attempt loop without incrementing batchIndex.
  }
  ```
- [x] **Step 4: Integrate `ReceiverControlClient.Session` in `SyncForegroundService`.** Discover the native receiver once for the run, pass the session to `HttpFileUploader`, implement `PauseAwareUploader.awaitReceiverRunning` through the same session, and update notification text while `onReceiverPauseWaitChanged(true)` is active. Clear the wait indicator on resume, stop, and every `onFinished` path. Keep `ACTION_STOP` and `userStopRequested` separate from receiver pause.
- [x] **Step 5: Run focused and full Android tests.** Run `./android/run_tests.sh`; assert pause retry, cancellation, generic WebDAV, ordinary network failure, batch-index, and existing queue tests pass. Confirm the run remains `RUNNING` during the wait so `MainActivity.stopSync()` continues to send `ACTION_STOP`.
- [x] **Step 6: Commit the independently tested Android runner/service unit.** Stage only the three files in this task and commit as `fix: resume uploads interrupted by receiver pause`.

### Task 4: macOS AppModel 与暂停/恢复界面状态

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Stores/AppModel.swift`
- Modify: `macos/Sources/AndroidSyncMac/Views/MenuBarView.swift`
- Modify: `macos/Sources/AndroidSyncMac/Views/StatusCapsuleView.swift`
- Modify: `macos/Sources/AndroidSyncMac/Views/LibraryToolbar.swift`
- Modify: `macos/Sources/AndroidSyncMac/Views/TransferCardRow.swift`
- Modify: `macos/Sources/AndroidSyncMac/Support/Localization.swift`
- Modify: `macos/Tests/AndroidSyncMacTests/AppModelReceiverTests.swift`
- Modify: `macos/Tests/AndroidSyncMacTests/TransferCardStateTests.swift`
- Modify: `macos/Tests/AndroidSyncMacTests/LocalizationTests.swift`

**Interfaces:**
- Extend `ReceiverStatus` with `.pausing` and `.paused`, and `TransferCardState` with `.paused`; expose derived pause/resume button title, help, image, and availability from `AppModel` so all controls share one state.
- `toggleReceiver()` maps `.running -> pause()`, `.paused -> resume()`, disables action in `.pausing`, and preserves existing start behavior for `.stopped`/startup states.
- Handle `ReceiverServiceEvent.uploadInterrupted` by removing only that active upload, subtracting its partial received bytes from `burstBytesReceived`, resetting the speed sample window to the corrected byte total, preserving completed-file counts and other active uploads, and switching the transfer card to paused rather than transient failure.

- [x] **Step 1: Add failing AppModel and localization tests.** Cover running→pausing→paused→running with one retained `ReceiverService` instance; verify all control labels switch Pause/Resume, pausing controls are disabled, interruption does not increment terminal/completed count, the interrupted upload’s partial bytes are removed while another active upload remains counted, and the interruption produces no failure banner.

  ```swift
  model.handle(.availabilityChanged(state: .paused))
  XCTAssertEqual(model.receiverActionTitle, model.text(.resumeReceiving))
  model.handle(.uploadInterrupted(id: interruptedID, filename: "video.mp4"))
  XCTAssertEqual(model.transferCompletedCount, 0)
  XCTAssertNil(model.transientUploadMessage)
  ```
- [x] **Step 2: Run `swift test --package-path macos --filter AppModelReceiverTests` and `swift test --package-path macos --filter TransferCardStateTests`; verify the new tests fail before changes.**
- [x] **Step 3: Add model state and event handling.** Connect AppModel pause/resume actions to the existing receiver service, consume receiver-state events, and handle upload interruption separately from `uploadFailed`. Do not detach the service or clear its port when paused.
- [x] **Step 4: Bind every macOS receive control to the shared derived state.** Update menu bar, status capsule, library toolbar, and transfer card title/icon/help; disable action during pausing; add Chinese and English strings for pausing, paused, and resume.
- [x] **Step 5: Run the focused tests, then `swift test --package-path macos`.** Verify existing start/stop, old receiver generation, progress completion, and localized status tests remain green.
- [x] **Step 6: Commit the independently tested macOS UI/model unit.** Stage only the files in this task and commit as `fix: reflect native receiver pause state`.

### Task 5: ADR、项目记忆、构建与最终审查

**Files:**
- Modify: `PROJECT_MEMORY/04_DECISION_LOG.md`
- Modify: `PROJECT_MEMORY/00_PROJECT_STATUS.md`
- Modify: `PROJECT_MEMORY/HANDOFF.md`
- Modify: `PROJECT_MEMORY/01_ARCHITECTURE.md`
- Modify: `PROJECT_MEMORY/02_RISK_REGISTER.md`
- Create: `PROJECT_MEMORY/batches/2026-09-22-B37-native-pause-resume.md`
- Modify: `android/README.md`
- Modify: `macos/README.md`
- Create: `docs/superpowers/specs/2026-09-22-native-pause-resume-design.md`
- Create: `docs/superpowers/plans/2026-09-22-native-pause-resume.md`

- [x] **Step 1: Append ADR-010 without rewriting ADR-008.** Record that the user-approved pause-induced reattempt is a narrow exception to “one attempt per file”; keep generic network failures single-attempt, keep service/database ownership and sequential PUT architecture, and explicitly mark ADR-010 as superseding only that retry clause of ADR-008.

  ```markdown
  ## ADR-010：原生接收端暂停时重传被中断文件
  状态：已接受；仅 supersedes ADR-008 中“每文件一次尝试/不自动重试”的暂停中断范围。
  普通网络错误、通用 WebDAV 和其他 ADR-008 后果保持不变。
  ```
- [x] **Step 2: Record batch B37 and update status/handoff/architecture/risk docs.** List risks R-004, R-007, R-009, R-015, and R-016; correct the B36 result record now that the pre-existing work was committed first; state that real-device pause/resume/stop acceptance remains open until performed, rather than claiming source tests prove device behavior.
- [x] **Step 3: Update platform READMEs with the native pause protocol.** Document the health fields, PUT 503 code, pause-induced whole-file resend behavior, generic WebDAV fallback, and user Stop behavior; add no new dependency or generated files.
- [x] **Step 4: Run complete acceptance checks.** Run `./android/run_tests.sh`, `./android/build.sh`, `swift test --package-path macos`, `./macos/build_and_run.sh verify`, and `git diff --check`. Confirm `git status --short` contains only intended B37 files and no generated APK/build output is staged.
- [ ] **Step 5: Commit the project decision and batch record separately.** Stage only the decision/status/architecture/risk/handoff/batch/README/spec/plan files and commit as `docs: record native pause resume behavior`. After verifying that commit SHA, add it to the B37 record and mark this step complete in a small follow-up documentation commit; the commit cannot contain its own final SHA. Leave the working tree clean and report the exact commits plus tests; report device acceptance as pending unless a real pause/resume/stop test is completed.
