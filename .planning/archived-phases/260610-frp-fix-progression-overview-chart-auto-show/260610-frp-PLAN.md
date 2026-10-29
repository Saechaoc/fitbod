---
phase: quick-260610-frp
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - fitbod/Periodization/BlockBuilderView.swift
autonomous: false
requirements: [BUGFIX-PROGRESSION-CHART-AUTO-SELECT]

must_haves:
  truths:
    - "Progression Overview chart opens with NO selection — no selected-point ring, no callout pill"
    - "Selection ring + callout pill appear only after the user taps or scrubs a point"
    - "Tap-away (deselect back to nil) still works"
    - "Callout pill stays clamped inside plot bounds when shown (no regression of the clamp commit)"
    - "All three New Block guardrail suites + the progression chart suite stay GREEN"
  artifacts:
    - path: "fitbod/Periodization/BlockBuilderView.swift"
      provides: "NewBlockProgressionChart with nil-default selection at rest"
      contains: "chartXSelection"
  key_links:
    - from: "NewBlockProgressionChart.selectedWeek (@State, Optional)"
      to: "ring PointMark + callout pill + RuleMark + accessibility label"
      via: "Optional binding starts nil and stays nil until user interaction"
      pattern: "selectedWeek"
---

<objective>
Fix the Progression Overview chart in the New Block screen auto-showing a Week 1 selection (selected-point ring + "WK 1 — INT 75% — VOL Hold" callout pill) the moment the screen opens.

The chart should open with no selection (no ring, no pill). Selection chrome should appear only after the user taps/scrubs, matching the standard Swift Charts `chartXSelection` pattern (selection is `Optional`, starts `nil`).

Purpose: The auto-selection is a visual bug — it implies the user has already interacted with the chart and clutters the at-rest view.
Output: `NewBlockProgressionChart` opens clean; selection chrome is fully gated behind user interaction.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

<root_cause>
File: fitbod/Periodization/BlockBuilderView.swift — `fileprivate struct NewBlockProgressionChart` (starts line ~900).

`@State private var selectedWeek: Int? = nil` is correctly declared as nil (line ~904). The bug comes from FOUR places that force or fall back to week 1 at rest:

1. PRIMARY CAUSE — `.onAppear` block (lines ~1286-1290). It does, in effect: when `selectedWeek == nil` and `!phases.isEmpty`, assign `selectedWeek = 1`. This sets the selection to week 1 every time the chart appears. Removing this block stops the callout pill (line ~1246, correctly guarded `if let sel = selectedWeek`) and the RuleMark (line ~1162, correctly guarded `if let sel = selectedWeek`) from auto-appearing.

2. RING FALLBACK — line ~1147: the hollow selection-ring PointMark is gated on `pt.week == (selectedWeek ?? 1)`, so it renders around week 1 even when `selectedWeek` is nil. Must only render when a selection exists.

3. ACCESSIBILITY FALLBACK — line ~1207: the accessibilityLabel ends with the interpolation `Selected week \(selectedWeek ?? 1).`, announcing "Selected week 1" at rest. Should announce no selection.

4. STALE COMMENT — line ~903-904: the comment "Selected week for scrub / callout pill. Defaults to week 1 on appear." is now incorrect.

ALREADY CORRECT — do NOT touch these (they already guard on Optional, and removing the `.onAppear` makes them behave right):
- RuleMark `if let sel = selectedWeek` (line ~1162)
- Callout pill `if let sel = selectedWeek, let xPos = ...` (line ~1246) — including ALL the clamp / `calloutWidth` / `halfPill` / `clampedX` logic from the recent "clamp progression callout pill inside plot bounds" commit. DO NOT modify the clamp math.
- Axis-label emphasis `week == (selectedWeek ?? -1)` (lines ~1176, ~1180) — `?? -1` already means "no week highlighted" when nil.
- `.chartXSelection(value: $selectedWeek)` (line ~1200) and `.sensoryFeedback(.selection, trigger: selectedWeek)` (line ~1201) — the deselect (tap-away to nil) path flows through `chartXSelection`; leave intact.
</root_cause>

<guardrail_tests>
ANY edit to the New Block screen MUST keep ALL of these GREEN. The plan's verify step runs all four:
- fitbodTests/NewBlockBuilderFidelityTests.swift (source-introspection fidelity — NOTE: has uncommitted local edits adding drag/swipe assertions; unrelated to this fix but must still pass)
- fitbodTests/BlockBuilderViewCopyTests.swift (verbatim copy guardrail)
- fitbodTests/BlockBuilderViewActivationTests.swift (activation guardrail)
- fitbodTests/NewBlockProgressionChartTests.swift (progression chart structure: asserts presence of `RuleMark(`, `chartXSelection`, `sensoryFeedback`, `AreaMark(`, "PROGRESSION OVERVIEW", "Volume", "Intensity", struct name)

Pre-checked during planning: none of these suites assert the week-1-default behavior, and none assert a verbatim source token that this fix removes. The accessibility string and the `.onAppear` block are NOT asserted by any suite. Every token the tests DO require (`RuleMark(`, `chartXSelection`, `sensoryFeedback`, `AreaMark(`, the copy strings, the struct name) is preserved by this fix.
</guardrail_tests>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Gate selection chrome behind user interaction (nil at rest)</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
In `fileprivate struct NewBlockProgressionChart`, make the chart open with NO selection by removing the week-1 force and tightening the two nil-fallbacks that still render week-1 chrome at rest. Make exactly these four edits and nothing else in the struct — in particular do NOT touch the callout-pill clamp math (calloutWidth / halfPill / clampedX) or the chartXSelection / sensoryFeedback modifiers:

1. DELETE the entire `.onAppear { ... }` modifier (lines ~1286-1290) whose body force-assigns selectedWeek to 1 when nil and phases is non-empty. Remove the whole `.onAppear { }`, not just its body. This is the primary fix.

2. RING (line ~1147): the ring PointMark is currently gated on `if pt.week == (selectedWeek ?? 1) {`. Re-gate it on an actual selection so no ring shows when nil — bind the optional first, then compare, e.g. `if let sel = selectedWeek, pt.week == sel {`. The PointMark ring body inside stays unchanged.

3. ACCESSIBILITY (line ~1207): the label currently ends with the interpolation `Selected week \(selectedWeek ?? 1).`. Change ONLY that trailing interpolation so it reads "No week selected." at rest and "Selected week N." once a week is chosen — e.g. end the string with `\(selectedWeek.map { "Selected week \($0)." } ?? "No week selected.")`. Keep the rest of the accessibilityLabel (the "Progression overview, N weeks, M phases. Volume and intensity by week. " prefix) byte-identical.

4. COMMENT (line ~903-904): update the stale comment "Defaults to week 1 on appear." to reflect the new behavior — note that selectedWeek starts nil and selection chrome (ring, RuleMark, callout pill) appears only after the user taps or scrubs.

Leave fully intact: the RuleMark `if let sel = selectedWeek` block, the callout-pill `if let sel = selectedWeek, let xPos = ...` block AND all its clamp logic, the axis-label `?? -1` emphasis, `.chartXSelection(value: $selectedWeek)`, and `.sensoryFeedback(.selection, trigger: selectedWeek)`. The deselect (tap-away) path is handled by chartXSelection and needs no change.
  </action>
  <verify>
    <automated>bash .planning/quick/260610-frp-fix-progression-overview-chart-auto-show/verify-gated.sh</automated>
  </verify>
  <done>The verify script prints GATED-OK: no `selectedWeek ?? 1` fallback and no `selectedWeek = 1` assignment remain, the `.onAppear` force-select block is gone, and the ring + accessibility label now derive from an actual selection. The callout-pill clamp logic and chartXSelection/sensoryFeedback are untouched.</done>
</task>

<task type="auto">
  <name>Task 2: Build + run all four New Block guardrail suites</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
Compile the change and run all four guardrail suites (three New Block suites + the progression chart suite) to prove nothing regressed.

Use the provided helper script, which builds for the iOS simulator and filters xcodebuild output (pipes through rg + tail) to keep context small. The script defaults the destination to "iPhone 16 Pro"; if no such simulator exists, run `xcrun simctl list devices available` to pick an available iOS 26.x device and pass its name as the first argument to the script.

The script runs, by class filter: NewBlockBuilderFidelityTests, BlockBuilderViewCopyTests, BlockBuilderViewActivationTests, NewBlockProgressionChartTests. ALL FOUR MUST PASS. Per the project guardrail, a New Block edit that runs fewer than all three New Block suites is incomplete — run every suite the script lists, not a subset. If a SourceKit phantom diagnostic appears (a known false positive on this codebase per project memory), trust the xcodebuild result, not the editor.
  </action>
  <verify>
    <automated>bash .planning/quick/260610-frp-fix-progression-overview-chart-auto-show/verify-guardrails.sh</automated>
  </verify>
  <done>xcodebuild reports all four suites passed (filtered output shows passing test suites and "** TEST SUCCEEDED **"), and the script exits 0. No new compile errors. The fix is build-clean and guardrail-clean.</done>
</task>

</tasks>

<verification>
- `verify-gated.sh` prints GATED-OK (no week-1 force or fallback remains in the source).
- `verify-guardrails.sh` exits 0 with all four guardrail suites GREEN.
- Manual smoke (optional, in simulator): open Routines → New Block. The Progression Overview chart shows no selected-point ring and no callout pill at rest. Tap a week → ring + pill appear, pill stays inside the plot for edge weeks (W1 and last week). Tap away → ring + pill disappear.
</verification>

<success_criteria>
- The Progression Overview chart opens with no selection chrome (no ring, no callout pill, no RuleMark, accessibility announces "No week selected.").
- Tapping/scrubbing a week shows the ring + pill; tapping away clears them.
- The callout-pill clamp behavior from the prior commit is unchanged (no clipping at edge weeks).
- All three New Block guardrail suites and the progression chart suite are GREEN.
- Exactly one file changed: fitbod/Periodization/BlockBuilderView.swift.
</success_criteria>

<output>
Create `.planning/quick/260610-frp-fix-progression-overview-chart-auto-show/260610-frp-SUMMARY.md` when done.
</output>
