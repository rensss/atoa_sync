#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build/test-classes"
mkdir -p "$BUILD"

find "$ROOT/src/main/java/com/androidsync/app/core" -name '*.java' | sort > "$ROOT/build/test-sources.list"
printf '%s\n' "$ROOT/tests/SyncQueueTest.java" >> "$ROOT/build/test-sources.list"

javac -d "$BUILD" @"$ROOT/build/test-sources.list"
java -cp "$BUILD" SyncQueueTest
