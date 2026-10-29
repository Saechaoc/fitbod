# Risks

Each entry is a way this run can fail, and what limits the damage.

## A worker drifts out of scope

- Failure: a medium-effort worker "improves" nearby code, renames things, or fixes bugs that belong to other tickets.
- Mitigation: each ticket names its files and its acceptance.
  The coordinator checks `git show --stat` against the ticket's `owns` list before accepting a commit.
  Out-of-scope bugs go to `notes.md` and become new tickets.

## Two tickets fight over one file

- Failure: hot files such as `ProgramView.swift`, `BlockBuilderView.swift` and `SessionExerciseCard.swift` change under a worker.
- Mitigation: a ticket never starts while a live ticket owns one of its files, and each worker edits only its own worktree.
  `capacity_model.py` prints the files that three or more tickets own, so the coordinator knows where tickets will wait for each other and where regressions are likely.
  The coordinator merges only as a fast-forward, after a rebase and a build when `main` moved.

## The lanes overload the Mac

- Failure: three workers build and run UI tests at the same time, so tests time out or turn flaky, and good work gets rejected.
- Mitigation: each lane runs one simulator job at a time, with its own phones and DerivedData.
  Gates and exclusive tickets run with no other worker.
  The coordinator drops to two lanes when timeouts show, and notes it in the run log.

## A merge breaks another lane's work

- Failure: two tickets edit different files that depend on each other, so each one passes alone, and together they break the build or a flow.
- Mitigation: each worker rebases onto `main` before its final runs, and the coordinator rebases and builds again when `main` moved after that.
  Each phase gate runs the full suite on the merged `main`, and a failing gate gets a fix ticket before the next phase opens.

## Ticket worktrees pile up

- Failure: worktrees, branches and booted phones from finished tickets fill the disk, and later checks confuse them with live work.
- Mitigation: the coordinator removes each worktree and its branch right after the merge.
  Evidence lives in the main checkout, so nothing is lost with a worktree.
  Phase 8 checks that no ticket worktree or branch is left, and shuts down the lane phones.

## GitNexus rates an edit CRITICAL

- Failure: a worker stops, or ignores the rating.
- Mitigation: [worker-rules.md](worker-rules.md) says to report every HIGH or CRITICAL rating and cover the named flows with tests.
  In `manual` mode, where the index has no Swift symbols, the worker's own rating from its caller check takes GitNexus's place.
  The coordinator copies each rating into [run-log.md](run-log.md).

## A shared fix breaks a screen nobody tested

- Failure: an app-wide change, such as swipe-back (T18) or the number field (T39), breaks a screen outside the ticket's tests.
- Mitigation: phase gates run the full suite after each phase.
  T46 screenshots every milestone screen in eight configurations.

## UI tests are slow or flaky

- Failure: a full UI run takes longer than one shell call allows, or a flaky test blocks acceptance.
- Mitigation: workers start long runs in the background.
  Each ticket runs the unit target plus its own UI suites, and full runs happen only at phase gates.
  A flaky test that blocks acceptance gets fixed in that ticket and noted.

## The fresh-store reset races the install

- Failure: `-fitbod-reset-store` is lost on the first launch, and a test starts on old data.
- Mitigation: T01 launches and terminates once per test process and checks that the store is fresh.

## A worker changes the schema

- Failure: an "easy" model change moves the user's store aside and loses data.
- Mitigation: the rules forbid schema changes and tell the worker to ask instead.
  The coordinator checks every diff under `fitbod/Models/` and `fitbod/Persistence/`.

## A worker adds a Co-Authored-By trailer

- Failure: the worker's system prompt asks for the trailer, and the worker follows it.
- Mitigation: the rules say the user's `CLAUDE.md` wins.
  The coordinator checks each commit message, and Phase 8 checks every commit of the run before the push.

## A worker touches pre-existing or protected files

- Failure: a worker stages the user's uncommitted files or the other terminal's design files.
- Mitigation: the rules list every such path, ban `git add -A`, and require `status-before.txt`.
  The coordinator compares status before and after each ticket.

## The project workflow rule blocks workers

- Failure: a worker reads the project `CLAUDE.md`, sees the GSD rule, and refuses to edit or starts `/gsd-quick`.
- Mitigation: the task header records the user's approval of the exception, and the rules tell workers never to run `/gsd-*`.
  Without that approval, no ticket is dispatched.

## Workers stall on permission prompts

- Failure: workers wait for approval of every build, test or commit, and the run stops while nobody watches.
- Mitigation: worker tabs follow the user's Orca setting for new agent tabs.
  The user chooses that setting before dispatch, as [dispatch.md](dispatch.md) asks.

## The design export arrives mid-run

- Failure: the refreshed export lands after T32 or T33 is built, and those screens are built twice.
- Mitigation: T31 runs before T32 and T33, and the coordinator checks again before Phases 5 and 6.
  T43 limits the refresh to milestone screens.

## Backup restore deletes routines (N1)

- Failure: N1 is real, so any user who restores a backup today loses every routine.
- Mitigation: T41 reproduces it with a round-trip test first, then fixes it with a format version bump that keeps older backups restorable.

## Old commit hashes mislead someone

- Failure: the plan, the review and older notes cite hashes from before the 2026-10-29 rewrite, such as `4e43f88`, so a `git show` fails or a diff starts from the wrong base.
- Mitigation: the worker rules point to the commit map, and the coordinator records a run base that T44 and Phase 8 use.

## The old history gets pushed

- Failure: someone pushes `backup/main-before-build-purge-20261029`, `backup/m1-worktree-20261028` or `task/codex`, and the remote gets the 5,358 old `build/` files back.
- Mitigation: workers never push.
  The coordinator pushes only `main`, and only as a fast-forward.

## Another session runs the same plan

- Failure: on 2026-10-29, while this bundle was being written, another session started running the same plan.
  It wrote `/gsd-quick` plans for every phase, from 1a to 4, under `.planning/quick/261028-uhg-*` and `.planning/quick/261029-*`.
  It dispatches its own Orca workers in the main checkout, in run `run_b263b8bcfd94`.
  By 10:32 it had committed four fixes on `main`: `ba8e0fa` (item 1), `4d7e07e` (item 2 and `Session.loggedSetCount`), `c0f6773` (item 41) and `e74c810` (item 42).
  None of them is pushed yet.
  At 10:39 its worker `task_2375eb69fb1b` was live, with uncommitted edits in the three note sheets, `NotesPersistenceTests` and `NoteSheetsUITests`, which matches item 33.
  Two efforts on one checkout overwrite each other's edits, commit each other's files and fight over the two simulators.
  Update at 14:47 on 2026-10-29: that effort now runs on the `csaechao4` Mac as Orca run `run_f64c6aa47f95`, with each quick task in its own git worktree under `~/orca/workspaces/fitbod/`.
  Two of its agents are still working there: `q-261029-a9s` (items 4, 5, 6 and 34) and `q-261028-uhg-t3` (item 3).
  Its `260610-hcv` fix for New Block phase titles at 390-393pt is on `main` as `3ff4a8a`.
  Later on 2026-10-29 the user chose to let that run finish only those two tasks, start none of its queued plans (`261029-d6u` to `261029-di1`), and then continue with this bundle in parallel lanes.
- Mitigation: only one effort runs.
  The user chose this bundle, so its coordinator creates no Orca run until the other effort has stopped.
  If this bundle continues, the other effort first finishes or stops, and the worktree checks in precondition 7 of [dispatch.md](dispatch.md) pass.
  The coordinator then maps each of that effort's commits to tickets by review item.
  It lists them with `git log --oneline 12aad09..HEAD` right before the first dispatch, because the list grew while this bundle was written.
  A capacity-model warning that a `new:` file already exists is another sign of overlap.
  A ticket whose items are all fixed is marked `skipped`, with the commit hashes.
  A ticket with some items fixed is dispatched with those items and hashes in its task header.
  A worker whose repro already passes reports "not reproduced", as the worker rules say.

## A large ticket exhausts a worker's context

- Failure: an L ticket on a hot file runs out of context before it commits.
- Mitigation: tickets are scoped to one concern each.
  If a worker fails twice, the coordinator splits the ticket.

## Simulator results do not match a real phone

- Failure: VoiceOver, haptics, notifications and offline behavior pass on a simulator but differ on a device.
- Mitigation: these stay open flags in the closeout docs, each with its next action.
