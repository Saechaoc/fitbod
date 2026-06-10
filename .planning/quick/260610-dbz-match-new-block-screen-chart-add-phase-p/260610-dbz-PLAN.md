---
phase: quick-260610-dbz
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - fitbod/Periodization/BlockBuilderView.swift
autonomous: true
requirements: [QUICK-260610-DBZ]
must_haves:
  truths:
    - "Progression chart renders Intensity as a solid ink line WITH dots and Volume as a dashed muted line with no dots (swapped from current)."
    - "Phase abbreviation labels above the chart are title-case (Accum./Intens./Peak/Deload) and each is tinted with its phase color, not muted gray."
    - "Chart x-axis labels every week W1..WN when totalWeeks <= 8 (strides up for longer), has no tick marks; the y-axis is hidden."
    - "ADD PHASE control is a white card-token capsule with a hairline border and soft shadow, a coral plus glyph, and ink ADD PHASE text."
    - "Phase cards are separated by 10pt of paper (was 6pt) and each row shows vertical hairline dividers between the title block and the WEEKS / VOL / INT stat columns."
    - "All three New Block guardrail suites stay green and the TOTAL WEEKS / DAYS PER WEEK band is visually unchanged."
  artifacts:
    - path: "fitbod/Periodization/BlockBuilderView.swift"
      provides: "Restyled NewBlockProgressionChart, NewBlockPhasesHeader, NewBlockPhaseEditorRow, NewBlockReadOnlyStatColumn, and NewBlockPhaseText.abbreviation"
      contains: "NewBlockProgressionChart"
  key_links:
    - from: "NewBlockProgressionChart phase labels"
      to: "BlockPhaseColors.badgeColor(for:)"
      via: "foregroundStyle on the per-phase abbreviation Text"
      pattern: "BlockPhaseColors\\.badgeColor"
    - from: "NewBlockPhasesHeader ADD PHASE button"
      to: "accessibilityLabel literal"
      via: "accessibilityLabel preserving the quoted ADD PHASE substring"
      pattern: "accessibilityLabel"
---

<objective>
Match the New Block screen (`BlockBuilderView.swift`) to `bru-screens/New-block/final-design.png`. Locked visual changes, all inside ONE production file:

1. Restyle the progression chart: swap Intensity/Volume line styles, title-case + color the phase labels, label every week, hide the y-axis, bump band opacity.
2. Restyle the ADD PHASE pill: coral-outline to white card capsule with two-tone "+ ADD PHASE" text.
3. Widen phase-card gap 6pt to 10pt.
4. Add in-row vertical hairline dividers between the title block and the WEEKS/VOL/INT stat columns; center the stat columns.

Purpose: Bring the shipped build into pixel agreement with the final mockup. The 260528-vi2 r3 pass overshot on density (6pt gap) and the chart/pill styling diverged from the mockup.
Output: A single restyled `BlockBuilderView.swift` with all three guardrail suites green.

Scope guardrails (do NOT touch):
- `NewBlockMetricsBand` (TOTAL WEEKS / DAYS PER WEEK) — leave entirely unchanged.
- `BlockPhaseColors.swift` — read only; do not edit. (And do not edit any file other than `BlockBuilderView.swift`.)
- Phase badge colors, subtitle copy (`BUILD VOLUME` / `BUILD STRENGTH` / `SHARPEN OUTPUT` / `RECOVER`), fonts.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md

DO NOT read `CLAUDE.md` — it is very large and exhausts the context window. This plan
already encodes everything you need. Likewise do NOT re-read `STATE.md` or unrelated files.

When you build with xcodebuild, the full output floods the context window. ALWAYS pipe it
through `tail` or `grep` (see verify steps). Never run a bare unfiltered xcodebuild.

If `iPhone 16 Pro` is not an available simulator, list destinations with
`xcodebuild -scheme fitbod -showdestinations` (grep for `platform:iOS Simulator`) and
substitute an available iPhone simulator name in every command.
</execution_context>

<context>
The ONLY production file to edit is `fitbod/Periodization/BlockBuilderView.swift`. All target
views are `fileprivate` structs inside it.

Reference mockup (open with your image reader if you need it): `bru-screens/New-block/final-design.png`

<interfaces>
<!-- Already-existing API on BlockPhaseColors.swift (DO NOT edit that file; just call these). -->
From fitbod/Periodization/BlockPhaseColors.swift:
```swift
public static func badgeColor(for kind: BlockPhaseKind) -> Color      // pastel phase fill — use for chart bands + phase labels
public static func badgeLabelColor(for kind: BlockPhaseKind) -> Color // contrasting label color for badgeColor
public static func phaseLabel(_ kind: BlockPhaseKind) -> String
```

Design tokens already defined inside BlockBuilderView.swift (`NewBlockScreenTokens`):
```swift
static let paper, ink, muted, hair, faint, signal: Color
static let card        = #FCFBF8 warm white   // white-card capsule fill for the ADD PHASE pill
static let cardStroke  = #E1DED6 faint border  // hairline border
static let cardShadow  = Color.black.opacity(0.06)
static let cardStrokeWidth: CGFloat = 0.75
static let chipTracking: CGFloat = 2.1
```
The `bruCard()` private View modifier (card fill + cardStroke border + cardShadow) is defined in this file
but is tuned for large/medium rounded cards. For the ADD PHASE pill you need a *capsule* shape, so build the
capsule fill/stroke/shadow inline rather than reusing `bruCard()`.

`BlockPhaseKind` has cases: `.accumulation`, `.intensification`, `.realization` (displayed as "Peak"), `.deload`.
</interfaces>

<current_state>
<!-- Exact references in BlockBuilderView.swift as it exists now (read this; do not re-read the file). -->
- Chart phase-label color: `NewBlockProgressionChart` GeometryReader block, per-phase `Text(...)` uses
  `.foregroundStyle(NewBlockScreenTokens.muted)` and wraps `ForEach(phases, id: \.draftID)`.
- Chart series (INVERTED vs mockup): Volume currently = ink solid `lineWidth: 2` + PointMark `symbolSize(24)`;
  Intensity currently = muted dashed `lineWidth: 1.5, dash: [4, 3]` with no points. These must SWAP.
- Legend (top-right HStack): currently LEFT = ink Rectangle(16x2) + ink Circle(5x5) + "Volume" (ink);
  RIGHT = three muted dash Rectangles + "Intensity" (muted). These must SWAP per the mockup.
- X-axis: `AxisMarks(values: cumulativeBoundaries)` with an `AxisTick(...)`.
- Y-axis: `.chartYAxis { AxisMarks(position: .trailing ...) { AxisGridLine ... } }`.
- Band opacity: `BlockPhaseColors.badgeColor(for: band.kind).opacity(0.12)`.
- `NewBlockPhaseText.abbreviation(for:)` returns uppercase "ACCUM"/"INTEN"/"PEAK"/"DELOAD".
- `NewBlockPhasesHeader` ADD PHASE button: single coral `Text("+ ADD PHASE")` + coral Capsule stroke (lineWidth 1.5).
- Phase-cards inner VStack: `VStack(alignment: .leading, spacing: 6)` (comment "260528-vi2 r3: tighter card to card gap (6pt)").
- `NewBlockPhaseEditorRow` stat grid: `HStack(alignment: .top, spacing: 12)` with three `NewBlockReadOnlyStatColumn`s, then a chevron.
- `NewBlockReadOnlyStatColumn`: `VStack(alignment: .leading, spacing: 2)` ... `.frame(width: 40, alignment: .leading)`.
</current_state>

<test_guardrails>
Three suites MUST stay green. They are source-introspection / draft tests:

1. `NewBlockBuilderFidelityTests` — asserts `BlockBuilderView.swift` source contains struct names
   (`NewBlockProgressionChart`, `NewBlockPhasesHeader`, `NewBlockPhaseEditorRow`, ...) and copy substrings
   including `"+ ADD PHASE"`, `"PROGRESSION OVERVIEW"`, `"PHASES ·"`, `"BUILD VOLUME"`, `"BUILD STRENGTH"`,
   `"Accumulation"`, `"Intensification"`, `"Deload"`, `"RECOVER"`, and the literal `ForEach(phases, id: \.draftID)`.
2. `BlockBuilderViewCopyTests` — asserts QUOTED literals in `BlockBuilderView.swift`:
   `"+ ADD PHASE"`, `"PHASES · \(phaseCount)"`, `"PROGRESSION OVERVIEW"`, etc. (The `"WEEKS"`/`"VOL"`/`"INT"`
   assertions in this suite target a SEPARATE file `BlockPhaseEditorRow.swift` — you are NOT editing that file,
   so they are unaffected.)
3. `BlockBuilderViewActivationTests` (`.serialized`) — draft-behavior tests (Days Per Week clamp, save persists
   inactive). Your visual changes must not break draft behavior. RUN IT — project memory: an executor once ran
   only 1 of the 3 suites and left a sibling red.

HARD CONSTRAINTS that protect these tests:
- Keep the literal `ForEach(phases, id: \.draftID)` in the chart's phase-label block.
- Keep a literal `"+ ADD PHASE"` quoted string somewhere in source. Because the visible button becomes two-tone
  (`Text("+ ") + Text("ADD PHASE")`), add `.accessibilityLabel("+ ADD PHASE")` on the Button so the quoted
  substring still exists in source.
- Keep `Text("PHASES · \(phaseCount)")` exactly (the copy test matches `"PHASES · \(phaseCount)"`).
- Keep `Text("Accumulation")` / `"Intensification"` / `"Deload"` etc. — those live in `NewBlockPhaseText.title`
  and `.subtitle`, which you are NOT editing. Only `NewBlockPhaseText.abbreviation` changes.
- Do NOT rename any `fileprivate struct`.
</test_guardrails>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Restyle the progression chart (NewBlockProgressionChart + NewBlockPhaseText.abbreviation)</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
Apply six chart changes inside `fileprivate struct NewBlockProgressionChart` (and one in `NewBlockPhaseText`). Do not touch any view outside the chart.

(a) Title-case + color the phase abbreviation labels. In `NewBlockPhaseText.abbreviation(for:)`, change the
returned strings from uppercase to title-case with trailing dots where shown in the mockup:
`.accumulation` to "Accum.", `.intensification` to "Intens.", `.realization` to "Peak", `.deload` to "Deload".
Then in the chart's phase-label `GeometryReader` block, change the per-phase `Text(...)` `.foregroundStyle`
from `NewBlockScreenTokens.muted` to `BlockPhaseColors.badgeColor(for: phase.kind)`. KEEP the surrounding
`ForEach(phases, id: \.draftID)` literal exactly (a fidelity test asserts it).

(b) SWAP the two series' line styles so they match the mockup (mockup: Intensity is the bold solid line with
dots; Volume is the faint dashed line). The current code has this inverted. After the change:
  - The `points.filter { $0.series == "Intensity" }` ForEach renders a `LineMark` with
    `foregroundStyle(NewBlockScreenTokens.ink)` + `lineStyle(StrokeStyle(lineWidth: 2))`, PLUS a `PointMark`
    with `foregroundStyle(NewBlockScreenTokens.ink)` and `symbolSize(40)`.
  - The `points.filter { $0.series == "Volume" }` ForEach renders ONLY a `LineMark` with
    `foregroundStyle(NewBlockScreenTokens.muted)` + `lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))`,
    and NO PointMark.
Keep both `LineMark`s carrying their existing `series: .value("Series", pt.series)` argument so the lines
connect per-series.

(c) Restyle the hand-rolled legend row (the `HStack` in the top section, currently left=ink line+dot "Volume",
right=muted dashes "Intensity") to mirror the mockup: LEFT item = a small faint square swatch
(an 8x8 `RoundedRectangle(cornerRadius: 2)` filled with `NewBlockScreenTokens.hair`) + `Text("Volume")`
in `NewBlockScreenTokens.muted`; RIGHT item = an ink line-dot-line glyph (Rectangle 8x2 ink, Circle 5x5 ink,
Rectangle 8x2 ink, all `NewBlockScreenTokens.ink`) + `Text("Intensity")` in `NewBlockScreenTokens.ink`. Keep
the `Text("Volume")` / `Text("Intensity")` font at `NewBlockType.micro`.

(d) X-axis: label every week W1..WN evenly when `totalWeeks <= 8`; for longer blocks stride up with
`step = Int(ceil(Double(totalWeeks) / 8.0))`. Add a small computed `[Int]` property (e.g. `weekAxisValues`)
that guards `totalWeeks >= 1` and returns `Array(stride(from: 1, through: totalWeeks, by: max(1, step)))`.
Replace `AxisMarks(values: cumulativeBoundaries)` with `AxisMarks(values: weekAxisValues)`. DROP the
`AxisTick(...)` call entirely (mockup has labels only). Keep the `AxisValueLabel { Text("W\(week)") ... }`
rendering in `NewBlockType.micro` / `NewBlockScreenTokens.muted`.

(e) Y-axis: replace the entire `.chartYAxis { AxisMarks(...) { AxisGridLine ... } }` block with
`.chartYAxis(.hidden)` so the mockup's gridline-free chart is reproduced.

(f) Phase background bands: bump the band opacity in the `RectangleMark.foregroundStyle(...)` from
`.opacity(0.12)` to `.opacity(0.18)` for more distinct pastel columns. Keep the
`BlockPhaseColors.badgeColor(for: band.kind)` base.

Do NOT change `PROGRESSION OVERVIEW`, the empty-state copy, the `previewHeight` frame, or the `bruCard()` wrap.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod; xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -40</automated>
  </verify>
  <done>
Build succeeds (last lines show BUILD SUCCEEDED, no errors). `NewBlockPhaseText.abbreviation` returns
title-case strings; chart phase labels use `BlockPhaseColors.badgeColor(for: phase.kind)`; Intensity series is
solid ink line + PointMark(symbolSize 40); Volume series is dashed muted line with no points; legend left=faint
square "Volume", right=ink line-dot-line "Intensity"; x-axis labels every week (stride up >8 weeks) with no
AxisTick; `.chartYAxis(.hidden)` present; band opacity is 0.18. `ForEach(phases, id: \.draftID)` literal still present.
  </done>
</task>

<task type="auto">
  <name>Task 2: Restyle ADD PHASE pill, widen phase-card gap, add in-row dividers + center stat columns</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
Four changes across `NewBlockPhasesHeader`, the phase-card `VStack` in `BlockBuilderView.body`,
`NewBlockPhaseEditorRow`, and `NewBlockReadOnlyStatColumn`.

(a) ADD PHASE pill — in `fileprivate struct NewBlockPhasesHeader`, restyle the `Button(action: onAddPhase)`
to a white card capsule with two-tone label (mockup: white capsule, hairline border, soft shadow; coral "+",
ink "ADD PHASE"). Replace the current single coral `Text("+ ADD PHASE")` + coral capsule outline with:
  - Label = a concatenated two-tone Text built from
    `Text("+ ").foregroundStyle(NewBlockScreenTokens.signal)` + `Text("ADD PHASE").foregroundStyle(NewBlockScreenTokens.ink)`,
    rendered in `NewBlockType.chrome` with `.tracking(NewBlockScreenTokens.chipTracking)` (apply `.font`/`.tracking`
    to the combined result; per-`Text` if the compiler requires). Rendered glyph = coral "+", ink "ADD PHASE".
  - Padding: `.padding(.horizontal, 12)` + `.padding(.vertical, 7)`.
  - Background: `.background(NewBlockScreenTokens.card, in: Capsule())`.
  - Border: `.overlay(Capsule().stroke(NewBlockScreenTokens.cardStroke, lineWidth: NewBlockScreenTokens.cardStrokeWidth))`.
  - Shadow: `.shadow(color: NewBlockScreenTokens.cardShadow, radius: 6, x: 0, y: 2)`.
  - Keep `.frame(minHeight: 44)` for the tap target.
  - Add `.accessibilityLabel("+ ADD PHASE")` on the Button so the QUOTED literal `"+ ADD PHASE"` still exists in
    source (BlockBuilderViewCopyTests + fidelity test both assert this substring). This is REQUIRED — without it
    the copy test goes red because the visible label is now split across two `Text` calls.
Leave the `Text("PHASES · \(phaseCount)")` line and the `Spacer()` exactly as-is.

(b) Phase-card gap — in `BlockBuilderView.body`, find the inner phase-cards VStack (currently
`VStack(alignment: .leading, spacing: 6) { ForEach(Array(draft.phases.enumerated()) ...) }`, the one with the
"260528-vi2 r3: tighter card to card gap (6pt)" comment) and change `spacing: 6` to `spacing: 10`. Update that
inline comment to note the 10pt paper-separation match. Do NOT change the OUTER `VStack(... spacing: 10)` that
wraps the header + cards (it is already 10).

(c) In-row cell dividers + centered stat columns — in `fileprivate struct NewBlockPhaseEditorRow`, the inner
`HStack(alignment: .top, spacing: 12)` currently holds three `NewBlockReadOnlyStatColumn`s (WEEKS / VOL / INT).
Insert 1pt-wide, ~34pt-tall hairline vertical dividers so the row reads: title block (existing), Spacer, divider,
WEEKS, divider, VOL, divider, INT, chevron. Concretely:
  - Define a tiny divider builder (a local computed property returning some View, or a small fileprivate helper
    view) that returns `Rectangle().fill(NewBlockScreenTokens.hair).frame(width: 1, height: 34)`.
  - Place a divider BEFORE the WEEKS column, BEFORE the VOL column, and BEFORE the INT column. Do NOT place a
    divider before the chevron (mockup has no divider there). Keep the existing `Spacer(minLength: 10)` that sits
    between the title block and the stat grid so the dividers hug the stat columns, not the title.
  - Keep the chevron (`Image(systemName: "chevron.right")`) after the INT column, unchanged.
You may keep the stat columns + dividers inside the existing `HStack(alignment: .top, spacing: 12)`; reduce its
spacing if 12pt looks too loose with dividers added — `spacing: 8` is acceptable. Use your judgment to match the
mockup's even column rhythm.

(d) Stat-column alignment — in `fileprivate struct NewBlockReadOnlyStatColumn`, change the
`VStack(alignment: .leading ...)` to `VStack(alignment: .center ...)`, center the inner `Text(label)` and
`Text(value)` as needed, and change the outer `.frame(width: 40, alignment: .leading)` to
`.frame(width: 38, alignment: .center)` (narrower by 2pt to compensate for the added divider widths so the
"Intensification" title is not over-shrunk). Do NOT change the label/value copy, fonts, or tracking.

Do NOT touch `NewBlockMetricsBand`, the colored left rail Rectangle, the badge, the title/subtitle block copy,
or `BlockPhaseColors.swift`.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod; xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -40; echo "=== GUARDRAIL SUITES ==="; xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:fitbodTests/NewBlockBuilderFidelityTests -only-testing:fitbodTests/BlockBuilderViewCopyTests -only-testing:fitbodTests/BlockBuilderViewActivationTests 2>&1 | grep -E "Test Suite|passed|failed|error:|BUILD|TEST" | tail -40</automated>
  </verify>
  <done>
Build succeeds and ALL THREE guardrail suites report passed with 0 failures (the grep output shows
NewBlockBuilderFidelityTests passed, BlockBuilderViewCopyTests passed, and BlockBuilderViewActivationTests
passed, ending with TEST SUCCEEDED). ADD PHASE button uses `NewBlockScreenTokens.card` capsule fill +
`cardStroke` border + `cardShadow`, two-tone `Text("+ ")` (signal) + `Text("ADD PHASE")` (ink), and
`.accessibilityLabel("+ ADD PHASE")`. Phase-cards inner VStack `spacing: 10`. Each phase row has three
1pt x 34pt hair dividers before WEEKS / VOL / INT, none before the chevron. `NewBlockReadOnlyStatColumn` is
center-aligned at width 38. `NewBlockMetricsBand` is byte-for-byte unchanged.
  </done>
</task>

</tasks>

<verification>
After both tasks, the executor's final state must satisfy:

- `xcodebuild build` succeeds with no errors or new warnings introduced by these edits.
- All three guardrail suites pass:
  - `NewBlockBuilderFidelityTests` (struct names + copy substrings + `ForEach(phases, id: \.draftID)`)
  - `BlockBuilderViewCopyTests` (quoted literals incl. `"+ ADD PHASE"` and `"PHASES · \(phaseCount)"`)
  - `BlockBuilderViewActivationTests` (draft behavior — `.serialized`)
- Only `fitbod/Periodization/BlockBuilderView.swift` is modified (`git status` shows no other changed source file).
- `NewBlockMetricsBand` (TOTAL WEEKS / DAYS PER WEEK) is unchanged.

Optional fidelity self-check (do NOT block on it; it requires a device/simulator render): compare the New Block
screen against `bru-screens/New-block/final-design.png` for the chart series swap, title-case colored phase
labels, white ADD PHASE capsule, 10pt phase-card gaps, and in-row dividers.
</verification>

<success_criteria>
- [ ] Chart: Intensity = solid ink line + dots (symbolSize 40); Volume = dashed muted line, no dots.
- [ ] Chart: phase labels title-case (Accum./Intens./Peak/Deload), each colored via `BlockPhaseColors.badgeColor(for:)`.
- [ ] Chart: legend left = faint square swatch "Volume" (muted); right = ink line-dot-line "Intensity" (ink).
- [ ] Chart: x-axis labels every week (stride up when totalWeeks > 8), no AxisTick; y-axis hidden; band opacity 0.18.
- [ ] ADD PHASE: white card capsule + hairline border + soft shadow; coral "+", ink "ADD PHASE"; `.accessibilityLabel("+ ADD PHASE")` present.
- [ ] Phase-card gap is 10pt (was 6pt); in-row hairline dividers separate title | WEEKS | VOL | INT; stat columns centered at width 38.
- [ ] `NewBlockMetricsBand` untouched; `BlockPhaseColors.swift` untouched; no other file edited.
- [ ] `xcodebuild build` succeeds; all three guardrail suites green.
</success_criteria>

<output>
Create `.planning/quick/260610-dbz-match-new-block-screen-chart-add-phase-p/260610-dbz-SUMMARY.md` when done.
</output>
