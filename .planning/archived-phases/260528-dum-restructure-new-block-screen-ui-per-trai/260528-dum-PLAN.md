---
phase: quick
plan: 260528-dum
type: execute
wave: 1
depends_on: []
files_modified:
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbodTests/BlockBuilderViewCopyTests.swift
  - fitbodTests/NewBlockBuilderFidelityTests.swift
autonomous: true
requirements:
  - QUICK-260528-DUM (UI-only restructure of New Block screen per training-block-spec)
tags: [bru, new-block, presets, templates-band, cta-copy]

must_haves:
  truths:
    - "Opening the New Block screen with no name shows ONLY the BLOCK NAME label + large input in the name band — no preset chips inside that band."
    - "Between the metrics band and the PHASES header there is a new band titled START FROM TEMPLATE with subtitle 'Choose a preset or build from scratch.' and a row of 6 chips: BLANK, HYPERTROPHY MESO, LINEAR STRENGTH, POWERBUILDING, OFF-SEASON, PRE-MEET."
    - "The currently-selected preset chip renders in an inverted ink-fill style (ink background, paper foreground); every other chip renders in the default outlined style."
    - "Tapping BLANK clears `draft.name` to empty and sets the orchestrator's `selectedPreset` back to `.blank`."
    - "Tapping any non-BLANK chip sets `draft.name` to that preset's display name (existing semantics) and marks that chip selected."
    - "The bottom CTA reads SAVE TEMPLATE ▸ when creating a new block (canCreate && !isEditing), SAVE CHANGES ▸ when editing, NAME FIRST ↑ when disabled. CREATE + ACTIVATE ▸ no longer appears anywhere in the source."
    - "Editing an existing block whose `draft.name` matches a preset display name shows that preset as the initially-selected chip; mismatched names fall back to `.blank`."
    - "xcodebuild build clean; BlockBuilderViewCopyTests, NewBlockBuilderFidelityTests, ProgramViewFidelityTests all GREEN."
  artifacts:
    - path: "fitbod/Periodization/BlockBuilderView.swift"
      provides: "Restructured single-screen builder with new NewBlockTemplatePresetsBand + selected-preset state + updated CTA copy."
      contains: "NewBlockTemplatePresetsBand, NewBlockPreset, selectedPreset, START FROM TEMPLATE, SAVE TEMPLATE"
    - path: "fitbodTests/BlockBuilderViewCopyTests.swift"
      provides: "CREATE + ACTIVATE anchor swapped for SAVE TEMPLATE; new START FROM TEMPLATE / BLANK anchors added."
      contains: "SAVE TEMPLATE"
    - path: "fitbodTests/NewBlockBuilderFidelityTests.swift"
      provides: "CREATE + ACTIVATE entry in the required-copy list swapped for SAVE TEMPLATE; new band structure type added."
      contains: "SAVE TEMPLATE"
  key_links:
    - from: "BlockBuilderView body VStack"
      to: "NewBlockTemplatePresetsBand"
      via: "structural placement between NewBlockMetricsBand and NewBlockPhasesHeader"
      pattern: "NewBlockMetricsBand[\\s\\S]{0,800}NewBlockTemplatePresetsBand[\\s\\S]{0,800}NewBlockPhasesHeader"
    - from: "NewBlockTemplatePresetsBand"
      to: "BlockBuilderView.selectedPreset"
      via: "Binding<NewBlockPreset> drives chip isSelected + applyPreset callback"
      pattern: "selectedPreset"
    - from: "NewBlockBottomActionBar.primaryTitle"
      to: "SAVE TEMPLATE ▸ string literal"
      via: "create-new branch of the ternary (formerly CREATE + ACTIVATE ▸)"
      pattern: "SAVE TEMPLATE ▸"
---

<objective>
UI-only restructure of `fitbod/Periodization/BlockBuilderView.swift` per the user-approved subset of `.planning/quick/training-block-spec/spec.md`:

1. Extract preset chips out of `NewBlockNameBand` into a new dedicated `NewBlockTemplatePresetsBand` that sits between metrics and the phases header.
2. Add a `BLANK` chip + visible selected-state styling for the active preset.
3. Rename the bottom CTA from `CREATE + ACTIVATE ▸` to `SAVE TEMPLATE ▸` for the new-block path.

Architectural work (entity split, schema V7, Start Block flow, preset-populates-phases behavior, FIX PHASES / CHECK WEEKS disabled states, dropping `draft.isActive = true` from `saveIfValid`) is OUT OF SCOPE — captured in `.planning/backlog/block-template-active-split.md`.

Purpose: Reads the screen like the spec's "block-setup stack (name + metrics + templates) → phases stack" instead of jamming presets under the name field. Lays clean copy + structural ground for the Phase 7 architectural split without committing to any of its semantics.

Output: One Swift file restructured in place + two test anchor swaps. Three named test suites stay GREEN.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md
@.planning/quick/training-block-spec/spec.md
@.planning/backlog/block-template-active-split.md
@.planning/quick/260528-cby-fix-new-block-screen-blockbuilderview-sw/260528-cby-SUMMARY.md
@fitbod/Periodization/BlockBuilderView.swift
@fitbod/Periodization/BlockNameField.swift
@fitbod/Periodization/BlockDraft.swift
@fitbod/Periodization/BlockPhaseDraft.swift
@fitbodTests/BlockBuilderViewCopyTests.swift
@fitbodTests/NewBlockBuilderFidelityTests.swift
@fitbodTests/ProgramViewFidelityTests.swift

<interfaces>
<!-- Verified by reading source at plan time. Executor uses these directly; no codebase exploration required. -->

From fitbod/Periodization/BlockBuilderView.swift (post 260528-cby state):

- `BlockBuilderView` — the orchestrator. Holds `@Bindable var draft: BlockDraft`, `editing: Block?`, `@State private var presentingDiscardConfirm`, `@State private var initialSnapshot`, `@State private var saveError`. Its `body` is a `NavigationStack { ZStack(alignment: .bottom) { VStack(spacing: 0) { NewBlockTopBar; ScrollView { VStack(spacing: 0) { NewBlockNameBand; NewBlockMetricsBand; NewBlockPhasesHeader; NewBlockTimelinePreview; ForEach phases; NewBlockAddPhaseSlot; NewBlockLinkedRoutinesBand?; errorBand? } } } NewBlockBottomActionBar } }`.

- `NewBlockNameBand(draft: BlockDraft)` — fileprivate struct at lines 279–347. Currently:
  - body: `VStack(spacing: 0) { BlockNameField; if name empty { presetRows } else { activeChips }; Spacer(minLength: 0) }` with `.padding(.horizontal, sidePadding)`, `.frame(height: nameBandHeight)`, `.background(paper)`, `.overlay(.bottom) { NewBlockInkRule() }`.
  - `presetRows`: `VStack(spacing: 7) { HStack(spacing: 5){ HYPERTROPHY MESO; LINEAR STRENGTH; POWERBUILDING }; HStack(spacing: 5){ OFF-SEASON; PRE-MEET } }` — each wired to `applyName("…")`.
  - `activeChips`: WILL ACTIVATE ON SAVE + {N} DAYS / WK pills.
  - private `func applyName(_ name: String) { draft.name = name; draft.isActive = true }`.

- `NewBlockPresetChip` — fileprivate struct at lines 349–372. Signature: `init(_ title: String, action: @escaping () -> Void)`. Body: `Button(action:) { Text(title).font(NewBlockType.chip).tracking(1.8).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.75).frame(height: 26).padding(.horizontal, 9).overlay(Rectangle().stroke(ink, lineWidth: 1.5)) }.buttonStyle(.plain)`.

- `NewBlockMetricsBand` — fileprivate struct at lines 376–442. Two-column TOTAL WEEKS / DAYS PER WEEK band. `.frame(height: metricsHeight)`. Currently `.overlay(.bottom) { Rectangle().fill(ink).frame(height: heavyRule) }` — this is the heavyRule that the divider-placement decision moves.

- `NewBlockPhasesHeader(phaseCount:addPhase:)` at lines 463–489. `.frame(height: phasesHeaderHeight)`, `.overlay(.bottom) { NewBlockInkRule() }`.

- `NewBlockBottomActionBar(canCreate:isEditing:onCancel:onPrimary:)` at lines 806–855. `primaryTitle` ternary at line 853 is the CTA copy site:
  ```
  if !canCreate { return "NAME FIRST ↑" }
  return isEditing ? "SAVE CHANGES ▸" : "CREATE + ACTIVATE ▸"
  ```

- `NewBlockScreenTokens` at lines 182–216. Spacing scale already in place: `microGap=4, tightGap=6, rowGap=8, sectionGap=10`. Heights: `nameBandHeight=152` (will drop), all other heights stay. Colors `paper, ink, muted, hair, faint, signal` and rule sizes `rule=1, heavyRule=3` stay.

- `NewBlockType` at lines 218–228. Fonts: `chrome=SpaceGrotesk-Bold 11`, `chip=SpaceGrotesk-Bold 9`, `label=SpaceGrotesk-Bold 10`, `micro=SpaceGrotesk-Bold 8`, `display=BebasNeue 39`, `displayLarge=BebasNeue 44`, `number=BebasNeue 29`, `phaseIndex=BebasNeue 28`, `phaseTitle=Geist-Regular 18`. No new font allowed.

- `NewBlockInkRule` at lines 859–865. `Rectangle().fill(ink).frame(height: rule)` — 1pt black hairline.

- `BlockDraft` (from BlockDraft.swift): `@Observable @MainActor final class` with `var name: String`, `var isActive: Bool`, `var daysPerWeek: Int`, `var phases: [BlockPhaseDraft]`. Static `BlockDraft.newBlock()` returns a draft with empty name, `isActive=true`, `daysPerWeek=4`, and 3 default phases (accumulation/intensification/deload). The convenience `init(block: Block)` is what edit-mode uses — sets `name = block.name`.

From fitbodTests/BlockBuilderViewCopyTests.swift:
- Line 36: `#expect(builder.contains("\"CREATE + ACTIVATE ▸\""))` — MUST be swapped to `"\"SAVE TEMPLATE ▸\""`.

From fitbodTests/NewBlockBuilderFidelityTests.swift:
- Line 116 (inside `blockBuilderViewExposesNewBlockMockStructureAndCopy`): the string `"CREATE + ACTIVATE ▸",` inside the `requiredCopy` array MUST be swapped to `"SAVE TEMPLATE ▸",`.
- Lines 78–88 (`requiredType` array) — current entries: NewBlockScreenTokens, NewBlockTopBar, NewBlockNameBand, NewBlockPresetChip, NewBlockMetricsBand, NewBlockTimelinePreview, NewBlockPhaseEditorRow, NewBlockBottomActionBar. ADD `"NewBlockTemplatePresetsBand"` so the new structural type is pinned.

From fitbodTests/ProgramViewFidelityTests.swift: confirmed via grep that this file has NO reference to "CREATE + ACTIVATE" — no anchor to update here. Test must remain GREEN as-is.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Restructure presets into a new band, add BLANK + selected state, rename CTA, update two test anchors</name>
  <files>fitbod/Periodization/BlockBuilderView.swift, fitbodTests/BlockBuilderViewCopyTests.swift, fitbodTests/NewBlockBuilderFidelityTests.swift</files>
  <action>
Edit `fitbod/Periodization/BlockBuilderView.swift` end-to-end as described, then swap two test anchors. Everything below is exhaustive — do not improvise structure, copy, spacing, or font choices.

(A) Add a `NewBlockPreset` enum (fileprivate, inside BlockBuilderView.swift, near `NewBlockPhaseText` or after `NewBlockType`). Cases in this exact order: `blank, hypertrophyMeso, linearStrength, powerbuilding, offSeason, preMeet`. Add two computed properties:
  - `var chipLabel: String` returning the uppercase chip text: `BLANK / HYPERTROPHY MESO / LINEAR STRENGTH / POWERBUILDING / OFF-SEASON / PRE-MEET`.
  - `var displayName: String` returning the title-cased draft name applied on tap: `"" / "Hypertrophy Meso" / "Linear Strength" / "Powerbuilding" / "Off-Season" / "Pre-Meet"`. (BLANK's displayName is the empty string — used by the orchestrator to clear `draft.name`.)
  - `static func matching(name: String) -> NewBlockPreset` — case-insensitive match against `displayName` for each case (returns `.blank` if `name.trimmingCharacters(in: .whitespacesAndNewlines)` is empty OR no other case matches). Used by BlockBuilderView's `.onAppear` to seed the initial selection when editing an existing block.
  - Add `static let all: [NewBlockPreset] = [.blank, .hypertrophyMeso, .linearStrength, .powerbuilding, .offSeason, .preMeet]` to drive the chip row's ForEach in the exact spec'd order.

(B) Extend `NewBlockPresetChip` to support a selected state without breaking any other call site:
  - Add a second initializer parameter `isSelected: Bool = false` (default false so existing call sites — there are none after this task, but the test suite proofreads the type's continued presence — would still compile).
  - Replace the body's foreground + background:
    - When `isSelected == true`: `foregroundStyle(NewBlockScreenTokens.paper)`, `.background(NewBlockScreenTokens.ink)`, keep the same 1.5pt ink stroke overlay (the stroke now blends with the fill but preserves the box geometry — DO NOT remove the overlay or the chip shrinks by a hair).
    - When `isSelected == false`: existing behavior — `foregroundStyle(NewBlockScreenTokens.ink)`, no background fill, 1.5pt ink stroke overlay.
  - Keep `font(NewBlockType.chip)`, `.tracking(1.8)`, `.lineLimit(1)`, `.minimumScaleFactor(0.75)`, `.frame(height: 26)`, `.padding(.horizontal, 9)`, `.buttonStyle(.plain)` unchanged.

(C) Add the new `NewBlockTemplatePresetsBand` fileprivate struct (place it between `NewBlockNameBand` and `NewBlockMetricsBand` in source order to mirror its on-screen position — purely cosmetic for the reader). Signature:
  ```
  fileprivate struct NewBlockTemplatePresetsBand: View {
      @Binding var selectedPreset: NewBlockPreset
      let applyPreset: (NewBlockPreset) -> Void
  }
  ```
  Body — three vertical regions inside one `VStack(alignment: .leading, spacing: 0)`:
    1. Header label `Text("START FROM TEMPLATE")` with `font(NewBlockType.label)`, `.tracking(NewBlockScreenTokens.labelTracking)`, `.foregroundStyle(NewBlockScreenTokens.muted)`. Same pattern BLOCK NAME / TOTAL WEEKS / DAYS PER WEEK use today. Pad the top with `NewBlockScreenTokens.sectionGap`.
    2. Subtitle `Text("Choose a preset or build from scratch.")` with `font(NewBlockType.chip)` (9pt SpaceGrotesk-Bold), `.tracking(0)` (no chip tracking — this is sentence-case prose, the ONE non-uppercase chrome string per the constraint doc), `.foregroundStyle(NewBlockScreenTokens.muted)`. Pad the top with `NewBlockScreenTokens.microGap` so it sits tight under the label.
    3. Chip row: a single horizontal `ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 5) { ForEach(NewBlockPreset.all, id: \.self) { preset in NewBlockPresetChip(preset.chipLabel, isSelected: preset == selectedPreset) { applyPreset(preset) } } } }`. Pad the top with `NewBlockScreenTokens.tightGap`. The horizontal scroll handles overflow on small phones without forcing two rows. (Wrap-vs-scroll: spec says "horizontal scroll row, segmented card row, or compact preset grid" — horizontal scroll matches the editorial density and avoids touching `NewBlockScreenTokens` for a new "templateBandHeight" wrap-mode constant.)
  Outer modifiers on the VStack:
    - `.padding(.horizontal, NewBlockScreenTokens.sidePadding)`
    - `.padding(.bottom, NewBlockScreenTokens.sectionGap)` (no fixed `.frame(height:)` — band sizes to content; the surrounding ScrollView VStack has `spacing: 0` so the band's intrinsic height is its visual height).
    - `.frame(maxWidth: .infinity, alignment: .leading)`
    - `.background(NewBlockScreenTokens.paper)`
    - `.overlay(alignment: .bottom) { Rectangle().fill(NewBlockScreenTokens.ink).frame(height: NewBlockScreenTokens.heavyRule) }`

(D) ── Divider-placement decision ──
The OLD layout had `NewBlockMetricsBand`'s `.overlay(.bottom) { heavyRule }` marking the "block-setup → phases" boundary. With the new templates band sitting BETWEEN metrics and the phases header, that heavyRule has to either stay under metrics (visually splitting the setup stack in half — bad) or move under the new templates band (cleanly marking the bottom of the whole setup stack — good).

**Decision: move the 3pt heavyRule from `NewBlockMetricsBand` to `NewBlockTemplatePresetsBand`'s bottom overlay.** Rationale: the spec asks for "name + metrics + templates" to read as one setup stack and "phases" as the next stack; a single heavyRule at the bottom of the setup stack does that with one stroke, whereas keeping heavyRule under metrics + adding a 1pt rule under templates would create a redundant break inside what should read as one region. To make metrics still feel attached to the band below it (templates), replace metrics' bottom overlay with a 1pt `NewBlockInkRule()` (matches name-band style — all three setup bands now have a 1pt black bottom rule, and only the LAST setup band has the heavyRule).

Concretely:
  - In `NewBlockMetricsBand` (~line 436): change `.overlay(alignment: .bottom) { Rectangle().fill(ink).frame(height: heavyRule) }` → `.overlay(alignment: .bottom) { NewBlockInkRule() }`.
  - In the new `NewBlockTemplatePresetsBand`: add `.overlay(alignment: .bottom) { Rectangle().fill(NewBlockScreenTokens.ink).frame(height: NewBlockScreenTokens.heavyRule) }` per step (C).

(E) Strip preset rows out of `NewBlockNameBand`:
  - Delete the `presetRows` computed property entirely (lines ~309–321).
  - Delete the `applyName(_:)` private helper (lines ~343–346) — its responsibility moves to BlockBuilderView's `applyPreset(_:)`.
  - In the body, remove the `if … empty { presetRows } else { activeChips }` ternary and replace with: only render `activeChips` when `!draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`. When the name IS empty, render nothing below `BlockNameField` (the band shrinks to just label + input + the trailing `Spacer(minLength: 0)`).
  - Drop the `Spacer(minLength: 0)` since the band's `.frame(height: nameBandHeight)` now matches the field's intrinsic height + a small breathing pad; the spacer was only there to push content to the top when the chip rows were tall. Replace with `.frame(maxWidth: .infinity, alignment: .topLeading)` so an empty name still hugs the top.

(F) Resize `nameBandHeight` in `NewBlockScreenTokens`:
  - `static let nameBandHeight: CGFloat = 152` → `static let nameBandHeight: CGFloat = 104`. (BlockNameField: 16pt top pad + 10pt label + 2pt gap + 46pt input frame ≈ 74pt; add `sectionGap`-ish trailing pad = ~84pt content; 104pt gives ~20pt of breathing without making the band feel floaty. activeChips row when name is non-empty is 30pt — still fits inside 104 with the `tightGap` top pad from the existing `padding(.top, tightGap)` left attached to `activeChips`.)
  - DO NOT touch any other height constant. `metricsHeight=74, phasesHeaderHeight=36, previewHeight=104, phaseRowHeight=108, metricCellHeight=36, addPhaseSlotHeight=70, bottomActionHeight=60, bottomButtonHeight=54, topBarRowHeight=50, scrollBottomInset=12` all stay.

(G) Wire the orchestrator (`BlockBuilderView`):
  - Add `@State private var selectedPreset: NewBlockPreset = .blank` near the other `@State` declarations.
  - In the ScrollView VStack, insert `NewBlockTemplatePresetsBand(selectedPreset: $selectedPreset, applyPreset: applyPreset)` BETWEEN `NewBlockMetricsBand(...)` and `NewBlockPhasesHeader(...)` (this is the structural rearrangement — the new order is Name → Metrics → Templates → Phases header → Preview → Phase rows → Add phase → Linked routines → bottom bar).
  - Add `private func applyPreset(_ preset: NewBlockPreset) { draft.name = preset.displayName; draft.isActive = true; selectedPreset = preset }`. (`displayName` is `""` for `.blank` so this clears the name; for every other case it sets the name to the preset's title-cased display name. The `isActive = true` side-effect is preserved exactly — matches today's `applyName` semantics. Phase population is OUT OF SCOPE per the backlog.)
  - In `.onAppear` (already exists; currently only sets `initialSnapshot`), add a leading line: `selectedPreset = NewBlockPreset.matching(name: draft.name)`. This handles both the new-block path (empty name → `.blank`) and the edit path (existing `block.name` matched against the preset list).

(H) Rename the CTA in `NewBlockBottomActionBar.primaryTitle`:
  - Line ~853: `return isEditing ? "SAVE CHANGES ▸" : "CREATE + ACTIVATE ▸"` → `return isEditing ? "SAVE CHANGES ▸" : "SAVE TEMPLATE ▸"`.
  - Leave `if !canCreate { return "NAME FIRST ↑" }` untouched.

(I) DO NOT touch `saveIfValid` — the `draft.isActive = true` line on ~line 116 is architectural (the "saving a template no longer activates it" change moves activation into a future Start Block flow) and is OUT OF SCOPE per the backlog. Leaving the v1 ship behavior intact: saving a template still flips `isActive = true` exactly like today.

(J) DO NOT touch any other copy string. Preserve verbatim: NEW BLOCK / EDIT BLOCK, BLOCK NAME, NAME YOUR BLOCK, TOTAL WEEKS, DAYS PER WEEK, PHASES · {N}, + ADD PHASE, PREVIEW, BUILD VOLUME / BUILD STRENGTH / RECOVER / PEAK, WEEKS / VOL / INT, ↘ PRESETS, ROUTINES · {N} LINKED, + LINK, CANCEL, NAME FIRST ↑, SAVE CHANGES ▸, WILL ACTIVATE ON SAVE, {N} DAYS / WK, DELOAD, < PROGRAM, SAVE, W1/W{N}, Accumulation, Intensification, Deload, ACCUM, INTEN, PEAK, HOLD. The preset chip names HYPERTROPHY MESO / LINEAR STRENGTH / POWERBUILDING / OFF-SEASON / PRE-MEET stay character-for-character identical (they now come from `NewBlockPreset.chipLabel` instead of inline string literals, but the literal text is byte-equal).

(K) Update two test anchors in the same commit (otherwise the suite goes RED for the CTA copy swap):
  - `fitbodTests/BlockBuilderViewCopyTests.swift` line 36: change `#expect(builder.contains("\"CREATE + ACTIVATE ▸\""))` → `#expect(builder.contains("\"SAVE TEMPLATE ▸\""))`. (Quotes-around-quotes — the test scans the BlockBuilderView.swift source for the exact double-quoted literal.)
  - `fitbodTests/NewBlockBuilderFidelityTests.swift` line 116: inside the `requiredCopy` array, change `"CREATE + ACTIVATE ▸",` → `"SAVE TEMPLATE ▸",`. Also in the `requiredType` array on lines ~78–88, append `"NewBlockTemplatePresetsBand",` after `"NewBlockBottomActionBar",` so the new structural type is pinned by the fidelity gate.
  - DO NOT add new test expects for the new copy strings (`START FROM TEMPLATE`, `BLANK`, `Choose a preset or build from scratch.`) in this PR — keep the anchor swap minimal. If future drift surfaces, a follow-up can extend the suites. The verify step below greps the source directly to confirm the new strings landed.
  - `fitbodTests/ProgramViewFidelityTests.swift` — DO NOT TOUCH. Verified at plan time that it has no `CREATE + ACTIVATE` anchor; it must stay GREEN as-is.

(L) Build + test gate:
  ```
  cd /Users/chrissaechao/Desktop/fitbod && \
    xcodebuild -scheme fitbod \
      -destination 'platform=iOS Simulator,name=iPhone 17' \
      -only-testing:fitbodTests/BlockBuilderViewCopyTests \
      -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
      -only-testing:fitbodTests/ProgramViewFidelityTests \
      test
  ```
  Expect `** TEST SUCCEEDED **`. If SourceKit emits phantom "cannot find type" diagnostics on the new struct, trust `xcodebuild` per the user's `project_sourcekit_stale_widget_diagnostics` memory.

(M) Commit as ONE atomic commit (single Swift file + two test files form a coherent unit — splitting them creates a non-compiling/non-GREEN intermediate):
  ```
  git add fitbod/Periodization/BlockBuilderView.swift \
          fitbodTests/BlockBuilderViewCopyTests.swift \
          fitbodTests/NewBlockBuilderFidelityTests.swift
  git commit -m "$(cat <<'EOF'
  feat(new-block): extract presets band + BLANK + selected state + SAVE TEMPLATE CTA (260528-dum)

  UI-only restructure of BlockBuilderView per training-block-spec.md sections 1–3
  (the user-approved subset; architectural split stays backlogged).

  - Move 5 preset chips out of NewBlockNameBand into a new
    NewBlockTemplatePresetsBand sitting between metrics and the phases header.
    Label: START FROM TEMPLATE. Subtitle: Choose a preset or build from scratch.
  - Add a BLANK chip (clears draft.name). 6 chips total in horizontal scroll.
  - Extend NewBlockPresetChip with isSelected: inverted ink-fill for the active
    preset. Selection state owned by BlockBuilderView via @State selectedPreset.
  - .onAppear seeds selectedPreset by matching draft.name against the preset
    list (handles both new-block and edit-existing paths).
  - Bottom CTA: CREATE + ACTIVATE ▸ → SAVE TEMPLATE ▸ for the create-new path.
    SAVE CHANGES ▸ and NAME FIRST ↑ preserved.
  - Move the 3pt heavyRule from metrics-bottom to templates-bottom so the
    name+metrics+templates trio reads as one setup stack ending in the heavy
    rule. Metrics-bottom now gets a 1pt NewBlockInkRule() to match name-band.
  - nameBandHeight 152 → 104 (band no longer carries chip rows).
  - Update two test anchors: CREATE + ACTIVATE ▸ → SAVE TEMPLATE ▸ in
    BlockBuilderViewCopyTests and NewBlockBuilderFidelityTests requiredCopy.
    Add NewBlockTemplatePresetsBand to NewBlockBuilderFidelityTests requiredType.

  Out of scope (backlog: block-template-active-split.md):
  - saveIfValid still sets draft.isActive = true (architectural change moves
    activation into a future Start Block flow)
  - Preset taps don't populate phases/multipliers/totalWeeks/daysPerWeek (just
    sets draft.name like today's applyName)
  - FIX PHASES ↑ / CHECK WEEKS ↑ disabled states (need new validation logic)

  EOF
  )"
  ```
  </action>
  <verify>
<automated>
cd /Users/chrissaechao/Desktop/fitbod && \
  xcodebuild -scheme fitbod \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:fitbodTests/BlockBuilderViewCopyTests \
    -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
    -only-testing:fitbodTests/ProgramViewFidelityTests \
    test 2>&1 | tail -40
# Expect: ** TEST SUCCEEDED **

# Source grep gates — all should return >0 hits:
grep -c 'NewBlockTemplatePresetsBand' fitbod/Periodization/BlockBuilderView.swift   # struct decl + call site + (optional) #Preview ⇒ ≥ 2
grep -c '"START FROM TEMPLATE"'        fitbod/Periodization/BlockBuilderView.swift  # ≥ 1
grep -c '"Choose a preset or build from scratch."' fitbod/Periodization/BlockBuilderView.swift  # ≥ 1
grep -c '"SAVE TEMPLATE ▸"'            fitbod/Periodization/BlockBuilderView.swift  # ≥ 1 (CTA only)
grep -c 'isSelected'                   fitbod/Periodization/BlockBuilderView.swift  # ≥ 2 (init param + body branch)
grep -c 'selectedPreset'               fitbod/Periodization/BlockBuilderView.swift  # ≥ 3 (@State + Binding + onAppear)
grep -c 'enum NewBlockPreset'          fitbod/Periodization/BlockBuilderView.swift  # = 1

# Source grep gates — all should return 0 hits:
grep -v '^[[:space:]]*//' fitbod/Periodization/BlockBuilderView.swift | grep -c '"CREATE + ACTIVATE ▸"'  # = 0
grep -v '^[[:space:]]*//' fitbod/Periodization/BlockBuilderView.swift | grep -c 'private var presetRows' # = 0
grep -v '^[[:space:]]*//' fitbod/Periodization/BlockBuilderView.swift | grep -c 'private func applyName' # = 0

# Test file swaps landed:
grep -c '"SAVE TEMPLATE ▸"' fitbodTests/BlockBuilderViewCopyTests.swift     # ≥ 1 (was CREATE + ACTIVATE)
grep -c 'SAVE TEMPLATE ▸'   fitbodTests/NewBlockBuilderFidelityTests.swift  # ≥ 1
grep -c 'NewBlockTemplatePresetsBand' fitbodTests/NewBlockBuilderFidelityTests.swift  # ≥ 1 (in requiredType)
grep -v '^[[:space:]]*//' fitbodTests/BlockBuilderViewCopyTests.swift    | grep -c 'CREATE + ACTIVATE'   # = 0
grep -v '^[[:space:]]*//' fitbodTests/NewBlockBuilderFidelityTests.swift | grep -c 'CREATE + ACTIVATE'   # = 0

# Preserved-token guard (any 0 hit = regression):
grep -c 'static let nameBandHeight: CGFloat = 104' fitbod/Periodization/BlockBuilderView.swift  # = 1 (resized)
grep -c 'static let metricsHeight'      fitbod/Periodization/BlockBuilderView.swift  # ≥ 1
grep -c 'static let heavyRule: CGFloat = 3' fitbod/Periodization/BlockBuilderView.swift  # = 1 (intact)
grep -c 'NewBlockInkRule()'             fitbod/Periodization/BlockBuilderView.swift  # ≥ 4 (name, top bar ×2, metrics ⇐ NEW, phases, linked-routines)
</automated>
  </verify>
  <done>
- `NewBlockTemplatePresetsBand` exists between metrics and phases header in the body ScrollView, renders 6 chips in spec'd order (BLANK / HYPERTROPHY MESO / LINEAR STRENGTH / POWERBUILDING / OFF-SEASON / PRE-MEET), and shows the active chip in inverted ink-fill.
- `NewBlockNameBand` no longer contains `presetRows` or `applyName`; the band collapses to label + input when `draft.name` is empty, and shows the activeChips row when non-empty.
- `nameBandHeight = 104` (down from 152). No other height constant changed.
- 3pt heavyRule lives under templates band; metrics band carries a 1pt `NewBlockInkRule()` under it.
- `BlockBuilderView` owns `@State selectedPreset` and seeds it via `NewBlockPreset.matching(name: draft.name)` in `.onAppear`. Tapping a chip calls `applyPreset(_:)` which sets `draft.name = preset.displayName`, `draft.isActive = true`, and `selectedPreset = preset`.
- Bottom CTA reads `SAVE TEMPLATE ▸` for create-new, `SAVE CHANGES ▸` for editing, `NAME FIRST ↑` for disabled. `CREATE + ACTIVATE ▸` no longer appears anywhere in `fitbod/` or `fitbodTests/`.
- `saveIfValid` unchanged — `draft.isActive = true` still flips on save (architectural change deferred per backlog).
- All three named test suites GREEN. SourceKit phantoms ignored per `project_sourcekit_stale_widget_diagnostics` memory.
- One atomic commit on `main`: 1 Swift file + 2 test files staged together.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | UI-only edit on an existing local-form view. No new network, no auth, no file IO, no SwiftData schema delta. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-260528-dum-01 | Tampering | `BlockBuilderView` form input | accept | `draft.name` is user-typed local string; existing `BlockDraft.save` already calls `.trimmingCharacters(in: .whitespacesAndNewlines)` before persistence. No new sanitization required. |
| T-260528-dum-02 | Information Disclosure | New chip copy strings | accept | All new strings (`START FROM TEMPLATE`, `Choose a preset or build from scratch.`, `BLANK`, `SAVE TEMPLATE ▸`) are static UI labels — no PII, no secrets, no telemetry. |
| T-260528-dum-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this task. No package manifest touched. |
</threat_model>

<verification>
Three named test suites (BlockBuilderViewCopyTests, NewBlockBuilderFidelityTests, ProgramViewFidelityTests) must report `** TEST SUCCEEDED **` on `iPhone 17` / iOS 26.x simulator. Source-grep gates in `<verify><automated>` enforce the structural + copy guarantees beyond what the unit tests pin.
</verification>

<success_criteria>
- Name band renders ONLY label + input when name is empty (no preset chips visible inside it).
- New band labeled `START FROM TEMPLATE` with subtitle `Choose a preset or build from scratch.` sits between metrics and the phases header, carrying 6 chips in the exact spec'd order.
- Active preset chip renders inverted (ink fill, paper foreground); inactive chips outlined.
- Tapping `BLANK` clears `draft.name` to `""` and resets `selectedPreset = .blank`. Tapping any other chip sets `draft.name` to the preset display name and marks it selected.
- Bottom CTA: `SAVE TEMPLATE ▸` (create-new), `SAVE CHANGES ▸` (edit), `NAME FIRST ↑` (disabled).
- 3pt heavyRule moved from metrics-bottom to templates-bottom; metrics-bottom carries a 1pt NewBlockInkRule.
- `nameBandHeight = 104` (down from 152). All other height tokens unchanged.
- `xcodebuild build` clean. Three named test suites GREEN.
- One atomic commit on `main` with the message format shown in step (M).
</success_criteria>

<output>
Create `.planning/quick/260528-dum-restructure-new-block-screen-ui-per-trai/260528-dum-SUMMARY.md` when done, per the standard quick-mode summary template — covering files changed, divider-placement decision callout, test-anchor swap callout, test results, deviations (if any), and known stubs (this task introduces NO stubs — preset taps still apply name + isActive=true exactly like today; phase population is explicitly OUT OF SCOPE, not stubbed).
</output>
</content>
</invoke>