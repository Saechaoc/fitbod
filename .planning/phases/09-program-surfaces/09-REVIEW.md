---
phase: 09-program-surfaces
reviewed: 2026-06-11T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - fitbod/Periodization/SplitDetailView.swift
  - fitbod/Periodization/SplitDetailRoute.swift
  - fitbod/Design/LiveEditBanner.swift
  - fitbod/Periodization/ProgramView.swift
  - fitbod/Views/TodayView.swift
  - fitbod/Periodization/BlockOverviewScreen.swift
  - fitbod/Routines/RoutineBuilderView.swift
  - fitbod/Periodization/BlockDraft.swift
  - fitbod/Periodization/BlockBuilderView.swift (NewBlockSplitBand)
  - fitbodTests/BlockDraftSaveTests.swift
  - fitbodTests/SplitDetailViewTests.swift
  - fitbodTests/RoutineBuilderLiveEditTests.swift
  - fitbodTests/BlockOverviewScreenCopyTests.swift
  - fitbodTests/TodayViewBRUCopyTests.swift
  - fitbodTests/ProgramViewFidelityTests.swift
findings:
  critical: 3
  warning: 5
  info: 3
  total: 11
status: fixes_applied
fix_report:
  fixed: 10
  accepted_documented: 1
  skipped: 0
  fixed_at: 2026-06-11
---

# Phase 9: Code Review Report

**Reviewed:** 2026-06-11
**Depth:** standard
**Files Reviewed:** 11 source + 5 test files
**Status:** issues_found

## Summary

Phase 9 implements the full Program Surfaces layer: `SplitDetailView`, `ProgramView` BLOCKS/ROUTINES sections, `BlockOverviewScreen` live/archived modes, `LiveEditBanner`, `EmptySplitFixIt`, and the `NewBlockSplitBand` in the builder. The architecture is generally sound — reindex-on-write is correctly implemented, the no-live-fallback archive rule is enforced, and the one-save lifecycle transactions are upheld.

Three blockers were found: two test failures (a test suite runs against a schema version that lacks the V7 entities it creates, causing runtime crashes; an archive render path reads `block.split` for session counting in the week carousel for completed blocks), and one logic flaw (the `addSlot` function reads `split.slots?.count` after relationship assignment, which may produce an off-by-one when SwiftData includes the newly-inserted slot in the live relationship count before `reindexSlots` normalizes it). Warnings cover a dead `startBlank()` function, silent `ctx.save()` error swallowing, a spec-vs-implementation divergence in the mismatch hint condition, a `List`/navigation-title in `SplitPickerSheet` violating the BRU no-system-chrome contract, and a hardcoded amber color in `NewBlockSplitBand`. Info items cover the conformationDialog vs alert spec wording mismatch and a residual TODO in the empty-state no-op button.

---

## Critical Issues

### CR-01: `BlockDraftSaveTests` uses `SchemaV5` but creates `Split`/`SplitSessionSlot` (V7-only models)

**Status:** FIXED (commit 8c16102) — line 17 now `Schema(SchemaV7.models)`. All 9 BlockDraftSaveTests cases pass (were crashing under V5).

**File:** `fitbodTests/BlockDraftSaveTests.swift:17`

**Issue:** The test suite opens a `ModelContainer` with `Schema(SchemaV5.models)`, which does not register `Split`, `SplitSessionSlot`, or `SessionTemplate`. Tests `savedDraftWithSplitAndRotationIsReady` (line 108) and `initFromBlockRoundTripsSchedulingFields` (line 153) then insert and assign `Split` / `SplitSessionSlot` objects, and `trainingDaysArePersistedSorted` saves a draft that writes `block.split` (nil). SwiftData will throw an `NSError` (entity not found in schema) when these tests try to save, causing them to either silently no-op the save (if `try? ctx.save()` swallows the error) or crash. The assertion `block.derivedStatus == .ready` on line 132 will fail because `block.split` is nil — the split relationship was never persisted.

**Fix:** Change line 17 from `Schema(SchemaV5.models)` to `Schema(SchemaV7.models)`:
```swift
private func makeContext() throws -> ModelContext {
    let schema = Schema(SchemaV7.models)   // V7 required — Split, SplitSessionSlot, SessionTemplate
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: schema,
        migrationPlan: FitbodSchemaMigrationPlan.self,
        configurations: config
    )
    return ModelContext(container)
}
```

---

### CR-02: `addSlot` reads `split.slots?.count` after relationship assignment — potential off-by-one position

**Status:** FIXED (commit 25f8140) — sentinel position + end-pinned stable sort; test mirrors the fix and asserts contiguity. Requires human verification (logic change).

**File:** `fitbod/Periodization/SplitDetailView.swift:539-544`

**Issue:** `addSlot(for:)` assigns `slot.split = split` on line 536, which registers the slot in SwiftData's in-memory relationship graph. Line 539 then reads `split.slots?.count` to determine the append position. Depending on SwiftData's eager relationship tracking, `split.slots` may already include the newly inserted slot at this point, making `currentCount` return `n+1` (where `n` is the true prior count). The `reindexSlots` call on line 544 then normalizes all slots to `0..<n`, so the off-by-one in `slot.position` before reindex is harmless — BUT the array built on line 543 (`(split.slots ?? []).sorted { $0.position < $1.position }`) would include the new slot at an arbitrary position in the sort. If `currentCount` is already `n+1` and the new slot sorts last anyway, this is benign; but the initial assignment on line 540 is redundant with reindex and represents a fragile assumption about relationship graph timing.

More critically: `SplitDetailViewTests.addSlotAppendsContiguously` (line 109) mirrors this exact logic and thus tests the same potentially-fragile assumption rather than exposing it.

**Fix:** Remove the pre-assignment position and rely entirely on `reindexSlots`. Assign `slot.position = 0` (or any value) before reindex — the reindex will correct it:
```swift
private func addSlot(for template: SessionTemplate) {
    let slot = SplitSessionSlot()
    ctx.insert(slot)
    slot.split = split
    slot.sessionTemplate = template
    slot.position = 0  // sentinel — reindexSlots sets the real position

    // Reindex all slots (including new one) for contiguity.
    // Sort by existing position first; new slot at position 0 sorts to front
    // but reindex renumbers them all to 0..<n.
    let allSlots = (split.slots ?? []).sorted { a, b in
        // New slot (id matches) should sort last to append at end
        if a.id == slot.id { return false }
        if b.id == slot.id { return true }
        return a.position < b.position
    }
    reindexSlots(allSlots)
    try? ctx.save()
    onDismiss()
    dismiss()
}
```

---

### CR-03: `weekCarousel` reads `block.split?.slots?.count` for completed (archived) blocks — violates spec §6 no-live-template-read rule

**Status:** FIXED (commit 627f618) — completed blocks derive scheduledCount from decoded ArchivedBlockConfig; nil/undecodable archive omits the count (no 0/0 lie). rg confirmed no live block.split reads in archived render path. Requires human verification (logic change).

**File:** `fitbod/Periodization/BlockOverviewScreen.swift:474`

**Issue:** `weekCarousel` is rendered for ALL block statuses (line 157 — it is not inside the `if block.derivedStatus != .completed` gate). Line 474 reads `block.split?.slots?.count ?? 0` to compute `scheduledCount`, which feeds the "X / Y SESSIONS DONE · Z LEFT" footer. For completed blocks, spec §6 mandates: "NO live-template fallback path in readers, ever" — the archive is the sole source. Reading `block.split?.slots?.count` on a completed block reads the live (post-archive) split relationship. This will silently show 0 if the split was archived/deleted (nullify delete rule), misleading the user with "0 / 0 SESSIONS DONE · 0 LEFT" instead of the archived slot count.

Similarly, `dayState(for:)` at line 268 reads `session.slot?.split?.id == block.split?.id` — for completed blocks with a nullified split this comparison will always be false, falling back to the `session.block?.id == block.id` path (which works), so this particular read is not a silent failure. But the carousel footer is.

**Fix:** In `weekCarousel`, derive `scheduledCount` from the archive for completed blocks:
```swift
let scheduledCount: Int = {
    if block.derivedStatus == .completed,
       let json = block.archivedConfigJSON,
       let config = try? BlockLifecycleService.decodeArchive(json) {
        return config.split.slots.count
    }
    return block.split?.slots?.count ?? 0
}()
```

---

## Warnings

### WR-01: `startBlank()` is dead code — popover bypasses it, test pin passes incorrectly

**Status:** FIXED (commit 578f709) — popover '+ New block' now calls startBlank(); function kept (test pin still matches). ProgramViewFidelityTests green.

**File:** `fitbod/Periodization/ProgramView.swift:283`

**Issue:** `ProgramViewFidelityTests` (line 184) pins `source.contains("startBlank()")`. The `startBlank()` function appears at line 283 but is never called — the `BRUActionPopover` item's closure on line 264 writes `presentingStartChoice = true` directly. The test passes because `startBlank()` exists as a function definition, but the actual popover behavior bypasses the function. This is a dead-code condition: any future logic added to `startBlank()` would not execute.

**Fix:** Replace the inline `presentingStartChoice = true` in the popover closure with a call to `startBlank()`:
```swift
BRUActionPopoverItem(title: "+ New block") {
    showingNewPopover = false
    startBlank()      // use the named function so test and production path are the same
},
```

---

### WR-02: `try? ctx.save()` silently swallows errors in archive and reorder paths — data loss risk

**Status:** FIXED (commit b4e26ec) — SplitDetailView archive/reorder/remove/moveSlot and BlockOverviewScreen mode/day/end now do/catch with a 'Couldn't save. Try again.' BRU alert. Archive does not dismiss and reverts isArchived on failure. SlotPickerSheet.addSlot and SplitPickerSheet.attachOrSwap try? left as-is (outside cited scope). Requires human verification (error-path control flow).

**File:** `fitbod/Periodization/SplitDetailView.swift:244` (archive), `283` (commitReorder), `320` (removeSlot), `334` (moveSlot); `fitbod/Periodization/BlockOverviewScreen.swift:189` (end block)

**Issue:** Every `ctx.save()` in these mutation paths uses `try?`, silently discarding save errors. If SwiftData fails to persist (e.g., disk full, schema validation error), the in-memory state diverges from the store. The user sees the change but it is not durable. The most severe case is `attemptArchive()` at line 244: if `ctx.save()` fails, `split.isArchived = true` is set in memory, `dismiss()` is called, and the split disappears from the Routines list — but the archive flag was not persisted. On next launch the split reappears. Equally severe is `BlockOverviewScreen`'s `try? BlockLifecycleService.end(block:context:)` — the end transaction already does `try context.save()` inside `context.transaction`, but errors are swallowed at the call site.

**Fix:** Log or surface save errors. For `attemptArchive`, propagate the failure:
```swift
private func attemptArchive() {
    do {
        try BlockLifecycleService.assertSplitDeletable(split)
        split.isArchived = true
        try ctx.save()
        dismiss()
    } catch {
        showArchiveDenied = true
        // If save failed (not a deletable error), revert the in-memory flag
        split.isArchived = false
    }
}
```
For reorder/remove paths, at minimum log via `os.Logger` rather than `try?`. For the end-block path in `BlockOverviewScreen`, the error is already handled inside `BlockLifecycleService.end`'s transaction; the `try?` wrapper at the call site means the UI gives no feedback on failure — add an `@State private var endError: Bool = false` alert.

---

### WR-03: `NewBlockSplitBand` mismatch hint uses hardcoded amber color instead of `Color.bruAmber` token

**Status:** FIXED (commit 4ec24fb) — hardcoded RGB replaced with Color.bruAmber. 3 copy-guardrail suites green.

**File:** `fitbod/Periodization/BlockBuilderView.swift:1964`

**Issue:** Line 1964 uses `Color(red: 1.0, green: 0.65, blue: 0.0)` with a comment `// bruAmber`. The shipped `Color+BRU.swift` exports `Color.bruAmber` as a named colorset asset that has separate light/dark values and is the single source of truth. The hardcoded RGB value will not adapt to dark mode and will diverge if the design token is updated. `BlockOverviewScreen` correctly uses `Color.bruAmber` at line 676.

**Fix:**
```swift
.foregroundStyle(Color.bruAmber)  // use the BRU token, not a hardcoded RGB
```

---

### WR-04: `NewBlockSplitBand` mismatch hint suppressed when `slotCount == 0`, diverging from `BlockOverviewScreen` behavior

**Status:** FIXED (commit 4ec24fb) — `slotCount > 0` guard dropped; hint now shows whenever a split is attached and counts differ (matches BlockOverviewScreen), hidden only when no split attached. Requires human verification (condition change).

**File:** `fitbod/Periodization/BlockBuilderView.swift:1960`

**Issue:** Line 1960 guards the mismatch hint with `slotCount > 0 &&`. If the user sets `fixedWeekly` mode and picks 3 training days before attaching a split (or when the split has no slots), no hint appears — training days are set but the slot count comparison is silently skipped. `BlockOverviewScreen.dayChipSection` (line 673) shows the hint whenever `block.trainingDays.count != slotCount` unconditionally. The spec (UI-SPEC §4 BlockOverviewScreen) says: "soft mismatch hint shown when `trainingDays.count != split.slots?.count ?? 0`" — no `slotCount > 0` guard. This means "3 days / 0 sessions" is a valid and informative state in BlockOverviewScreen but is suppressed in the builder.

**Fix:** Remove the `slotCount > 0 &&` guard in `NewBlockSplitBand`:
```swift
if draft.trainingDays.count != slotCount {
    Text("\(draft.trainingDays.count) days / \(slotCount) sessions")
        ...
}
```

---

### WR-05: `SplitPickerSheet` uses `List` with `navigationTitle` — BRU contract violation

**Status:** FIXED (commit 203a2f7) — replaced List/.navigationTitle with ScrollView + BRUSectionHead("Choose Routine") + row + BRUDivider(.hair) on bruPaper, nav bar hidden (matches SlotPickerSheet).

**File:** `fitbod/Periodization/BlockOverviewScreen.swift:1124,1141`

**Issue:** `SplitPickerSheet` uses `List(splits) { ... }` with `.navigationTitle("Choose Routine")` inside its own `NavigationStack`. The BRU contract (documented in the file header) forbids system list chrome: "NO List chrome violates BRU contract" (see `SplitDetailView.swift` header: "NOT List .onMove — List chrome violates BRU contract"). `List` adds system separator lines, row backgrounds, and inset group styling that are inconsistent with the BRU paper/ink aesthetic used everywhere else. `.navigationTitle` adds a system navigation bar title which conflicts with the BRU header pattern.

**Fix:** Replace with a `ScrollView` + `LazyVStack` + `BRUSectionHead` pattern matching `SlotPickerSheet`:
```swift
var body: some View {
    NavigationStack {
        VStack(spacing: 0) {
            BRUSectionHead("Choose Routine")
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(splits) { split in
                        Button { attachOrSwap(split: split); dismiss() } label: {
                            HStack { ... }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        BRUDivider(.hair)
                    }
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
```

---

## Info

### IN-01: Spec says `.alert` for remove-slot confirmation; implementation uses `.confirmationDialog`

**Status:** ACCEPTED (documented, no code change) — `.confirmationDialog` is acceptable / arguably better iOS UX for a destructive action. Implementation kept; spec divergence accepted per reviewer's own recommendation.

**File:** `fitbod/Periodization/SplitDetailView.swift:132`

**Issue:** UI-SPEC §3 states: "Swipe trailing `.swipeActions` → confirm alert". The implementation uses `.confirmationDialog` which renders as an action sheet (bottom-anchored) on iPhone rather than a centered alert. The copy is correct ("Remove Session?" title, "Remove Session" destructive, "Cancel" cancel). This is a spec divergence in presentation style only — functionally correct and arguably better UX for a destructive action on iOS.

**Fix:** Either update the UI-SPEC to accept `.confirmationDialog` (the better UX) or change to `.alert` for strict spec compliance:
```swift
.alert("Remove Session?", isPresented: $removeAlertPresented) {
    Button("Remove Session", role: .destructive) { ... }
    Button("Cancel", role: .cancel) {}
}
```
Recommend updating the spec rather than changing the implementation.

---

### IN-02: `noWorkoutScheduledEmptyState` "+ NEW ROUTINE" button has a no-op action

**Status:** FIXED (commit ba0b0cb) — wired to present RoutineBuilderView(draft: RoutineDraft()) sheet on Today's own NavigationStack (same flow ProgramView uses). Non-cross-tab. Empty-state copy pin preserved.

**File:** `fitbod/Views/TodayView.swift:313`

**Issue:** The "+ NEW ROUTINE" button in `noWorkoutScheduledEmptyState` (line 313) has an empty action closure: `Button { // Navigate to RoutinesListView's +NEW routine action }`. The comment acknowledges the intended destination but the action is not wired. Pressing this button does nothing. This affects the `.restDay`, `.noBlock`-with-active-block, and defensive nil-template branches.

**Fix:** Wire the navigation. Since `TodayView` has its own `NavigationStack`, the simplest v1 resolution is to push a `SplitDetailRoute` to the Program tab or present a `RoutineBuilderView` sheet:
```swift
@State private var presentingNewRoutineFromEmpty = false

// In button action:
presentingNewRoutineFromEmpty = true

// Add sheet modifier:
.sheet(isPresented: $presentingNewRoutineFromEmpty) {
    NavigationStack { RoutineBuilderView(draft: RoutineDraft()) }
}
```

---

### IN-03: `BlockOverviewScreen.phaseRow` background uses `BlockPhaseColors.rowTint(for: .intensification)` for ALL "now" rows regardless of actual phase kind

**Status:** FIXED (commit 9bd0ff8) — phase.kind is available at the call site; now `rowTint(for: phase.kind)`.

**File:** `fitbod/Periodization/BlockOverviewScreen.swift:786`

**Issue:** Line 786: `.background(isNow ? BlockPhaseColors.rowTint(for: .intensification) : Color.clear)` uses `.intensification` as a hardcoded argument regardless of the actual `phase.kind`. An accumulation, peak, or deload "now" row will receive the intensification tint color. This appears to be either a copy-paste artifact or an intentional design decision that was not documented. The signal stripe on the left edge (line 788) correctly identifies the row without needing a color cue, so the impact is minor.

**Fix:** Pass the actual phase kind:
```swift
.background(isNow ? BlockPhaseColors.rowTint(for: phase.kind) : Color.clear)
```
If the intention was to always use a neutral tint regardless of phase, document it as an intentional design decision.

---

_Reviewed: 2026-06-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
