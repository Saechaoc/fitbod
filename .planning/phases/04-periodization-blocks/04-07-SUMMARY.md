# 04-07 Summary - Session Block Snapshot + Deload Volume

Implemented:
- `SessionFactory.start` now resolves `scheduledBlockPhase` /
  `scheduledDeloadActive` once at the top of the function via
  `PeriodizationEngine.phase(for: routine.block, on: date)` (read-only;
  no SwiftData mutation).
- The pre-existing `session.block = routine.block` snapshot line
  (Phase 2 / D-20) is now exercised by a dedicated test suite that
  pins the snapshot-survives-template-mutation contract.
- Working `SetEntry` count is `max(1, floor(targetSets *
  phase.volumeMultiplier))` when `scheduledDeloadActive` is true
  (D-12 halve sets / keep weight; RESEARCH §Pitfall 7 floor-div
  clamp). Non-deload phases (accumulation / intensification /
  realization) and routines without a block keep the full
  `re.targetSets` count.
- `WarmupRamp.shouldGenerate` is now invoked with the actual
  `scheduledDeloadActive` flag (was hard-coded `false` in Phase 3).
  Deload weeks skip warm-up ramps end-to-end per WARM-02.
- `RPEAutoregStrategy.prescribe` passes explicit `now: today` to
  `Calibration.predict` so the time-kernel computation honors the
  caller's date (defensive — previously defaulted to `Date()`).

Test suites flipped GREEN:
- `SessionBlockSnapshotTests` — 5 @Test functions. Pins
  `session.block?.id == routine.block?.id` after start; pins that
  mutating `routine.block = nil` post-start leaves `session.block`
  intact; pins `session.block == nil` when routine has no block; pins
  that `block.name` mutations DO propagate (the snapshot is the
  RELATIONSHIP, not field values); pins that deleting the block
  nullifies `session.block` (SwiftData inverse default).
- `DeloadVolumeApplicationTests` — 8 @Test functions. Pins the
  halve-on-deload contract (4 -> 2), the `max(1, ...)` clamp
  (`targetSets=1` -> 1 on deload), unchanged behavior on accumulation
  / intensification / realization (volumeMultiplier only halves on
  `.deload`), no-block paths, past-end-of-block paths, and the
  multi-exercise behavior (each exercise scales independently).
- `WarmupDeloadIntegrationTests` — 5 @Test functions. Pins the
  warmup-skip-on-deload contract end-to-end (SessionFactory invokes
  WarmupRamp with `deloadActive: scheduledDeloadActive`).

V3 -> V4 test schema flips: 6 Phase 4 test files
(`BlockDraftSaveTests`, `BlocksSectionTests`,
`SingleActiveBlockInvariantTests`, `SessionBlockSnapshotTests`,
`DeloadVolumeApplicationTests`, `WarmupDeloadIntegrationTests`)
flipped to `Schema(SchemaV4.models)` to match the runtime container
shape locked by Phase 3.1 Plan 02.

Verification:
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:fitbodTests/SessionBlockSnapshotTests -only-testing:fitbodTests/DeloadVolumeApplicationTests -only-testing:fitbodTests/WarmupDeloadIntegrationTests` -> TEST SUCCEEDED
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17'` -> BUILD SUCCEEDED
- Phase 4 supporting suites still GREEN: BlockDraftSave (4),
  SingleActiveBlockInvariant (4), BlocksSection (5),
  PeriodizationEngine (10), BlockTemplates (4),
  FatigueAdvisoryCanonicality (3).

Notes:
- The phase resolution lifted out of the per-exercise loop is the
  load-bearing optimization: a single PeriodizationEngine call per
  session covers all exercises and both the warmup-skip and
  set-count paths. The engine is pure (no SwiftData coupling) so the
  hoist is free.
- Block snapshot semantics are documented inside SessionBlockSnapshotTests
  itself: the `editingBlockNameAfterSnapshotPropagatesViaReference`
  test explicitly asserts that the snapshot is the RELATIONSHIP, not
  the field values. A future requirement to snapshot block name /
  date / phases would need new fields on Session (out of scope for
  Phase 4 per D-20).
- `RPEAutoregStrategy`'s `now: today` parameter pass-through was a
  Rule 1 auto-fix found in the same touch of `SessionFactory.start`:
  the test infrastructure for scheduled deload weeks tests against
  specific dates, and Calibration.predict's time-kernel must honor
  the caller's `today:` for deterministic test math.
