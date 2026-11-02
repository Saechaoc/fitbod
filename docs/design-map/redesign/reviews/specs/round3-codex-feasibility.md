# Round 3 (Codex): feasibility lens on draft v3

You were dispatched to review draft v1 of the Today/Program redesign bundle and hit the ChatGPT usage limit before writing a report.
This round you take the feasibility lens: can the plan be built as written in this codebase, and are its test lists complete?
Discard any notes you kept on v1; the bundle has changed twice since.
Bundle: `/Users/chrissaechao/Desktop/fitbod/docs/design-map/redesign/` (draft v3).
Repository: `/Users/chrissaechao/Desktop/fitbod` at commit 0ef702ea (unchanged since your first dispatch).
Read `index.md`, `changelog.md` and `review-log.md` first.
The log maps every round-1 and round-2 finding of the interim Claude reviewers to a resolution or an accepted-with-reason entry; nobody has reviewed v3 itself.

Your job is to break draft v3 against the source and the project's conventions (`CLAUDE.md`, `docs/DEVELOPMENT.md`, `.claude/rules/swift/`).

1. Pick the ten claims in `review-log.md` with the widest blast radius (the seven blockers B-1 to B-5, B2-1, B2-2 and three fix-soon items of your choice) and say for each whether the leaves really close it, naming the leaf and the line.
2. Attack v3 fresh with the feasibility lens:
   - Can every Phase 1 step in `plan.md` be built as written: no schema change, no `ObservableObject`, no `@Query` in a view model, no multi-level optional chain in a `#Predicate`? Check the queries step 1.1 names and their Swift post-filters.
   - `workingSetCount(targetSets:phase:)`: can `SessionFactory.swift` (lines 183-200 and 284-310) call it with `scheduledBlockPhase` without changing what the factory generates? The factory resolves the phase with `Calendar.current` and Today with the environment calendar: name a day or time zone where the hero and the logger would disagree, if one exists.
   - `TodayState` as a pure function: list the inputs it needs that `TodayView.swift` does not already hold, and whether each is available without a new query.
   - The this-week row: `FatigueModel.completedWorkingSets(startedFrom:before:in:)` filtered to `SessionSetActions.countedWorkouts`, in a `.task(id:)` keyed on the finished workout IDs and the week start from `mondayAtMidnightForToday`. Is that enough, and does each named symbol exist with that visibility and signature?
   - The session sheet: can `TodaySessionPicker` compute "the resolver's next slot, else the first slot after it that holds the session, wrapping" and the "skips …" subline from what it holds plus `TodayResolution`? Name the inputs and anything the resolver does not expose.
   - The review as a sheet with `onDismiss` calling `acknowledge` guarded on `reviewedAt == nil`, and `BlockReviewView` with an `origin` parameter defaulting to `.today`: what in `BlockReviewView.swift`, `BlockReviewTriggerTests`, `BlockReviewHeroLayoutTests`, `BlockReviewPRMarkTests`, `BlockReviewAfterEndUITests`, `ArchiveRoutineUITests` and `BlockLifecycleEntryPointsUITests` breaks, and is step 2.1's list complete?
   - Deleting `pendingBlockBuilder`'s `.template` case with StartBlockCTA while keeping `.edit`: is `TodayView.swift:206` the only setter and does anything else read the case?
   - `VolumeScreen` on both stacks: does registering `VolumeRoute` and `MuscleSlugRoute` on the Progress stack conflict with anything in `fitbod/Progress/` or `fitbod/App/RootView.swift`?
   - Program's `HeaderAction("+ New")` with the popover's height measurement: does `BRUHeaderBar` support what `program-layouts.md` describes?
   - Is every test suite named in a step the right one, and is any suite that would break missing? Spot-check with `rg`.
   - Is any Phase 1 step still dependent on a Phase 2 piece?
3. Rank by blast radius and split blockers from fix-soon.
   Each finding states Trigger, Mechanism, Blast radius and the Smallest fix.

Write the report to `<bundle>/reviews/round3-codex-feasibility.md`.
Do not edit any other file.
Then report `worker_done` through the Orca orchestration CLI as your original task instructions said, with one verdict line (final as written, or not final) and the number of blockers.
