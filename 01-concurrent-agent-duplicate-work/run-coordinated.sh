#!/usr/bin/env bash
# Same scenario as run-uncoordinated.sh, but each agent atomically claims
# the job (mkdir is atomic on POSIX filesystems) before doing any real work.
# This is the shape of the fix a peer session was mid-building the same day
# (a `repair_filings` SQLite ledger with a UNIQUE(kind, subject, state_sha)
# constraint) -- this demo uses a lock directory instead of SQLite to keep
# it dependency-free, but the principle (claim-before-work, not
# check-then-append) is the same.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

JOB_NAME="playwright-1-of-9"
AGENT_COUNT="${AGENT_COUNT:-4}"

echo "Same $AGENT_COUNT agents, same job, but each claims the job before"
echo "doing any real work -- only the first claimant pays the full cost."
echo ""

pids=()
for i in $(seq 1 "$AGENT_COUNT"); do
  bash "$SCRIPT_DIR/lib/agent.sh" "$JOB_NAME" "agent-$i" "$WORK_DIR" coordinated &
  pids+=($!)
done
for pid in "${pids[@]}"; do
  wait "$pid"
done

bash "$SCRIPT_DIR/lib/summarize.sh" "$WORK_DIR/${JOB_NAME}.costs" "COORDINATED (mkdir-based claim)"
