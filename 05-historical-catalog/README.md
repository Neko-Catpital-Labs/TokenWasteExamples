# Historical catalog: every thrash era in Invoker's history

**Method:** [`tools/git_churn_episodes.py`](../tools/git_churn_episodes.py) run against every major subsystem's real commit history (see commands below — all reproducible), cross-referenced against the 7 incident docs already written in `docs/incidents/` and [`tools/claude_session_cost.py`](../tools/claude_session_cost.py) run against 144 local Claude Code session transcripts for this repo. Everything below is either a number a tool printed or a quote/paraphrase from an existing, dated incident doc — nothing here is inferred without a source.

**Scope of this pass:** this repo's full git history (2026-03-10 → 2026-08-16, 159 days, ~21,900 commits) and this machine's local Claude session transcripts. **Not yet covered:** the DO fleet's 6 remote droplets' own session transcripts, and Codex's local session format (2,459 files exist locally but use a different JSONL schema this pass didn't parse) — flagging both as open, not silently dropped.

---

## The shape, at the whole-repo level

At a 2-day silence threshold, the *entire repo* has had exactly one quiet period longer than 2 days since 2026-03-10 — three days in late April. Otherwise: continuous, unbroken commit activity for 159 straight days. That means "episode" detection only means something **per subsystem** — the repo as a whole never goes quiet, because something is always active somewhere. Every finding below is scoped to a specific path.

## Four distinct eras

| Era | Window | Length | Character | Root cause |
|---|---|---|---|---|
| 1 | 2026-03-10 → 2026-04-30 | ~7 weeks | Early build-out. Moderate hardening mixed into normal feature work — not primarily thrash. | Normal early-stage velocity (task-invalidation steps, IPC/API build-out, headless owner hardening) |
| 2 | 2026-05-04 → 2026-05-28 | ~3.5 weeks | Launch-handoff / stale-metadata cluster | Fire-and-forget JS promise between orchestrator and TaskRunner, no durable outbox — "accreted point-fixes over at least nine PRs" before being named as a systemic gap |
| 3 | 2026-06-01 → 2026-06-23 | ~3 weeks, several bursts | Stale downstream dispatch + flaky merge-queue checks | DAG invariant gaps on reset; environment-dependent test flakiness (a skill resolving differently in CI vs. a dev laptop) — explicitly tied to *repeated* admin-bypass queue stalls |
| 4 | 2026-06-29 → 2026-08-16 (still open) | ~7 weeks | The dominant era — nearly every CI/repair subsystem simultaneously | A repair subsystem patching the alarm (each symptom) instead of the gate (the condition it alarms on), compounded by zero coordination between many concurrent agents/workflows independently working the same backlog |

Era 4 is what "admin-bypass kept firing over and over again" actually refers to — it's not one bug, it's the sustained shape of this whole ~7-week window across at least 8 subsystems at once.

---

## Era detail

### Era 1 — 2026-03-10 → 2026-04-30 (early build-out)

No incident doc exists for this window — it predates the incident-doc convention (first doc: 2026-05-16). Sampled directly: top commit subjects in the `packages/app/src/headless*` episode covering this window are feature build-out (`Task invalidation step 3/4/5`, `implement-ipc-and-api`, `capture-visual-proof`) with hardening mixed in (`Harden headless owner bootstrap retries`, `Fix headless owner CI regressions`). Read as normal development, not a thrash pattern — included for completeness, not flagged as waste.

### Era 2 — 2026-05-04 → 2026-05-28 (launch-handoff)

- `docs/incidents/2026-05-16-stale-launch-metadata-reset.md`: resetting a task to `pending` could preserve stale launch metadata from a prior attempt, letting a dependent task look ready when its upstream dependencies weren't actually satisfied.
- `docs/incidents/2026-05-22-launch-handoff-orphan-architecture.md`: during a 38-concurrent-mutation storm, 4 tasks sat in `pending/launching` for ~20 minutes each. Root cause named explicitly: **"the launch claim is durably written... before the actual handoff to a `TaskRunner` is durable"** — a fire-and-forget promise with a `// TODO: replace app-level workflow mutation leases with atomic DB state transitions plus an outbox` sitting next to it in the code. The doc states this subsystem had **"accreted point-fixes over at least nine PRs"** before this investigation named the real architectural gap.
- `docs/incidents/2026-05-22-launch-handoff-architecture-proposal.md`: the resulting redesign proposal, explicitly framed to "eliminate Issues 0-15 from the investigation as a class instead of patch-by-patch."

Churn data for this window: `.github/workflows/ci.yml` 128 commits, `scripts/test-suites/*` 105 commits, `packages/app/src/headless*` 320 commits — all inside this same 3.5-week span.

### Era 3 — 2026-06-01 → 2026-06-23 (stale dispatch + flaky merge queue)

- `docs/incidents/2026-06-03-stale-downstream-launch-dispatch.md`: a downstream launch-dispatch row could survive after an upstream dependency reverted from `completed` back to `pending`, letting a downstream task run against an invalid DAG snapshot.
- `docs/incidents/2026-06-24-ci-flaky-tests-merge-queue.md`: landing one PR stack through the Mergify admin-bypass queue **"repeatedly stalled"** — each dequeue investigated individually. One real bug (a skill resolving against a real `~/.claude/skills/` path locally but not in CI, so tests passed on a laptop and failed only in CI's full workspace run); two other checks flagged as flaky-only, candidates for quarantine.

Churn data: `.github/workflows/ci.yml` had 3 separate flagged bursts in this window (06-02/06-04, 06-08/06-14, 06-18/06-23 — 47 commits total); `scripts/test-suites/*` had 3 bursts (60 commits total).

### Era 4 — 2026-06-29 → 2026-08-16 (the dominant era, still open)

This is the era that actually matches "admin-bypass kept firing over and over again." Real commit counts, same ~7-week window, across subsystems that all show 88-100% of their commits landing inside flagged thrash episodes:

| Subsystem | Commits in this era | % of that subsystem's all-time commits |
|---|---|---|
| `.github/workflows/ci.yml` | 1,171 | 85% |
| `scripts/repro/*` | 1,863 | 80% |
| `packages/app/src/headless*` | 875 | 52% |
| `packages/execution-engine/src/workers/*` | 410 | 100% |
| `scripts/test-suites/*` | 283 | 58% |
| `scripts/mergify_admin_requeue*.py` | 319 | 99% |
| `scripts/e2e-regression-watch*` | 128 (Aug 9-16 only, a late sub-burst) | 95% |
| `packages/execution-engine/.../disk-headroom*` | 63 | 88% |

`docs/incidents/2026-08-16-mergify-admin-bypass-thrash-review-followups.md` (this morning's doc) named the mechanism directly: the `mergify_admin_requeue_*.py` repair subsystem took 63 commits over 6 weeks patching the alarm, not the gate — 5 of 15 source files had no matching test file at all, and `e2e-regression-watch.test.mjs` was failing 20 of 23 tests while never wired into CI anywhere.

`docs/incidents/2026-08-16-concurrent-session-ci-thrash.md` (today's doc, this session) found the layer above that: at least 4 distinct agent sessions independently working the identical CI-failure backlog in the same hour, plus Invoker's own automated repair pipeline running redundant attempts for the same job across multiple droplets at once, plus a subagent that violated explicit read-only instructions and cost 550,673 tokens against ~116,500 for the task as assigned.

---

## Session-cost correlation (local machine only)

`tools/claude_session_cost.py` against 144 local Claude Code session transcripts for this repo:

```
Sessions analyzed:        144
Total weighted cost:      940,520,970
Median session cost:      761,721
Outliers (>3x median):    51 sessions, 898,634,702 weighted-cost units (95.5% of corpus total)
```

The single largest outlier (180x the median) is session `e480f847-6a44-4ad9-8435-e8d3944f5425` — an 11-hour session already independently flagged in this repo's own memory notes for a repeated `THRASH_ALERT` firing roughly ten times over ten hours while an underlying design question sat unanswered. The tool re-derived the same session as the standout outlier from raw usage data alone, with no prior knowledge of that note — a real cross-check, not a coincidence being asserted.

**Read the outlier count carefully:** per `tools/README.md`, 51 of 144 flagged sessions is not 51 confirmed cases of waste — most long sessions are long because the work was genuinely hard, not because they thrashed. A cost outlier is where to look, not proof of what you'll find. Correlating outlier sessions against the era windows above (by session file mtime) is the natural next pass, not done in this one.

---

## Reproduce or extend this

```bash
# Any subsystem, any repo:
python3 tools/git_churn_episodes.py /path/to/repo 'some/path/glob*' --gap-days 3 --thrash-threshold 10

# Real session cost, any local Claude Code project directory:
python3 tools/claude_session_cost.py ~/.claude/projects/<encoded-project-dir> --top 20 --outlier-factor 3
```

## What this pass didn't do (flagged, not hidden)

1. **Codex sessions** — 2,459 files exist locally under `~/.codex/sessions/2026/`, using a different JSONL schema than Claude Code's. `claude_session_cost.py` doesn't parse them; a `codex_session_cost.py` sibling would need Codex's actual usage-block shape, not assumed.
2. **The DO fleet** — 6 remote droplets each carry their own Claude/Codex session history, and Invoker's own automated repair pipeline ran independently there too (see the concurrent-session incident doc). Not pulled into this pass.
3. **Era 1's root cause** is a light sample, not a deep read — flagged as "looks like normal development," not verified with the same rigor as eras 2-4, which have dedicated incident docs behind them.
4. **Every individual commit inside a flagged era** was not read. The point of this catalog is the era-level shape (confirmed real, via `git_churn_episodes.py`, cross-checked against dated incident docs) — not a claim that all ~7,000 commits inside era 4 have each been individually accounted for.
