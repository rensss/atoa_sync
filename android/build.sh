#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_HOME:-/Users/ios_k/Library/Android/sdk}"
BUILD_TOOLS="$SDK/build-tools/35.0.0"
PLATFORM="$SDK/platforms/android-35/android.jar"
STAMP="$(date +%Y%m%d%H%M%S)"
WORK="$ROOT/build/apk-$STAMP"
OUT="$ROOT/build/AndroidSync-debug.apk"
KEYSTORE="$ROOT/debug.keystore"

mkdir -p "$WORK/compiled" "$WORK/generated" "$WORK/classes" "$WORK/dex" "$ROOT/build"

"$BUILD_TOOLS/aapt2" compile --dir "$ROOT/src/main/res" -o "$WORK/resources.zip"
"$BUILD_TOOLS/aapt2" link \
  -I "$PLATFORM" \
  --manifest "$ROOT/AndroidManifest.xml" \
  --java "$WORK/generated" \
  -o "$WORK/base.apk" \
  "$WORK/resources.zip"

find "$ROOT/src/main/java" "$WORK/generated" -name '*.java' | sort > "$WORK/sources.list"
javac -source 8 -target 8 -bootclasspath "$PLATFORM" -d "$WORK/classes" @"$WORK/sources.list"

(cd "$WORK/classes" && jar cf "$WORK/classes.jar" .)
"$BUILD_TOOLS/d8" --min-api 26 --lib "$PLATFORM" --output "$WORK/dex" "$WORK/classes.jar"
cp "$WORK/base.apk" "$WORK/unsigned.apk"
(cd "$WORK/dex" && zip -q -r "$WORK/unsigned.apk" classes.dex)

"$BUILD_TOOLS/zipalign" -f -p 4 "$WORK/unsigned.apk" "$WORK/aligned.apk"

if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair \
    -keystore "$KEYSTORE" \
    -storepass android \
    -keypass android \
    -alias androiddebugkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US"
fi

"$BUILD_TOOLS/apksigner" sign \
  --ks "$KEYSTORE" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$OUT" \
  "$WORK/aligned.apk"

"$BUILD_TOOLS/apksigner" verify "$OUT"
echo "$OUT"
