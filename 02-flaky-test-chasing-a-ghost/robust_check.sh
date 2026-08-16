#!/usr/bin/env bash
# Same real race as naive_check.sh, same writer, same random delay -- the
# only difference is this check polls with a bounded retry loop instead of
# reading once on a fixed schedule. This is the actual fix shape Invoker's
# case-2.16 harness already uses in production (see ../README.md): you
# cannot "fix" a real timing race by patching product code, only by making
# the check tolerant of the race it's inherently exposed to.
set -euo pipefail
MARKER="$(mktemp)"
rm -f "$MARKER"

DELAY="$(printf '0.%03d' "$((RANDOM % 150 + 10))")"  # 10-159ms, uniform
( sleep "$DELAY"; echo done > "$MARKER" ) &
WRITER_PID=$!

status=1
for _attempt in 1 2 3 4 5 6 7 8 9 10; do
  if [ -f "$MARKER" ] && [ "$(cat "$MARKER" 2>/dev/null)" = "done" ]; then
    status=0
    break
  fi
  sleep 0.02
done

wait "$WRITER_PID" 2>/dev/null || true
rm -f "$MARKER"
exit "$status"
