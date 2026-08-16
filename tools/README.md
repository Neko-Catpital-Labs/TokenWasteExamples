# Detection tools

Two standalone scripts that run over **real** data — your own session transcripts, your own git history — rather than simulating a scenario. No network access, no writes, dependency-free (stdlib Python 3 only).

## `claude_session_cost.py` — real per-session cost from Claude Code transcripts

```bash
python3 claude_session_cost.py ~/.claude/projects/<your-encoded-project-dir> --top 15 --outlier-factor 3
```

Parses real `.jsonl` session files, dedupes usage by `message.id` (a single API turn can span several JSONL lines — thinking, tool_use, text — that all repeat the same usage snapshot; summing without dedup roughly doubles the count), and reports a **weighted** cost per session: fresh input at 1x, cache-read at 0.1x, output at 5x. These are illustrative relative weights, not your exact billing rate — edit `WEIGHTS` at the top of the script to match your actual pricing.

**Why weighted, not raw summed tokens:** `cache_read_input_tokens` reflects the *entire* growing conversation being re-read from cache on every single turn. Summing it unweighted across a long session scales close to the square of the turn count and produces numbers with no comparable meaning across sessions of different length — a first version of this script did exactly that and reported a 144-session corpus at 8 billion tokens with a single session at 1.25 billion, which is not a believable number for what it claims to measure. Caught before publishing by checking the raw numbers against a real, independently-reported figure from earlier in the same investigation (a subagent's own 467,780-token self-report) and finding they weren't in the same units.

**Real caveat, not a limitation to gloss over:** run against Invoker's own local session history, this flagged 51 of 144 sessions as "cost outliers" at a 3x-median threshold. Most of those are not thrash — they're long sessions doing real, hard, legitimately expensive work. A cost outlier is a candidate for a human to look at, not proof of waste on its own. It worked well earlier in this same investigation specifically because the comparison set was several *near-identical-scope* subagent tasks given in the same batch — one being 4x the others' cost, when all were assigned the same kind of narrow read-only task, was real signal. Comparing wildly different session types (an 11-hour marathon against a 10-minute fix) on raw cost alone conflates "big" with "wasteful." For a sharper signal on a specific recurring pattern, see `git_churn_episodes.py`.

## `git_churn_episodes.py` — repeated-churn detection from real git history

```bash
python3 git_churn_episodes.py /path/to/repo 'scripts/some-subsystem*.py' --gap-days 3 --thrash-threshold 10
```

Groups a path's real commit history into episodes (runs of commits separated by a quiet gap), flags any episode above a commit-count threshold. See [`../04-admin-bypass-repeated-firing/`](../04-admin-bypass-repeated-firing/) for real output against Invoker's own `mergify_admin_requeue` subsystem: 322 commits over 41 days, 99% of them inside two dense bursts.

This is the sharper tool for "did the same thing keep breaking" specifically — many small commits clustered in time on one narrow path is a much less ambiguous signal than raw session cost.

## What neither tool does

Neither script tells you *why* a flagged session or episode happened — that still needs a human (or an agent) reading the actual commits or transcript in the flagged window. These are fast first-pass triage, not root-cause analysis. Treat a flag as "look here," not "confirmed waste."
