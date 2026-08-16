#!/usr/bin/env bash
# Models what we actually found on 2026-08-16 in Invoker: 4+ agent sessions
# (this session, two live peers, and whoever force-merged a third peer's
# PRs) independently working the identical CI-failure backlog, plus
# Invoker's own automated pipeline running 3+ concurrent attempt chains
# for the same job (e.g. playwright-1-of-9) across separate droplets --
# with no shared claim mechanism. See ../README.md for the real numbers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

JOB_NAME="playwright-1-of-9"
AGENT_COUNT="${AGENT_COUNT:-4}"

echo "Simulating $AGENT_COUNT agents independently discovering and fixing"
echo "the SAME failing job ('$JOB_NAME') at the same time, with no"
echo "coordination mechanism -- exactly what the fleet scan found live."
echo ""

pids=()
for i in $(seq 1 "$AGENT_COUNT"); do
  bash "$SCRIPT_DIR/lib/agent.sh" "$JOB_NAME" "agent-$i" "$WORK_DIR" uncoordinated &
  pids+=($!)
done
for pid in "${pids[@]}"; do
  wait "$pid"
done

bash "$SCRIPT_DIR/lib/summarize.sh" "$WORK_DIR/${JOB_NAME}.costs" "UNCOORDINATED (no claim mechanism)"
