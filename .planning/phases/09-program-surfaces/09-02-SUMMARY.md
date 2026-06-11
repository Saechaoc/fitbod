---
phase: 09-program-surfaces
plan: "02"
subsystem: periodization-ui
tags: [swiftui, swiftdata, navigation, bru, blocks, routines]
dependency_graph:
  requires:
    - fitbod/Periodization/SplitDetailRoute.swift       # from 09-01
    - fitbod/Design/LiveEditBanner.swift                # from 09-01
    - fitbod/Periodization/SplitDetailView.swift        # from 09-01
    - fitbod/Periodization/BlockOverviewScreen.swift    # BlockOverviewRoute
    - fitbod/Periodization/BlockBuilderView.swift       # BlockDraft(block:) init
    - fitbod/Models/Block.swift                         # derivedStatus, BlockStatus
    - fitbod/Models/Split.swift                         # isArchived, blocks, slots
    - fitbod/Design/BRUSectionHead.swift
    - fitbod/Design/BRUDivider.swift
    - fitbod/Design/BRUChip.swift
  provides:
    - fitbod/Periodization/ProgramView.swift            # rebuilt: empty-state gate + BLOCKS + ROUTINES + destinations
  affects:
    - Phase 9 Wave 3 plans (BlockOverviewScreen live modes, TodayView emptySplit)
tech_stack:
  added: []
  patterns:
    - "Empty-state gate: allBlocks.isEmpty && allSplits.isEmpty → NoProgramHero; otherwise BLOCKS+ROUTINES sections"
    - "Swift post-filter for derivedStatus ordering: @Query allBlocks then sort by [active:0, ready:1, draft:2, completed:3] in orderedBlocks computed property"
    - "DONE collapse: @State showAllDone + Array.prefix(3) + reduce-motion gated .easeOut animation"
    - "BlockStatusCard fileprivate in ProgramView.swift to share ProgramChipFlow and ProgramScreenTokens"
    - "RoutineSplitRow + UsageTagFlow fileprivate, usage tags filter derivedStatus != .completed in Swift (T-09-06)"
    - "navigationDestination(for: BlockOverviewRoute.self) + (for: SplitDetailRoute.self) both registered on ProgramView's stack (T-09-04)"
    - "PendingBlockBuilder .edit(Block) case mirrors TodayView pattern: BlockBuilderView(draft: BlockDraft(block:), editing:)"
key_files:
  created: []
  modified:
    - fitbod/Periodization/ProgramView.swift
    - fitbodTests/ProgramViewFidelityTests.swift
decisions:
  - "BlockStatusCard and RoutineSplitRow kept fileprivate in ProgramView.swift so they can access ProgramChipFlow layout and ProgramScreenTokens without visibility promotion (09-RESEARCH Pitfall 7)"
  - "derivedStatus ordering and usage-tag filtering performed as Swift post-filter after @Query — T-09-05 / T-09-06 mitigations; documented with inline comment in orderedBlocks"
  - "BRUSectionHead now legitimately used in BLOCKS and ROUTINES sections; ProgramViewFidelityTests narrowed from blanket !contains to positive presence assertions"
  - "showAllDone animation gated on @Environment(\.accessibilityReduceMotion): withAnimation(.easeOut(duration:0.2)) when not reduced, immediate assignment otherwise"
metrics:
  duration_seconds: 720
  completed_date: "2026-06-11"
  tasks_completed: 2
  files_created: 0
  files_modified: 2
---

# Phase 9 Plan 02: ProgramView Rebuild — BLOCKS + ROUTINES Sections Summary

**One-liner:** Rebuilt ProgramView with empty-state gate (zero blocks AND zero splits), status-ordered BLOCKS section (BlockStatusCard with DONE collapse), ROUTINES section (RoutineSplitRow with usage tags), both navigation destinations registered, and .edit(Block) added to PendingBlockBuilder.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Empty-state gate + BLOCKS section + nav destinations + .edit(Block) | 09de6de | ProgramView.swift |
| 2 | ROUTINES section + update ProgramViewFidelityTests | 0e7208a | ProgramView.swift (routinesSection already in Task 1), ProgramViewFidelityTests.swift |

---

## What Was Built

### ProgramView.swift — rebuilt

**Empty-state gate (lines ~95-120):** `if allBlocks.isEmpty && allSplits.isEmpty` shows the locked `NoProgramHero` + `ProgramTemplateSection` verbatim. The else branch renders `blocksSection` + `routinesSection`. `ResumeWorkoutBanner` always appears above the conditional.

**New @Query properties:**
- `allBlocks`: `@Query(sort: [SortDescriptor(\Block.startDate, order: .reverse)])` — all blocks, status ordering done in Swift
- `allSplits`: `@Query(filter: #Predicate<Split> { !$0.isArchived }, sort: [SortDescriptor(\Split.name)])` — non-archived only (`isArchived` is stored Bool, predicate-safe)

**`orderedBlocks` computed property:** Post-filters `allBlocks` by status precedence `[.active:0, .ready:1, .draft:2, .completed:3]` then `startDate` desc within each group. `derivedStatus` is computed, not stored — explicit code comment documents the T-09-05 disposition.

**`blocksSection` @ViewBuilder:**
- `BRUSectionHead("Blocks")`
- `ForEach` live blocks (non-completed) → `BlockStatusCard` + `BRUDivider(.hair)`
- `ForEach` visible DONE blocks (prefix 3 unless showAllDone)
- "ALL HISTORY ▸" disclosure Button (only when doneBlocks.count > 3 and not expanded): `labelSmall` / uppercase / tracking 1.2 / `bruSignal`, `accessibilityLabel("Show all N completed blocks")`, reduce-motion gated animation
- `BRUDivider(.ink)`

**`BlockStatusCard` (fileprivate):**
- Top HStack: `statusChip` (ACTIVE=filled signal, READY=outline signal, DRAFT=default, DONE=default) + Spacer + ACTIVE-only "W{n} · {PHASE}" labelSmall
- `Text(block.name)` bodyEmphasis bruInk
- ACTIVE-only: "Week N of M · Phase" bodyDefault bruMuted
- `accessibilityElement(children: .combine)` with status+name+week/phase label
- `.contentShape(Rectangle())` + `.frame(minHeight: 44)` + tap → `navigationPath.append(BlockOverviewRoute.summary(blockID:))`

**Navigation destinations (T-09-04 mitigation):**
- `.navigationDestination(for: BlockOverviewRoute.self)`: resolves Block by UUID via `FetchDescriptor`, presents `BlockOverviewScreen(block:onEdit:)` where onEdit sets `pendingBlockBuilder = .edit(resolvedBlock)`; fallback "Block not found"
- `.navigationDestination(for: SplitDetailRoute.self)`: resolves Split by UUID via `FetchDescriptor`, presents `SplitDetailView(split:)`; fallback "Routine not found"

**`PendingBlockBuilder.edit(Block)` (added to existing enum):**
- `id`: `"edit-\(block.id)"`
- `.fullScreenCover` switch: `BlockBuilderView(draft: BlockDraft(block: block), editing: block)` — mirrors TodayView

**`routinesSection` @ViewBuilder:**
- `BRUSectionHead("Routines")`
- `ForEach(allSplits)` → `RoutineSplitRow` + `BRUDivider(.hair)`
- "+ NEW ROUTINE" action Button: labelSmall / uppercase / tracking 1.2 / bruSignal / right-aligned, tap → `presentingNewRoutine = true`
- `BRUDivider(.ink)`

**`RoutineSplitRow` (fileprivate):**
- HStack(spacing: 12): VStack(name `bodyEmphasis`, "{N} sessions" `bodyDefault bruMuted`), Spacer, `UsageTagFlow(names: liveBlockNames)` (if non-empty), "›" bodyEmphasis bruMuted
- `liveBlockNames`: `(split.blocks ?? []).filter { $0.derivedStatus != .completed }.map { $0.name }` — T-09-06 mitigation
- `.frame(minHeight: 44)` + `.contentShape(Rectangle())` + tap → `navigationPath.append(SplitDetailRoute.detail(splitID:))`

**`UsageTagFlow` (fileprivate):** Wraps `BRUChip(name)` items using `ProgramChipFlow` layout. Renders `EmptyView()` when names is empty (no "unused" label). Accessible at 390pt (wrap to multiple lines, no truncation).

### ProgramViewFidelityTests.swift — updated

**`programViewUsesCompactMockupChrome` narrowed:**
- Removed: `#expect(!codeOnly.contains("BRUSectionHead(")` — blanket negative was broken by new sections
- Added: `#expect(codeOnly.contains(#"BRUSectionHead("Blocks")"#))` and `BRUSectionHead("Routines")` positive assertions
- Retained: `ProgramChromeHeader`, `ProgramTemplateHeader`, `!Text("setup")`, `!statusBandHeight`

**New `programViewPinsBlocksAndRoutinesSectionCopy` @Test:**
Pins all 8 verbatim strings: "Blocks", "Routines", "+ NEW ROUTINE", "ALL HISTORY ▸", and status chips ACTIVE/READY/DRAFT/DONE. Also asserts both `navigationDestination` registrations are present (T-09-04 guard).

**All previous tests preserved and passing (7/7 green).**

---

## Seams for Downstream Plans

| Seam | Signature | Consumers |
|------|-----------|-----------|
| `BlockOverviewRoute` destination on ProgramView | `.navigationDestination(for: BlockOverviewRoute.self)` | Phase 9 Wave 3 (BlockOverviewScreen live modes) |
| `SplitDetailRoute` destination on ProgramView | `.navigationDestination(for: SplitDetailRoute.self)` | Phase 9 Wave 3 (SplitDetailView wired) |
| `.edit(Block)` in PendingBlockBuilder | `case edit(Block)` + fullScreenCover switch | Edit-from-overview flow |

---

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Other Notes

Task 1 and Task 2 both touched `ProgramView.swift` — `routinesSection`, `RoutineSplitRow`, and `UsageTagFlow` were implemented together with `blocksSection` in Task 1's commit since they are logically coupled. Task 2's commit covers only the test file update.

---

## Known Stubs

None. All sections are fully wired:
- `allBlocks` and `allSplits` are live `@Query` results
- `orderedBlocks` computes real status ordering
- Usage tags filter real `split.blocks` post-filter
- Week/phase values derived from `PeriodizationEngine` and `MesocycleWeekPage` (same accessors as `BlockOverviewScreen`)

---

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary schema changes. All reads are local SwiftData queries. Threat mitigations addressed:

| Threat | Mitigation |
|--------|------------|
| T-09-04: unregistered BlockOverviewRoute → silent no-op | Both `BlockOverviewRoute` and `SplitDetailRoute` destinations registered; `programViewPinsBlocksAndRoutinesSectionCopy` test guards registration strings |
| T-09-05: #Predicate on derivedStatus | `@Query` plain on allBlocks; `orderedBlocks` sorts in Swift; inline code comment documents disposition |
| T-09-06: usage tags showing completed block refs | `liveBlockNames` filters `derivedStatus != .completed` in Swift post-filter; never in #Predicate |

---

## Self-Check: PASSED

- [x] `fitbod/Periodization/ProgramView.swift` exists and modified
- [x] `fitbodTests/ProgramViewFidelityTests.swift` exists and modified
- [x] Commit 09de6de exists (Task 1)
- [x] Commit 0e7208a exists (Task 2)
- [x] Build: SUCCEEDED
- [x] ProgramViewFidelityTests: 7/7 PASSED (including new programViewPinsBlocksAndRoutinesSectionCopy)
- [x] NewBlockBuilderFidelityTests: all PASSED (3 copy-guardrail suites green)
- [x] Empty-state copy pins untouched: programViewPinsExactMockupCopy PASSED
