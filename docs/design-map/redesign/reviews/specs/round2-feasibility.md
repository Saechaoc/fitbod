# Round 2 verification: feasibility lens

You reviewed draft v1 of the Today/Program redesign bundle and wrote `reviews/round1-claude-feasibility.md`.
The bundle is now draft v2.
Bundle: `/Users/chrissaechao/Desktop/fitbod/docs/design-map/redesign/`.
Repository: `/Users/chrissaechao/Desktop/fitbod` at commit 0ef702ea (unchanged since round 1).
Read `changelog.md` and `review-log.md` first; the log maps every round-1 finding to a resolution or an accepted-with-reason entry.

Your job is to break draft v2, not to re-review v1.

1. For each finding in your round-1 report, say closed, partly closed or not closed, naming the v2 leaf and the line that closes it.
   Where `review-log.md` claims a closure you cannot find in the leaves, say so.
2. Attack v2 fresh with your lens, against the source and the project's conventions (`CLAUDE.md`, `docs/DEVELOPMENT.md`, `.claude/rules/swift/`):
   - Can every Phase 1 step in `plan.md` be built as written, with no schema change and no `ObservableObject`, `@Query` in a view model or multi-level optional chain in a `#Predicate`?
   - The prescribed-count helper: can `SessionFactory.swift` lines 183-200 and 284-310 and `WarmupRamp.shouldGenerate` share one helper with `BlackSlabCTA.swift` and `LiftListRow.swift` without changing what the factory generates? Name what the helper needs as inputs.
   - `TodayState` as a pure function: list the inputs it needs that `TodayView.swift` does not already hold, and whether each is available without a new query.
   - The this-week row: is making `FatigueModel.fetchWorkingSets` non-private and calling it in a `.task(id:)` keyed on finished workout IDs enough, or does the row need something else (week boundary, the calendar, empty-workout exclusion)?
   - `VolumeScreen` on both stacks: does registering `VolumeRoute` and `MuscleSlugRoute` on the Progress stack conflict with anything in `fitbod/Progress/` or `fitbod/App/RootView.swift`?
   - The review as a sheet with `onDismiss` calling `acknowledge`, and `BlockReviewView` taking an origin: what in `BlockReviewView.swift` and `BlockReviewTriggerTests` breaks, and is the step's test list complete?
   - Program's `HeaderAction("+ New")` with the popover's height measurement: does `BRUHeaderBar` support what `program-layouts.md` describes?
   - Is every test suite named in a step the right one, and is any suite that would break missing? Spot-check with `rg`.
   - Is any Phase 1 step still dependent on a Phase 2 piece?
3. Rank by blast radius and split blockers from fix-soon.
   Each finding states Trigger, Mechanism, Blast radius and the Smallest fix.

Write the report to `<bundle>/reviews/round2-claude-feasibility.md`.
Do not edit any other file.
Then report `worker_done` with one verdict line (final as written, or not final) and the number of blockers.
