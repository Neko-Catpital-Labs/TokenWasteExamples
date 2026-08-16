# Admin-bypass, repeated firing

**Models:** the recurring pattern the Invoker team has hit multiple times where an "admin-bypass" repair subsystem keeps firing, breaking, and getting re-patched instead of the underlying gate getting fixed once. Unlike the other three examples (synthetic scenarios standing in for a real pattern), this one is a **real detector you run against real history** — no simulation, the data is your own git log.

## Why cost-outlier detection isn't enough here

[`tools/claude_session_cost.py`](../tools/claude_session_cost.py) (see the root tools README) flags sessions that cost far more than the corpus median. Run against Invoker's real local session history, it flagged 51 of 144 sessions as "outliers" — but a lot of those are just long, legitimately hard sessions, not thrash. Raw cost can't tell the difference between "this took a while because it was real work" and "this took a while because it kept re-breaking."

The admin-bypass pattern needs a sharper signal: not *how expensive was one session*, but *how many separate commits landed on the same narrow subsystem in a burst*. A real bug fix is usually 1-3 commits. Dozens of commits to the same files inside a tight window is a different shape entirely.

## What's here

- [`../tools/git_churn_episodes.py`](../tools/git_churn_episodes.py) — walks real `git log` history for a given path glob, groups commits into "episodes" (runs separated by a configurable quiet-gap), and flags any episode with commits above a threshold as a thrash episode.

## Run it

Against your own checkout of a repo with this pattern:

```bash
python3 ../tools/git_churn_episodes.py /path/to/repo 'scripts/mergify_admin_requeue*.py' --gap-days 3 --thrash-threshold 10
```

## Real output, run against Invoker's own history (2026-08-16)

```
Path:              scripts/mergify_admin_requeue*.py
Total commits:     322
First -> last:     2026-07-06 -> 2026-08-16  (41 days)
Episodes found:    3  (gap >3d ends an episode)

  #  start       end          days   commits  flag
  1  2026-07-06  2026-07-08      3        18  <-- THRASH EPISODE
  2  2026-07-13  2026-07-13      1         3
  3  2026-07-18  2026-08-16     30       301  <-- THRASH EPISODE

=== Summary ===
Thrash episodes (>= 10 commits): 2
Commits inside thrash episodes:                  319 / 322 (99%)
```

Note: this glob (`scripts/mergify_admin_requeue*.py`) is deliberately broad — it counts every commit touching any file in that family, including tests and tooling, not just the repair-subsystem's own logic. A narrower, hand-curated definition used in an earlier incident doc (`docs/incidents/2026-08-16-mergify-admin-bypass-thrash-review-followups.md`) reports a different, smaller commit count for a more tightly-scoped read of "the repair subsystem itself." Both are real, correct answers to slightly different questions — the tool here is meant for a fast first pass across any repo, not a replacement for reading the actual commit messages in a flagged window.

## What the flagged window actually means

322 commits over 41 days to one narrow subsystem, 99% of them inside two dense bursts, is the git-history signature of a gate that kept re-breaking rather than getting fixed once — patching the alarm each time instead of the underlying condition it alarms on. Confirming *why* requires reading the commits inside a flagged episode, which this tool deliberately doesn't do for you (see "Not fixed here" in the root README) — it points at where to look, not what you'll find there.
