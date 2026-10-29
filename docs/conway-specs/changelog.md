# Changelog

Newest first.

## 2026-10-29: fixes for unattended dispatch

- What: a "Settle a ticket" step now runs for every ending: merged, done without a commit, failed, rejected, stopped, split or abandoned.
  It releases the worker, copies the evidence, removes the worktree, frees the lane and held files, retires the ticket's own waiting asks, and answers the oldest ask waiting for each freed file.
- Why: held files were freed only on a merge, so a stopped worker in a mutual wait kept its file, and neither ticket could finish.
- What: Supervise is one loop: handle every message in a delivery, then acknowledge the delivery once.
- Why: `--ack` covers the whole batch, and failed or rejected results skipped the only ack, so their delivery replayed ahead of newer results.
- What: acceptance knows no-commit results, such as T44 or "not reproduced", checks only the evidence a ticket's kind and acceptance ask for, and reruns a repro only where one exists.
- What: tasks take no `--deps`, because the ledger is the dependency record and skipped tickets have no task; the ledger keeps each ticket's latest task id.
- What: every task header gives the run base, and T47 and T48 get a copy of the live run log.
  The evidence copy list now covers T33 and T41's result for T47, and the coordinator checks that every input is there before it starts a worker.
- What: the coordinator does T31 itself in the main checkout, finds design changes with git instead of file dates, and keeps a copy of any export in `evidence/T31/export/`.
- Why: a new worktree has none of the uncommitted design files or home folders that T31 searches, and checkouts give every file a fresh date.
- What: after the findings are fixed, the touched T46 screens are captured again, and Phase 8 reruns T44, and T45 if needed, when code changed after the verification, then refreshes T47's docs and T48's review page.
- What: new findings tickets get an index.md row before validation, and coordinator changes to the bundle are committed by exact path as they happen; Phase 8 also checks that nothing is left uncommitted.
- What: questions are answered with `orca orchestration reply --id <message id> --body "<answer>" --json`, because `--body` is required.
- What: `capacity_model.py` adds the T46 rerun and the Phase 8 reruns, so it now estimates about 114 hours serial and about 72 with three lanes.

## 2026-10-29: review fixes for the parallel run

- What: workers keep their evidence inside their own worktree, and the coordinator copies it to the main checkout before it removes the worktree.
  The coordinator also copies in the earlier evidence that T32, T41, T43 and T47 read.
- Why: Copilot CLI asks before it changes files outside its folder, so a worker that wrote to the main checkout could wait for an approval nobody gives.
- What: the coordinator now creates each worktree with `orca worktree create`, checks its base, copies evidence in, and then starts the worker there.
- What: a worker asks before it edits any file outside its `owns` list, and the coordinator holds that file for the ticket until it merges.
- Why: otherwise two tickets could both fix the same broken UI test, and the second merge would send a whole ticket back to the start.
- What: a rejected ticket whose worker reported `succeeded` is retried as a new task.
- Why: Orca accepts `--retry-of` only for a failed or stopped attempt.
- What: dropped the phase-window report from `capacity_model.py`, which no doc used.
- What: when a requested file is owned or held, the coordinator replies "wait"; the worker commits everything else, asks again, and edits the file in one more commit after its rebase.
  Two workers never wait on each other: the later one stops and is retried.
- Why: the playbook said when to grant a file but not what happens otherwise, and T04 and T09 can both need `WorkoutLoggerJourneyUITests` at the same time.
- What: exclusive and Phase 7 tickets follow their own Ownership section without asking, and accept check 2 allows those files.
- Why: they run alone, and T42, T43 and T47 get files by kind, such as "any app or test file that has a warning", which they would otherwise have to ask for one by one.
- What: the coordinator acknowledges a waiting worker's second ask at once, notes its message id under "Held files", and replies yes to the oldest waiting ask when the file is freed.
- Why: Orca replays the oldest unacknowledged batch and hides newer mail, so holding the ask unacknowledged would hide the holder's `worker_done` and stall the run.
- What: T47 and T48 are exclusive tickets now, and the exemption from asking covers exclusive tickets only.
- Why: a findings ticket made during T47 lands in Phase 7 and could run beside T47 or T48, so "Phase 7 runs alone" was not always true.

## 2026-10-29: parallel lanes in worktrees

- What: up to three workers now run at once, each ticket in its own Orca worktree and branch from the newest `main`, with each lane's own simulators and DerivedData.
- Why: the user asked for several agents in parallel and worktrees, and the serial run took about 107 hours against a 29-hour critical path.
- What: [dispatch.md](dispatch.md) gains terms, run setup, start rules, a merge step and worktree cleanup.
  A ticket waits while a live ticket owns one of its files, T42 to T46 run alone, and phases still wait for their gates.
- What: the coordinator merges each accepted branch with `git merge --ff-only`, after a rebase and a build when `main` moved.
- What: [worker-rules.md](worker-rules.md) now covers the worktree, the lane's phones by id, one `git rebase main` before the final runs, and evidence in the main checkout.
  It drops the last paths and simulator ids from the other Mac.
- What: GitNexus has an `index` and a `manual` mode, because the index on csaechao4's Mac has no Swift symbols, and `detect_changes` cannot see a worktree's staged files in either mode.
- What: `capacity_model.py` simulates one to four lanes; it estimates about 64 hours with three lanes and shows little gain from a fourth.
- What: [tradeoffs.md](tradeoffs.md) replaces the serial call, [risks.md](risks.md) gains three parallel risks, and [assumptions.md](assumptions.md) records csaechao4's Mac.
- What: the run log records the two approvals, the lanes, and two more ledger columns.
  T07 is skipped, because `c0f6773` and `2f6a955` fixed both of its items, and T25 and T33 note the other effort's work.
- Why: the user chose to let the quick-task run finish its two live tasks and then continue with this bundle.

## 2026-10-29: review docs in the repo, and every worktree checked

- What: the bundle now points at `docs/review-docs/fitbod-m1-review.md` and `docs/review-docs/history-rewrite-20261029-commit-map.txt`, which `dd42060` added to the repo.
- What: dispatch precondition 7 and the matching risk now check every git worktree: `orca worktree ps --json` must show no working agent outside the main checkout, and each other worktree in `git worktree list` needs the user's word that it is idle.
- Why: the other effort runs each quick task in its own worktree, so a check of the main checkout passed while two of its agents were working.
- What: the risk and the run log record those two agents, in `q-261029-a9s` and `q-261028-uhg-t3`, as of 14:47.

## 2026-10-29: moved into the repo

- What: moved the bundle from `~/Desktop/fitbod-review/conway-specs/` to `docs/conway-specs/` in the repo, and git now ignores its `evidence/` folder.
- Why: the user wants the specs in the project, so they can add them to their GSD plans later.
- What: updated the bundle path in the task header and the evidence path in the worker rules.
- What: workers may not edit the bundle or `.gitignore`, and the dispatch `git status` check expects both.
- What: the capacity model now finds the repo from its own location instead of a fixed path.
- What: the bundle now points at the plan's copy in the repo, `.planning/noble-wishing-conway.md`, which the other session added in `2e87d8d`.
- Not moved: the review (`fitbod-m1-review.md`) and the history-rewrite commit map stay in `~/Desktop/fitbod-review/`, and the bundle still points there.

## 2026-10-29: capacity model run, fourth commit from the other effort

- What: ran `capacity_model.py` and fixed what it found: an em dash in the model itself, and a T41 link to a tradeoff heading that did not match.
- What: the model now reports file line numbers, ignores quoted UI copy in its two-sentence check, and drops the Phase 5 gate from the estimate when T43 is skipped.
- What: added a worker rule for a `new:` file that already exists: add to it, keep its tests, and say so.
- Why: `4d7e07e` created `SkipWarmupsUITests.swift`, which T04 lists as new, and more overlaps will follow while the other effort runs.
- What: recorded `e74c810` (item 42) in the risk, the assumptions, the run base note and the T33 ledger row, and made the coordinator list the other effort's commits right before the first dispatch.
- Why: that effort committed a fourth fix at 10:32, which covers T33's only item.

## 2026-10-29: tickets finished, parallel effort advanced

- What: wrote T31 to T48 and the capacity model.
- Why: they finish Phases 2 to 7 of the plan.
- What: moved Program's "phase shown twice" fix from T38 into T26.
- Why: T26 already rebuilds that row.
- What: added the Library calls "Muscle picker labels" and "Muscle weight control", and clarified "Today's third stat" to mean a flat week trend.
- Why: T32 and T35 need exact rules, and the first third-stat wording did not say when the phase label shows.
- What: rewrote "Backup keeps routines (finding N1)" with the delete order, the format version and the rule for older backups.
- Why: T41 changes restore, and the first wording said older backups restore "as they do today", which no longer holds.
- What: rewrote "Shared counts" around `Session.loggedSetCount`, and added a T02 hint for it.
- Why: the other effort added that count in `4d7e07e`, and a second rule would split the count again.
- What: T40 now proves that removing a session from a routine survives a relaunch, and may fix `removeSlot`.
- Why: in Core Data terms, the `.deny` rule acts when a slot is deleted, so the slot delete itself may be refused, and no UI test covers it.
- What: T41 now depends on T40 and lists `BackupVersionSkewTests`; T39 now owns the session editor for its keyboard DONE.
- What: the worker rules' typing trap now points at T39's shared helper.
- What: updated the risk "Another session runs the same plan", dispatch preconditions 4 and 7, the run base, the assumptions and the ledger notes for T02, T03, T04 and T07.
- Why: by 10:27 that session had plans for every phase, its own Orca run, and three commits on `main` (`ba8e0fa`, `4d7e07e` and `c0f6773`) for items 1, 2 and 41.
- What: T44 and T45 reruns get their own evidence folders, and a T46 retry continues from the last finished configuration.

## 2026-10-29: parallel effort found, week rule corrected

- What: added the risk "Another session runs the same plan" and extended dispatch precondition 7 to cover it.
- Why: while T08 to T21 were being written, another session wrote `/gsd-quick` plans for phases 1a to 2g and started editing app files for T03 and T04.
- What: corrected the "Weekly Tonnage weeks" call in the tradeoffs.
- Why: the aggregator follows the user's week-start setting, which defaults to Monday, and is not fixed to Monday as the first draft said.

## 2026-10-29: history rewrite landed mid-write

- What: removed the Phase 8 stop for `build/`, replaced the old base hash `4e43f88` with a run base that the coordinator records, and added an old-hash trap to the worker rules.
- Why: while this bundle was being written, another session rewrote the unpushed history without `build/` and pushed `main` at `12aad09`, so every hash from before the rewrite is gone from `main`.
- Also: dropped `.planning/research/STACK.md` and `docs/STACK-RESEARCH.md` from the uncommitted list, because that session committed them.

## 2026-10-29: bundle created

- What: wrote 48 tickets for Phases 1 to 7 of the conway plan, plus the shared leaves and the capacity model.
- Why: the user wants Opus 5.5 medium workers to build the plan from Jira-style tickets that contain no code.
- Changes from the plan:
  - Added T41 for finding N1, because backup and restore never mention routines or their slots.
  - Added six New Block guardrail suites to the rules, because the plan names five and a sixth exists.
  - Interpreted decision 3 through `Block.derivedStatus`, because "ready" is a derived status and both saves call the same function today (see [tradeoffs.md](tradeoffs.md)).
  - Added a Phase 8 stop for the 5,358 tracked files under `build/`, because they would go to the remote with the push.
  - Replaced the plan's per-phase `/gsd-quick` with Orca tickets, which needs the user's approval (see [dispatch.md](dispatch.md)).
