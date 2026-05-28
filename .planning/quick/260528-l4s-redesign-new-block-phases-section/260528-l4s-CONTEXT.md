# Quick Task 260528-l4s: New Block Phases section redesign — Context

**Gathered:** 2026-05-28
**Status:** Ready for planning
**Scope confirmed by user:** EVERYTHING — visual redesign + List refactor + gestures.

> ⚠️ LARGE single-file change to a churn hotspot (`fitbod/Periodization/BlockBuilderView.swift`, ~1202 lines at HEAD 20a7137). SwiftUI/BRU — NOT web; the brief's "Tailwind/styled-components" phrasing is generic. Keep the diff to the Phases section. Read the file FRESH (Reads in this repo can be stale — cross-check `git show HEAD:`).

<domain>
## Task Boundary
Redesign the Phases section of the New Block editor: per-phase color, timeline/preview bar, phase cards, and the section header — PLUS convert the phase list to a SwiftUI `List` and add gestures (swipe-delete + undo, drag-reorder, inline-editable metric steppers, add-phase type-picker). All inside `BlockBuilderView.swift`. Do not touch `ProgramView.swift` or the shared public `BlockPhaseColors` API (used by 5 other screens).

## Current structure (HEAD 20a7137, post-af6aaff)
- Body: `NavigationStack { ZStack(alignment:.bottom) { VStack { NewBlockTopBar; GeometryReader { ScrollView { VStack(spacing:0) { NameBand; MetricsBand; PhasesHeader; TimelinePreview; ForEach phases { NewBlockPhaseEditorRow }; NewBlockAddPhaseSlot; LinkedRoutinesBand?; errorBand? } .padding(.bottom, actionBar+safeArea) } } }; NewBlockBottomActionBar } }` + sheets/confirms on the NavigationStack.
- `NewBlockPhasesHeader(phaseCount:addPhase:)` — "PHASES · N" + "+ ADD PHASE" (APPLY PRESET already removed last task).
- `NewBlockTimelinePreview` — "PREVIEW" + GeometryReader proportional segments, 1.5pt ink outer stroke, height 44; below: "W1" … "W{total}". previewHeight token=120.
- `NewBlockTimelineSegment.segmentFill` — switch on kind: accumulation=ink, intensification=signal, realization=ink@25%, deload=`NewBlockDeloadStripes` (hatched Canvas).
- `NewBlockPhaseEditorRow` — "01" index, title, deload badge, subtitle, "⋮⋮" glyph (decorative only, no real reorder), then HStack of 3 `NewBlockPhaseMetricCell` (WEEKS/VOL/INT) each in a 1.5pt ink border box (the "nested boxes"). DISPLAY-ONLY today.
- `NewBlockAddPhaseSlot(addPhase:addPreset:)` — bottom dashed row: "+" + "ADD PHASE" (two Texts, NOT one literal) on the left, "↘ PRESETS" on the right → `presentPresetPicker()` → full `NewBlockTemplateSheet`.
- `NewBlockPhaseText.volumeValue` — `~1.0 → "HOLD"`, else `(mult-1)*100 → "+20%"/"-15%"`. `intensityValue` → `mult*100 → "70%"`.
- `BlockPhaseDraft`: class with `kind: BlockPhaseKind`, settable `weeks: Int`, `volumeMultiplier: Double`, `intensityMultiplier: Double`, `draftID` (ForEach id). `draft.phases: [BlockPhaseDraft]` settable. `draft.totalWeeks` = COMPUTED `phases.reduce(0){ $0+$1.weeks }` (no setter).
- `selectedPreset: NewBlockPreset` @State already tracks the applied preset (`.blank` / a named preset). `presetWouldReplacePhases` + "Apply Preset?" confirm already exist. Last task added `NewBlockDurationSheet` (per-phase week steppers) + `NewBlockDaysSheet` + made TOTAL WEEKS/DAYS read-only tappable cells.
</domain>

<decisions>
## Locked decisions (do not revisit)

### D1 — Per-phase color (timeline + cards)
- New ordered palette keyed by phase ORDER (index), New-Block-LOCAL (fileprivate in BlockBuilderView.swift). DO NOT modify the public `BlockPhaseColors.color(for:)` — it's used by MesocycleWeekPage/BlockCard/BlockOverviewScreen/BlockReviewView/BlockPhaseEditorRow.
- Palette = BRU-faithful tonal set anchored in existing tokens: ink (100%), signal (coral), ink@~55%, ink@~30%, + at most one muted companion (e.g. a desaturated slate) if >4 slots; cycle if more phases. MUTED, paper-friendly — not neon (must read as BRU, not a new design language). Two Accumulations get DIFFERENT slots by order index → distinguishable.
- Apply the SAME color to the timeline segment AND a filled number chip behind "01"/"02" on the card (or a colored left edge). Color is ALWAYS paired with the number + phase name → colorblind-safe, never color-alone.
- Deload: SOLID muted color (e.g. bruMuted-ish gray). Remove `NewBlockDeloadStripes` usage (hatching reads as disabled). Verify text contrast on each palette color (white or ink label as appropriate).

### D2 — Volume metric convention (USER-DIRECTED — overrides earlier multiplier idea)
- Volume = SIGNED % vs base volume: `(volumeMultiplier-1)*100` → ">0 → +X%", "<0 → −X%", "==0 → Hold". (User: "signed-% stepper that renders 0 as Hold.")
- Make baseline explicit via ONE small legend/caption near the cards or timeline, e.g. "VOL Δ vs base · INT % of training max".
- Intensity stays a plain % (`intensityMultiplier*100 → "70%"`).
- ⚠️ FLAG for user review: rendering 0 as "Hold" partially re-creates the "HOLD vs −15%" category/number mix brief #3 wanted removed. Implement as directed (Hold@0) but note in SUMMARY that switching 0→"0%" gives pure consistency if preferred.

### D3 — Phase cards (declutter + editable)
- Remove the 1.5pt ink border boxes on WEEKS/VOL/INT (`NewBlockPhaseMetricCell`). Present each metric as label-over-value separated by thin hair dividers / spacing → card reads as one calm unit.
- Add the D1 colored number chip on "01"/"02".
- Cards become INLINE-EDITABLE (user chose "everything"): Weeks/Vol/Int via `Stepper` styled to match the existing `NewBlockStepperButton` −/+ look. Weeks: 1...52 step 1. Vol: edits `volumeMultiplier` (~0.4...1.6, step 0.05), rendered per D2 (Hold@0). Int: edits `intensityMultiplier` (~0.5...1.0, step 0.05), rendered "%". Reuse `NewBlockStepperButton`-style controls; keep the model bindings (@Bindable BlockPhaseDraft).
- Preserve the "⋮⋮" reorder affordance (see D7).
- ⚠️ This reverses last task's "cards display-only; weeks edited only in the duration sheet" decision. KEEP `NewBlockDurationSheet`/`NewBlockDaysSheet` (TOTAL WEEKS/DAYS cells still open them) but FLAG the weeks-editing redundancy in SUMMARY for user to resolve later.

### D4 — Timeline / preview bar
- Keep proportional segment widths.
- ⚠️ "Sum-vs-total mismatch" is VACUOUS here: `totalWeeks` IS the computed sum of phase weeks — they cannot diverge. Do NOT build a fake divergence warning. Optionally surface a real validity hint instead (e.g. ≥1 phase required, or a phase with weeks<1) — keep it subtle. Document the no-op in SUMMARY.
- Add week-boundary tick marks / cumulative week numbers at each phase boundary (W1, W{after p1}, … W{total}) — replace the bare "W1 … W{total}" pair. Keep "W…" copy idiom.
- Narrow-segment labels: when a segment is too narrow to fit its abbreviation legibly (measure width via GeometryReader vs a threshold), DROP the inline label (rely on color + a compact legend mapping color→phase, or reveal-on-tap). Wide segments keep labels.
- Tone DOWN visual weight: it's currently the heaviest element (1.5pt full ink stroke). Lighten — thinner/hair stroke or drop the outer box, smaller height, muted — so it's lighter than the screen title. Keep "PREVIEW" label.

### D5 — Section header → stateful preset selector
- Header LEFT stays "PHASES · \(phaseCount)".
- Header RIGHT becomes a STATEFUL preset selector: a `Menu` whose label is `Preset: {state} ▾` (HStack: Text("Preset:") + Text(name).bold/ink + chevron.down). State from `selectedPreset`: `.blank` → "Custom" (the user is on a hand-tuned/blank config), else `selectedPreset.displayName`. Menu lists the presets; selecting one routes through the EXISTING `presetWouldReplacePhases` → "Apply Preset?" destructive confirm before overwrite. 44pt tap target.
- REMOVE the "+ ADD PHASE" button from the header (it moves to the bottom — D6).
- Pin the header so the preset state stays visible while scrolling (see D7 List/pinning).

### D6 — Add Phase (bottom, full-width, type-picker)
- Bottom dashed `NewBlockAddPhaseSlot` becomes the SINGLE full-width "+ ADD PHASE" row (remove "↘ PRESETS" from it). Render the literal string `"+ ADD PHASE"` (one literal) here so the test guard stays satisfied after removing it from the header.
- Tapping it opens an add-phase TYPE PICKER (sheet preferred — color swatch + name + short descriptor per kind; the 4 `BlockPhaseKind`s) → appends a `BlockPhaseDraft` of the chosen kind (replaces `addDefaultPhase`'s always-accumulation default with sensible per-kind default multipliers via `BlockPhaseDraft.defaultMultipliers(for:)`). 44pt rows.

### D7 — List conversion + reorder + swipe-delete + undo
- Convert the scroll body to a SwiftUI `List` (`.listStyle(.plain)`, `.listRowSeparator(.hidden)`, `.listRowInsets(EdgeInsets())` for full-bleed bands, `.listRowBackground(Color.clear)`) so the brutalist look is preserved. Upper bands (Name, Metrics, Timeline) become rows or a header section; phases are a `Section` with `.onMove` + `.onDelete`; the Add-Phase row is the last row / footer. KEEP `NewBlockBottomActionBar` as the `ZStack` overlay OUTSIDE the List, and preserve the bottom safe-area inset so the action bar never covers the last row. Keep all sheets/confirms on the NavigationStack.
- PIN the PHASES header (plain `List` pins section headers automatically; or `LazyVStack(pinnedViews:[.sectionHeaders])`) so the `Preset:` state stays visible.
- Reorder: `.onMove` on the phases ForEach over `draft.phases`. Activate via an explicit edit-mode toggle (e.g. a small "REORDER"/"DONE" control in the pinned header) OR always-on drag — planner's call; lean to `.onMove` + an editMode toggle (always-on `.draggable`/`.dropDestination` is "more work" per user). Reconcile the native List move-handle vs the custom "⋮⋮" glyph (keep one cue; avoid double handles).
- Swipe-delete: `.swipeActions(edge:.trailing){ Button(role:.destructive) }`. Native delete is immediate with no undo → BUILD an undo affordance: pending-delete buffer `{phase, originalIndex}`, remove from `draft.phases`, show a transient banner "Phase deleted · UNDO" (~4s); UNDO reinserts at originalIndex; timeout clears the buffer. Concurrency: use a `Task { try await Task.sleep(...) }` on `@MainActor`, cancel the prior task on each new delete (see [[project-swift6-activitykit-pattern]] for Swift 6 Task hygiene — build state inside the Task, don't capture across actors). Guard: deleting the last phase leaves 0 phases → `draft.isValid` already gates Save; allow it but the bottom bar will show "NAME FIRST ↑"/disabled — acceptable.
</decisions>

<test_constraints>
## Source-text test guards (must stay green)

`fitbodTests/NewBlockBuilderFidelityTests.swift` — `BlockBuilderView.swift` must still contain TYPE names: `NewBlockScreenTokens, NewBlockTopBar, NewBlockNameBand, NewBlockPresetChip, NewBlockMetricsBand, NewBlockTimelinePreview, NewBlockPhaseEditorRow, NewBlockBottomActionBar, NewBlockTemplateSheet` (keep all — they can be List rows). `NewBlockPhaseMetricCell`, `NewBlockDeloadStripes`, `NewBlockAddPhaseSlot` are NOT required → may be changed/removed/renamed.
Required copy (substring): `< PROGRAM, NEW BLOCK, SAVE, BLOCK NAME, NAME YOUR BLOCK, HYPERTROPHY MESO, LINEAR STRENGTH, POWERBUILDING, OFF-SEASON, PRE-MEET, TOTAL WEEKS, DAYS PER WEEK, PHASES ·, + ADD PHASE, PREVIEW, Accumulation, BUILD VOLUME, Intensification, BUILD STRENGTH, Deload, RECOVER, ↘ PRESETS, CANCEL, NAME FIRST ↑, SAVE TEMPLATE ▸`.
- `+ ADD PHASE`: must remain — render it as ONE literal in the bottom Add-Phase row (it currently lives only in the header). KEEPS the guard with no test edit.
- `↘ PRESETS`: being REMOVED (presets → header selector). DELETE the single `"↘ PRESETS"` assertion in NewBlockBuilderFidelityTests (legitimate copy change). It is NOT in the CopyTests file.
- Phase titles/subtitles via `NewBlockPhaseText` — keep.

`fitbodTests/BlockBuilderViewCopyTests.swift` — asserts BlockBuilderView.swift quoted strings incl. `"PHASES · \(phaseCount)"`, `"+ ADD PHASE"`, `"Apply Preset?"`, `"Start From Template"`, etc. (keep). The `WEEKS/VOL/INT` quoted-string asserts in this file read a DIFFERENT file (`BlockPhaseEditorRow.swift`) — NOT the New Block card → restructuring the card's metric cells is UNGUARDED.

New copy (e.g. `Preset:`, `UNDO`, add-type-picker titles, legend) is additive. Optionally add anchors for the new sheets/labels.
`draft.totalWeeks == 5` default is guarded by FidelityTests — do not change `BlockDraft.newBlock()` defaults.
Also run `BlockBuilderViewActivationTests` (activation logic) — should be unaffected; keep green.
</test_constraints>

<constraints>
- Don't break: the −/+ steppers, `NewBlockDurationSheet`/`NewBlockDaysSheet`, the preset apply + "Apply Preset?" confirm, `initialPreset`/.task seeding, the save flow, `NewBlockBottomActionBar`, the `BlockPhaseDraft` model.
- 44pt min tap targets for ALL new controls (preset Menu, Add-Phase row, per-card steppers, swipe action, UNDO button, reorder toggle).
- Colorblind-safe: color ALWAYS paired with the number/label.
- Swift 6 strict concurrency for the undo timer.
- Reuse existing primitives/tokens (`NewBlockScreenTokens`, `NewBlockType`, `NewBlockStepperButton`, BRU colors). No new dependencies, no new design language.
- SINGLE production file → SEQUENTIAL execution, no worktrees (workflow.use_worktrees=false), no parallel executors.
- Build clean on iPhone 17 simulator + run NewBlockBuilderFidelityTests, BlockBuilderViewCopyTests, BlockBuilderViewActivationTests green.
</constraints>

<execution_guidance>
## For the planner/executors
- This is large for one file. Produce ONE PLAN.md with ~6–9 atomic, individually-committable+buildable tasks, EXPLICITLY ORDERED with dependencies. Suggested order (planner finalizes):
  1. D1 colors (local palette + timeline fills + card number chips + deload solid).
  2. D4 timeline (ticks/legend, narrow-label drop, lighter weight; document mismatch no-op).
  3. D3 cards (declutter boxes→dividers + inline editable Weeks/Vol/Int steppers + D2 Volume convention + legend).
  4. D5 header stateful preset selector + D6 bottom full-width Add-Phase + add-type-picker.
  5. D7a List conversion + pinned header (foundational for gestures).
  6. D7b reorder (.onMove + edit-mode toggle) + swipe-delete + undo toast.
  7. Test updates (delete "↘ PRESETS" assertion; add new anchors) + build/test gate on iPhone 17 sim.
- Orchestrator will dispatch CHUNKED executors (~2–3 tasks each) to avoid exhausting context on this ~1200-line hotspot ([[feedback-gsd-executor-chunk-skip-claudemd]]): executors filter xcodebuild output and need not re-read the giant CLAUDE.md. Each executor commits its tasks atomically and leaves the file buildable.
- A plan-checker pass will run before execution (large scope → verify coverage of all of D1–D7 + test couplings).
</execution_guidance>

<deferred_followups>
- Weeks now editable both inline (cards) AND via `NewBlockDurationSheet` — redundant; user to decide whether to drop the sheet later.
- Volume "Hold@0" vs brief #3's de-HOLD intent — switch 0→"0%" if pure consistency is preferred.
- Timeline divergence/mismatch warning is impossible (derived total) — only a validity hint was added.
- Always-on drag (`.draggable`/`.dropDestination`) instead of edit-mode reorder — deferred (more work).
</deferred_followups>
