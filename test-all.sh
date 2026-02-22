#!/usr/bin/env bash
set -euo pipefail

bun test:web &
P1=$!
bun test:desktop &
P2=$!
bun test:mobile &
P3=$!

FAIL=0
wait $P1 || FAIL=1
wait $P2 || FAIL=1
wait $P3 || FAIL=1
exit $FAIL
