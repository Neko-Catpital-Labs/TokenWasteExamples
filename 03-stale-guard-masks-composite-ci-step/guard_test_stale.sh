#!/usr/bin/env bash
# The actual pre-fix shape of scripts/test-suites/required/05-delete-all-prod-db-guard.sh:
# still asserts the refusal message that was intentionally removed from product.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(bash "$SCRIPT_DIR/product.sh" 2>&1)"

if ! grep -q "Refusing to run" <<<"$OUT"; then
  echo "FAIL: expected production DB guard message, got: $OUT"
  exit 1
fi
echo "PASS: production delete-all guard is enforced"
