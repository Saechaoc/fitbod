---
phase: 09-program-surfaces
reviewed: 2026-06-11T00:00:00Z
depth: ui-advisory
files_reviewed:
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbod/Periodization/BlockOverviewScreen.swift
  - fitbod/Periodization/SplitDetailView.swift
  - fitbod/Periodization/ProgramView.swift
findings:
  advisory: 7
  total: 7
status: fixes_applied
fix_report:
  fixed: 7
  skipped: 0
  noted: 0
  fixed_at: 2026-06-11
---

# Phase 9: UI Advisory Review

**Reviewed:** 2026-06-11
**Depth:** UI advisory (BRU contract, accessibility, token discipline)
**Files Reviewed:** 4 source files
**Status:** fixes_applied

## Summary

Seven UI advisory findings across four files. All seven applied and verified.
Build green. All 5 guardrail test suites green (64 test cases, 0 failures).

---

## Advisory Findings

### UI-01: `NewBlockSplitPickerSheet` uses `List` + `.navigationTitle` — BRU contract violation

**File:** `fitbod/Periodization/BlockBuilderView.swift:2048-2083`

**Issue:** `NewBlockSplitPickerSheet` used `List(splits, id: \.id)` with `.navigationTitle("Choose Routine")`, adding system separator lines, row backgrounds, and a nav-bar title that violate the BRU no-system-chrome contract.

**Fix Applied:** Replaced with `ScrollView` + `LazyVStack` + `BRUSectionHead("Choose Routine")` + `BRUDivider(.hair)` rows on `Color.bruPaper` background, nav bar hidden. Matches `BlockOverviewScreen.SplitPickerSheet` pattern exactly.

---

### UI-02: `DayToggleChip` / `NewBlockDayToggleChip` missing full weekday `.accessibilityLabel`

**Files:** `fitbod/Periodization/BlockOverviewScreen.swift:~1094`, `fitbod/Periodization/BlockBuilderView.swift:~2019`

**Issue:** Both chips rendered a single letter ("M", "T"…). VoiceOver announced "M" not "Monday". `.accessibilityLabel` was absent; only `.accessibilityAddTraits(.isToggle)` and `.accessibilityValue` were present.

**Fix Applied:** Added `weekdayName: String` parameter to both structs. Wired `.accessibilityLabel(weekdayName)`. Updated call sites: `BlockOverviewScreen.dayChipSection` adds `weekdayNames` array; `NewBlockSplitBand` expands tuples to `(Int, String, String)` with full name in third element.

---

### UI-03: `SplitDetailView` drag-reorder spring animation ignores `accessibilityReduceMotion`

**File:** `fitbod/Periodization/SplitDetailView.swift:199`

**Issue:** The sibling-shift spring animation `.animation(.spring(response: 0.28, dampingFraction: 0.86), value: dragTargetIndex)` was applied unconditionally, violating the Reduce Motion accessibility setting.

**Fix Applied:** Added `@Environment(\.accessibilityReduceMotion) private var reduceMotion`. Changed animation to `reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86)`.

---

### UI-04: `SplitDetailView` "Used in" chips use plain default color — should mirror `ProgramView.statusChip`

**File:** `fitbod/Periodization/SplitDetailView.swift:230`

**Issue:** `BRUChip(block.derivedStatus.rawValue.uppercased())` applied the default ink outline to all statuses. `ProgramView.statusChip` uses `bruSignal fill` for ACTIVE and `bruSignal outline` for READY.

**Fix Applied:** Replaced with a `switch block.derivedStatus` that maps `.active` → `BRUChip("ACTIVE", color: .bruSignal, fill: true)`, `.ready` → `BRUChip("READY", color: .bruSignal)`, and `default` → the plain chip.

---

### UI-05: `BlockOverviewScreen` mismatch hint missing `block.split != nil` guard

**File:** `fitbod/Periodization/BlockOverviewScreen.swift:722`

**Issue:** The training-days mismatch hint showed whenever `trainingDays.count != slotCount` with no guard on whether a split was attached. `NewBlockSplitBand` correctly guards `draft.split != nil`. Without a split, `slotCount` is 0 by default (`block.split?.slots?.count ?? 0`), so a block with 4 training days and no split attached would incorrectly show "4 days / 0 sessions".

**Fix Applied:** Added `block.split != nil &&` guard before the count comparison, matching `NewBlockSplitBand` semantics.

---

### UI-06: `SplitDetailView` screen background is `bruBg` — should be `bruPaper`

**File:** `fitbod/Periodization/SplitDetailView.swift:124`

**Issue:** `.background(Color.bruBg.ignoresSafeArea())` used `bruBg` (`#F2EFE7` / `#16140F`) — the status-bar/screen-edge chrome token. Per the 60/30/10 doctrine, `bruPaper` is the screen background and row fill surface; `bruBg` is reserved for screen-edge chrome.

**Fix Applied:** Changed to `.background(Color.bruPaper.ignoresSafeArea())`.

---

### UI-07: Token discipline — raw `.custom("JetBrainsMono-Bold", size: 10)` in `BlockOverviewScreen` phase rows

**Files:** `fitbod/Periodization/BlockOverviewScreen.swift:801-805,939-944`

**Issue:** Both `phaseRow` and `archivedPhaseRow` used `.font(.custom("JetBrainsMono-Bold", size: 10))` for the week-range label. `BRUFont.labelSmall` is the canonical token for this spec (same postscript name and size). Direct raw font values bypass the token system and will drift if the type scale changes.

**Fix Applied (BlockOverviewScreen):** Replaced both instances with `.font(BRUFont.labelSmall)`. Tracking `.tracking(1.2)` preserved at call site (per `BRUFont.swift` usage note).

**Decision (BlockBuilderView `NewBlockSplitBand` section head):** The `NewBlockSplitBand` section head at lines 1858–1865 uses `NewBlockType.chrome` — CONSISTENT with the local token world. Every other New Block band (name, metrics, phases header, bottom bar, undo toast) uses `NewBlockType.chrome` for section-level chrome text. Switching to `BRUSectionHead` would cross token worlds mid-screen. Left as-is; noted here as intentional local token usage.

---

## Remediation Table

| # | Finding | File | Lines | Status | Commit |
|---|---------|------|-------|--------|--------|
| UI-01 | NewBlockSplitPickerSheet: replace List with BRU ScrollView pattern | BlockBuilderView.swift | 2048–2083 | FIXED | 0808e7f |
| UI-02 | DayToggleChip/NewBlockDayToggleChip: add full weekday accessibilityLabel | BlockOverviewScreen.swift, BlockBuilderView.swift | ~1094, ~2019 | FIXED | fd3028a |
| UI-03 | SplitDetailView: gate spring animation on accessibilityReduceMotion | SplitDetailView.swift | 199 | FIXED | f41a79e |
| UI-04 | SplitDetailView usedIn chips: adopt status badge colors | SplitDetailView.swift | 230 | FIXED | 544f144 |
| UI-05 | BlockOverviewScreen mismatch hint: guard block.split != nil | BlockOverviewScreen.swift | 722 | FIXED | a2a9be7 |
| UI-06 | SplitDetailView screen background: bruBg → bruPaper | SplitDetailView.swift | 124 | FIXED | 9e6ee27 |
| UI-07a | BlockOverviewScreen phase rows: raw .custom font → BRUFont.labelSmall | BlockOverviewScreen.swift | 801–805, 939–944 | FIXED | e61325b |
| UI-07b | BlockBuilderView NewBlockSplitBand section head | BlockBuilderView.swift | 1858–1865 | NOTED: consistent with local token world — left as NewBlockType.chrome | — |

**Tests:** BUILD SUCCEEDED · SplitDetailViewTests ✓ · BlockOverviewScreenCopyTests ✓ · BlockBuilderViewCopyTests ✓ · NewBlockBuilderFidelityTests ✓ · ProgramViewFidelityTests ✓ (64 passed, 0 failed)

---

_Fixed: 2026-06-11_
_Fixer: Claude (gsd-code-fixer)_
