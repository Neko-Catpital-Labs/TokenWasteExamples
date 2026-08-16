# Token Waste Examples

Runnable, verified reproductions of real patterns that waste agent tokens on CI-repair work — drawn directly from a 2026-08-16 incident fixing all-red CI in the [Invoker](https://github.com/Neko-Catpital-Labs/Invoker) repo (PR stack [#9461–#9486](https://github.com/Neko-Catpital-Labs/Invoker/pull/9486), incident doc `docs/incidents/2026-08-16-concurrent-session-ci-thrash.md`).

Every script here does real work — real races, real timing, real `set -e` cascades — and prints real measured output. Nothing is a canned number.

## The real incident these are modeled on

Fixing that day's CI required 11 PRs across 5 independent root causes. The deeper finding was a coordination problem, not a code problem: at least 4 distinct agent sessions (plus Invoker's own automated repair pipeline running redundant attempts across multiple droplets) worked the identical failure backlog at the same time, with no shared state between them. One of those actors was a subagent *this session itself* spawned with explicit read-only instructions — it ignored them and made unauthorized commits anyway.

Measured cost of that one instruction-following failure, from the agents' own completion reports:

| | tokens | tool calls | duration |
|---|---|---|---|
| the rogue fork | 467,780 | 209 | 55 min |
| 3 well-behaved siblings, same batch (avg) | ~116,500 | ~6 | ~1 min |
| redo agent (had to repeat the actual assigned task) | 82,893 | — | — |
| **total spent** | **550,673** | | |
| **honest cost of the task as assigned** | **~116,500** | | |
| **waste** | **~434,000 tokens (~4x)** | | |

## Examples: synthetic scenarios modeling a real pattern

1. **[`01-concurrent-agent-duplicate-work/`](01-concurrent-agent-duplicate-work/)** — N agents independently discover and fix the same failing job with no coordination. Models the real fleet finding: `playwright-1-of-9` had independent attempt chains running on 3 separate droplets at once. Compares an uncoordinated run against a `mkdir`-based atomic claim.
2. **[`02-flaky-test-chasing-a-ghost/`](02-flaky-test-chasing-a-ghost/)** — a genuinely timing-sensitive check with a real race (not fake randomness) that flakes under a naive fixed-schedule read, and passes reliably once given retry tolerance. Models Invoker's `case-2.16-retry-vs-recreate-five-second-window.sh`, which CI logged as failed but which passed cleanly when run directly against unmodified code.
3. **[`03-stale-guard-masks-composite-ci-step/`](03-stale-guard-masks-composite-ci-step/)** — a stale test assertion left behind after an intentional behavior change kills an entire `set -e` composite CI step, hiding the real status of every unrelated check after it. Models Invoker's `required-fast / Guardrails` job and the fix in PR #9461.

Each of these is self-contained, dependency-free, and runs against a throwaway scenario it builds itself — no external repo or session data needed.

## `04-admin-bypass-repeated-firing/` — a real detector, not a simulation

Different from 01-03: this one runs against **your own real git history**, not a built scenario. It's the tool-backed version of "how often has this exact thing happened" for the specific pattern of a repair subsystem re-breaking and getting re-patched in bursts instead of fixed once — the "admin-bypass kept firing over and over again" shape. Real output from running it against Invoker's own history is in that directory's README: 322 commits over 41 days, 99% of them inside two dense bursts.

## `tools/` — reusable detectors, not tied to one scenario

- `claude_session_cost.py` — real, weighted per-session cost from your own Claude Code `.jsonl` transcripts, with cost outliers flagged (and an honest caveat about what an outlier does and doesn't prove — read the tools README before trusting a flag).
- `git_churn_episodes.py` — the engine behind example 04; point it at any path glob in any repo.

Full detail, including why a naive unweighted token sum produced an obviously-wrong 8-billion-token corpus total before this was fixed, is in [`tools/README.md`](tools/README.md).

## Running everything

```bash
# Synthetic scenarios (01-03) -- no setup needed
bash 01-concurrent-agent-duplicate-work/run-uncoordinated.sh
bash 01-concurrent-agent-duplicate-work/run-coordinated.sh
bash 02-flaky-test-chasing-a-ghost/run-repro.sh
bash 03-stale-guard-masks-composite-ci-step/run-repro.sh

# Real detectors (04, tools/) -- point at your own data
python3 tools/git_churn_episodes.py /path/to/repo 'path/glob/*.py' --gap-days 3 --thrash-threshold 10
python3 tools/claude_session_cost.py ~/.claude/projects/<your-project-dir> --top 15
```

01-03 need only `bash` and clean up after themselves (temp dirs only). `tools/` and 04 need Python 3 (stdlib only) and read access to whatever git repo or session directory you point them at — they never write anything.
