---
phase: 09-program-surfaces
plan: "01"
subsystem: periodization-ui
tags: [swiftui, swiftdata, drag-reorder, navigation, tdd, bru]
dependency_graph:
  requires:
    - fitbod/Models/Split.swift
    - fitbod/Models/SplitSessionSlot.swift
    - fitbod/Models/Block.swift
    - fitbod/Periodization/BlockLifecycleService.swift
    - fitbod/Models/SplitDeletionGuard.swift
    - fitbod/Design/BRUHeaderBar.swift
    - fitbod/Design/BRUSectionHead.swift
    - fitbod/Design/BRUDivider.swift
    - fitbod/Design/BRUChip.swift
  provides:
    - fitbod/Periodization/SplitDetailRoute.swift   # UUID-identity route for downstream consumers
    - fitbod/Design/LiveEditBanner.swift             # Reusable banner for BlockOverviewScreen + RoutineBuilderView
    - fitbod/Periodization/SplitDetailView.swift     # Full slot CRUD + drag-reorder + archive
    - reindexSlots(_:) internal helper              # Testable reindex seam, consumed by SplitDetailViewTests
  affects:
    - Phase 9 Wave 2 plans (ProgramView, TodayView, BlockOverviewScreen consume SplitDetailRoute + LiveEditBanner)
tech_stack:
  added: []
  patterns:
    - "Hysteresis drag-reorder: LongPressGesture.sequenced(before: DragGesture) with 0.55-pitch threshold and @GestureState row-local translation (copy-adapted from NewBlockPhaseEditorRow in BlockBuilderView.swift)"
    - "Reindex-on-write: reindexSlots() renumbers positions 0..<n after every add/remove/reorder in a single ctx.save()"
    - "Archive deny seam: archive routes through BlockLifecycleService.assertSplitDeletable → SplitDeletionGuard; deny shows .alert, not inline count check"
    - "Post-filter in Swift for derivedStatus: multi-level optional chain not expressible in #Predicate; computed properties filter in Swift"
    - "UUID-identity route enum: SplitDetailRoute mirrors BlockOverviewRoute pattern for Swift 6 Sendable safety"
key_files:
  created:
    - fitbod/Periodization/SplitDetailRoute.swift
    - fitbod/Design/LiveEditBanner.swift
    - fitbod/Periodization/SplitDetailView.swift
    - fitbodTests/SplitDetailViewTests.swift
  modified: []
decisions:
  - "reindexSlots() exposed at internal access (not fileprivate) so SplitDetailViewTests can call it directly without needing to go through the view"
  - "SlotPickerSheet presented as sheet with NavigationStack (picker itself is not a stack — it houses RoutineBuilderView which needs one); v1 UX debt comment added at RoutineBuilderView call site"
  - "Copy-pin for interpolated title checks prefix literal \"Routine · \\(\" rather than a closed-string substring"
metrics:
  duration_seconds: 898
  completed_date: "2026-06-11"
  tasks_completed: 2
  files_created: 4
  files_modified: 0
---

# Phase 9 Plan 01: SplitDetailRoute + LiveEditBanner + SplitDetailView Summary

**One-liner:** Typed SplitDetailRoute enum + reusable LiveEditBanner + full SplitDetailView (ordered slots, hysteresis drag-reorder with reindex-on-write, slot picker, remove-slot confirm, usage section, archive via BlockLifecycleService deny seam).

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | SplitDetailRoute + LiveEditBanner + SplitDetailView skeleton | a5c8efc | SplitDetailRoute.swift, LiveEditBanner.swift, SplitDetailView.swift |
| 2 (RED) | Failing SplitDetailViewTests | d1a6289 | SplitDetailViewTests.swift |
| 2 (GREEN) | Fix tests to all-pass | 450aea0 | SplitDetailViewTests.swift |

---

## What Was Built

### SplitDetailRoute.swift
`public enum SplitDetailRoute: Hashable, Sendable { case detail(splitID: UUID) }` — UUID-identity typed route, parallel to `BlockOverviewRoute`. Downstream Wave 2 consumers (ProgramView, TodayView) register `navigationDestination(for: SplitDetailRoute.self)`.

### LiveEditBanner.swift
Reusable `public struct LiveEditBanner: View`. Fixed anatomy: 4pt `bruSignal` left stripe, `VStack` with "ACTIVE BLOCK" (`labelSmall` UPPERCASE tracking 1.2 `bruSignal`) and body copy (`bodyDefault` `bruMuted`), 44pt minHeight, `bruBg2` background, 2pt `bruInk` bottom overlay. `.accessibilityElement(children: .combine)` with combined label. Consumed by SplitDetailView and will be reused in RoutineBuilderView (Phase 9 Wave 2).

### SplitDetailView.swift
Full `public struct SplitDetailView: View` with:
- `BRUHeaderBar.slots(left: .back, center: "Routine · {name}", right: .action("ARCHIVE"))` header
- `LiveEditBanner()` conditional on `liveActiveBlock != nil` (post-filter in Swift)
- Sessions section: `BRUSectionHead` with `+ ADD SESSION` tappable right, `ForEach` of `SplitSlotRow` with hysteresis drag-reorder
- Used-in section: non-completed blocks display with `BRUChip(derivedStatus.rawValue.uppercased())`
- Archive deny alert: title/body verbatim from UI-SPEC Copywriting Contract
- Remove-slot `.confirmationDialog`: "Remove Session?" / "Remove Session" (destructive) / "Cancel"
- `SlotPickerSheet` (fileprivate): `@Query` over non-archived `SessionTemplate`s + "New session" entry → `RoutineBuilderView`

**Drag-reorder pattern** (copy-adapted from `NewBlockPhaseEditorRow`, BlockBuilderView.swift lines 1511–1543):
- `LongPressGesture(minimumDuration: 0.25).sequenced(before: DragGesture(minimumDistance: 0))`
- `@GestureState` row-local `dragTranslation` with spring reset transaction
- Hysteresis threshold 0.55 pitch
- Parent aggregates via `onReorderBegan/onReorderTarget/onReorderEnded` callbacks
- `.sensoryFeedback(trigger: draggingSlotID)` with `.impact(weight: .medium)` on drag start
- Reduced motion: `@Environment(\.accessibilityReduceMotion)` disables gesture; informational overlay shown
- VoiceOver: `accessibilityAction(named: "Move up/down")` on each row

**Reindex-on-write seam:** `internal func reindexSlots(_ slots: [SplitSessionSlot])` — exposed at `internal` access so `SplitDetailViewTests` calls it directly without routing through the view.

### SplitDetailViewTests.swift
4 tests — all GREEN:
1. `reorderKeepsPositionsContiguous` — simulate move, assert positions == [0,1,2,3]
2. `addSlotAppendsContiguously` — add slot, assert 0..<4 contiguous
3. `removeSlotDeletesSlotNotTemplateAndReindexes` — delete middle slot, assert template survives in store (`.deny` rule), positions == [0,1,2]
4. `splitDetailViewPinsCopy` — source-introspection via `#filePath`; pins "Sessions", "+ ADD SESSION", "Used in", "Not linked to any active block.", "ARCHIVE", "Cannot Archive Routine", "Remove Session?", "Remove Session", `"Routine · \(`

---

## Seams for Downstream Plans

| Seam | Signature | Consumers |
|------|-----------|-----------|
| `SplitDetailRoute` | `public enum SplitDetailRoute: Hashable, Sendable { case detail(splitID: UUID) }` | ProgramView (navigationDestination), TodayView (navigationDestination) |
| `LiveEditBanner` | `public struct LiveEditBanner: View` (no args) | SplitDetailView (used), RoutineBuilderView (Phase 9-04 or later) |
| `SplitDetailView` | `public struct SplitDetailView: View` with `public init(split: Split)` | ProgramView + TodayView navigationDestination closures |
| `reindexSlots(_:)` | `internal func reindexSlots(_ slots: [SplitSessionSlot])` | SplitDetailViewTests (direct call) |

---

## Deviations from Plan

### Auto-fixed Issues

None.

### Other Notes

**[Rule 1 - Bug] Copy-pin for interpolated title** — The test initially used `"Routine · "` (closed-string literal) to pin the screen title, but the source contains `"Routine · \(split.name)"` (string interpolation), so the closed-string form is never present. Fixed to `"Routine · \\("` prefix pin, which is unique enough to anchor the copy contract.

---

## Known Stubs

**v1 UX debt — 2-tap create+attach flow:** After `RoutineBuilderView` dismiss inside `SlotPickerSheet`, the picker re-opens for the user to explicitly select the newly created session. The CTA navigates to `RoutineBuilderView` but does not auto-attach the created template as a slot. A `// v1 UX debt:` comment is at the call site in `SlotPickerSheet` (line ~525 of SplitDetailView.swift). This is intentional v1 simplification, not a correctness defect.

---

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary schema changes introduced. All mutations are local SwiftData writes. Threat mitigations T-09-01/T-09-02/T-09-03 addressed:
- T-09-01: `reindexSlots()` + `SplitDetailViewTests` assert 0..<n contiguity
- T-09-02: `attemptArchive()` calls `BlockLifecycleService.assertSplitDeletable`, no inline count check
- T-09-03: `removeSlot()` deletes `SplitSessionSlot` only; `SessionTemplate` preserved (test 3 asserts this)

---

## Self-Check: PASSED

- [x] `fitbod/Periodization/SplitDetailRoute.swift` exists
- [x] `fitbod/Design/LiveEditBanner.swift` exists
- [x] `fitbod/Periodization/SplitDetailView.swift` exists (min_lines 200: ~530 lines)
- [x] `fitbodTests/SplitDetailViewTests.swift` exists
- [x] Commit a5c8efc exists (Task 1)
- [x] Commit d1a6289 exists (Task 2 RED)
- [x] Commit 450aea0 exists (Task 2 GREEN)
- [x] Build: SUCCEEDED
- [x] SplitDetailViewTests: 4/4 PASSED
