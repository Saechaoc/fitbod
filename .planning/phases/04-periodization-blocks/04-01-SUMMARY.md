# 04-01 Summary - Wave 0 Pure Foundation

Implemented (Wave 0 — non-conflicting Phase 4 primitives that don't
require SchemaV4 ownership):
- `fitbod/Prescription/PeriodizationEngine.swift` — `enum PeriodizationEngine`
  static facade with three pure-function helpers:
    - `phase(for: Block, on: Date) -> BlockPhase?` — resolves the
      `BlockPhase` containing the given date by walking the
      `block.phases` sorted by `orderIndex` and accumulating each
      phase's `weeks * 7` days from `block.startDate`. Returns the
      first phase for dates BEFORE block.startDate; returns nil
      for dates AFTER the block's last phase.
    - `weekIndex(for: Block, on: Date) -> Int?` — zero-based linear
      week counter spanning the entire block, computed from
      `block.startDate`. Returns nil for dates outside the block's
      span.
    - `weekContext(for: Block, weekIndex: Int, on: Date) -> MesocycleWeekContext?`
      — produces a value snapshot for the BlockCard week-pager,
      carrying phase kind / order / weeks / volume + intensity
      multipliers / week start + end dates / days remaining /
      isCurrentWeek / isDeloadWeek.
    - `recommendedNextKind(after: BlockPhaseKind) -> BlockPhaseKind`
      — static map per D-23: accumulation -> intensification,
      intensification -> realization, realization -> deload,
      deload -> accumulation.
- `fitbod/Periodization/MesocycleWeekContext.swift` — Sendable value
  type the engine emits for a single mesocycle week. Carries all
  the data the BlockCard week-pager needs without leaking the
  underlying @Model.
- `fitbod/Periodization/BlockTemplates.swift` — `enum BlockTemplates`
  with the 3 stock templates from D-03 + a blank template, plus
  `template(for: BlockPhaseKind)` helper used by BlockReviewView's
  recommended-next CTA seed:
    - Generic Strength Meso: 4w accumulation + 2w intensification +
      1w realization + 1w deload.
    - Hypertrophy Meso: 5w accumulation + 2w intensification + 1w
      deload.
    - Powerlifting Peak: 3w accumulation + 3w intensification + 1w
      realization + 1w deload.
    - Blank Block (no phases).
  Each template uses the D-10 RP-aligned multipliers (accumulation
  1.0/0.75, intensification 0.85/0.88, realization 0.6/0.97, deload
  0.5/0.75).
- `fitbod/Periodization/BlockPhaseColors.swift` — `enum BlockPhaseColors`
  static helpers for the D-07 heat-map palette:
    - `color(for: BlockPhaseKind) -> Color` (accent teal /
      system-amber / system-orange / desaturated gray).
    - `phaseLabel(_:) -> String` for the chip text + the
      BlockReviewView recommended-next CTA label.
- `fitbod/Prescription/FatigueAdvisory.swift` — protocol
  `FatigueAdvisory` with `shouldSuggest(context:) -> Bool` returning
  ONLY a Bool (BLOCK-08 type-level canonicality enforcement — no
  way for an advisory implementation to return a `DeloadMutation`).
- `fitbod/Prescription/StubFatigueAdvisory.swift` — Phase 4 stub
  returning `false` for every context. Phase 5 will replace this
  with the real fatigue signal without touching the UI.

Test suites:
- `PeriodizationEngineTests` — pins phase-resolution math + week
  index math + week context value contents + recommendedNextKind
  rules. 10 @Test functions cover the day-by-day boundary cases
  (Phase 1 of N, edges of each phase, past-end, before-start, empty
  block).
- `BlockTemplatesTests` — pins each template's exact phase counts
  + multipliers + total weeks. 4 @Test functions.
- `FatigueAdvisoryCanonicalityTests` — pins that the protocol's
  return type is `Bool` (not `DeloadMutation`), pins
  `StubFatigueAdvisory.shouldSuggest` returns false in v1, and pins
  the file-source-anchor `FatigueAdvisory` protocol declaration. 3
  @Test functions.

Verification:
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/PeriodizationEngine -only-testing:fitbodTests/BlockTemplates -only-testing:fitbodTests/FatigueAdvisoryCanonicality` -> all GREEN.
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'` -> BUILD SUCCEEDED.

Notes:
- Wave 0 ships ONLY the pure-function primitives that don't
  collide with Phase 3.1's SchemaV4 ownership. `Block.reviewedAt`
  (D-26) was DEFERRED to Plan 04-08 and lands in SchemaV5.
- `RoutineExercise.prescribedWeight` (D-17 explicit baseline) was
  also deferred for the same reason; the existing `lastSessionWeight`
  path in `SessionFactory` covers the no-baseline case for Phase 4.
- The static rule map (D-23) lives in `PeriodizationEngine` rather
  than `BlockReviewStatistics` so it's testable as a pure function
  without any block fixture.

Commit: 761c78f (Wave 0..04-06 combined commit — pre-3.1
reconciliation in-flight work).
