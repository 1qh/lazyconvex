#!/usr/bin/env bash
set -euo pipefail

PIDS=()

for entry in \
  "blog BlogDesktop BlogUITests" \
  "chat ChatDesktop ChatUITests" \
  "movie MovieDesktop MovieUITests" \
  "org OrgDesktop OrgUITests"; do
  read -r dir proj scheme <<< "$entry"
  xcodebuild build-for-testing \
    -project "desktop/$dir/$proj.xcodeproj" \
    -scheme "$scheme" \
    -destination 'platform=macOS' \
    -skipMacroValidation -quiet &
  PIDS+=($!)
done

FAIL=0
for pid in "${PIDS[@]}"; do
  wait "$pid" || FAIL=1
done
exit $FAIL
