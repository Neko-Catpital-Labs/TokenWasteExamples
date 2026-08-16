#!/usr/bin/env bash
set -euo pipefail
COSTS_FILE="$1"
LABEL="$2"

total=0
count=0
honest=0
while read -r _agent _state elapsed_kv tokens_kv; do
  tokens="${tokens_kv#tokens=}"
  total=$((total + tokens))
  count=$((count + 1))
  if [ "$tokens" -gt "$honest" ]; then
    honest="$tokens"
  fi
done < "$COSTS_FILE"

echo ""
echo "=== $LABEL ==="
echo "agents that touched this job: $count"
echo "total tokens spent:           $total"
echo "honest cost (one agent, once): $honest"
if [ "$total" -gt "$honest" ]; then
  waste=$((total - honest))
  pct=$(( (waste * 100) / total ))
  echo "wasted tokens:                 $waste (${pct}% of total spend)"
else
  echo "wasted tokens:                 0 (0% of total spend)"
fi
