---
phase: 09-program-surfaces
plan: "06"
subsystem: periodization-ui
tags: [swiftui, swiftdata, live-edit-banner, reachability, tdd]
dependency_graph:
  requires:
    - fitbod/Design/LiveEditBanner.swift   # from 09-01; consumed here
    - fitbod/Models/SessionTemplate.swift
    - fitbod/Models/SplitSessionSlot.swift
    - fitbod/Models/Split.swift
    - fitbod/Models/Block.swift
  provides:
    - fitbod/Routines/RoutineBuilderView.swift   # live-edit banner wired; isTemplateOnActiveBlock seam
    - isTemplateOnActiveBlock(_:context:)         # internal free function; testable reachability seam
  affects:
    - Any screen that presents RoutineBuilderView (session editing flow)
tech_stack:
  added: []
  patterns:
    - "Swift post-filter reachability: fetch SplitSessionSlots via single-level #Predicate, then traverse slots→split→blocks in Swift — multi-level chain is NOT expressible in #Predicate"
    - "Testable seam: isTemplateOnActiveBlock exposed at internal so tests call it directly without instantiating SwiftUI views"
    - "Banner placement: VStack(spacing: 0) in .safeAreaInset(edge: .top) below BRUHeaderBar — banner scrolls with header, not with content"
key_files:
  created:
    - fitbodTests/RoutineBuilderLiveEditTests.swift
  modified:
    - fitbod/Routines/RoutineBuilderView.swift
decisions:
  - "isTemplateOnActiveBlock exposed at internal (not fileprivate) to keep logic unit-testable without SwiftUI view instantiation — mirrors reindexSlots pattern from 09-01"
  - "Banner placed inside .safeAreaInset VStack alongside BRUHeaderBar so it sits pinned above scroll content (consistent with SplitDetailView placement)"
  - "Reachability uses FetchDescriptor<SplitSessionSlot> with single-level predicate ($0.sessionTemplate?.id == templateID), then Swift loops for the multi-hop — safe for SwiftData #Predicate limitations"
metrics:
  duration_seconds: 890
  completed_date: "2026-06-11"
  tasks_completed: 1
  files_created: 1
  files_modified: 1
---

# Phase 9 Plan 06: RoutineBuilderView Live-Edit Banner Summary

**One-liner:** Live-edit banner in session template editor via Swift reachability (template → SplitSessionSlot fetch → split → active block post-filter) with 4-test TDD suite covering on/off/zero-split/copy-pin cases.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Live-edit banner in RoutineBuilderView with Swift reachability + test | d7864a0 | RoutineBuilderView.swift, RoutineBuilderLiveEditTests.swift |

---

## What Was Built

### isTemplateOnActiveBlock(_:context:) — internal free function

Exposed at `internal` in `RoutineBuilderView.swift` so the logic is unit-testable without instantiating a SwiftUI view (mirrors the `reindexSlots` pattern from 09-01).

Reachability algorithm:
1. Fetch `SplitSessionSlot`s with `#Predicate { $0.sessionTemplate?.id == templateID }` — single-level, safe.
2. Swift-loop over results: for each slot, walk `slot.split?.blocks` and check `$0.derivedStatus == .active`.
3. Return `true` iff any block is active. Zero slots → `false`.

The multi-level chain `sessionTemplate → split → blocks` is NOT expressible in a `#Predicate` — computed in Swift as specified (T-09-17 mitigation).

### RoutineBuilderView.swift changes

- New `isOnActiveBlock: Bool` computed property: guards `editing != nil` then delegates to `isTemplateOnActiveBlock(_:context:)` with the view's `@Environment(\.modelContext)` — create mode always `false`.
- `.safeAreaInset(edge: .top)` wrapped in `VStack(spacing: 0)` containing `BRUHeaderBar` + conditional `LiveEditBanner()` (non-blocking, no dismiss button). Banner is reactive — disappears if block ends between body evaluations.

### RoutineBuilderLiveEditTests.swift

4 tests — all GREEN:
1. `slottedOnActiveBlock` — template slotted into a split with `isActive: true` block → `true`
2. `slottedOnNonActiveBlocks` — template slotted into a split with draft + completed blocks → `false`
3. `templateInZeroSplits` — unlinked template (no slots) → `false`
4. `sourceIntrospectionCopyPin` — asserts `RoutineBuilderView.swift` contains `"LiveEditBanner"` and `LiveEditBanner.swift` carries verbatim `"Part of active block — edits apply to upcoming workouts."`

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None — banner is fully wired with live reachability.

---

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary schema changes. Threat mitigations addressed:
- **T-09-16** (false liveness): `slottedOnNonActiveBlocks` + `templateInZeroSplits` tests assert banner is hidden for non-active templates.
- **T-09-17** (multi-level #Predicate crash): reachability uses single-level `#Predicate` + Swift post-filter; test suite verifies correctness without triggering the predicate limitation.

---

## Self-Check: PASSED

- [x] `fitbod/Routines/RoutineBuilderView.swift` modified — contains `LiveEditBanner` and `isTemplateOnActiveBlock`
- [x] `fitbodTests/RoutineBuilderLiveEditTests.swift` created
- [x] Commit d7864a0 exists
- [x] Build: SUCCEEDED (iPhone 17 Pro simulator)
- [x] RoutineBuilderLiveEditTests: 4/4 PASSED
- [x] NewBlockBuilderFidelityTests: 6/6 PASSED (guardrail)
