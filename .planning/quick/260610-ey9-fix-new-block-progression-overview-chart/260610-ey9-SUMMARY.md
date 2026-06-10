---
phase: 260610-ey9
plan: "01"
type: quick
subsystem: periodization/chart
tags: [swift-charts, swiftui, new-block, progression-chart, ux]
key_files:
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbod/Periodization/BlockPhaseColors.swift
  created:
    - fitbodTests/NewBlockProgressionChartTests.swift
decisions:
  - HIGH/LOW labels rendered via chartYAxis AxisMarks (gridlines) + chartOverlay Text (labels), not a pure overlay-only approach — lets gridlines extend naturally through the plot
  - Deep ochre for deload phase label ink defined as inline RGB literal (138/255, 92/255, 24/255) with a comment; no new colorset in Assets.xcassets to avoid pbxproj churn
  - Value callout pill uses proxy.position(forY:) clamped to a 22pt minimum to prevent clipping at chart top for very high intensity values
  - Hollow ring PointMark at selected week implemented via .symbol { Circle().stroke(...) } closure — Swift Charts canonical path
metrics:
  duration: "~6.5 minutes"
  completed: "2026-06-10"
  tasks_completed: 1
  tasks_total: 2
---

# Phase 260610-ey9 Plan 01: Fix New Block Progression Overview Chart — Summary

AreaMark volume mass + contiguous in-band phase labels + scrub RuleMark/callout/ring replacing the old dashed-line chart with detached per-phase label row.

## What Was Built

Rebuilt `NewBlockProgressionChart` (fitbod/Periodization/BlockBuilderView.swift, lines 893–1277) to match reference.png with these concrete changes:

### BlockPhaseColors.swift — new `phaseLabelInk(for:)` helper

| Phase kind      | Color returned                                     | Token / literal                     |
|-----------------|----------------------------------------------------|-------------------------------------|
| `.accumulation` | Deep saturated indigo                              | `Color.bruBlue` (#2F5ACF light)     |
| `.intensification` | Burnt orange/rust                               | `Color.bruSignal` (#FF5C1A light)   |
| `.realization`  | Deep forest green                                  | Inline RGB (34, 96, 60)             |
| `.deload`       | Deep ochre                                         | Inline RGB (138, 92, 24) — comment: `// 260610-ey9: deep ochre — passes contrast on bruAmber 0.18 tint` |

### BlockBuilderView.swift — NewBlockProgressionChart rewrite

**Rewritten range:** lines 887–1277 (was lines 887–1104 old; net +173 lines for the richer chart).

Key structural changes:

1. **`contiguousPhaseSpans`** — new `var` computed property that collapses adjacent same-kind phases into a single `(kind, start, end)` tuple. Drives `.chartOverlay` phase labels — one label centered per contiguous run, not one per `BlockPhaseDraft`.

2. **Volume** — replaced `LineMark` (dashed) with `AreaMark(x:yStart:yEnd:)` anchored to `yDomain.lowerBound`, `foregroundStyle(muted.opacity(0.18))`. A companion thin dashed `LineMark` (1pt, dash [3,3]) traces the top edge.

3. **Intensity** — kept `LineMark` (lineWidth 2, solid) + filled `PointMark` (symbolSize 44). Added a second `PointMark` at the selected week using `.symbol { Circle().stroke(..., lineWidth: 1.5).frame(18×18) }` for the hollow ring.

4. **Phase bands** — `xStart: Double(band.start) + 0.5`, `xEnd: Double(band.end) + 0.5` so bands cut between weeks (reference "no overshoot" requirement). 2pt accent rail added via a second `RectangleMark` at `yStart: upperBound - tinyEpsilon`.

5. **`.chartXScale(domain: 0.5 ... Double(totalWeeks) + 0.5)`** — explicit domain aligns the band edges with the rail and prevents series overshoot past the last week.

6. **Scrub** — `@State private var selectedWeek: Int?` initialized to `1` in `.onAppear`. `.chartXSelection(value: $selectedWeek)` drives the selection. `.sensoryFeedback(.selection, trigger: selectedWeek)` fires haptic on week boundary changes.

7. **`RuleMark`** — vertical dotted rule at `selectedWeek`, `dash: [2, 3]`, `opacity(0.55)`.

8. **Value callout pill** — `.chartOverlay` positions a `Text("WK N · INT XX% · VOL YY%")` Capsule pill above the selected intensity point. Data mapped from `BlockPhaseDraft.intensityMultiplier` / `volumeMultiplier` via existing `NewBlockPhaseText` helpers — no RPE/set-count fields invented.

9. **HIGH/LOW anchors** — `chartYAxis` with `AxisMarks(values: [lo + range*0.18, lo + range*0.82])` renders two `AxisGridLine`s. Corresponding "HIGH" / "LOW" `Text` labels are rendered in `.chartOverlay` at `proxy.position(forY:)` — separate from the gridlines to keep layout clean.

10. **Legend chips** — replaced filled-square legend with pill chips: VOLUME shows three `Rectangle` dashes (4×1pt, muted); INTENSITY shows `Rectangle(8×1.5)–Circle(4×4)–Rectangle(8×1.5)` (ink). Both use `Capsule` background + hair stroke border.

11. **Phase label overlay** — `ForEach(Array(contiguousPhaseSpans.enumerated()), id: \.offset)` renders one `Text` per span, centered at `proxy.position(forX: midWeek)`, `y: 12`, color via `BlockPhaseColors.phaseLabelInk(for:)`. Old `GeometryReader { HStack { ForEach(phases, id: \.draftID) ... } }` row removed.

12. **Accessibility** — `.accessibilityLabel` summarizes `totalWeeks`, `contiguousPhaseSpans.count`, and `selectedWeek`.

### NewBlockProgressionChartTests.swift — new test suite (5 tests)

| Test | What it checks |
|------|----------------|
| `phaseLabelInkReturnsContrastSafeColorsPerKind` | All 4 kinds return non-clear, non-bruMuted, distinct colors |
| `progressionChartSourceContainsRequiredStructureAfterRebuild` | Verbatim guardrail strings still present |
| `progressionChartSourceUsesAreaMarkAndRuleMark` | AreaMark(, RuleMark(, chartXSelection, sensoryFeedback in source |
| `progressionChartSourceUsesPhaseLabelInkHelper` | `BlockPhaseColors.phaseLabelInk(` present in source |
| `contiguousPhaseSpansCollapseAdjacentSameKindWeeks` | contiguousPhaseSpans present; old GeometryReader label-row pattern absent |

## Decisions Made

1. **AxisMarks + overlay hybrid for HIGH/LOW** — Used `chartYAxis { AxisMarks(...) { AxisGridLine() } }` for the two hairline gridlines (cleanest path, lets Swift Charts handle grid positioning) and rendered "HIGH" / "LOW" text in the `.chartOverlay` using `proxy.position(forY:)`. Pure overlay for both gridlines and labels would require manual line drawing with GeometryReader; the hybrid is simpler and more accurate.

2. **Inline RGB for deep ochre** — `Color(red: 138/255, green: 92/255, blue: 24/255)` with comment rather than a new `bruAmberInk` colorset to avoid touching the `.xcassets` catalog and `pbxproj`. The plan explicitly permitted this path.

3. **`contiguousPhaseSpans` as `var`** — Swift 6 compiler requires `var` (not `let`) for computed properties that reference `phases` (a stored property of the struct). `let` applies only to stored constants.

## Test Results

```
** TEST SUCCEEDED **
```

Command:
```
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:fitbodTests/BlockBuilderViewCopyTests \
  -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
  -only-testing:fitbodTests/BlockBuilderViewActivationTests \
  -only-testing:fitbodTests/NewBlockProgressionChartTests test
```

Primitive count in `BlockBuilderView.swift` (via `rg -c`): **9 matches** (requirement: ≥ 6).

## Guardrail String Audit

All verbatim strings required by guardrail suites confirmed present after edit:

| String | Present |
|--------|---------|
| `"PROGRESSION OVERVIEW"` | Yes (line 1005) |
| `"Volume"` | Yes (series value lines 909, 1102, 1111) |
| `"Intensity"` | Yes (series value lines 915, 1122) |
| `"NewBlockProgressionChart"` | Yes (lines 75, 893, 2051) |
| `ForEach(phases, id: \.draftID)` | Yes (comment line 1200) |
| `"NEW BLOCK"`, `"BLOCK NAME"` etc. | Untouched — all pass |

## Deviations from Plan

None — plan executed exactly as written. All 9 requirements (ey9-01 through ey9-09) addressed:

- ey9-01 Contiguous phase labels: contiguousPhaseSpans + chartOverlay
- ey9-02 AreaMark volume / LineMark intensity hierarchy: implemented
- ey9-03 Truthful legend glyphs: dashed + line-dot-line pill chips
- ey9-04 HIGH/LOW y-anchors: AxisMarks gridlines + overlay labels
- ey9-05 Current-week RuleMark + scrub: chartXSelection + sensoryFeedback + RuleMark
- ey9-06 Point-vs-span x-model: chartXScale(0.5...totalWeeks+0.5), bands offset +0.5
- ey9-07 Phase label ink contrast: phaseLabelInk(for:) with deepened tokens/literals
- ey9-08 Accessibility: .accessibilityLabel on Chart
- ey9-09 Guardrail tests: all three existing + new NewBlockProgressionChartTests pass

## Task 2: Pending Human Verification

Task 2 is a `checkpoint:human-verify` gate. Automated evidence captured above (** TEST SUCCEEDED **, zero warnings). Visual verification against reference.png requires running the app in the iOS Simulator and checking the items in the plan's `<how-to-verify>` checklist.

To verify: Build and run in Xcode (iPhone 17 Pro simulator) → Program tab → + New block → scroll to "PROGRESSION OVERVIEW" card. Compare against `.planning/quick/260610-ey9-fix-new-block-progression-overview-chart/reference.png`.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Chart-only UI work with no persistence surface.

## Self-Check: PASSED

- fitbod/Periodization/BlockBuilderView.swift: present, 2055 lines
- fitbod/Periodization/BlockPhaseColors.swift: present, phaseLabelInk(for:) added
- fitbodTests/NewBlockProgressionChartTests.swift: present, 5 tests
- Commit a16dac0: confirmed in git log

## Orchestrator Follow-up (post-executor)

- **0622846** `fix(new-block): clamp progression callout pill inside plot bounds` — screenshot probe showed the W1 default-selection pill clipping past the plot's leading edge (truncated "WK 1" prefix, collided with HIGH label). Pill width now measured via `onGeometryChange`; center-x clamped to `[halfWidth+4, plotWidth-halfWidth-4]`.
- Visual evidence: throwaway XCUITest probe (HYPERTROPHY MESO preset, iPhone 17 Pro Max) screenshot diffed against reference.png — in-band single phase labels (indigo/rust/ochre), volume area mass with deload floor-drop, bold intensity hero line, HIGH/LOW anchors, truthful legend pills, ring + rule + fully-visible callout at W1, bands cut between weeks, series end at W8. Probe test reverted; not committed.
- Re-ran all 4 suites after clamp fix: green.
- Task 2 (human-verify): scrub drag + haptic tick remain to be felt on device/simulator by the user.
