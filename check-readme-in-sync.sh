#!/usr/bin/env bash
# Catches the exact drift this repo's README already hit once: run-all.sh's
# real report changed shape (a category renamed, added, or removed) while
# README.md's embedded example-output block, hand-pasted from one run, never
# got updated to match -- so the front page quietly stopped describing what
# the tool actually does.
#
# This does NOT check the numbers -- those are real, live data and change
# every run by design. It only checks the category LABELS (the "1. Foo",
# "2. Bar" lines) match between what run-all.sh's report actually prints
# and what README.md's embedded example block shows, since the labels are
# the part that should only change when someone deliberately updates both
# places together.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REAL_LABELS="$(bash "$SCRIPT_DIR/run-all.sh" 2>&1 | awk '/^ REPORT -- waste by category/,0' | grep -E '^[0-9]+\.' | sed -E 's/^([0-9]+\. [^ ]+( [^ ]+)*)  +.*/\1/' | sed -E 's/[[:space:]]+$//')"
README_LABELS="$(awk '/REPORT -- waste by category/,/^```/' "$SCRIPT_DIR/README.md" | grep -E '^[0-9]+\.' | sed -E 's/^([0-9]+\. [^ ]+( [^ ]+)*)  +.*/\1/' | sed -E 's/[[:space:]]+$//')"

if [ "$REAL_LABELS" != "$README_LABELS" ]; then
  echo "FAIL: README.md's example report block doesn't match run-all.sh's real categories."
  echo ""
  echo "--- run-all.sh actually reports ---"
  echo "$REAL_LABELS"
  echo ""
  echo "--- README.md's example block shows ---"
  echo "$README_LABELS"
  echo ""
  echo "If you added/removed/renamed a category in run-all.sh, update README.md's"
  echo "embedded example block (under '## Run the full report') to match -- run"
  echo "run-all.sh yourself and paste its real output back in."
  exit 1
fi

echo "PASS: README.md's example report block matches run-all.sh's real categories."
