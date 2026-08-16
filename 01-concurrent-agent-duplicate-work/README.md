# Concurrent agents, duplicate work

**Models:** a 2026-08-16 SSH sweep of Invoker's 6-droplet fleet (`scripts/fleet-ssh.sh`) found its own automated `fix-ci` → `reflect-ci` → repair pipeline running redundant, independent fix attempts for the *same* failing job on *multiple droplets simultaneously* — e.g. `playwright-1-of-9` had separate attempt chains running on 3 droplets at once, with no cross-droplet locking. The same session separately found 3+ live agent sessions on one machine independently working the identical CI-failure backlog by hand.

## What's here

- `lib/agent.sh` — one simulated agent. Given a job name and a mode (`uncoordinated` or `coordinated`), it "investigates" (1.5s), "fixes" (1.0s), and tries to commit. Real elapsed wall-clock time converts to a token estimate at the end (`TOKENS_PER_SECOND`, default 2000) — this is a stand-in unit, not a claim about real per-second token rates; what matters is the *ratio* between runs, not the absolute number.
- `lib/summarize.sh` — reads every agent's logged cost, reports total spend vs. the honest cost of one agent doing the job once, and the waste.
- `run-uncoordinated.sh` — launches 4 agents in parallel against the same job with **no** coordination. All 4 do the full investigate+fix cycle; only the first to write wins, the other 3's work is discarded on conflict.
- `run-coordinated.sh` — same 4 agents, same job, but each does an atomic `mkdir` claim before doing any real work (`mkdir` is atomic on POSIX filesystems — this is a real lock, not a simulated one). Only the claimant does the work; the rest exit immediately.

## Run it

```bash
bash run-uncoordinated.sh
bash run-coordinated.sh
```

## What you'll see

Uncoordinated: 4 agents all pay the full investigate+fix cost; 3 of the 4 have their commits rejected as conflicts. Typical output: ~75% of total tokens spent are pure waste.

Coordinated: 1 agent claims and pays the full cost; the other 3 detect the claim immediately and skip. 0% waste.

The mechanism (an atomic claim before starting work, not a check-then-append race) is the same shape as the fix a peer session was mid-building the same day this was modeled on: a `repair_filings` SQLite table with a `UNIQUE(kind, subject, state_sha)` constraint, exposed via a `--headless repair-filing insert|release` command. This demo uses a lock directory instead of SQLite to stay dependency-free, but the principle is identical.
