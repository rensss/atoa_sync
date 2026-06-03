#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/.."

python3 -m receiver.server \
  --host 0.0.0.0 \
  --port 8765 \
  --output-dir "$ROOT/received" \
  --log-path "$ROOT/received/uploads.jsonl"
