#!/usr/bin/env bash
# The post-fix shape (PR #9461): asserts current, intended behavior.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(bash "$SCRIPT_DIR/product.sh" 2>&1)"

if ! grep -q "All workflows deleted." <<<"$OUT"; then
  echo "FAIL: expected delete-all completion message, got: $OUT"
  exit 1
fi
echo "PASS: delete-all runs unconditionally and completes"
