# Quick Task 260528-gr0: New Block value-editor sheets — Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Task Boundary

Declutter the New Block editor (`fitbod/Periodization/BlockBuilderView.swift`) by replacing
the inline `−/+` steppers in `NewBlockMetricsBand` with **tappable value cells that open
editor sheets**, and trim a redundant in-editor preset entry.

> ⚠️ CRITICAL REALITY CHECK — the original design brief was written against a STALE build.
> Most of the brief is ALREADY SHIPPED in the committed code. Verify against the live file;
> do NOT re-implement already-done work. Reconciliation below.

</domain>

<already_done>
## Already shipped in committed code — DO NOT touch / re-build

Verified by reading the real `BlockBuilderView.swift` + `ProgramView.swift` at HEAD (cd9f4a0):

- **STARTING POINT band: already removed.** No `NewBlockStartingPointBand` exists. Body is
  NameBand → MetricsBand → PhasesHeader → TimelinePreview → phase rows → AddPhaseSlot.
- **Bottom `↘ PRESETS` already opens the full 6-preset picker** —
  `NewBlockAddPhaseSlot.addPreset → presentPresetPicker() → presentingTemplateSheet →
  NewBlockTemplateSheet` (all 6 presets). Not hypertrophy-only.
- **Overwrite-confirm already built** — `presetWouldReplacePhases(_:)` +
  `.confirmationDialog("Apply Preset?")` with message
  "This will replace your current phases and settings." (BlockBuilderView.swift:131-147).
  NOTE (known limitation, OUT OF SCOPE this pass): the confirm currently fires only for
  `.hypertrophyMeso` on a non-empty draft, because `applyPreset` only mutates phases for
  hypertrophy. Leave as-is; record as a follow-up.
- **Pre-editor "Use Preset" flow already built** in `ProgramView` — `NewBlockStartChoiceSheet`
  ("Start From Scratch" / "Use Preset") → `NewBlockPresetPickerSheet` (6 presets) →
  `stagedBuilder = .newBlock(chosenPreset)` → `BlockBuilderView(initialPreset:)` applies it in
  `.task`. This is the user's "primary preset path." DO NOT modify ProgramView.
- **"3-6" hint** never existed in code.

</already_done>

<decisions>
## Implementation Decisions (LOCKED — do not revisit)

### D1 — Total Weeks editor (read-only cell → Edit Block Duration sheet)
- `draft.totalWeeks` is a COMPUTED sum (`phases.reduce(0){ $0+$1.weeks }`, no setter).
- In `NewBlockMetricsBand`, the TOTAL WEEKS cell becomes a **read-only, tappable** cell:
  big value (`draft.totalWeeks`, `NewBlockType.display`) + a micro hint line `TAP TO EDIT PHASES`.
- **Remove** the two weeks `−/+` `NewBlockStepperButton`s and the `decrementWeeks`/`incrementWeeks`
  closures.
- Tapping opens a new **Edit Block Duration** sheet (`presentingDurationSheet`):
  - Title line + a LIVE total readout that recalculates from the phases.
  - One row per phase: `01 Accumulation   [−] N [+]` editing `phase.weeks`, **clamp ≥ 1**.
    Reuse the existing `NewBlockStepperButton` for the `[−]`/`[+]` controls.
  - "Done" dismisses.
  - BRU styling (paper/ink/fonts via `NewBlockScreenTokens`/`NewBlockType`).
    `presentationDetents([.medium])`, scrollable if many phases.
- Phase rows on the MAIN screen stay **display-only** (no new per-row editing on the main screen).
- NO direct numeric total entry — allocation UX deferred (user: "probably overkill right now").
  Source of truth is `phase.weeks`; total is derived. This is the honest model.

### D2 — Days / Week editor (tappable cell → days picker sheet)
- DAYS PER WEEK cell becomes **tappable**: value (`draft.daysPerWeek`) + micro hint `TAP TO EDIT`.
- **Remove** the two days `−/+` steppers and `decrementDays`/`incrementDays` closures.
- Tapping opens a new **Days picker** sheet (`presentingDaysSheet`):
  - 1–7 selector, BRU-styled to match the brutalist aesthetic (NOT a default segmented Picker
    unless it can be styled to fit). Binds `draft.daysPerWeek`.
  - `Recommended: 3-6` hint shown **only inside the sheet** (never on the main screen).
  - "Done" dismisses. `presentationDetents([.medium])`.
- User chose sheet over inline 1-7.

### D3 — Trim redundant in-editor preset entry
- **Remove `APPLY PRESET`** button from `NewBlockPhasesHeader` (drop its `applyPreset`
  parameter; header reverts to `PHASES · N` + `+ ADD PHASE`).
- **Keep** the bottom `↘ PRESETS` in `NewBlockAddPhaseSlot` (already routes to full picker +
  overwrite-confirm — unchanged).
- Rationale (user): phases header should stay focused on the phase list; preset apply is a
  secondary reset/replace action; pre-editor flow is the primary discoverable path.

### Wiring / cleanup
- Add `@State private var presentingDurationSheet = false` and
  `@State private var presentingDaysSheet = false` to `BlockBuilderView`.
- Add two `.sheet(isPresented:)` modifiers presenting the new sheets (bound to `draft`).
- Update the `NewBlockMetricsBand(...)` call site: replace the 4 stepper closures with
  `onEditWeeks` / `onEditDays` present-closures.
- Remove now-dead `adjustTotalWeeks(by:)` and `adjustDaysPerWeek(by:)`.
- KEEP `NewBlockStepperButton` (relocated usage into the duration sheet).
- Tappable cells need accessibility: button trait + label (e.g., "Total weeks, N, edit phase
  durations" / "Days per week, N, edit").
- Likely grow `NewBlockScreenTokens.metricsHeight` (currently 74) so the added hint line under
  each value doesn't clip — tune visually.

### Claude's Discretion
- New sheets implemented **inline** as `fileprivate` structs in `BlockBuilderView.swift`
  (token + `NewBlockStepperButton` access, consistent with the inline `NewBlockTemplateSheet`,
  and the copy/fidelity tests scan that file). Extraction to new files is acceptable only with
  fileprivate token-subset duplication (the established `BlockNameField.swift` pattern) — but
  inline is preferred for this pass.
- Exact sheet layout/spacing within BRU tokens.

</decisions>

<test_constraints>
## Test guardrails (source-text assertions — must stay green)

`fitbodTests/NewBlockBuilderFidelityTests.swift` requires `BlockBuilderView.swift` to still
contain these TYPE names: `NewBlockScreenTokens, NewBlockTopBar, NewBlockNameBand,
NewBlockPresetChip, NewBlockMetricsBand, NewBlockTimelinePreview, NewBlockPhaseEditorRow,
NewBlockBottomActionBar, NewBlockTemplateSheet` — keep all. And copy: `< PROGRAM, NEW BLOCK,
SAVE, BLOCK NAME, NAME YOUR BLOCK, HYPERTROPHY MESO, LINEAR STRENGTH, POWERBUILDING, OFF-SEASON,
PRE-MEET, TOTAL WEEKS, DAYS PER WEEK, PHASES ·, + ADD PHASE, PREVIEW, Accumulation, BUILD VOLUME,
Intensification, BUILD STRENGTH, Deload, RECOVER, ↘ PRESETS, CANCEL, NAME FIRST ↑, SAVE TEMPLATE ▸`
— keep all (labels survive the refactor).

`fitbodTests/BlockBuilderViewCopyTests.swift` asserts `BlockBuilderView.swift` contains quoted
strings including `"TOTAL WEEKS"`, `"DAYS PER WEEK"`, `"PHASES · \(phaseCount)"`, `"+ ADD PHASE"`,
`"↘ PRESETS"`(via fidelity), `"Apply Preset?"`, `"APPLY PRESET"`.
- **D3 BREAKS line 33**: `#expect(builder.contains("\"APPLY PRESET\""))` — when removing the
  header button, DELETE this one assertion. Keep `"Apply Preset?"` (the confirm dialog stays).
- Adding new sheet copy (e.g. "Edit Block Duration", "Done", "Recommended: 3-6", "TAP TO EDIT")
  is additive — won't break "must-contain" tests. Consider adding new copy anchors for the two
  sheets to the fidelity/copy suites.

Also check `fitbodTests/BlockBuilderViewActivationTests.swift` and
`fitbodUITests/NewBlockModalUITests.swift` (the latter taps `+ NEW → + New block →
Start From Scratch` then asserts `NEW BLOCK`, `NAME YOUR BLOCK`, `PHASES · 3`, `NAME FIRST ↑` —
unaffected by this change, but build + keep green).

`draft.totalWeeks == 5` default is guarded — do not alter `BlockDraft.newBlock()` defaults.

</test_constraints>

<specifics>
## Specific references

- Target file: `fitbod/Periodization/BlockBuilderView.swift` (HEAD has `initialPreset`,
  3-arg `init`, `NewBlockPhasesHeader` with `applyPreset`, `NewBlockMetricsBand` with 4 stepper
  closures, `NewBlockStepperButton`, `adjustTotalWeeks/adjustDaysPerWeek`).
- Do NOT modify `ProgramView.swift` (pre-editor flow lives there, already correct).
- BRU tokens: `NewBlockScreenTokens` (paper/ink/muted/hair/signal, sidePadding 16, rule/heavyRule,
  microGap/tightGap/rowGap/sectionGap). Fonts: `NewBlockType` (display/number/label/micro/chrome).
- Build target: iPhone 17 simulator. Executor MUST build clean AND run the affected suites
  (NewBlockBuilderFidelityTests, BlockBuilderViewCopyTests, BlockBuilderViewActivationTests)
  and report results before declaring done. `workflow.use_worktrees=false` → work on main tree.

</specifics>

<canonical_refs>
## Canonical References

- CLAUDE.md (project): SwiftUI + SwiftData, `@Observable`, iOS 18 target, BRU brutalist style.
  GitNexus MCP is currently DOWN — impact analysis done via grep (all edited symbols are
  `fileprivate`/`private` to BlockBuilderView.swift; public `BlockBuilderView.init` is unchanged,
  so the 9 call sites in Routines/ProgramView/TodayView/BlockCard/BlockPickerMenu/BlockReviewView
  are unaffected).
- Design intent: bru-screens/New-block/new-block.png (visual north star).

</canonical_refs>

<deferred_followups>
## Deferred (NOT this task)

- Broaden the overwrite-confirm to fire for ANY non-blank preset when the draft has unsaved
  edits (currently hypertrophy-only). User reaffirmed the rule; current behavior satisfies it
  only for the phase-replacing preset.
- Direct numeric Total-Weeks entry with allocation UX.
- Pre-editor "Use Preset" flow already exists — no work needed.

</deferred_followups>
