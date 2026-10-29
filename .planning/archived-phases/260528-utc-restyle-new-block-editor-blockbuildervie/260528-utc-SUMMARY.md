---
quick_id: 260528-utc
title: Restyle New Block editor (BlockBuilderView) to match final-design.png
completed: 2026-05-28
duration_minutes: ~25
tasks_completed: 5
tasks_total: 5
files_modified:
  - fitbod/Design/Color+BRU.swift
  - fitbod/Assets.xcassets/bruBlue.colorset/Contents.json
  - fitbod/Periodization/BlockPhaseColors.swift
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbodTests/NewBlockBuilderFidelityTests.swift
commits:
  - hash: 66a59e6
    message: "feat(new-block): semantic phase badge colors + bruBlue token (260528-utc T1)"
  - hash: 9fb5e95
    message: "feat(new-block): progression line chart replaces timeline, delete orphans (260528-utc T2)"
  - hash: e1faa97
    message: "feat(new-block): metrics cards with icons + Peak/SHARPEN OUTPUT copy (260528-utc T3)"
  - hash: 40d07ab
    message: "feat(new-block): read-only phase rows + NewBlockPhaseEditorSheet (260528-utc T4)"
  - hash: 0eb627f
    message: "feat(new-block): coral + ADD PHASE in header, remove dashed slot, update fidelity test (260528-utc T5)"
---

# Quick Task 260528-utc Summary

## One-liner

Restyled BlockBuilderView to match final-design.png: bruBlue token + semantic badge colors, Swift Charts progression line chart replacing timeline, bordered metric cards with SF Symbol icons, read-only phase rows with tap-to-edit sheet, and coral "+ ADD PHASE" in the phases header.

## Tasks Completed

### T1 — Colors foundation: bruBlue token + semantic badge API + badge/swatch swap

- Created `fitbod/Assets.xcassets/bruBlue.colorset/Contents.json` (sRGB #2F5ACF light / #4A78E6 dark), mirroring bruSignal colorset shape
- Added `Color.bruBlue` public static token to `Color+BRU.swift`
- Added `BlockPhaseColors.badgeColor(for:)` and `badgeLabelColor(for:)` additively to `BlockPhaseColors.swift` — existing `color(for:)`, `rowTint(for:)`, `drawDeloadStripes`, `phaseLabel` untouched
- Swapped phase-row badge and add-phase-type swatch from `NewBlockScreenTokens.paletteColor` to `BlockPhaseColors.badgeColor(for: draft.kind)`
- Fix applied: restored `let isDeload` variable (still needed by DELOAD chip display) after badge swap removed the original binding

### T2 — Progression line chart: replace timeline preview, delete orphans

- Added `import Charts`
- Added `NewBlockProgressionChart` with `NewBlockProgressionPoint` data struct; expands phases into per-week Volume/Intensity points
- Volume: `LineMark` + `PointMark`, solid `NewBlockScreenTokens.ink`; Intensity: `LineMark` dashed `[4,3]`, `NewBlockScreenTokens.muted`
- Bordered BRU card (1pt ink Rectangle stroke), PROGRESSION OVERVIEW label, hand-rolled legend, proportional top phase abbreviation labels, W1..Wn x-axis ticks, empty-state placeholder
- Removed `NewBlockTimelinePreview(phases:)` row and baseline legend row from body List
- Deleted orphaned `NewBlockTimelinePreview`, `NewBlockTimelineSegment`, `NewBlockDeloadStripes`
- Deleted orphaned `paletteSlots`, `paletteColor`, `paletteLabelColor` from `NewBlockScreenTokens` (confirmed zero call sites before deletion)

### T3 — Metrics cards + copy alignment

- Restyled `NewBlockMetricsBand` as two side-by-side bordered BRU cards with `rowGap` spacing
- Each card: `Image(systemName: "calendar")` / `"calendar.day.timeline.left"` icon + uppercase label + BebasNeue number + "TAP TO EDIT" hint
- 1pt ink `Rectangle().stroke(...)` overlay (sharp corners), paper background
- Both cards remain tappable, `accessibilityAddTraits(.isButton)` and `accessibilityLabel` preserved
- `NewBlockPhaseText.title(for: .realization)` changed "Realization" → "Peak"
- `NewBlockPhaseText.subtitle(for: .realization)` changed "PEAK" → "SHARPEN OUTPUT"
- `abbreviation(for: .realization)` left as "PEAK" (correct for chart labels)
- `WeekDetailView.swift` not touched (WeeklyTonnageViewCopyTests unaffected)

### T4 — Phase rows read-only + per-phase editor sheet

- Replaced inline stepper `HStack` in `NewBlockPhaseEditorRow` with three read-only `NewBlockReadOnlyStatColumn` views (WEEKS / VOL / INT), right-aligned, compact
- Added `@State private var presentingEditor = false` to row; `.contentShape(Rectangle()).onTapGesture { presentingEditor = true }` — coexists with `swipeActions` and `.onMove`
- `.sheet(isPresented: $presentingEditor)` drives `NewBlockPhaseEditorSheet` — uses row-local Bool identity, never `BlockPhaseDraft.id` (nil until saved)
- Added `NewBlockPhaseEditorSheet` (NavigationStack, `.presentationDetents([.medium])`, `NewBlockInkRule` separators, "Done" dismiss); WEEKS/VOL/INT rows with `NewBlockStepperButton` and exact clamp rules from plan
- Deleted `NewBlockInlineMetricColumn` (no remaining consumers)
- Retained `NewBlockStepperButton` (still used by `NewBlockDurationSheet` lines ~1475, ~1482)
- Reduced `phaseRowHeight` token 148 → 100

### T5 — Phases header coral "+ ADD PHASE" + remove dashed slot + update guardrail test

- Added `onAddPhase: () -> Void` closure to `NewBlockPhasesHeader`; coral `NewBlockScreenTokens.signal` "+ ADD PHASE" button as rightmost accent (≥44pt)
- REORDER toggle and Preset menu remain to the left, still reachable
- Passed `onAddPhase: { presentingAddPhaseTypePicker = true }` from body header construction
- Removed `NewBlockAddPhaseSlot(onTap:)` row from body List
- Deleted orphaned `NewBlockAddPhaseSlot` struct
- `BlockBuilderViewCopyTests.swift` stays green ("+ ADD PHASE" still present, now in header)
- Updated `NewBlockBuilderFidelityTests`: `"NewBlockTimelinePreview"` → `"NewBlockProgressionChart"`, `"PREVIEW"` → `"PROGRESSION OVERVIEW"`
- All 5 `NewBlockBuilderFidelityTests` pass: TEST SUCCEEDED

## Build / Test Results

- All 5 tasks: BUILD SUCCEEDED on `platform=iOS Simulator,name=iPhone 17 Pro`
- Final test run: `xcodebuild test ... -only-testing:fitbodTests/NewBlockBuilderFidelityTests` → **TEST SUCCEEDED** (5/5 tests pass)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored `isDeload` variable after badge swap**
- **Found during:** Task 1
- **Issue:** After swapping badge colors away from palette helpers, `let isDeload = draft.kind == .deload` was removed from the chip binding block, but the variable was still referenced 10 lines later by the DELOAD chip conditional display
- **Fix:** Re-added `let isDeload = draft.kind == .deload` directly above the new `chipFill`/`chipLabel` bindings
- **Files modified:** `fitbod/Periodization/BlockBuilderView.swift`
- **Commit:** 66a59e6

None beyond the above — plan executed as written for all other tasks.

## Known Stubs

None — all changes are fully wired behavioral code.

## Threat Flags

None — all changes are pure UI/view layer within a single-user local app; no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check

- [x] `fitbod/Assets.xcassets/bruBlue.colorset/Contents.json` exists
- [x] `Color.bruBlue` in `fitbod/Design/Color+BRU.swift`
- [x] `BlockPhaseColors.badgeColor` and `badgeLabelColor` in `fitbod/Periodization/BlockPhaseColors.swift`
- [x] `NewBlockProgressionChart` struct in `BlockBuilderView.swift`
- [x] No `NewBlockTimelinePreview` in `BlockBuilderView.swift`
- [x] No `NewBlockInlineMetricColumn` in `BlockBuilderView.swift`
- [x] No `NewBlockAddPhaseSlot` in `BlockBuilderView.swift`
- [x] `NewBlockPhaseEditorSheet` in `BlockBuilderView.swift`
- [x] `"Peak"` and `"SHARPEN OUTPUT"` in `BlockBuilderView.swift`; no `"Realization"`
- [x] All 5 commits exist: 66a59e6, 9fb5e95, e1faa97, 40d07ab, 0eb627f
- [x] `NewBlockBuilderFidelityTests` passes (5/5)

## Self-Check: PASSED

---

## Follow-up (post-execution) — pixel-match `final-design-2.png` metrics

After the 5 plan tasks, the user supplied a second reference (`bru-screens/New-block/final-design-2.png`) showing the **DAYS PER WEEK** cell with inline `− 4 +` steppers (the original `final-design.png` did not show them). One additional commit (`098c040`) closes that gap:

- **`NewBlockMetricsBand` reworked** to match design-2: a single rounded card (cornerRadius 12) split by a hairline divider.
  - **TOTAL WEEKS** — read-only number (it is `draft.totalWeeks`, the computed sum of phase durations); the cell still taps through to `NewBlockDurationSheet`.
  - **DAYS PER WEEK** — inline `−`/`+` steppers adjusting `draft.daysPerWeek`, clamped `1...7` (matches `BlockBuilderViewActivationTests.daysPerWeekClampsToOneThroughSeven`). Reuses `NewBlockStepperButton`.
  - Removed the `"TAP TO EDIT"` hint lines and the per-label SF Symbol icons to match design-2's cleaner labels.
- **Deleted the now-redundant `NewBlockDaysSheet`** and its plumbing (`presentingDaysSheet` state, the `onEditDays` closure param, the `.sheet`) — the inline steppers fully replace the 1–7 picker sheet. No test referenced it.
- **Fixed a stale copy guardrail** in `fitbodTests/BlockBuilderViewCopyTests.swift`: it still asserted the removed `"PREVIEW"` string. This was a **pre-existing regression from T2** (timeline→chart) — the executor updated only `NewBlockBuilderFidelityTests` and its T5 verify ran only that one suite, so `BlockBuilderViewCopyTests` was silently red from commit `9fb5e95`. Realigned the assertion to `"PROGRESSION OVERVIEW"`.

**Decisions:** kept the labels verbatim as `TOTAL WEEKS` / `DAYS PER WEEK` (not design-2's `DAYS / WEEK`) because two suites assert those exact literals and per-vs-slash was not the user's flagged concern. The metrics card uses on-system tokens (paper fill + hair border); design-2's near-white card fill has no BRU token, so the structure matches but the fill stays on-system.

**Verification (follow-up):** `BUILD SUCCEEDED` on iPhone 17 Pro; `NewBlockBuilderFidelityTests` (5/5), `BlockBuilderViewCopyTests` (1/1), `BlockBuilderViewActivationTests` (3/3) all pass. Note: the copy-test fix initially appeared to still fail due to a **stale incremental test build** — a `touch` of the test file forced recompilation and it passed.

**Commit:** `098c040` — `feat(new-block): pixel-match metrics to final-design-2 — inline days/week steppers (260528-utc)`
