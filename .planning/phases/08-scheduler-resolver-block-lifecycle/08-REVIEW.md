---
phase: 08-scheduler-resolver-block-lifecycle
reviewed: 2026-06-11T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - fitbod/Periodization/TodayResolver.swift
  - fitbod/Periodization/BlockLifecycleService.swift
  - fitbod/Periodization/TrainingDaysWriter.swift
  - fitbod/Models/ArchivedBlockConfig.swift
  - fitbod/Sessions/SessionFactory.swift
  - fitbod/Views/TodayView.swift
  - fitbod/Periodization/BlockOverviewScreen.swift
  - fitbod/Periodization/MesocycleWeekPage.swift
  - fitbodTests/TodayResolverTests.swift
  - fitbodTests/BlockLifecycleServiceTests.swift
  - fitbodTests/TrainingDaysWriterTests.swift
  - fitbodTests/SessionFactoryTests.swift
findings:
  critical: 2
  warning: 5
  info: 1
  total: 8
status: fixed
fixed_at: 2026-06-11
fix_summary:
  fixed: 8
  skipped: 0
  fix_commits:
    - CR-01/CR-02: 3b06c99
    - WR-01: 225ae3b
    - WR-02/WR-03: 05cf092
    - WR-04: c830210
    - WR-05: 6509956
    - IN-01: 068bf70
---

# Phase 8: Code Review Report

**Reviewed:** 2026-06-11
**Depth:** standard
**Files Reviewed:** 9 source files + 4 test files
**Status:** issues_found

## Summary

Phase 8 delivers `TodayResolver`, `BlockLifecycleService`, `TrainingDaysWriter`, `ArchivedBlockConfig.write`, and wiring updates to `SessionFactory` / `TodayView` / `BlockOverviewScreen`. The resolver logic, lifecycle atomicity, and archive encoding are structurally sound. Two critical defects surfaced: one renders the entire rotation scheduler permanently broken post-migration (session.slot is never set by `SessionFactory.start`), and one conflates `.emptySplit` with `.restDay` in `TodayView` against the explicit contract in both the spec and the resolver's own file header. Five warnings cover: wrong sort key vs the spec requirement (startedAt vs completedAt), data loss of phase and exercise notes at archive time, a missing guard in `BlockLifecycleService.end`, and two test-coverage gaps (tautological region-change test, missing "repeat" rotation test).

---

## Critical Issues

### CR-01: `SessionFactory.start` never sets `session.slot` — rotation resolver permanently returns slot 0  [FIXED — 3b06c99]

**File:** `fitbod/Sessions/SessionFactory.swift:110-140` / `fitbod/Views/TodayView.swift:366-379` / `fitbod/Views/TodayView.swift:398-401`

**Issue:** `Session.slot: SplitSessionSlot?` is the field the rotation resolver uses as its anchor (spec §5: "the latest completed session whose `slot` is non-nil and whose `slot.split == block.split`"). `SessionFactory.start` has no `slot` parameter and never writes `session.slot`. The only production code that writes `session.slot` is the V6→V7 migration backfill for the one most-recent historical session. Every session started after migration via `TodayView.startWorkout` will have `session.slot == nil`, making every completed session invisible to the resolver's post-filter. The resolver finds no qualifying anchor on every call and always falls back to `nextPosition = 0` — rotation is stuck at slot 0 indefinitely.

`TodayView.todaysRoutine` extracts the resolved slot (`case .session(let slot)`) but then discards it: only `slot.sessionTemplate` is forwarded to `startWorkout(_ routine: SessionTemplate)`. The slot is never threaded through to `SessionFactory`.

This is a spec contradiction: spec §3 defines `Session.slot` as "which slot launched this workout" and spec §5 builds the entire rotation predicate on that field.

**Fix:**

1. Add a `slot` parameter to `SessionFactory.start`:

```swift
public static func start(
    template: SessionTemplate,
    slot: SplitSessionSlot? = nil,     // NEW
    activeBlock: Block? = nil,
    on date: Date = .now,
    context: ModelContext
) throws -> Session {
    // ...existing body...
    session.slot = slot                 // ADD after context.insert(session)
    // ...
}
```

2. Update `TodayView.todaysRoutine` to surface the slot, not just the template:

```swift
// Change return type to (template: SessionTemplate, slot: SplitSessionSlot)? 
// or store resolution state in a @State var.
private var todaysResolution: (template: SessionTemplate, slot: SplitSessionSlot)? {
    guard let block = activeBlocks.first else { return nil }
    if case .session(let slot) = TodayResolver.resolve(block: block, context: ctx),
       let template = slot.sessionTemplate {
        return (template, slot)
    }
    return nil
}
```

3. Pass both to `startWorkout`:

```swift
private func startWorkout(template: SessionTemplate, slot: SplitSessionSlot) {
    do {
        let session = try SessionFactory.start(
            template: template,
            slot: slot,
            activeBlock: activeBlocks.first,
            context: ctx
        )
        navigationPath.append(SessionRoute.logger(session))
    } catch { }
}
```

---

### CR-02: `TodayView` collapses `.emptySplit` into `.restDay` display path, violating spec §5 and the resolver's own contract  [FIXED — 3b06c99]

**File:** `fitbod/Views/TodayView.swift:374-378`

**Issue:** `TodayResolver.swift` line 7–9 contains an explicit contract: "DO NOT collapse `.emptySplit` into `.restDay` — they render differently (Phase 9)." Spec §5 states: "Active block, split emptied mid-block → fix-it pointer to `SplitDetailView` ('Routine has no sessions'), **not** the rest-day state (which would lie)." The current code returns `nil` for both `.emptySplit` and `.restDay` from `todaysRoutine`, then falls through to the generic "No workout scheduled" text. A user whose split was accidentally emptied mid-block sees the same "No workout scheduled" copy as a rest day — no repair surface is shown. The resolver output distinction is lost before it reaches any UI branch.

**Fix:**

Drive the CTA branch from the full `TodayResolution`, not from a `SessionTemplate?` collapse:

```swift
// Replace todaysRoutine: SessionTemplate? with:
private var todaysResolution: TodayResolution {
    guard let block = activeBlocks.first else { return .noBlock }
    return TodayResolver.resolve(block: block, context: ctx)
}

// In body, replace the CTA switch on todaysRoutine / activeBlocks.isEmpty:
switch todaysResolution {
case .session(let slot):
    BlackSlabCTA(
        routine: slot.sessionTemplate!,
        dayIndex: dayIndexInBlock,
        totalDays: totalDaysInBlock,
        onStart: { startWorkout(template: slot.sessionTemplate!, slot: slot) }
    )
case .restDay, .noBlock where !activeBlocks.isEmpty:
    // existing "No workout scheduled" empty state
    ...
case .emptySplit:
    // fix-it surface pointing to SplitDetailView
    EmptySplitFixItView()
case .noBlock:
    StartBlockCTA(onStart: { ... })
}
```

---

## Warnings

### WR-01: `TodayResolver.resolveRotation` sorts by `startedAt` — spec review requirement says `completedAt desc`  [FIXED — 225ae3b]

**File:** `fitbod/Periodization/TodayResolver.swift:106-108`

**Issue:** The review spec explicitly states: "latest ordering is correct (completedAt desc, not insertion order)." The implementation uses `SortDescriptor(\Session.startedAt, order: .reverse)`. For non-overlapping sessions (enforced by the one-active-session invariant) the two orderings are equivalent in practice, but the sort key deviates from the spec requirement. A future where session completion times diverge from start times (e.g., a long session started Mon completed Tue vs a short session started Tue completed Tue) would produce a different anchor under startedAt vs completedAt sort.

**Fix:**

```swift
let descriptor = FetchDescriptor<Session>(
    predicate: #Predicate { $0.completedAt != nil },
    sortBy: [SortDescriptor(\Session.completedAt, order: .reverse)]   // was: startedAt
)
```

---

### WR-02: `ArchivedBlockConfig.write` drops `BlockPhase.notes` — data loss, spec §6 "full BlockPhase field mirror" violated  [FIXED — 05cf092]

**File:** `fitbod/Models/ArchivedBlockConfig.swift:192-202`

**Issue:** Spec §6 requires "full BlockPhase field mirror." `BlockPhase` has `notes: String?`. `ArchivedBlockConfig.write` constructs `ArchivedPhaseDTO` with `notes: nil` unconditionally, silently discarding any phase notes the user has authored. The DTO struct has the `notes` field; the serializer just never reads it from the live model.

**Fix:**

```swift
ArchivedPhaseDTO(
    kind: phase.nameRaw,
    weeks: phase.weeks,
    volumeMultiplier: phase.volumeMultiplier,
    intensityMultiplier: phase.intensityMultiplier,
    notes: phase.notes          // was: nil
)
```

---

### WR-03: `ArchivedBlockConfig.write` drops exercise `notes` and hardcodes `generateWarmups: false` — data loss, spec §6 "full SessionExerciseTemplate prescription mirror" violated  [FIXED — 05cf092]

**File:** `fitbod/Models/ArchivedBlockConfig.swift:211-231`

**Issue:** Spec §6 requires "full SessionExerciseTemplate prescription mirror." `SessionExerciseTemplate` has `notes: String?` and `generateWarmups: Bool`. The `write` function passes `notes: nil` and `generateWarmups: false` unconditionally. Exercise-level notes authored by the user are silently dropped at archive time. The `generateWarmups` flag is also incorrect for any template where it was set to `true`.

**Fix:**

```swift
ArchivedExerciseDTO(
    // ...existing fields...
    notes: ex.notes,                            // was: nil
    intentRaw: intentRaw,
    progressionKindRaw: progressionKindRaw,
    generateWarmups: ex.generateWarmups,        // was: false
    tracksTempo: ex.tracksTempo,
    tracksPartialReps: ex.tracksPartialReps
)
```

---

### WR-04: `BlockLifecycleService.end` has no guard — can archive a draft or ready block, producing corrupt state  [FIXED — c830210]

**File:** `fitbod/Periodization/BlockLifecycleService.swift:113-123`

**Issue:** `BlockLifecycleService.end` has no precondition check. `BlockLifecycleService.start` correctly guards `block.derivedStatus == .ready`. The symmetric guard for `end` is missing: calling `end` on a `.draft` or `.ready` block will set `endDate` (making it `.completed`) and write an archive stamped with `block.startDate = Date.now` (the Swift default for a block that was never started), producing a completed block with a nonsensical archive. The spec §4 lifecycle says "End (from active block detail)," implying only `.active` blocks can be ended.

**Fix:**

```swift
public static func end(block: Block, context: ModelContext, now: Date = .now) throws {
    guard block.derivedStatus == .active else {
        throw BlockLifecycleError.notActive    // add case to BlockLifecycleError
    }
    let json = try ArchivedBlockConfig.write(from: block, endedAt: now)
    try context.transaction {
        block.isActive = false
        block.endDate = now
        block.archivedConfigJSON = json
        try context.save()
    }
}
```

Add `case notActive` to `BlockLifecycleError` and a corresponding `BlockLifecycleServiceTests` test (analogous to Test 3 for `.notReady`).

---

### WR-05: `TrainingDaysWriterTests.regionChangeDoesNotResort` is tautological — does not prove region-change stability  [FIXED — 6509956]

**File:** `fitbodTests/TrainingDaysWriterTests.swift:51-84`

**Issue:** The test writes with a Mon-first calendar, then reads `block.trainingDays` twice from the **same in-memory object** and asserts the two reads are equal. This is trivially true regardless of implementation — it checks `x == x`. It does not prove that: (a) the sorted array survives a round-trip through the SwiftData store, (b) a subsequent fetch by a calendar with a different `firstWeekday` would return the stored-order array. The spec §9 requirement is that the stored order is stable across a region change. The test does not demonstrate that.

**Fix:** Add a second context fetch after save to prove the order survived persistence:

```swift
@Test("Region change after write does not re-sort stored trainingDays")
func regionChangeDoesNotResort() throws {
    // ... setup as before ...
    block.trainingDays = TrainingDaysWriter.sort(weekdays: [3, 5, 7], using: monFirstCal)
    try ctx.save()
    let storedID = block.id

    // Simulate a region change by fetching from a NEW context (simulates cold re-launch
    // where Calendar.current has a different firstWeekday).
    let ctx2 = ModelContext(container)
    let fetched = try ctx2.fetch(FetchDescriptor<Block>(
        predicate: #Predicate { $0.id == storedID }
    )).first!

    // The fetched array must match the Mon-first-sorted order, not be re-sorted.
    #expect(fetched.trainingDays == [3, 5, 7])
}
```

---

## Info

### IN-01: `TodayResolverTests` missing explicit "repeat" rotation behavior test (spec §9)  [FIXED — 068bf70]

**File:** `fitbodTests/TodayResolverTests.swift`

**Issue:** Spec §9 lists eight required rotation behaviors: "skip / repeat / reorder / ad-hoc / deleted-slot / swapped-split / abandoned-in-progress." "Repeat" (completing the same slot position twice consecutively) has no dedicated test. The general sequence tests implicitly cover correct behavior, but a named test makes the spec coverage self-documenting and will catch any future regression in the "latest anchor" logic when a slot recurs in history.

**Fix:** Add:

```swift
@Test("rotation: same slot done twice consecutively — advances to next position")
func rotationRepeatSameSlotAdvances() throws {
    let ctx = try makeContext()
    let (block, _, slots) = try makeBlock(slotCount: 3, context: ctx)
    let base = Date(timeIntervalSinceReferenceDate: 0)
    // Complete slot 1 twice — latest is still slot 1
    try completeSession(slot: slots[1], block: block, startedAt: base, context: ctx)
    try completeSession(slot: slots[1], block: block, startedAt: base.addingTimeInterval(86400), context: ctx)

    let resolution = TodayResolver.resolve(block: block, context: ctx)
    if case .session(let slot) = resolution {
        #expect(slot.position == 2, "Latest anchor is slot 1 → next is (1+1)%3 == 2")
    } else {
        Issue.record("Expected .session(slot 2), got \(resolution)")
    }
}
```

---

_Reviewed: 2026-06-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
