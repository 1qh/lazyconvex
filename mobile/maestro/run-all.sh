#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EMULATOR="$HOME/Library/Android/sdk/emulator/emulator"
AVDS=(Maestro_Shard_2)
PORTS=(5556)

cleanup() {
  if [ -n "${PROXY_PID:-}" ]; then
    kill "$PROXY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! lsof -i :3210 -sTCP:LISTEN >/dev/null 2>&1; then
  bun "$SCRIPT_DIR/../../packages/e2e/src/auth-proxy.ts" &
  PROXY_PID=$!
  sleep 1
fi

for i in "${!AVDS[@]}"; do
  port=${PORTS[$i]}
  if ! adb devices 2>/dev/null | grep -q "emulator-${port}"; then
    "$EMULATOR" -avd "${AVDS[$i]}" -no-window -no-audio -no-boot-anim -port "$port" &
  fi
done

for port in "${PORTS[@]}"; do
  while [ "$(adb -s "emulator-${port}" shell getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    sleep 2
  done
done

SHARD_COUNT=$(( ${#AVDS[@]} + 1 ))

MOBILE_DIR="$SCRIPT_DIR/.."

exec maestro test \
  --exclude-tags helper \
  --shard-split="$SHARD_COUNT" \
  --format JUNIT \
  --output "$SCRIPT_DIR/test-results.xml" \
  "$MOBILE_DIR/movie/e2e/" \
  "$MOBILE_DIR/blog/e2e/" \
  "$MOBILE_DIR/chat/e2e/" \
  "$MOBILE_DIR/org/e2e/"
