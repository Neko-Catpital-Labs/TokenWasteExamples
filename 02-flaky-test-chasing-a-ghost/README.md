# Flaky test, chasing a ghost

**Models:** Invoker's `required-fast / Reset Rulebook Repro` CI job logged `case-2.16-retry-vs-recreate-five-second-window.sh` as FAILED on 2026-08-16. Running that exact script directly against unmodified `master` passed cleanly (`PASS case 2.16`, exit 0) — real evidence, not a guess, that the failure was a timing flake rather than a deterministic bug. The real script's own comments already acknowledge this: *"a read-only sampler can lose that race; retry transient busy/empty reads so the assertion still checks reset timing instead of failing on the harness read."* No fix was proposed for it, since this repo's policy requires a reproducible failure before proposing one, and none was found.

## What's here

- `naive_check.sh` — starts a background "writer" that finishes after a real, random 10-159ms delay (standing in for a headless owner process finishing a state transition), then reads the result exactly once on a fixed 50ms schedule. No fake randomness in the assertion itself — this is an actual race between two real processes.
- `robust_check.sh` — the identical writer and the identical race, but the read side polls with a bounded retry loop (up to 200ms) instead of reading once on a fixed schedule.
- `run-repro.sh` — runs each check 30 times against the same underlying code and reports the pass/fail split for both.

## Run it

```bash
bash run-repro.sh
```

## What you'll see

The naive check fails a large fraction of its 30 runs (typically 50-80%) — same code, same race, different outcome every time, because the outcome was never deterministic to begin with. The robust check passes essentially all 30 runs, because the retry window comfortably covers the writer's maximum real delay.

**The point:** the underlying race never goes away between the two checks — only the check's tolerance for it does. If an agent had "fixed" the naive check's failures the way you'd fix a real bug (root-cause a code change, patch something, verify, ship a PR), every one of those fixes would have been chasing a check design problem while leaving the actual, correct product code untouched. The real fix for a timing-sensitive test is widening its tolerance, not patching the thing it's testing.
