#!/usr/bin/env python3
"""Detect repeated-churn episodes on a subsystem from real git history.

Unlike a raw session-cost outlier (see claude_session_cost.py -- which
can't tell "big legitimate work" from "thrashing"), this looks for a
sharper, more specific signal: many commits landing on the SAME narrow
set of files in bursts, separated by quiet gaps. That shape -- not one
big session, but many small "fix the fix" commits clustered in time --
is what the mergify_admin_requeue subsystem in Invoker actually looks
like: 322 commits to scripts/mergify_admin_requeue*.py across 3 weeks,
in bursts (57 commits in a single day at the peak), the exact
"admin-bypass kept firing over and over again" pattern.

Usage:
    python3 git_churn_episodes.py <repo-path> <path-glob> [--gap-days N] [--thrash-threshold N]

Example (run from inside an Invoker checkout):
    python3 git_churn_episodes.py . 'scripts/mergify_admin_requeue*.py' --gap-days 3 --thrash-threshold 10

Read-only: runs `git log`, nothing else. No writes anywhere.
"""
import argparse
import datetime
import subprocess
import sys


def git_commit_dates(repo_path: str, path_glob: str):
    result = subprocess.run(
        ["git", "-C", repo_path, "log", "--all", "--format=%ad|%H|%s", "--date=short", "--", path_glob],
        capture_output=True, text=True, check=True,
    )
    rows = []
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        date_str, sha, subject = line.split("|", 2)
        rows.append((datetime.date.fromisoformat(date_str), sha, subject))
    rows.sort(key=lambda r: r[0])
    return rows


def group_episodes(rows, gap_days: int):
    episodes = []
    current = []
    prev_date = None
    for date, sha, subject in rows:
        if prev_date is not None and (date - prev_date).days > gap_days:
            episodes.append(current)
            current = []
        current.append((date, sha, subject))
        prev_date = date
    if current:
        episodes.append(current)
    return episodes


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("repo_path")
    ap.add_argument("path_glob")
    ap.add_argument("--gap-days", type=int, default=3, help="Days of silence that ends an episode")
    ap.add_argument("--thrash-threshold", type=int, default=10, help="Commits in one episode to flag as thrash")
    args = ap.parse_args()

    rows = git_commit_dates(args.repo_path, args.path_glob)
    if not rows:
        print(f"No commits found touching '{args.path_glob}' in {args.repo_path}", file=sys.stderr)
        sys.exit(1)

    episodes = group_episodes(rows, args.gap_days)
    total_commits = len(rows)
    total_span_days = (rows[-1][0] - rows[0][0]).days

    print(f"Path:              {args.path_glob}")
    print(f"Total commits:     {total_commits}")
    print(f"First -> last:     {rows[0][0]} -> {rows[-1][0]}  ({total_span_days} days)")
    print(f"Episodes found:    {len(episodes)}  (gap >{args.gap_days}d ends an episode)")
    print()

    thrash_commits = 0
    print(f"{'#':>3}  {'start':<10}  {'end':<10}  {'days':>5}  {'commits':>8}  flag")
    for i, ep in enumerate(episodes, 1):
        start, end = ep[0][0], ep[-1][0]
        span = (end - start).days + 1
        n = len(ep)
        is_thrash = n >= args.thrash_threshold
        if is_thrash:
            thrash_commits += n
        flag = "  <-- THRASH EPISODE" if is_thrash else ""
        print(f"{i:>3}  {start}  {end}  {span:>5}  {n:>8}{flag}")

    print()
    thrash_episodes = [e for e in episodes if len(e) >= args.thrash_threshold]
    print(f"=== Summary ===")
    print(f"Thrash episodes (>= {args.thrash_threshold} commits): {len(thrash_episodes)}")
    print(f"Commits inside thrash episodes:                  {thrash_commits} / {total_commits} ({thrash_commits/total_commits*100:.0f}%)")
    if thrash_episodes:
        print()
        print("A healthy fix for a real, one-off bug is usually 1-3 commits: a repro,")
        print("a fix, maybe a follow-up. Anything landing in double digits inside one")
        print("burst on the same narrow path is a strong signal of 'fix the fix' churn")
        print("-- worth pulling the actual commit messages for that window and reading")
        print("what kept re-breaking, rather than assuming it was N different bugs.")


if __name__ == "__main__":
    main()
