# Assumptions

Each line is a fact this bundle relies on, checked on 2026-10-29 unless it says otherwise.
The coordinator re-checks the first group before the first dispatch.

## Repository state

- The bundle was written on another Mac, where the repo is `/Users/chrissaechao/Desktop/fitbod`.
  The run now happens on csaechao4's Mac, where the main checkout is `/Users/csaechao4/orca/fitbod`, on branch `main`.
  When this bundle was finished at 10:36, `main` was at `e74c810`, four commits from the other effort after `12aad09`.
- At 15:26, `main` was at `a520c26` and `origin/main` at `c64dd8c`, so four docs commits were not pushed yet.
- Phase 0 of the plan is done: the backup branch `backup/m1-worktree-20261028` exists, the seven commit groups are committed, and GitNexus was refreshed.
- On 2026-10-29 another session rewrote the unpushed history to drop the tracked `build/` folder (5,358 files), then pushed `main`.
  `/build/` is now in `.gitignore`, and git tracks no file under `build/`.
- Hashes from before that rewrite, such as `4e43f88` in the plan and the review, no longer exist on `main`.
  `docs/review-docs/history-rewrite-20261029-commit-map.txt` maps each old hash to its new one, so old `4e43f88` is new `df108b0`.
- The old history survives only on the local branches `backup/main-before-build-purge-20261029`, `backup/m1-worktree-20261028` and `task/codex`.
  None of them may ever be pushed.
- The paths listed under "Files you must never edit or stage" in [worker-rules.md](worker-rules.md) were uncommitted on the other Mac before this run.
  On csaechao4's Mac, `git status` in the main checkout showed no uncommitted path apart from this bundle's own edits.
- No app source changed between the Oct 5 review and Phase 0, so review items 1 to 47 still apply.
  Line numbers in the review refer to the Oct 5 snapshot.

## Baseline

- The Phase 0 baseline ran the full suite on the large phone at default text: 1,026 tests, 1,023 passed, 2 failed and 1 expected failure, in about 15.8 minutes.
- The two failures are `MilestoneOneJourneyUITests/testAuthorRoutineLogRelaunchFinishAndHistory` ("106" instead of "10", item 5) and `WhyThisWeightSheetBRUUITests/testWhyThisWeightSectionHeadVisible` (item 4).
- The expected failure is `ProgramGraphDeleteRuleBehaviorTests.slottedTemplateDenyRuleRuntimeEnforcement`, wrapped in `withKnownIssue`.
- The build has one warning: a deprecated text concatenation in `BlockBuilderView.swift` near line 736.

## Tools and devices

- The bundle was written beside Xcode 26.5 (17F42) on an Apple M4 with 10 cores and 32 GB of memory.
- csaechao4's Mac has Xcode 27.1 (27A9275) on an Apple M4 Pro with 12 cores and 48 GB of memory, which carries three lanes.
- The Orca CLI is `/Applications/Orca.app/Contents/Resources/bin/orca`.
- On the other Mac, the GitNexus CLI is the global `gitnexus` binary, and the index holds three repos, so every call passes `--repo fitbod`.
- On csaechao4's Mac, GitNexus's Swift parser does not load, so the index has no Swift symbols, and the run uses `manual` mode.
  Running `gitnexus analyze` there rewrites `.gitignore` and skill files.
- On csaechao4's Mac, the gate phones "sw6 iPhone 17e" (`FF89B400-1160-4818-8436-314B014D2614`) and "sw6 iPhone 17 Pro Max" (`69E32D56-148D-40A7-9D1B-543F6878B1D1`) use the iOS 27.0 runtime.
  New phones need that runtime too, because creating them on iOS 27.1 failed there.
  Simulator ids differ between Macs, so the run log records each lane's ids.
- `orca worktree create --base-branch main` makes each ticket worktree from the local `main`, as the quick-task run's worktree branches show ("Created from refs/heads/main").
  `worker-start --worktree path:<worktree>` then starts a worker in it.
  `worker-release` closes only the worker's terminal, so the coordinator removes worktrees itself.
- Copilot CLI asks before it changes files outside its working folder, so workers keep their evidence inside their worktree.
- The app and test targets use folder-synchronized groups, so new files need no project file edit.

## Code facts the tickets rely on

- Block status is derived, never stored: completed, then active, then ready, then draft (`Block.derivedStatus`).
- A block is ready when it has a routine with at least one session, and, under fixed weekly scheduling, as many training days as sessions.
- `Block` has a `startDate` that defaults to the creation time, but no separate creation timestamp.
- Both New Block save buttons call the same save function today.
  The review's item 36 says they create different things, so T11 must re-check before changing anything.
- `Split` and `SessionTemplate` both have an `isArchived` flag.
- `BackupArchiver` and `BackupRestorer` never mention `Split` or `SplitSessionSlot` (finding N1).
  Nobody has run a round trip to prove the loss yet.
- `RoutinesListView` appears only in its own previews.
- `Session.loggedSetCount` counts completed work sets and never warm-ups; the other effort added it in `4d7e07e`.
- `SplitDetailView.removeSlot` deletes a slot without clearing its session link first, and no UI test removes a session from a routine (T40).
- Restore never checks the backup format version; it checks the checksum, the schema version and whether a workout is in progress.
- The plan names five New Block guardrail suites, but six exist: `BlockBuilderViewActivationTests` is the sixth.

## Outside the repo

- The refreshed design export from the claude.ai design project had not landed in the repo, Desktop, Downloads or Documents when this bundle was written.
  T31 checks again.
- Another terminal may still write files under `bru-screens/`.
- The user authorized the push to `main` in the plan, and CI does not run on pushes to `main`.
