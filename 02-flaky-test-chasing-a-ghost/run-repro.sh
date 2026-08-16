#!/usr/bin/env bash
# Models what we actually found on 2026-08-16 in Invoker: CI logged
# case-2.16-retry-vs-recreate-five-second-window.sh as FAILED, but running
# that exact script directly against unmodified master passed cleanly.
# Real evidence, not a guess, that the CI failure was a timing flake, not
# a deterministic bug -- so no code fix was proposed. See ../README.md.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS="${RUNS:-30}"

run_n_times() {
  local script="$1" pass=0 fail=0
  for _i in $(seq 1 "$RUNS"); do
    if bash "$script" >/dev/null 2>&1; then
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
    fi
  done
  echo "$pass $fail"
}

echo "Running the naive (single fixed-schedule read) check $RUNS times against"
echo "the SAME underlying code -- nothing changes between runs:"
read -r naive_pass naive_fail < <(run_n_times "$SCRIPT_DIR/naive_check.sh")
echo "  pass=$naive_pass fail=$naive_fail"
echo ""
echo "If each of those failures had been treated as a real bug and 'fixed'"
echo "by an agent (root-cause, patch, verify, PR), that's $naive_fail wasted"
echo "fix attempts against a check that was never actually broken."
echo ""
echo "Running the robust (bounded-retry) check $RUNS times against the exact"
echo "same underlying race -- only the check's tolerance changed:"
read -r robust_pass robust_fail < <(run_n_times "$SCRIPT_DIR/robust_check.sh")
echo "  pass=$robust_pass fail=$robust_fail"
echo ""
echo "=== SUMMARY ==="
echo "naive check flake rate:  $naive_fail/$RUNS"
echo "robust check flake rate: $robust_fail/$RUNS"
echo "The underlying race never went away -- only the check's tolerance for"
echo "it did. This is the fix shape for a real timing-sensitive test: widen"
echo "the check's tolerance, don't chase the 'bug' the flake implies."
