#!/usr/bin/env python3
"""Real token-cost audit over a directory of Claude Code session transcripts.

Parses actual .jsonl session files (the format Claude Code writes to
~/.claude/projects/<encoded-cwd>/), sums real usage from each assistant
turn, and flags cost outliers -- the same mechanism that caught a rogue
subagent mid-incident on 2026-08-16 (see ../04-... and the root README).

A single API turn can span multiple JSONL lines (one per content block:
thinking, tool_use, text) that all repeat the SAME usage snapshot. This
script dedupes by message.id before summing, confirmed against a real
session file: 4,977 raw usage-bearing lines collapsed to 2,566 distinct
message ids in one sampled session -- summing without dedup overstates
cost by roughly 2x.

Usage:
    python3 claude_session_cost.py <dir-of-jsonl-files> [--top N] [--outlier-factor X]

No network access, no writes -- read-only over the given directory.
"""
import argparse
import json
import statistics
import sys
from pathlib import Path



# Rough relative price weights for a Sonnet-class model (fresh input = 1x).
# These are NOT exact current list prices -- adjust to your own rate card.
# The point of weighting at all: cache_read tokens are real API traffic but
# heavily discounted, and a long-running session re-reads its own growing
# history on every single turn, so a raw unweighted sum scales close to
# O(turns^2) and produces numbers with no comparable meaning across
# sessions of very different length. Weighting collapses that back to
# something in the same units as "how much did this actually cost."
WEIGHTS = {"fresh_input": 1.0, "cache_read": 0.1, "output": 5.0}


def session_cost(path: Path):
    seen_ids = {}
    turns = 0
    first_ts = None
    last_ts = None
    with path.open(errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = obj.get("timestamp")
            if ts:
                if first_ts is None:
                    first_ts = ts
                last_ts = ts
            msg = obj.get("message")
            if not isinstance(msg, dict):
                continue
            usage = msg.get("usage")
            if not isinstance(usage, dict):
                continue
            mid = msg.get("id") or f"noid-{obj.get('uuid')}"
            if mid in seen_ids:
                continue
            fresh_input = usage.get("input_tokens", 0) + usage.get("cache_creation_input_tokens", 0)
            cache_read = usage.get("cache_read_input_tokens", 0)
            output = usage.get("output_tokens", 0)
            seen_ids[mid] = (fresh_input, cache_read, output)
            turns += 1
    fresh_input_total = sum(v[0] for v in seen_ids.values())
    cache_read_total = sum(v[1] for v in seen_ids.values())
    output_total = sum(v[2] for v in seen_ids.values())
    weighted = (
        fresh_input_total * WEIGHTS["fresh_input"]
        + cache_read_total * WEIGHTS["cache_read"]
        + output_total * WEIGHTS["output"]
    )
    return {
        "file": path.name,
        "fresh_input": fresh_input_total,
        "cache_read": cache_read_total,
        "output": output_total,
        "weighted_cost": weighted,
        "turns": turns,
        "first_ts": first_ts,
        "last_ts": last_ts,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("session_dir", type=Path, help="Directory of .jsonl Claude Code session files")
    ap.add_argument("--top", type=int, default=15, help="How many top-cost sessions to print")
    ap.add_argument(
        "--outlier-factor",
        type=float,
        default=3.0,
        help="Flag sessions costing more than this many times the corpus median",
    )
    args = ap.parse_args()

    files = sorted(args.session_dir.glob("*.jsonl"))
    if not files:
        print(f"No .jsonl files found in {args.session_dir}", file=sys.stderr)
        sys.exit(1)

    results = [session_cost(p) for p in files]
    results = [r for r in results if r["turns"] > 0]
    if not results:
        print("No sessions with usage data found.", file=sys.stderr)
        sys.exit(1)

    costs = [r["weighted_cost"] for r in results]
    median = statistics.median(costs)
    total = sum(costs)

    print(f"Sessions analyzed:        {len(results)}")
    print(f"Total weighted cost:      {total:,.0f}  (weights: fresh_input=1x, cache_read=0.1x, output=5x -- adjust WEIGHTS in this script to your real rate card)")
    print(f"Median session cost:      {median:,.0f}")
    print(f"Mean session cost:        {statistics.mean(costs):,.0f}")
    print()

    ranked = sorted(results, key=lambda r: r["weighted_cost"], reverse=True)
    threshold = median * args.outlier_factor
    outliers = [r for r in ranked if r["weighted_cost"] > threshold and median > 0]

    print(f"=== Top {args.top} sessions by weighted cost ===")
    print(f"{'w.cost':>12}  {'turns':>6}  {'fresh_in':>10}  {'cache_rd':>12}  {'output':>10}  {'vs median':>10}  file")
    for r in ranked[: args.top]:
        ratio = (r["weighted_cost"] / median) if median else 0
        flag = "  <-- outlier" if r["weighted_cost"] > threshold and median > 0 else ""
        print(
            f"{r['weighted_cost']:>12,.0f}  {r['turns']:>6}  {r['fresh_input']:>10,}  "
            f"{r['cache_read']:>12,}  {r['output']:>10,}  {ratio:>9.1f}x  {r['file']}{flag}"
        )

    print()
    print(f"=== Outliers (> {args.outlier_factor}x median weighted cost) ===")
    if outliers:
        outlier_cost = sum(r["weighted_cost"] for r in outliers)
        print(f"{len(outliers)} session(s), {outlier_cost:,.0f} weighted-cost units ({outlier_cost/total*100:.1f}% of corpus total)")
        for r in outliers:
            print(f"  {r['file']}  {r['weighted_cost']:,.0f} units, {r['turns']} turns, {r['output']:,} real output tokens")
    else:
        print("None found at this threshold.")

    print()
    print("=== Waste summary ===")
    if outliers and median > 0:
        excess = sum(r["weighted_cost"] - median for r in outliers)
        print(f"Sessions analyzed:            {len(results)}")
        print(f"Sessions flagged as outliers: {len(outliers)}  (> {args.outlier_factor}x median cost)")
        print(f"Median session cost (baseline): {median:,.0f}")
        print(f"Excess cost above baseline across the outliers: {excess:,.0f}  ({excess/total*100:.1f}% of total corpus cost)")
        print()
        print("This is NOT a claim that all outlier sessions thrashed -- a cost outlier")
        print("is where to look, not proof of what you'll find (see README.md). It reads")
        print("as: if every outlier had cost the same as a typical session instead, the")
        print("corpus would be smaller by this many weighted-cost units.")
    else:
        print("No outliers at this threshold -- no excess-cost figure to report.")


if __name__ == "__main__":
    main()
