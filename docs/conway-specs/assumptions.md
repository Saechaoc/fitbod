# Assumptions

Each line is a fact this bundle relies on, checked on 2026-10-29 unless it says otherwise.
The coordinator re-checks the first group before the first dispatch.

## Repository state

- The repo is `/Users/chrissaechao/Desktop/fitbod`, on branch `main`.
  When this bundle was finished at 10:36, `main` was at `e74c810`, four commits from the other effort after `12aad09`.
- `origin/main` is still `12aad09`, so those four commits are not pushed yet.
- Phase 0 of the plan is done: the backup branch `backup/m1-worktree-20261028` exists, the seven commit groups are committed, and GitNexus was refreshed.
- On 2026-10-29 another session rewrote the unpushed history to drop the tracked `build/` folder (5,358 files), then pushed `main`.
  `/build/` is now in `.gitignore`, and git tracks no file under `build/`.
- Hashes from before that rewrite, such as `4e43f88` in the plan and the review, no longer exist on `main`.
  `docs/review-docs/history-rewrite-20261029-commit-map.txt` maps each old hash to its new one, so old `4e43f88` is new `df108b0`.
- The old history survives only on the local branches `backup/main-before-build-purge-20261029`, `backup/m1-worktree-20261028` and `task/codex`.
  None of them may ever be pushed.
- The paths listed under "Files you must never edit or stage" in [worker-rules.md](worker-rules.md) were uncommitted before this run.
- No app source changed between the Oct 5 review and Phase 0, so review items 1 to 47 still apply.
  Line numbers in the review refer to the Oct 5 snapshot.

## Baseline

- The Phase 0 baseline ran the full suite on the large phone at default text: 1,026 tests, 1,023 passed, 2 failed and 1 expected failure, in about 15.8 minutes.
- The two failures are `MilestoneOneJourneyUITests/testAuthorRoutineLogRelaunchFinishAndHistory` ("106" instead of "10", item 5) and `WhyThisWeightSheetBRUUITests/testWhyThisWeightSectionHeadVisible` (item 4).
- The expected failure is `ProgramGraphDeleteRuleBehaviorTests.slottedTemplateDenyRuleRuntimeEnforcement`, wrapped in `withKnownIssue`.
- The build has one warning: a deprecated text concatenation in `BlockBuilderView.swift` near line 736.

## Tools and devices

- Xcode 26.5 (17F42) on an Apple M4 with 10 cores and 32 GB of memory.
- The Orca CLI is `/Applications/Orca.app/Contents/Resources/bin/orca`.
- The GitNexus CLI is the global `gitnexus` binary, and the index holds three repos, so every call passes `--repo fitbod`.
- The two simulators in [worker-rules.md](worker-rules.md) exist and are reserved for this run.
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
