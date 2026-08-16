#!/usr/bin/env bash
# A REAL race, not a fake random failure: a background "writer" (standing in
# for a headless owner process finishing a state transition) finishes after
# an unpredictable short delay. This check reads the result exactly once,
# on a fixed schedule, with no tolerance for the writer still being mid-flight.
# That's the actual shape of Invoker's case-2.16 harness before its own
# retry logic (see ../README.md) -- a real timing-sensitive sampler will
# sometimes lose this race no matter how "correct" the code under test is.
set -euo pipefail
MARKER="$(mktemp)"
rm -f "$MARKER"

DELAY="$(printf '0.%03d' "$((RANDOM % 150 + 10))")"  # 10-159ms, uniform
( sleep "$DELAY"; echo done > "$MARKER" ) &
WRITER_PID=$!

sleep 0.05

if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "done" ]; then
  wait "$WRITER_PID" 2>/dev/null || true
  rm -f "$MARKER"
  exit 0
else
  wait "$WRITER_PID" 2>/dev/null || true
  rm -f "$MARKER"
  exit 1
fi
