---
phase: 09-program-surfaces
plan: "04"
subsystem: periodization-ui
tags: [swiftui, swiftdata, block-lifecycle, archive, bru, copy-tests]
dependency_graph:
  requires:
    - fitbod/Periodization/BlockLifecycleService.swift
    - fitbod/Periodization/TrainingDaysWriter.swift
    - fitbod/Models/Block.swift
    - fitbod/Models/ArchivedBlockConfig.swift
    - fitbod/Models/Enums/SchedulingMode.swift
    - fitbod/Models/Split.swift
    - fitbod/Design/BRUButton.swift
    - fitbod/Design/BRUChip.swift
    - fitbod/Design/BRUSectionHead.swift
    - fitbod/Design/BRUDivider.swift
    - fitbod/Design/BRUFont.swift
  provides:
    - fitbod/Periodization/BlockOverviewScreen.swift   # extended with live + archived modes
    - fitbodTests/BlockOverviewScreenCopyTests.swift   # 14 verbatim copy + invariant pins
  affects:
    - Any consumer of BlockOverviewScreen (ProgramView navigation destination)
tech_stack:
  added: []
  patterns:
    - "Nil-conditional attach vs swap: explicit if block.split == nil branch before calling BlockLifecycleService.attachSplit vs swapSplit (T-09-09 defense-in-depth)"
    - "Archive nil guard: archivedConfigJSON == nil → NO ARCHIVE AVAILABLE quiet state; non-nil undecodable → ArchiveUnreadableView (T-09-11)"
    - "Result { try BlockLifecycleService.decodeArchive } in @ViewBuilder for inline decode-or-error branch without SwiftUI try limitations"
    - "ModeChip + DayToggleChip as fileprivate BRUChip-derived views; all day writes via TrainingDaysWriter.sort (T-09-10)"
    - "SwapConfirmSheet fetches other active block from ctx at sheet-render time via FetchDescriptor"
key_files:
  created:
    - fitbodTests/BlockOverviewScreenCopyTests.swift
  modified:
    - fitbod/Periodization/BlockOverviewScreen.swift
decisions:
  - "nil archivedConfigJSON renders 'NO ARCHIVE AVAILABLE' quiet state (bruMuted) distinct from ArchiveUnreadableView (bruSignal), per plan spec for legacy builder-completed blocks"
  - "Result { try decodeArchive } in @ViewBuilder avoids try-in-body restriction; no state variable needed for the decode path"
  - "SplitPickerSheet as fileprivate struct with @Query filter !isArchived + NavigationStack for title display; v1 wraps in a List with plain-button rows"
  - "bottomBar computed property switches on derivedStatus to gate start/edit/end button combinations per status"
metrics:
  duration_seconds: 420
  completed_date: "2026-06-11"
  tasks_completed: 2
  files_created: 1
  files_modified: 1
---

# Phase 9 Plan 04: BlockOverviewScreen Live + Archived Mode Summary

**One-liner:** Extended BlockOverviewScreen with live-mode edit controls (split attach/swap, mode picker, day-chip grid, Start/End CTAs, swap-confirm sheet) and archived mode rendering from decoded ArchivedBlockConfig with ArchiveUnreadableView on decode failure.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Live-mode controls — split band, mode picker, day-chips, Start/End, swap-confirm | 6adaf07 | BlockOverviewScreen.swift |
| 2 | Archived mode + ArchiveUnreadableView + copy test suite | 25172b4 | BlockOverviewScreen.swift, BlockOverviewScreenCopyTests.swift |

---

## What Was Built

### BlockOverviewScreen.swift (extended)

**Live-mode controls** (gated on `block.derivedStatus != .completed`):

- **Split attach/swap band** (draft/ready only): `BRUSectionHead("Routine")` + nil-conditional row. When `block.split == nil`, a full-width `BRUButton("+ ATTACH ROUTINE ▸", kind: .ghost)`. When split is attached, inline name + `"SWAP ▸"` signal text-button. Both present `SplitPickerSheet` which dispatches `BlockLifecycleService.attachSplit` vs `BlockLifecycleService.swapSplit` via explicit `if block.split == nil` branch. Hidden on `.active` status.

- **Mode picker** (all live statuses): `BRUSectionHead("Scheduling")` + `ModeChip` pair (`"ROTATION"` / `"FIXED WEEKLY"`). `ModeChip` is a `fileprivate` BRUChip-derived view: selected = bruInk fill + bruPaper text, unselected = outline. Tap sets `block.schedulingMode` then calls `TrainingDaysWriter.sort` + `ctx.save()`.

- **Day-chip grid** (fixedWeekly only): `BRUSectionHead("Training days")` + `LazyVGrid` of 7 `DayToggleChip` views (`M T W T F S S`). Grid uses 7 equal `.flexible()` columns at 4pt spacing, 28pt chip height. Tap toggles weekday presence then `TrainingDaysWriter.sort` + save. Amber mismatch hint `"{N} days / {M} sessions"` shown when `trainingDays.count != slotCount`.

- **Start CTA** (ready only): `BRUButton("START BLOCK ▸", kind: .signal)` pinned in bottom bar with 2pt bruInk top rule. Tap fetches other active block via `FetchDescriptor`; if found, presents `SwapConfirmSheet`; else calls `BlockLifecycleService.start` directly.

- **End action** (active only): `BRUButton("END BLOCK", kind: .ghost)` below the EDIT button. Tap triggers `.alert("End block?")` with destructive "End Block" → `BlockLifecycleService.end`.

- **SwapConfirmSheet** (`fileprivate`): `.presentationDetents([.fraction(0.4)])` sheet with `displayMedium` "Start Block?" title, Markdown-bold body "Ends **{name}** — its config freezes to history.", `BRUButton("Confirm", kind: .signal)`, `BRUButton("Cancel", kind: .ghost)`.

- **EDIT header action**: hidden on `.completed` blocks; present on all live statuses.

**Archived mode** (gated on `block.derivedStatus == .completed`):

- **Nil guard first**: `archivedConfigJSON == nil` → "NO ARCHIVE AVAILABLE" quiet state (bodyEmphasis bruMuted + bodyDefault bruMuted). Distinct from corrupt-archive error.
- **Decode attempt**: `Result { try BlockLifecycleService.decodeArchive(jsonString) }` inline in `@ViewBuilder` — no live-template fallback ever.
- **Decode success**: `archivedConfigView(config:)` renders phases from `ArchivedPhaseDTO` array + sessions from `ArchivedSplitDTO.slots` — never from `block.split`.
- **Decode failure**: `ArchiveUnreadableView()` — terminal, no recovery action.

**ArchiveUnreadableView** (`fileprivate`): `VStack(spacing: 16)` with "ARCHIVE UNREADABLE" (bodyEmphasis bruSignal, tracking 1.2) + body copy (bodyDefault bruMuted, multiline center). `.accessibilityElement(children: .combine)` with combined label.

**Archived hero band**: "● COMPLETED BLOCK · #{N}" label (replacing ACTIVE BLOCK) + "ENDED {date}" in bruMuted (replacing bruSignal DAYS REMAINING).

### BlockOverviewScreenCopyTests.swift (new, 14 tests — all GREEN)

Source-introspection tests reading `BlockOverviewScreen.swift` via `#filePath`-relative path:

| Test | What it pins |
|------|-------------|
| `splitAttachSwapCopy` | "Routine", "+ ATTACH ROUTINE ▸", "SWAP ▸" |
| `schedulingCopy` | "Scheduling", "ROTATION", "FIXED WEEKLY" |
| `trainingDaysCopy` | "Training days" |
| `startEndCopy` | "START BLOCK ▸", "END BLOCK" |
| `swapConfirmCopy` | "Start Block?", "Confirm", "Cancel" |
| `archiveUnreadableCopy` | "ARCHIVE UNREADABLE", full body copy |
| `completedHeroCopy` | "● COMPLETED BLOCK · #\(blockSequenceNumber)", "ENDED \(" prefix |
| `serviceSeamStart` | `BlockLifecycleService.start` |
| `serviceSeamEnd` | `BlockLifecycleService.end` |
| `serviceSeamDecodeArchive` | `decodeArchive` |
| `trainingDaysWriterSort` | `TrainingDaysWriter.sort` |
| `archiveUnreadableViewExists` | `ArchiveUnreadableView` |
| `completedBranchUsesArchive` | `decodeArchive` + `ArchiveUnreadableView` + `archivedConfigJSON` |
| `splitAttachSwapServiceRouting` | `attachSplit`, `swapSplit`, `block.split == nil` |

---

## Deviations from Plan

### Auto-fixed Issues

**[Rule 1 - Bug] @ViewBuilder guard return pattern**
- **Found during:** Task 1, first build attempt
- **Issue:** `guard let jsonString = block.archivedConfigJSON else { ... return }` is invalid in `@ViewBuilder` — the result-builder DSL does not allow bare `return` in the guard-else branch when the outer function has an opaque return type.
- **Fix:** Restructured to `if let jsonString = block.archivedConfigJSON { ... } else { ... }` which is idiomatic for SwiftUI `@ViewBuilder`.
- **Files modified:** fitbod/Periodization/BlockOverviewScreen.swift
- **Commit:** 6adaf07 (included in original Task 1 commit after rebuild)

---

## Known Stubs

None — all live controls and archived paths are fully wired. The `hasPR(cellDate:)` stub (always `false`) is pre-existing from Phase 4.1 with a documented FIXME; not introduced by this plan.

---

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary schema changes introduced. All mutations are local SwiftData writes through the existing Phase 8 service seam.

Threat mitigations confirmed:
- **T-09-09**: Attach/Swap UI gated on `derivedStatus == .draft || .ready`; `SplitPickerSheet.attachOrSwap` uses explicit `if block.split == nil` nil-conditional; service also refuses on active (defense-in-depth).
- **T-09-10**: Every `block.trainingDays =` assignment in this file routes through `TrainingDaysWriter.sort`. Copy test `trainingDaysWriterSort` pins this.
- **T-09-11**: `archiveContentSection` checks `archivedConfigJSON == nil` first (nil → quiet state), then wraps `BlockLifecycleService.decodeArchive` in `Result`; failure → `ArchiveUnreadableView`; never reads `block.split` in the completed branch. Copy tests `completedBranchUsesArchive` and `archiveUnreadableViewExists` pin both paths.
- **T-09-12**: `onStartTapped()` fetches active blocks via `FetchDescriptor`, presents `SwapConfirmSheet` if another active block exists before calling `BlockLifecycleService.start`.

---

## Self-Check: PASSED

- [x] `fitbod/Periodization/BlockOverviewScreen.swift` exists (extended, ~860 lines)
- [x] `fitbodTests/BlockOverviewScreenCopyTests.swift` exists (153 lines, 14 tests)
- [x] Commit 6adaf07 exists (Task 1)
- [x] Commit 25172b4 exists (Task 2)
- [x] Build: SUCCEEDED (iPhone 17 Pro)
- [x] BlockOverviewScreenCopyTests: 14/14 PASSED
- [x] BlockOverviewScreenWeekCarouselTests: 6/6 PASSED (regression verified)
