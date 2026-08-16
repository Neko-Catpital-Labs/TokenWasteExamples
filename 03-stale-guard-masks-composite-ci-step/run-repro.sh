#!/usr/bin/env bash
# Models what we actually found on 2026-08-16 in Invoker: required-fast /
# Guardrails runs 9 unrelated checks in one `set -e` step. #9290-#9306
# intentionally changed delete-all's behavior; the guard test was never
# updated to match, so it failed -- and silently killed the 5 real,
# unrelated checks after it in the same step. Fixed in PR #9461.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== BEFORE the fix: stale guard test + 5 real checks in one step ==="
set +e
bash "$SCRIPT_DIR/composite_step.sh" guard_test_stale.sh
status=$?
set -e
echo "(step exit code: $status)"
echo "check-06 through check-10 never ran -- their real status is unknown,"
echo "not 'passing'. The whole step reads as one opaque failure."
echo ""

echo "=== AFTER the fix: guard test matches current behavior ==="
bash "$SCRIPT_DIR/composite_step.sh" guard_test_fixed.sh
echo ""
echo "All 6 checks in the step actually ran and their real status is now"
echo "visible -- the fix wasn't 'make the step green', it was 'stop one"
echo "stale check from hiding five unrelated ones.'"
