#!/usr/bin/env bash
set -euo pipefail

PIDS=()

for pkg in swift-core desktop/shared desktop/blog desktop/chat desktop/movie desktop/org; do
  swift test --package-path "$pkg" &
  PIDS+=($!)
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/build-uitests.sh" &
PIDS+=($!)

FAIL=0
for pid in "${PIDS[@]}"; do
  wait "$pid" || FAIL=1
done
exit $FAIL
