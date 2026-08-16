#!/usr/bin/env bash
# One simulated agent working a CI-repair job. Real timing (sleep), not
# fake numbers -- elapsed wall-clock time is converted to a token estimate
# at the end so the waste ratio comes from an actual run, not a canned value.
set -euo pipefail

JOB_NAME="$1"
AGENT_ID="$2"
WORK_DIR="$3"
MODE="$4"        # uncoordinated | coordinated
TOKENS_PER_SECOND="${TOKENS_PER_SECOND:-2000}"

LOCK_DIR="$WORK_DIR/${JOB_NAME}.claim"
LOG_FILE="$WORK_DIR/${JOB_NAME}.${AGENT_ID}.log"
RESULT_FILE="$WORK_DIR/${JOB_NAME}.result"

start_epoch=$(date +%s)
log() { printf '[%s] %s\n' "$AGENT_ID" "$1" | tee -a "$LOG_FILE"; }

if [ "$MODE" = "coordinated" ]; then
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "job '$JOB_NAME' already claimed by another agent -- skipping (no duplicate work)"
    end_epoch=$(date +%s)
    elapsed=$((end_epoch - start_epoch))
    tokens=$((elapsed * TOKENS_PER_SECOND))
    echo "$AGENT_ID skipped elapsed=${elapsed}s tokens=${tokens}" >> "$WORK_DIR/${JOB_NAME}.costs"
    exit 0
  fi
  log "claimed job '$JOB_NAME' -- proceeding"
fi

log "investigating '$JOB_NAME' (reading logs, root-causing)"
sleep 1.5

log "writing and verifying a fix for '$JOB_NAME'"
sleep 1.0

if [ ! -f "$RESULT_FILE" ]; then
  echo "fixed-by=$AGENT_ID" > "$RESULT_FILE"
  log "committed the fix for '$JOB_NAME' (first to land)"
else
  log "attempted to commit a fix for '$JOB_NAME' but $(cat "$RESULT_FILE" | sed 's/fixed-by=//') already landed one -- conflict, this agent's work is discarded"
fi

end_epoch=$(date +%s)
elapsed=$((end_epoch - start_epoch))
tokens=$((elapsed * TOKENS_PER_SECOND))
echo "$AGENT_ID worked elapsed=${elapsed}s tokens=${tokens}" >> "$WORK_DIR/${JOB_NAME}.costs"
