#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build/test-classes"
mkdir -p "$BUILD"

find "$ROOT/src/main/java/com/androidsync/app/core" -name '*.java' | sort > "$ROOT/build/test-sources.list"
find "$ROOT/tests/stubs" -name '*.java' | sort >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/SyncQueueTest.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/AlbumFilterTest.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/AlbumTreeTest.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/AddressConfigurationTest.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/SyncTransferRunnerTest.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/SyncRunTest.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/src/main/java/com/androidsync/app/android/HttpFileUploader.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/src/main/java/com/androidsync/app/android/ReceiverControlClient.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/HttpFileUploaderTest.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/ReceiverControlClientTest.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/src/main/java/com/androidsync/app/ui/Theme.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/src/main/java/com/androidsync/app/ui/UiInsetsPadding.java" >> "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/AndroidUiFoundationTest.java" >> "$ROOT/build/test-sources.list"

javac -d "$BUILD" @"$ROOT/build/test-sources.list"
java -cp "$BUILD" SyncQueueTest
java -cp "$BUILD" AlbumFilterTest
java -cp "$BUILD" AlbumTreeTest
java -cp "$BUILD" AddressConfigurationTest
java -cp "$BUILD" SyncTransferRunnerTest
java -cp "$BUILD" SyncRunTest
java -cp "$BUILD" HttpFileUploaderTest
java -cp "$BUILD" ReceiverControlClientTest
java -cp "$BUILD" AndroidUiFoundationTest
