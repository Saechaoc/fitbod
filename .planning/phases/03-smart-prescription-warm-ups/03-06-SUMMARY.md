---
phase: 03-smart-prescription-warm-ups
plan: "06"
subsystem: session-ui-components
tags: [swiftui, components, standalone, ui-spec, phase3, prescription, warmup, plate-stack]
dependency_graph:
  requires: [03-01, 03-04, 03-05]
  provides:
    - WhyThisWeightSheet
    - PrescriptionWeightCell
    - PlateStackDisclosure
    - BumpBanner
    - CalibratingBadge
    - WarmupRampRows
  affects:
    - fitbod/Sessions/WhyThisWeightSheet.swift
    - fitbod/Sessions/PrescriptionWeightCell.swift
    - fitbod/Sessions/PlateStackDisclosure.swift
    - fitbod/Sessions/BumpBanner.swift
    - fitbod/Sessions/CalibratingBadge.swift
    - fitbod/Sessions/WarmupRampRows.swift
tech_stack:
  added: []
  patterns:
    - "PrescriptionWeightCell: conditional render — range != nil → read-only Text; range == nil → editable TextField"
    - "WhyThisWeightSheet: NavigationStack + List + status switch → calibrating/calibrated/notApplicable capsule variants"
    - "PlateStackDisclosure: PlateCalculator.solve → three-state render (below-bar / no-solution / stack HStack)"
    - "BumpBanner: @Binding<Bool> isVisible guard + Color(.systemGreen).opacity(0.15) background (NOT accent)"
    - "CalibratingBadge: Circle dot + Text label + systemGray5 Capsule (NOT accent per UI-SPEC item 19)"
    - "WarmupRampRows: ForEach(sorted by orderIndex) + percent-map by set count + ZStack divider overlay"
key_files:
  created:
    - fitbod/Sessions/WhyThisWeightSheet.swift
    - fitbod/Sessions/PrescriptionWeightCell.swift
    - fitbod/Sessions/PlateStackDisclosure.swift
    - fitbod/Sessions/BumpBanner.swift
    - fitbod/Sessions/CalibratingBadge.swift
    - fitbod/Sessions/WarmupRampRows.swift
  modified: []
decisions:
  - "PrescriptionWeightCell uses U+2013 en-dash literal in range Text to match UI-SPEC (not hyphen-minus)"
  - "PlateStackDisclosure plateColor() uses kg-tier thresholds only (lb thresholds nearly identical for default plate sets; documented limitation)"
  - "BumpBanner does not own its own onTapGesture — tap-dismiss delegated to parent SessionExerciseCard (plan 03-08)"
  - "WhyThisWeightSheet has no Done toolbar button — iOS sheet dismiss gesture is the affordance per UI-SPEC"
  - "WarmupRampRows renders warmup chip inline using systemBlue capsule (Phase 2 color convention) rather than SetTypeChip binding since these rows are read-only"
  - "incrementText() in WhyThisWeightSheet parses roundedLine string to extract increment for bump copy; falls back to '?' if parse fails"
metrics:
  duration_minutes: 5
  completed: "2026-05-23T00:51:00Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 6
  files_modified: 0
requirements: [PRES-02, PRES-10, PRES-08, WARM-01, WARM-02]
---

# Phase 3 Plan 06: Session UI Components Summary

**One-liner:** Six standalone SwiftUI components — WhyThisWeightSheet, PrescriptionWeightCell (with calibrating-range read-only mode), PlateStackDisclosure, BumpBanner, CalibratingBadge, WarmupRampRows — all UI-SPEC verbatim, no Phase 2 file modified.

## What Was Built

Six new files under `fitbod/Sessions/`, each standalone with `#Preview` coverage. None mutates any Phase 2 file — plan 03-08 owns the wiring into `SessionExerciseCard` / `SetRow` / `SessionLoggerView`.

### WhyThisWeightSheet (`fitbod/Sessions/WhyThisWeightSheet.swift`)

Medium-detent bottom sheet rendering a `PrescriptionExplanation` value type. Mirrors `DecimalRPEPickerSheet` for the NavigationStack + dismissal shape.

**Rows rendered (UI-SPEC verbatim):**
- "Last session" / `"{weight} × {reps} @ RPE {rpe} ({day})"` or `"No prior data — starting fresh."`
- "Formula" / strategy name
- "Computed" / e1RM line — ONLY for RPE autoreg (conditional on `computedLine != nil`)
- "Rounded" / rounded-line string
- "Status" / three variants:
  - `.calibrating(n, threshold)` → gray `systemGray5` capsule: `"Calibrating (n / threshold sets)"`
  - `.calibrated` → accent-tinted capsule: `"Calibrated"`
  - `.notApplicable` + `bumpOccurred` → bump-line copy
  - `.notApplicable` + no prior data → `"No prior data — starting at prescribed weight."`

Optional `onUseSuggested` closure renders `"Use Suggested Weight"` accent-filled button only when a manual override is active (plan 03-08 passes this closure; read-only sessions omit it).

**#Preview states:** calibrating, calibrated, bump-occurred, first-session, override-active (5 blocks).

### PrescriptionWeightCell (`fitbod/Sessions/PrescriptionWeightCell.swift`)

Compound control replacing the plain weight `TextField` in `SetRow`.

**Signature (plan 03-08 call site):**
```swift
PrescriptionWeightCell(
    weight: $entry.weight,
    prescribed: sessionExercise.prescribedWeight,
    range: explanation?.range,        // ClosedRange<Double>? — non-nil in calibrating mode
    explanation: explanation,
    unitLabel: "kg",                  // per-exercise unitOverride wired in 03-08
    wasManualOverride: $entry.wasManualOverride
)
```

**Conditional render:**
- `range != nil` → non-editable `Text("\(low) – \(high) kg")` with U+2013 en-dash (literal) and `.secondary` foreground
- `range == nil` → editable `TextField` + optional `"M"` badge when `wasManualOverride == true`

**Always present (when `explanation != nil`):** `info.circle` button with 44pt `.contentShape(Rectangle()).frame(minWidth: 44, minHeight: 44)` hit area, accent foreground (UI-SPEC item 18), opens `WhyThisWeightSheet` via `.sheet(isPresented:)` at `.medium` detent.

**#Preview states:** editable with prescription, override + M badge, calibrating range read-only (3 blocks).

### PlateStackDisclosure (`fitbod/Sessions/PlateStackDisclosure.swift`)

Inline plate-stack visualization. Calls `PlateCalculator.solve(target:barWeight:plates:)` internally.

**Three render states:**
1. `targetWeight < barWeight` → `"Target is below bar weight ({bar} kg). Log as bodyweight or adjust the bar."` (`.caption .secondaryLabel`)
2. `solve == nil` → `"No plate combination found. Adjust inventory in Settings."` (`.caption .systemRed`)
3. `solve != nil` → heading + plate HStack

**Heading (UI-SPEC verbatim):** `"{bar} bar + {plates} each side"` e.g. `"20 bar + 2×20 kg, 1×5 kg each side"`

**Color palette (UI-SPEC § Asset Contract):**
| Weight tier | Color |
|-------------|-------|
| ≥25 kg | `Color(.systemRed).opacity(0.8)` |
| ≥20 kg | `Color(.systemBlue).opacity(0.8)` |
| ≥15 kg | `Color(.systemYellow).opacity(0.8)` |
| ≥10 kg | `Color(.systemGreen).opacity(0.8)` |
| ≥5 kg | `Color(.systemGray5)` |
| ≥2.5 kg | `Color(.systemGray3)` |
| <2.5 kg | `Color(.systemGray6)` |
| Bar segment | `Color(.systemGray4)` |

Animation gated on `@Environment(\.accessibilityReduceMotion)` — `.easeInOut(duration: 0.2)` when false, nil when true.

**Limitation documented:** `plateColor()` uses kg-tier thresholds only. lb thresholds are nearly identical for default plate sets (45≈25, 35≈20, 25≈15); v1 acceptable.

**#Preview states:** 100 kg standard, 97.5 kg with microplates, no solution, below-bar (4 blocks).

### BumpBanner (`fitbod/Sessions/BumpBanner.swift`)

44pt pill banner for DoubleProgressionStrategy bump notification.

**Copy (UI-SPEC verbatim):** `"Bumping to {weight} kg — you cleared the top of the range last time."`
**Background:** `Color(.systemGreen).opacity(0.15)` — NOT accent per UI-SPEC explicit exclusion.
**Icon:** `arrow.up.circle` `.caption`-sized, `.secondary` foreground — NOT accent.
**Tap-dismiss:** delegated to parent `SessionExerciseCard.onTapGesture` (plan 03-08). `BumpBanner` does NOT own an `onTapGesture`.

**#Preview states:** standard 102.5 kg bump, hidden state (2 blocks).

### CalibratingBadge (`fitbod/Sessions/CalibratingBadge.swift`)

Small capsule badge for RPE autoreg calibrating mode.

**Copy (UI-SPEC verbatim):** badge label `"calibrating"`, a11y label `"Calibrating: {n} of {threshold} sets logged. Weight shown as a range."`
**Background:** `Color(.systemGray5)` — NOT accent per UI-SPEC item 19 exclusion (transitional/incomplete state).
**Dot:** 6×6pt `Circle()` filled `Color(.systemGray3)`.

**#Preview states:** 4/10 sets, 9/10 sets (2 blocks).

### WarmupRampRows (`fitbod/Sessions/WarmupRampRows.swift`)

Warm-up ramp block: sorted warmup `SetEntry` ForEach + "Skip warm-ups" text button + "Working sets" divider.

**Set-count → percentage mapping:**
| Count | Percentages | Reps |
|-------|-------------|------|
| 4 (barbell) | 40 / 60 / 75 / 90 | 5 / 3 / 2 / 1 |
| 2 (dumbbell) | 60 / 90 | 3 / 1 |
| other | linear fraction | defensive |

**Copy (UI-SPEC verbatim):**
- W{N} leading label: `"W1"`, `"W2"`, `"W3"`, `"W4"`
- Percentage hint: `"{pct}% × {reps}"` e.g. `"40% × 5"`
- Divider: `"Working sets"` (`.caption .secondaryLabel`, centered via ZStack overlay)
- Skip button: `"Skip warm-ups"` (`.secondaryLabel`, NOT accent)
- Empty placeholder: `"Warm up however you'd like."` (`.caption .secondaryLabel`)

**#Preview states:** 4-set barbell ramp, 2-set dumbbell ramp, empty placeholder (3 blocks).

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 — WhyThisWeightSheet + PrescriptionWeightCell | `38c04ec` | Sheet + compound weight cell with range display |
| 2 — PlateStackDisclosure + BumpBanner + CalibratingBadge | `23ba619` | Plate visualization + bump banner + calibrating badge |
| 3 — WarmupRampRows | `d99d6cc` | Warmup ramp rows component |

## Integration Contract for Plan 03-08

Plan 03-08 wires these components into the session logger. Key call-site contracts:

**PrescriptionWeightCell `range` parameter:**
- Source: `explanation.range` (from `PrescriptionExplanation.range: ClosedRange<Double>?`)
- Non-nil only during RPE autoreg calibrating window (< `minCalibrationSets` logged working sets)
- Pass `explanation?.range` — nil when no explanation or calibrated/double-progression

**BumpBanner `isVisible` binding:**
- Source: `@State var showBumpBanner: Bool` on `SessionExerciseCard`
- Initialize to `explanation.bumpOccurred` at session start
- Set to `false` on first tap anywhere on the card (`onTapGesture` on outer container)

**WarmupRampRows integration point:**
- Filter `sessionExercise.sets` where `isWarmup == true` → pass as `warmupSets`
- `onSkip` closure: sets all warmup `SetEntry.isComplete = true`, `SetEntry.weight = 0`

**CalibratingBadge integration point:**
- Render in `SessionExerciseCard` header when `explanation.status == .calibrating(n, threshold)`
- Extract `n` and `threshold` from the associated values

## Deviations from Plan

None — plan executed exactly as written.

All six components compile clean under Swift 6 strict concurrency (`xcrun swiftc -parse` zero errors). No Phase 2 files modified. UI-SPEC copy is verbatim throughout. All `#Preview` blocks cover the required states.

## Known Stubs

None. All six files are fully implemented. The `incrementText()` helper in `WhyThisWeightSheet` parses the `roundedLine` string to extract the increment value for the bump-status copy; it falls back to `"?"` if parsing fails — this is a defensive fallback, not a stub, since `roundedLine` format is well-defined by `DoubleProgressionStrategy`.

The warmup chip in `WarmupRampRows` is rendered as a direct systemBlue capsule rather than `SetTypeChip` — this is intentional since warmup rows are read-only (no cycle behavior needed) and avoids a `@Binding<String>` requirement on a value that cannot change.

## Threat Flags

None. All six files are pure SwiftUI view types operating on value-type inputs (no network endpoints, no auth paths, no file access, no schema changes). `WarmupRampRows` accepts `SessionExercise` for `prescribedWeight` access but does not write to it.

## Self-Check: PASSED

- FOUND: `fitbod/Sessions/WhyThisWeightSheet.swift`
- FOUND: `fitbod/Sessions/PrescriptionWeightCell.swift`
- FOUND: `fitbod/Sessions/PlateStackDisclosure.swift`
- FOUND: `fitbod/Sessions/BumpBanner.swift`
- FOUND: `fitbod/Sessions/CalibratingBadge.swift`
- FOUND: `fitbod/Sessions/WarmupRampRows.swift`
- FOUND: commit `38c04ec` (WhyThisWeightSheet + PrescriptionWeightCell)
- FOUND: commit `23ba619` (PlateStackDisclosure + BumpBanner + CalibratingBadge)
- FOUND: commit `d99d6cc` (WarmupRampRows)
- No Phase 2 files modified (git diff confirms clean)
- Parse check PASSED (zero errors across all 6 files)
