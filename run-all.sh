#!/usr/bin/env bash
# Runs every detector in this repo and prints one consolidated report.
#
# 01-03 are self-contained (no setup, always run). 04 and the session-cost
# tool need real data to point at -- a git repo with history, and a real
# Claude Code session directory -- so they're driven by env vars and skip
# cleanly with a note when nothing's configured, rather than failing.
#
# Usage:
#   bash run-all.sh
#   TARGET_REPO=/path/to/repo PATH_GLOB='scripts/some-subsystem*' bash run-all.sh
#   SESSION_DIR=~/.claude/projects bash run-all.sh
#   TARGET_REPO=... PATH_GLOB=... SESSION_DIR=... GREP=admin-bypass bash run-all.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREP="${GREP:-admin-bypass}"
SESSION_DIR="${SESSION_DIR:-}"
TARGET_REPO="${TARGET_REPO:-}"
PATH_GLOB="${PATH_GLOB:-}"

REPORT_ROWS=()
add_row() { REPORT_ROWS+=("$1|$2"); }

hr() { printf '%s\n' "----------------------------------------------------------------------"; }

echo "======================================================================"
echo " Token Waste Examples -- full run, $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "======================================================================"
echo

# --- 1. Concurrent agent duplicate work ---------------------------------
hr
echo "[1/5] Concurrent agent duplicate work (synthetic, real race)"
hr
OUT1=$(bash "$SCRIPT_DIR/01-concurrent-agent-duplicate-work/run-uncoordinated.sh" 2>&1)
echo "$OUT1"
WASTE1=$(echo "$OUT1" | grep -oE 'wasted tokens: *[0-9]+ \([0-9]+% of total spend\)' | head -1)
add_row "1. Concurrent agent duplicate work" "${WASTE1:-no result}"
echo

# --- 2. Flaky test chasing a ghost --------------------------------------
hr
echo "[2/5] Flaky test, chasing a ghost (real race, real timing)"
hr
OUT2=$(bash "$SCRIPT_DIR/02-flaky-test-chasing-a-ghost/run-repro.sh" 2>&1)
echo "$OUT2"
NAIVE=$(echo "$OUT2" | grep -oE 'naive check flake rate: *[0-9]+/[0-9]+' | grep -oE '[0-9]+/[0-9]+')
ROBUST=$(echo "$OUT2" | grep -oE 'robust check flake rate: *[0-9]+/[0-9]+' | grep -oE '[0-9]+/[0-9]+')
add_row "2. Flaky test chasing a ghost" "naive flake rate ${NAIVE:-?}, robust flake rate ${ROBUST:-?} -- same underlying race"
echo

# --- 3. Stale guard masks a composite CI step ---------------------------
hr
echo "[3/5] Stale guard masks a composite CI step (real set -e cascade)"
hr
OUT3=$(bash "$SCRIPT_DIR/03-stale-guard-masks-composite-ci-step/run-repro.sh" 2>&1)
echo "$OUT3"
BEFORE_DOWNSTREAM=$(echo "$OUT3" | awk '/BEFORE the fix/,/AFTER the fix/' | grep -c '^PASS: check-')
AFTER_DOWNSTREAM=$(echo "$OUT3" | awk '/AFTER the fix/,0' | grep -c '^PASS: check-')
add_row "3. Stale guard masks composite step" "${AFTER_DOWNSTREAM} downstream checks masked by 1 stale assertion (${BEFORE_DOWNSTREAM} ran before the fix, ${AFTER_DOWNSTREAM} after)"
echo

# --- 4. Admin-bypass repeated firing (real git history) -----------------
hr
echo "[4/5] Admin-bypass repeated firing (real git history)"
hr
if [ -n "$TARGET_REPO" ] && [ -n "$PATH_GLOB" ]; then
  OUT4=$(python3 "$SCRIPT_DIR/tools/git_churn_episodes.py" "$TARGET_REPO" "$PATH_GLOB" --gap-days 3 --thrash-threshold 10 2>&1)
  echo "$OUT4"
  CHURN=$(echo "$OUT4" | grep -oE 'Commits inside thrash episodes: *[0-9]+ / [0-9]+ \([0-9]+%\)')
  add_row "4. Admin-bypass repeated firing" "${CHURN:-no thrash episodes found at this threshold}"
else
  echo "Skipped: set TARGET_REPO and PATH_GLOB to run this against real history, e.g.:"
  echo "  TARGET_REPO=/path/to/repo PATH_GLOB='scripts/some-subsystem*' bash run-all.sh"
  add_row "4. Admin-bypass repeated firing" "skipped (no TARGET_REPO/PATH_GLOB set)"
fi
echo

# --- 5. Session cost, filtered to a category ----------------------------
hr
echo "[5/5] Session cost for sessions mentioning '${GREP}' (real transcripts)"
hr
if [ -z "$SESSION_DIR" ] && [ -d "$HOME/.claude/projects" ]; then
  SESSION_DIR="$HOME/.claude/projects"
fi
if [ -n "$SESSION_DIR" ] && [ -d "$SESSION_DIR" ]; then
  OUT5=$(python3 "$SCRIPT_DIR/tools/claude_session_cost.py" "$SESSION_DIR" --recursive --grep "$GREP" --top 5 --outlier-factor 3 2>&1)
  echo "$OUT5"
  MATCHED=$(echo "$OUT5" | grep -oE '^[0-9]+ / [0-9]+ session files match' | head -1)
  EXCESS=$(echo "$OUT5" | grep -oE 'Excess cost above baseline across the outliers: *[0-9,]+ *\([0-9.]+% of total corpus cost\)' | head -1)
  add_row "5. Sessions mentioning '${GREP}'" "${MATCHED:-?}; ${EXCESS:-no outliers at this threshold}"
else
  echo "Skipped: no session directory found. Set SESSION_DIR to a directory of Claude Code"
  echo "  .jsonl session files, e.g.: SESSION_DIR=~/.claude/projects bash run-all.sh"
  add_row "5. Sessions mentioning '${GREP}'" "skipped (no SESSION_DIR found or set)"
fi
echo

# --- Consolidated report --------------------------------------------------
echo "======================================================================"
echo " REPORT -- waste by category"
echo "======================================================================"
for row in "${REPORT_ROWS[@]}"; do
  IFS='|' read -r label value <<< "$row"
  printf '%-40s %s\n' "$label" "$value"
done
echo
echo "Full detail for each category is in its own directory's README. This"
echo "report is regenerated fresh every run -- nothing here is cached or"
echo "canned. Categories 4 and 5 need real data pointed at them (a repo with"
echo "history, a session directory) to say anything; 1-3 always run."
