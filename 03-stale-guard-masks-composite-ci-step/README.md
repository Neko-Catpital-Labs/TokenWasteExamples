# Stale guard masks a composite CI step

**Models:** Invoker's `required-fast / Guardrails` job runs 9 unrelated check scripts as one shell command under `set -e`. On 2026-08-16, three merged PRs (#9290, #9291, #9305, #9306) intentionally removed a production-DB refusal guard from the `delete-all` command — but `scripts/test-suites/required/05-delete-all-prod-db-guard.sh` still asserted the old refusal message. That one stale check failed on every run, and because it ran first in the composite step, it killed the step immediately — the 5 real, unrelated checks after it (`06` through `51` in the real job) never ran at all. Fixed in [PR #9461](https://github.com/Neko-Catpital-Labs/Invoker/pull/9461): the guard test was updated to assert the new, intended behavior instead.

## What's here

- `product.sh` — stands in for `delete-all` after the guard was intentionally removed: runs unconditionally, prints a completion message.
- `guard_test_stale.sh` — the actual pre-fix shape of `05-delete-all-prod-db-guard.sh`: still asserts the old refusal message.
- `guard_test_fixed.sh` — the actual post-fix shape (PR #9461): asserts the new, correct completion message.
- `check-06.sh` through `check-10.sh` — 5 trivial, always-passing checks standing in for the unrelated real checks that share a CI step with the guard test.
- `composite_step.sh` — runs the guard test plus all 5 downstream checks in one `set -e` sequence, exactly like the real job's one shell step.
- `run-repro.sh` — runs the composite step twice: once with the stale guard test, once with the fixed one.

## Run it

```bash
bash run-repro.sh
```

## What you'll see

**Before the fix:** the stale guard test fails immediately. `check-06` through `check-10` never execute — not "they passed," not "they failed," their status is simply unknown, and the whole step reports as one opaque failure with no way to tell from the outside whether any of the other 5 checks are actually broken too.

**After the fix:** all 6 checks run and report their real, individual status.

**The point:** a composite CI step that bundles unrelated checks behind one `set -e` sequence turns "one stale assertion" into "five checks' worth of lost signal." The fix here wasn't "make the job green" — it was "stop one stale check from hiding five unrelated ones." This is also why Invoker's own `skills/review-compression/SKILL.md` was updated the same day to call out composite/auto-discovery CI jobs as an explicit split trigger: each check bundled into one step is still a separate review claim, even though they share one job label.
