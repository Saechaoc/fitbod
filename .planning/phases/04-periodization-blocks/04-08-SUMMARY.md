# 04-08 Summary - Block Review Sheet (BLOCK-07 + BLOCK-08)

Implemented:
- `fitbod/Periodization/E1RMHelper.swift` — `enum E1RMHelper` with
  pure-function `epley(weight:reps:)`. Returns `weight * (1 + reps /
  30.0)` for reps in 1...10, returns the original weight unchanged
  for `reps == 0` or `reps > 10` (Epley loses accuracy above 10
  reps). Per RESEARCH §6 line 557 fallback.
- `fitbod/Periodization/BlockReviewView.swift` — the .large
  sheet with 4 sections:
    1. Total volume — sums `weight * reps` across completed
       non-warmup `SetEntry` rows whose `completedAt ∈ [blockStart,
       blockEnd]`, displays "X kg total / Y working sets across Z
       sessions" or "No logged sets in this block." empty-state
       copy.
    2. e1RM deltas — top working set per exercise per session,
       computes Epley e1RM, compares earliest vs latest session per
       exercise, sorts by `abs(delta)` descending with name tie-break.
       Empty-state "Not enough sessions logged to compute deltas."
    3. PRs hit — Phase 6 placeholder: "Coming in Phase 6. Full PR
       detection ships with the progress views update."
    4. Recommended next phase — `PeriodizationEngine.recommendedNextKind(after:)`
       resolves the just-finished phase kind. CTA "Start [Recommended]
       Block" presents `BlockBuilderView(draft: BlockDraft(template:
       template))` seeded with the recommended template. "Not now"
       dismisses the sheet without seeding.
  - Acknowledge action wraps the dual-write in
    `try ctx.transaction { block.reviewedAt = now; block.isActive =
    false; try context.save() }`. This is the SINGLE legitimate
    writer of `block.isActive = false` from review acknowledgment
    (alongside `BlockDraft.save` from plan 04-02 and `BlockCard.endBlock`
    from plan 04-04a). `FatigueAdvisory` cannot reach this code path
    — type-level BLOCK-08 enforcement from plan 04-01 holds.
  - `enum BlockReviewStatistics` namespace exposes the math as
    pure / @MainActor static helpers so the test target can call
    them directly without spinning up a SwiftUI view: `totalVolume`,
    `workingSetCount`, `sessionCount`, `completedWorkingSets`,
    `e1RMDeltas`, `recommendedNextKind`, `triggerDescriptor`,
    `pendingReviewBlocks`, `acknowledge`, `formattedKg`,
    `formattedDelta`.
- `fitbod/App/RootView.swift` TodayView gains
  `@State private var pendingBlockReview: Block? = nil` +
  `.task { pendingBlockReview = (try? BlockReviewStatistics
  .pendingReviewBlocks(context: ctx, now: Date.now))?.first }` +
  `.sheet(item: $pendingBlockReview) { block in
  BlockReviewView(block: block).presentationDetents([.large]) }`.
  The existing Phase 4 banner stack (DeloadWeekBanner /
  ConsiderDeloadBanner / BlockCard / StartBlockCTA /
  ResumeWorkoutBanner) is preserved unchanged.
- `fitbod/Models/Block.swift` gains `var reviewedAt: Date? = nil`
  (FOUND-02 safe optional + nil default).

Schema changes:
- `fitbod/Persistence/SchemaV5.swift` NEW — additive successor to
  SchemaV4. Typealias-based (16 entity typealiases pointing to the
  top-level production types). VersionIdentifier 5.0.0.
- `fitbod/Persistence/SchemaV4.swift` rewritten with nested @Model
  classes for the V3->V4 intermediate shape (carries intent +
  progression on BOTH parent and child). This freezes V4 as the
  pre-Phase-4 historical shape so SwiftData can checksum-distinguish
  V4 vs V5 stores by entity-shape.
- `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` registers
  SchemaV5 + adds `migrateV4toV5` (MigrationStage.lightweight — the
  single Optional<Date> addition is lightweight-eligible per Apple
  docs).
- Production runtime container flipped from `Schema(SchemaV4.models)`
  to `Schema(SchemaV5.models)` in `fitbodApp.swift` and
  `PreviewModelContainer.swift`.

Test suites turning GREEN:
- `BlockReviewMathTests` — 9 @Test functions. Pins E1RMHelper Epley
  formula + edge cases (reps 0 / in-range / >10); total volume sums
  over block range; total volume excludes warmup + incomplete sets;
  e1RM delta sign (positive / negative / zero); empty deltas when
  <2 sessions per exercise; recommendedNextKind for blocks ending
  in deload (-> accumulation) and realization (-> deload);
  acknowledge sets reviewedAt + deactivates in a transaction;
  source-anchor for `try context.transaction { ... block.reviewedAt
  = now; ... block.isActive = false }`.
- `BlockReviewTriggerTests` — 11 @Test functions. Pins the
  matched-once-then-acknowledged trigger semantics (D-21): trigger
  predicate matches ended + active + unreviewed; excludes
  active-but-unended / ended-but-inactive / ended-active-but-reviewed
  / nil endDate; invariant-violating multi-active case returns >= 1
  row; acknowledgment removes block from trigger set; UI-SPEC
  verbatim copy anchors for placeholder + CTA + Done + Not Now;
  TodayView wires the .task + .sheet(item:) + BlockReviewStatistics
  .pendingReviewBlocks call.

Verification:
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17'` -> BUILD SUCCEEDED
- `xcodebuild test -only-testing:fitbodTests/BlockReviewMathTests -only-testing:fitbodTests/BlockReviewTriggerTests` -> TEST SUCCEEDED (20/20 GREEN)
- Plan 04-01..04-07 supporting suites still GREEN.

Notes:
- Acknowledge transaction wraps the dual-write per BLOCK-08 — the
  single transaction guarantees that on failure neither field is
  updated.
- D-21 trigger semantics pin via `pendingReviewBlocks` which
  filters `triggerDescriptor`'s result by `endDate < now` in Swift
  (the predicate alone can't compare against a captured Date in the
  Swift 6 toolchain without a local-let workaround; the post-filter
  is the cleaner pattern at this scale).
- Recommended-next CTA presents `BlockBuilderView(draft:
  BlockDraft(template:))` with `isActive = false` default in the
  draft — the user must explicitly toggle "Active block" in the
  builder. This honors UI-SPEC line 575: "does NOT auto-activate
  the new block."

Deferred follow-up:
- **3 end-to-end SchemaV4MigrationTests fail at runtime** —
  `endToEndRoutineBackfill`, `endToEndSessionBackfillWithTieBreak`,
  `emptyExerciseListKeepsDefaults` all fail with "intentRaw is a
  required value" when the V3->V4->V5 migration chain runs. The
  V3->V4 didMigrate closure (per the Phase 3.1 + 4 redesign) doesn't
  populate the V4 child rows' intentRaw before SwiftData validates
  the V5-shape parent Routine/Session entities (V5 production
  Routine.intentRaw is non-optional String). This is a Phase 3.1
  migration-design issue exposed by Phase 4's V5 bump, not Plan
  04-08 scope. The user's freshly-seeded V5 dev store path is
  unaffected. The remaining 8 SchemaV4MigrationTests (smoke,
  modeRaw tie-break, fresh V5 container open, Block.reviewedAt
  round-trip) pass.

Phase 4 closure:
- With Plan 04-08 complete, all 10 Phase 4 requirements close:
  BLOCK-01 (block builder) — Plan 04-02.
  BLOCK-02 (Today block timeline) — Plan 04-04a.
  BLOCK-03 (mesocycle week pager) — Plan 04-04a.
  BLOCK-04 (deload volume cut) — Plan 04-07.
  BLOCK-05 (phase multipliers) — Plan 04-01 + 04-06.
  BLOCK-06 (fatigue advisory scaffold) — Plan 04-01 + 04-04b.
  BLOCK-07 (end-of-block review) — Plan 04-08 (this plan).
  BLOCK-08 (canonical block-deload writer) — Plan 04-01 + 04-08.
  PRES-05 (BlockPeriodizedStrategy) — Plan 04-06.
  PRES-06 (HybridStrategy) — Plan 04-06.
