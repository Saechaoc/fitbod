---
quick_id: 260528-utc
type: execute
title: Restyle New Block editor (BlockBuilderView) to match final-design.png
files_modified:
  - fitbod/Design/Color+BRU.swift
  - fitbod/Assets.xcassets/bruBlue.colorset/Contents.json
  - fitbod/Periodization/BlockPhaseColors.swift
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbodTests/NewBlockBuilderFidelityTests.swift
autonomous: true
---

<objective>
Restyle the New Block editor screen (`fitbod/Periodization/BlockBuilderView.swift`) to match
`bru-screens/New-block/final-design.png`. This is a UI restyle of a working screen — NOT a rewrite.
All existing behavior is preserved: save/discard, drag-reorder via `.onMove` gated by the REORDER
toggle, swipe-delete + 4s undo toast, preset menu, add-phase type picker, and the duration/days
editor sheets.

Five visual changes, locked by the user:
- **A** — Metrics band becomes two bordered BRU cards (icon + label + BebasNeue number), still tappable.
- **B** — Timeline preview is REPLACED by a Swift Charts progression line chart (Volume solid, Intensity dashed).
- **C** — Phase rows lose the inline −/+ steppers; right side becomes three read-only value columns; whole row taps open a new per-phase editor sheet.
- **D** — Phases header gets a coral "+ ADD PHASE"; the dashed bottom add slot is removed.
- **E** — Add `bruBlue` token + `BlockPhaseColors.badgeColor`/`badgeLabelColor`; phase badges use semantic colors.
- **F** — Copy: `.realization` title "Realization" → "Peak", subtitle "PEAK" → "SHARPEN OUTPUT".

Purpose: bring the committed screen up to the locked final design.
Output: restyled screen, additive color API, one updated guardrail test.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@bru-screens/New-block/final-design.png

# The single file holding ALL the UI being restyled. Every struct touched is fileprivate
# (file-local) — blast radius of editing them is THIS FILE ONLY.
@fitbod/Periodization/BlockBuilderView.swift

# Color tokens (bruBlue added here) + the asset-colorset pattern to mirror.
@fitbod/Design/Color+BRU.swift

# Public phase-color API (badgeColor/badgeLabelColor added here; existing funcs untouched).
@fitbod/Periodization/BlockPhaseColors.swift

# Draft model APIs (read-only reference — DO NOT modify these models).
@fitbod/Periodization/BlockDraft.swift
@fitbod/Periodization/BlockPhaseDraft.swift

# The ONE guardrail test that asserts struct names + copy in BlockBuilderView. Task 4 updates it.
@fitbodTests/NewBlockBuilderFidelityTests.swift

<verified_facts>
Embedded so the executor does NOT re-discover them:

- **All UI structs are `fileprivate` inside `BlockBuilderView.swift`.** Plus two design-token enums
  (`NewBlockScreenTokens`, `NewBlockType`) and `NewBlockPhaseText`. Editing any of them touches only this file.

- **`NewBlockStepperButton` MUST STAY** — it is used by `NewBlockDurationSheet` (lines ~1475, ~1482).
  Do NOT delete it even after removing the inline phase-row steppers.

- **`NewBlockInlineMetricColumn` (lines ~1108–1141)** is used ONLY by the phase row. Safe to DELETE in Task 3.

- **`NewBlockTimelinePreview` + `NewBlockTimelineSegment` + `NewBlockDeloadStripes`** (lines ~853–981)
  are used ONLY by the body's preview row. After Task 2 removes the preview, all three are orphaned and
  safe to DELETE. (`NewBlockDeloadStripes` already has zero references.)

- **`NewBlockAddPhaseSlot` (lines ~1201–1226)** is referenced only at the body call site (line ~138).
  Removing the body call site orphans it → DELETE the struct in Task 4.

- **Palette helpers** `NewBlockScreenTokens.paletteSlots` / `paletteColor(forOrderIndex:isDeload:)` /
  `paletteLabelColor(forOrderIndex:isDeload:)` are used in THREE places: the phase-row badge (~996),
  the timeline segment (~940 — removed in Task 2), and the add-phase-type sheet swatch (~1252).
  After Task 1 (badge → `BlockPhaseColors.badgeColor`), Task 2 (timeline removed), and Task 1 also swaps
  the add-phase swatch → all three call sites are gone and the palette helpers are orphaned. DELETE them in
  Task 1 once `grep -c paletteColor` over the file (excluding the definitions) confirms zero remaining uses.

- **Model APIs (all `@MainActor @Observable`, DO NOT modify):**
  - `BlockDraft`: `name:String`, `daysPerWeek:Int`, `phases:[BlockPhaseDraft]`, computed `totalWeeks:Int`, `isValid:Bool`.
  - `BlockPhaseDraft`: `let draftID:UUID` (stable identity), `id:UUID? = nil` (persistent, nil until saved —
    NEVER use as sheet/ForEach identity), `kind:BlockPhaseKind`, `weeks:Int`, `volumeMultiplier:Double`,
    `intensityMultiplier:Double`. Setting `kind` auto-resets multipliers via `didSet`.
  - `BlockPhaseKind` cases: `.accumulation`, `.intensification`, `.realization`, `.deload` (CaseIterable).
  - `NewBlockPhaseText` (fileprivate enum in the file): `title(for:)`, `subtitle(for:)`, `abbreviation(for:)`,
    `volumeValue(_:)` → signed % vs base ("Hold" when ==1.0), `intensityValue(_:)` → "NN%".

- **Clamp/step rules** (lift verbatim from the OLD `NewBlockInlineMetricColumn` call site in the phase row
  before deleting it): weeks `max(1, ...)` / `min(52, ...)`; volume step 0.05 clamp `max(0.4)` / `min(1.6)`
  then `(v*100).rounded()/100`; intensity step 0.05 clamp `max(0.5)` / `min(1.0)` then `(v*100).rounded()/100`.

- **Existing BRU-styled editor sheets to MIRROR for styling:** `NewBlockDurationSheet`, `NewBlockDaysSheet`
  (NavigationStack, `.presentationDetents([.medium])`, `NewBlockInkRule` separators, a plain "Done" button
  that calls `dismiss()`).

- **`bruSignal` colorset** exists at `fitbod/Assets.xcassets/bruSignal.colorset/Contents.json` and uses
  srgb `components` with light + a `luminosity: dark` appearance. Mirror this shape for `bruBlue`.

- **Tests that DO reference this screen / these strings:**
  - `fitbodTests/NewBlockBuilderFidelityTests.swift` — asserts struct names (incl. `"NewBlockTimelinePreview"`)
    and copy (incl. `"PREVIEW"`). Task 4 updates these. It does NOT assert `"Realization"` or `"PEAK"`, so the
    Task 2 copy change is safe against it.
  - `fitbodTests/BlockBuilderViewCopyTests.swift` — asserts `"+ ADD PHASE"` only. Still present after Task 4
    (it moves to the header), so this test stays green. Do NOT edit it.
  - `fitbodTests/Phase6/WeeklyTonnageViewCopyTests.swift` line 53 asserts `"Realization"` — but it reads
    `WeekDetailView.swift`, a DIFFERENT file. The Task 2 copy change to `NewBlockPhaseText` does NOT affect it.
    Do NOT touch `WeekDetailView.swift`.
</verified_facts>

<build_verify>
Discover scheme + simulator once, then reuse:
- `xcodebuild -list -project fitbod.xcodeproj` → scheme is `fitbod`.
- `xcrun simctl list devices available | grep iPhone` → pick any available iPhone (e.g. "iPhone 16").
- Build (filter to tail — full output is huge, per project memory):
  `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=<iPhone>' build 2>&1 | tail -40`
- For the test-touching task, also run the one suite:
  `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:fitbodTests/NewBlockBuilderFidelityTests 2>&1 | tail -40`

Swift 6 strict concurrency: all these views/sheets are view code on `@MainActor` (drafts are `@MainActor`);
Charts code is plain view code — no concurrency concerns. Add NO new bare color/font literals EXCEPT the
single `bruBlue` token — reuse `NewBlockScreenTokens` / `NewBlockType` / `bru*` everywhere else.

If SourceKit shows phantom "cannot find type" / "no such module" errors after edits, trust `xcodebuild`,
not the editor (project memory: stale SourceKit diagnostics).
</build_verify>

<gitnexus_note>
Per `./CLAUDE.md`, this repo mandates GitNexus impact analysis before editing symbols. Changed symbols here are
all `fileprivate` (file-local, near-zero blast radius) PLUS two ADDITIVE public funcs
(`BlockPhaseColors.badgeColor` / `badgeLabelColor`) and one additive token (`bruBlue`). No existing public API
changes. GitNexus MCP may need a restart (project memory) — do NOT block on it; a `git diff` review before each
commit substitutes for `detect_changes`. The build + `NewBlockBuilderFidelityTests` are the real gate.
</gitnexus_note>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Colors foundation — bruBlue token + semantic badge API + badge/swatch swap</name>
  <files>fitbod/Design/Color+BRU.swift, fitbod/Assets.xcassets/bruBlue.colorset/Contents.json, fitbod/Periodization/BlockPhaseColors.swift, fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
DECISION (locked): add `bruBlue` as an ASSET colorset to match the existing pattern (every other bru* token is
`Color("bruX")` backed by a colorset). Create `fitbod/Assets.xcassets/bruBlue.colorset/Contents.json` mirroring the
shape of `bruSignal.colorset/Contents.json`: a universal srgb color with `components` for a brutalist primary blue
~ #2F5ACF (red 0.184, green 0.353, blue 0.812, alpha 1.000) and a second entry with `appearances: [{appearance:
luminosity, value: dark}]` using a slightly lighter blue for dark mode (e.g. red 0.290, green 0.470, blue 0.900).
Include the standard `info` block (`author: xcode`, `version: 1`).

In `Color+BRU.swift`, add a public `static let bruBlue: Color = Color("bruBlue")` to the `public extension Color`
block, with a doc comment matching the style of the neighbors (note it is the accumulation phase-badge color).

In `BlockPhaseColors.swift`, ADD two new public functions ALONGSIDE the existing ones (DO NOT modify or remove
`color(for:)`, `rowTint(for:)`, `drawDeloadStripes`, `phaseLabel` — they are used by 5 other screens):
  - `badgeColor(for kind: BlockPhaseKind) -> Color`: `.accumulation` → `.bruBlue`, `.intensification` → `.bruSignal`,
    `.deload` → `.bruAmber`, `.realization` → `.bruGreen`.
  - `badgeLabelColor(for kind: BlockPhaseKind) -> Color`: contrasting label — `.accumulation` → `.white`,
    `.intensification` → `.white`, `.realization` → `.white`, `.deload` → `.bruInk` (amber is light).

In `BlockBuilderView.swift`, swap the per-phase color usages from the fileprivate palette helpers to the new
semantic API at the two badge/swatch call sites that remain after the other tasks:
  - The phase-row number badge (`NewBlockPhaseEditorRow`, ~lines 994–1005): replace `chipFill`/`chipLabel` derived
    from `NewBlockScreenTokens.paletteColor`/`paletteLabelColor(forOrderIndex: displayIndex - 1, isDeload:)` with
    `BlockPhaseColors.badgeColor(for: draft.kind)` / `BlockPhaseColors.badgeLabelColor(for: draft.kind)`.
  - The add-phase-type sheet swatch (`NewBlockAddPhaseTypeSheet`, ~line 1252): replace `swatchColor` derived from
    `paletteColor(forOrderIndex: orderIndex, isDeload:)` with `BlockPhaseColors.badgeColor(for: kind)`.

The timeline segment also uses the palette helpers (~940) but is deleted in Task 2, so do NOT touch it here.
After the swaps above, run `grep -vn '^\s*//' fitbod/Periodization/BlockBuilderView.swift | grep -c 'paletteColor\|paletteLabelColor\|paletteSlots'`
counting only the DEFINITIONS region (lines ~427–448) as remaining. If the ONLY remaining references are the three
definitions themselves and the timeline segment (to be removed in Task 2), leave `paletteSlots`/`paletteColor`/
`paletteLabelColor` in place for now — Task 2 removes the last consumer and Task 2 deletes the orphaned helpers.
(Net: badge + swatch are swapped in this task; the helper deletion happens in Task 2 after the timeline is gone.)
  </action>
  <verify>
    <automated>cat fitbod/Assets.xcassets/bruBlue.colorset/Contents.json | python3 -m json.tool > /dev/null && grep -q 'static let bruBlue' fitbod/Design/Color+BRU.swift && grep -q 'func badgeColor(for' fitbod/Periodization/BlockPhaseColors.swift && grep -q 'func badgeLabelColor(for' fitbod/Periodization/BlockPhaseColors.swift && grep -q 'BlockPhaseColors.badgeColor(for: draft.kind)' fitbod/Periodization/BlockBuilderView.swift && xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -40 | grep -q 'BUILD SUCCEEDED'</automated>
  </verify>
  <done>bruBlue colorset is valid JSON and resolves; `Color.bruBlue` compiles; `BlockPhaseColors.badgeColor`/`badgeLabelColor` exist additively (existing funcs untouched); phase-row badge and add-phase swatch use semantic colors; project builds; commit made.</done>
</task>

<task type="auto">
  <name>Task 2: Progression line chart (B) — replace timeline preview, delete orphans</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
Add `import Charts` to the file's imports. Build a new fileprivate `NewBlockProgressionChart: View` taking
`let phases: [BlockPhaseDraft]`, rendered INSIDE a bordered BRU card (paper background, 1pt `NewBlockScreenTokens.ink`
rectangle border — sharp corners or cornerRadius ≤ 4 to match the brutalist look). Structure:
  - Section label `"PROGRESSION OVERVIEW"` (`NewBlockType.label`, `NewBlockScreenTokens.muted`, `labelTracking`).
  - A compact legend row: "Volume" with a short solid line + filled dot, "Intensity" with a short dashed line.
    Hand-roll this legend (small HStack of shapes + `NewBlockType.micro` labels) rather than fighting the chart's
    `.chartForegroundStyleScale` against BRU — keep it calm.
  - DATA: expand `phases` into per-week points. Walk phases in order; for each phase contributing `weeks` weeks,
    emit one point per cumulative week index W1..Wn (n = `phases.reduce(0){$0+$1.weeks}`). Each point carries:
    `week:Int`, `value:Double`, `series:String` ("Volume" or "Intensity"), `kind:BlockPhaseKind`. Volume value =
    `phase.volumeMultiplier * 100`; Intensity value = `phase.intensityMultiplier * 100`. Make a small private
    `Identifiable` point struct for the chart data.
  - MARKS: for "Volume" use `LineMark` + `PointMark` (solid line, `.foregroundStyle(Color.bruInk)`, visible point
    markers). For "Intensity" use `LineMark` with `.lineStyle(StrokeStyle(dash: [4,3]))` and
    `.foregroundStyle(Color.bruMuted)` (dashed, minimal/no markers). Series colors are intentionally ink/muted for
    readability on paper — they are NOT the per-phase semantic badge colors.
  - X AXIS: bottom marks at phase boundaries labeled W1..Wn. Reuse the cumulative-week boundary logic from the OLD
    `NewBlockTimelinePreview` (`cumulativeWeeks` reduce). Use `.chartXAxis` with `AxisMarks` at those boundary values.
  - TOP PHASE LABELS: overlay an HStack of proportional-width phase-name labels ABOVE the plot (Accum/Inten/Deload/Peak
    abbreviations via `NewBlockPhaseText.abbreviation(for:)`), each width = totalWidth * phase.weeks / totalWeeks —
    mirror the old timeline segment width math. Do NOT fight Swift Charts' axis API for spanned labels.
  - Y AXIS: hide or minimal (a couple of % gridlines via `.chartYAxis`). Keep it calm/brutalist.
  - EMPTY STATE: if `phases.isEmpty`, render a muted placeholder `"Add phases to preview progression"`
    (`NewBlockType.label`, `NewBlockScreenTokens.muted`) instead of an empty chart.

In the body `List` (~lines 76–93): REMOVE the `NewBlockTimelinePreview(phases:)` row AND the
`Text("VOL Δ vs base · INT % of training max")` legend row that follows it (its meaning folds into the chart legend).
Insert `NewBlockProgressionChart(phases: draft.phases)` in their place, keeping the same `.listRowInsets(EdgeInsets())`
/ `.listRowSeparator(.hidden)` / `.listRowBackground(Color.clear)` row modifiers.

DELETE the now-orphaned fileprivate structs `NewBlockTimelinePreview`, `NewBlockTimelineSegment`, and
`NewBlockDeloadStripes` (~lines 853–981). Their only consumer was the body row just removed. After deletion, the
palette helpers (`paletteSlots`/`paletteColor`/`paletteLabelColor`, ~427–448) have NO remaining call sites (Task 1
already swapped the badge + swatch). Confirm with
`grep -vn '^\s*//' fitbod/Periodization/BlockBuilderView.swift | grep -c 'paletteColor(forOrderIndex\|paletteLabelColor(forOrderIndex'`
returning 0 (zero CALL sites; the function definitions match `static func paletteColor`, a different string) — then
DELETE `paletteSlots`, `paletteColor`, and `paletteLabelColor` from `NewBlockScreenTokens`. If for any reason a call
site remains, leave the helpers and note it in the summary.
  </action>
  <verify>
    <automated>grep -q 'import Charts' fitbod/Periodization/BlockBuilderView.swift && grep -q 'struct NewBlockProgressionChart' fitbod/Periodization/BlockBuilderView.swift && grep -q 'PROGRESSION OVERVIEW' fitbod/Periodization/BlockBuilderView.swift && ! grep -q 'NewBlockTimelinePreview' fitbod/Periodization/BlockBuilderView.swift && ! grep -q 'VOL Δ vs base' fitbod/Periodization/BlockBuilderView.swift && xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -40 | grep -q 'BUILD SUCCEEDED'</automated>
  </verify>
  <done>Swift Charts progression chart renders Volume (solid+points) and Intensity (dashed) in a bordered card with top phase labels and W1..Wn x-axis; empty state shows the placeholder; old timeline preview + legend row + 3 orphan structs deleted; palette helpers deleted iff no call sites remain; project builds; commit made.</done>
</task>

<task type="auto">
  <name>Task 3: Metrics cards (A) + copy alignment (F)</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
**A — Metrics cards.** Restyle `NewBlockMetricsBand` (~lines 694–763). Replace the two flat cells split by a vertical
ink `Rectangle` rule with TWO bordered BRU cards laid out side-by-side in an `HStack` with a small gap
(`NewBlockScreenTokens.rowGap`). Each card:
  - A leading SF Symbol icon tinted `NewBlockScreenTokens.ink`: `"calendar"` for TOTAL WEEKS; for DAYS PER WEEK pick
    the closest width/scheduling glyph — use `"calendar.day.timeline.left"` (fall back to `"arrow.left.and.right"`
    if unavailable on the deployment target).
  - The uppercase label (`NewBlockType.label`, `labelTracking`, `NewBlockScreenTokens.muted`): "TOTAL WEEKS" / "DAYS PER WEEK".
  - The big BebasNeue number (`NewBlockType.display`, `NewBlockScreenTokens.ink`): `\(draft.totalWeeks)` / `\(draft.daysPerWeek)`.
  - Fold the "TAP TO EDIT" hint into the card as a small `NewBlockType.micro` muted line (keep the affordance).
  - Card border = 1pt `NewBlockScreenTokens.ink` `Rectangle().stroke(...)` overlay (sharp BRU corners; if you round,
    cornerRadius ≤ 4 max). Background `NewBlockScreenTokens.paper`.
Keep BOTH cards tappable wired to the EXISTING closures: TOTAL WEEKS card → `onEditWeeks` (opens `NewBlockDurationSheet`),
DAYS card → `onEditDays` (opens `NewBlockDaysSheet`). Preserve the existing `.accessibilityAddTraits(.isButton)` and
`.accessibilityLabel(...)` on each card (keep the same label text). Keep the band's bottom `NewBlockInkRule` overlay
and the `NewBlockScreenTokens.metricsHeight` frame (bump height only if the cards need it — adjust the token, do not
hard-code a literal).

**F — Copy alignment.** In `NewBlockPhaseText` (~lines 1143–1195), change `.realization`:
  - `title(for:)`: "Realization" → "Peak".
  - `subtitle(for:)`: "PEAK" → "SHARPEN OUTPUT" (uppercase, consistent with the other uppercase subtitles).
Leave `abbreviation(for: .realization)` as "PEAK" (it already matches the design's top-of-chart label). Do NOT change
any other phase's copy.

SAFETY (verified): no test asserts the New Block screen's "Realization"/"PEAK" strings.
`NewBlockBuilderFidelityTests` asserts Accumulation/Deload/BUILD VOLUME/etc. but NOT Realization or PEAK.
`WeeklyTonnageViewCopyTests` line 53 asserts "Realization" but reads `WeekDetailView.swift` — a DIFFERENT file you
MUST NOT touch. So this task needs no test edits.
  </action>
  <verify>
    <automated>grep -q 'systemName: "calendar"' fitbod/Periodization/BlockBuilderView.swift && grep -q '"Peak"' fitbod/Periodization/BlockBuilderView.swift && grep -q '"SHARPEN OUTPUT"' fitbod/Periodization/BlockBuilderView.swift && ! grep -q '"Realization"' fitbod/Periodization/BlockBuilderView.swift && xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -40 | grep -q 'BUILD SUCCEEDED'</automated>
  </verify>
  <done>Metrics band shows two bordered tappable cards (icon + label + BebasNeue number + folded hint), each opening its existing sheet, accessibility preserved; `.realization` title is "Peak" and subtitle "SHARPEN OUTPUT"; WeekDetailView untouched; project builds; commit made.</done>
</task>

<task type="auto">
  <name>Task 4: Phase rows read-only + per-phase editor sheet (C)</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
**C — Phase rows.** In `NewBlockPhaseEditorRow` (~lines 985–1104), replace the inline metrics `HStack` (the three
`NewBlockInlineMetricColumn` blocks with hair dividers, ~lines 1037–1090) with THREE read-only right-aligned value
columns: WEEKS (`\(draft.weeks)`), VOL (`NewBlockPhaseText.volumeValue(draft.volumeMultiplier)`),
INT (`NewBlockPhaseText.intensityValue(draft.intensityMultiplier)`). Each column: a label (`NewBlockType.micro`,
`NewBlockScreenTokens.muted`) over a value (`NewBlockType.label` or `NewBlockType.number`, `NewBlockScreenTokens.ink`),
right-aligned, matching the design's compact stat columns. Keep the number badge (already swapped to semantic
`BlockPhaseColors.badgeColor`/`badgeLabelColor` in Task 1) and its `"%02d"` BebasNeue chip. Reduce
`NewBlockScreenTokens.phaseRowHeight` from 148 (no longer needs room for steppers) to a value that fits the calmer
layout (~96–112) — adjust the TOKEN, do not hard-code a literal in the row.

Make the WHOLE ROW tappable to open a new per-phase editor sheet. Add to `NewBlockPhaseEditorRow` a
`@State private var presentingEditor = false`, and attach a row-local
`.sheet(isPresented: $presentingEditor) { NewBlockPhaseEditorSheet(draft: draft) }`. Trigger with
`.contentShape(Rectangle()).onTapGesture { presentingEditor = true }` — use `onTapGesture` (NOT a `Button`) so it
coexists with the List's `swipeActions` and `.onMove`. This row-local-state pattern AVOIDS the `.sheet(item:)`
optional-id pitfall (`BlockPhaseDraft.id` is `UUID?` and nil for unsaved phases — never use it as sheet identity).

DELETE the now-orphaned `NewBlockInlineMetricColumn` struct (~lines 1108–1141). Do NOT delete `NewBlockStepperButton`
— `NewBlockDurationSheet` still uses it (lines ~1475, ~1482).

Add a new fileprivate `NewBlockPhaseEditorSheet: View` taking `@Bindable var draft: BlockPhaseDraft`, BRU-styled by
MIRRORING `NewBlockDurationSheet`/`NewBlockDaysSheet` (NavigationStack, `.presentationDetents([.medium])`,
`NewBlockInkRule` separators, paper background, a "Done" button calling `dismiss()`). Show the phase title at top
(`NewBlockPhaseText.title(for: draft.kind)`). Provide three − value + editors reusing `NewBlockStepperButton`,
applying the clamps/steps lifted from the OLD inline column code:
  - WEEKS: − sets `draft.weeks = max(1, draft.weeks - 1)`, + sets `min(52, draft.weeks + 1)`. Show `\(draft.weeks)`.
  - VOL: − sets `draft.volumeMultiplier = (max(0.4, draft.volumeMultiplier - 0.05) * 100).rounded() / 100`,
    + sets `(min(1.6, draft.volumeMultiplier + 0.05) * 100).rounded() / 100`. Show `NewBlockPhaseText.volumeValue(draft.volumeMultiplier)` (signed %).
  - INT: − sets `draft.intensityMultiplier = (max(0.5, draft.intensityMultiplier - 0.05) * 100).rounded() / 100`,
    + sets `(min(1.0, draft.intensityMultiplier + 0.05) * 100).rounded() / 100`. Show `NewBlockPhaseText.intensityValue(draft.intensityMultiplier)`.

Keep swipe-delete (`beginPendingDelete` via `.swipeActions` in the body) and `.onMove` reorder intact — they live on
the `ForEach`/row in the body and are NOT changed by this task.
  </action>
  <verify>
    <automated>grep -q 'struct NewBlockPhaseEditorSheet' fitbod/Periodization/BlockBuilderView.swift && grep -q 'presentingEditor' fitbod/Periodization/BlockBuilderView.swift && grep -q '.onTapGesture' fitbod/Periodization/BlockBuilderView.swift && ! grep -q 'NewBlockInlineMetricColumn' fitbod/Periodization/BlockBuilderView.swift && grep -q 'struct NewBlockStepperButton' fitbod/Periodization/BlockBuilderView.swift && xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -40 | grep -q 'BUILD SUCCEEDED'</automated>
  </verify>
  <done>Phase rows show three read-only WEEKS/VOL/INT columns + semantic badge; tapping a row opens a BRU-styled `NewBlockPhaseEditorSheet` with clamped − value + editors; `NewBlockInlineMetricColumn` deleted; `NewBlockStepperButton` retained; swipe-delete + reorder intact; project builds; commit made.</done>
</task>

<task type="auto">
  <name>Task 5: Phases header + ADD PHASE / remove dashed slot (D) + update guardrail test + final build</name>
  <files>fitbod/Periodization/BlockBuilderView.swift, fitbodTests/NewBlockBuilderFidelityTests.swift</files>
  <action>
**D — Phases header.** In `NewBlockPhasesHeader` (~lines 787–851): keep the left `"PHASES · \(phaseCount)"`
(`NewBlockType.chrome`, `NewBlockScreenTokens.ink`). On the right, ADD a coral `"+ ADD PHASE"` action wired to a new
`onAddPhase: () -> Void` closure. Style it with `NewBlockScreenTokens.signal` (coral — matches the design's accent,
same family as the top-bar SAVE), `NewBlockType.chrome`, `chipTracking`, ≥44pt tap target. Add the `onAddPhase`
parameter to the struct and pass it from the body header construction (~lines 116–133) wired to
`{ presentingAddPhaseTypePicker = true }` (the existing add-phase type picker sheet — unchanged).

Preserve BOTH the REORDER/DONE toggle (it gates `.onMove`) and preset access: keep the existing REORDER `Button`
(`onToggleReorder`) and the Preset ▾ `Menu` (`onSelectPreset`) in the header. Place "+ ADD PHASE" as the rightmost
accent action; REORDER and Preset stay to its left (a compact HStack with `Spacer()` after the title). If horizontal
space is tight, the Preset menu may collapse to just the chevron label, but it MUST remain reachable.

REMOVE the dashed bottom add slot: delete the `NewBlockAddPhaseSlot(onTap:)` row from the body `List` (~lines 138–143)
since "+ ADD PHASE" now lives in the header (single add affordance, matching the design). Then DELETE the orphaned
fileprivate `NewBlockAddPhaseSlot` struct (~lines 1201–1226) — its only consumer was that body row.

NOTE: `fitbodTests/BlockBuilderViewCopyTests.swift` asserts the literal `"+ ADD PHASE"` is present in the source; it
still is (now in the header), so that test stays green — do NOT edit it.

**Update guardrail test.** In `fitbodTests/NewBlockBuilderFidelityTests.swift` (the ONLY test asserting this screen's
struct names/copy), update the `blockBuilderViewExposesNewBlockMockStructureAndCopy` test so it matches the restyle:
  - In the `requiredType` array (~line 86): replace `"NewBlockTimelinePreview"` with `"NewBlockProgressionChart"`.
  - In the `requiredCopy` array (~line 109): replace `"PREVIEW"` with `"PROGRESSION OVERVIEW"`.
  - Leave all other entries unchanged (they still hold: `"+ ADD PHASE"`, `"TOTAL WEEKS"`, `"DAYS PER WEEK"`,
    `"Accumulation"`, `"BUILD VOLUME"`, `"Deload"`, `"RECOVER"`, etc. — none of those copy strings were removed).

**Final build + targeted test run** to gate the whole restyle (see <build_verify>).
  </action>
  <verify>
    <automated>grep -q 'onAddPhase' fitbod/Periodization/BlockBuilderView.swift && ! grep -q 'NewBlockAddPhaseSlot' fitbod/Periodization/BlockBuilderView.swift && grep -q '"+ ADD PHASE"' fitbod/Periodization/BlockBuilderView.swift && grep -q 'NewBlockProgressionChart' fitbodTests/NewBlockBuilderFidelityTests.swift && grep -q 'PROGRESSION OVERVIEW' fitbodTests/NewBlockBuilderFidelityTests.swift && ! grep -q 'NewBlockTimelinePreview' fitbodTests/NewBlockBuilderFidelityTests.swift && xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests/NewBlockBuilderFidelityTests 2>&1 | tail -40 | grep -q 'TEST SUCCEEDED\|Test Suite.*passed'</automated>
  </verify>
  <done>Header shows coral "+ ADD PHASE" wired to the type picker, with REORDER + Preset still reachable; dashed bottom slot row + `NewBlockAddPhaseSlot` struct removed; `NewBlockBuilderFidelityTests` updated (TimelinePreview→ProgressionChart, PREVIEW→PROGRESSION OVERVIEW) and PASSES; full build succeeds; commit made.</done>
</task>

</tasks>

<verification>
- `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=<iPhone>' build` → BUILD SUCCEEDED.
- `xcodebuild test ... -only-testing:fitbodTests/NewBlockBuilderFidelityTests` → suite passes.
- No new bare color/font literals introduced except the single `bruBlue` token (asset-backed).
- All preserved behaviors still wired: save/discard (`saveIfValid`/`cancel`), drag-reorder (`.onMove` gated by REORDER),
  swipe-delete + 4s undo toast (`beginPendingDelete`/`NewBlockUndoToast`), preset menu, add-phase type picker,
  duration + days editor sheets.
- `git diff` reviewed before each commit (substitutes for GitNexus detect_changes per the gitnexus_note).
</verification>

<success_criteria>
- Metrics band = two bordered tappable BRU cards (icon + label + BebasNeue number), each opening its existing sheet.
- Timeline preview replaced by `NewBlockProgressionChart` (Volume solid + points, Intensity dashed, top phase labels,
  W1..Wn x-axis, empty-state placeholder); old timeline + legend row + orphan structs gone.
- Phase rows are read-only WEEKS/VOL/INT columns with a semantic-colored badge; whole-row tap opens
  `NewBlockPhaseEditorSheet` with clamped − value + editors; inline steppers removed.
- Header has coral "+ ADD PHASE" (REORDER + Preset still reachable); dashed bottom slot removed.
- `bruBlue` asset token added; `BlockPhaseColors.badgeColor`/`badgeLabelColor` added additively (existing API untouched).
- `.realization` copy = "Peak" / "SHARPEN OUTPUT".
- Build succeeds; `NewBlockBuilderFidelityTests` passes; each task committed independently.
</success_criteria>

<output>
Create `.planning/quick/260528-utc-restyle-new-block-editor-blockbuildervie/260528-utc-SUMMARY.md` when done.
</output>
