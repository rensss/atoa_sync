# Platform Directory Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split all active macOS and Android project files into their platform directories and remove the obsolete Python receiver.

**Architecture:** The repository root retains shared product metadata and release artifacts. Each platform directory becomes independently buildable, with the Android web prototype owned by `android/prototype/` and the Swift package fully owned by `macos/`.

**Tech Stack:** Java/Android SDK command-line tools, Swift 6/SwiftPM, Bash, static HTML/CSS/JavaScript.

---

### Task 1: Move Platform-Owned Files

**Files:**
- Move: `Package.swift` to `macos/Package.swift`
- Move: `script/build_and_run.sh` to `macos/build_and_run.sh`
- Move: `index.html`, `app.js`, `styles.css`, `assets/`, and `design-qa.md` to `android/prototype/`
- Delete: `receiver/`

- [x] **Step 1: Move the Android browser prototype**

Create `android/prototype/` and move the HTML, CSS, JavaScript, image assets,
and QA report into it without changing relative asset URLs.

- [x] **Step 2: Move the macOS package files**

Move the Swift package manifest and app packaging script into `macos/`.

- [x] **Step 3: Remove the Python receiver**

Delete the tracked Python receiver source, tests, documentation, and upload
placeholder because the native macOS receiver supersedes it.

### Task 2: Repair Build and Documentation Paths

**Files:**
- Modify: `macos/Package.swift`
- Modify: `macos/build_and_run.sh`
- Modify: `macos/README.md`
- Modify: `android/README.md`
- Modify: `.gitignore`
- Create: `README.md`

- [x] **Step 1: Make the Swift package self-contained**

Change target paths in `macos/Package.swift` to `Sources/...` and `Tests/...`.

- [x] **Step 2: Update macOS packaging paths**

Set the script package directory to `macos/`, repository directory to its
parent, version input to repository `VERSION`, icon input to
`macos/Resources/AppIcon.icns`, and output to repository `dist/`.

- [x] **Step 3: Update active documentation**

Document root commands using `--package-path macos`, direct Android users to
the native macOS receiver, and add a root project map.

- [x] **Step 4: Update ignore rules**

Remove Python receiver rules and ignore SwiftPM output inside `macos/`.

### Task 3: Verify Both Platforms

**Files:**
- Verify only

- [x] **Step 1: Run Android unit tests**

Run `./android/run_tests.sh` and require exit code 0.

- [x] **Step 2: Build Android APK**

Run `./android/build.sh` and require APK signature verification to succeed.

- [x] **Step 3: Run macOS unit tests**

Run `swift test --package-path macos` and require all tests to pass.

- [x] **Step 4: Build macOS executable**

Run `swift build --package-path macos` and require exit code 0.

- [x] **Step 5: Audit paths and repository state**

Search active files for stale paths, inspect `git diff --check`, and verify the
final root layout.
