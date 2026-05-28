# Quick Task 260528-ejb: Refactor New Block screen — Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Task Boundary

Refactor the New Block SwiftUI screen (`fitbod/Periodization/BlockBuilderView.swift` + its fileprivate band components) to reduce visual clutter, fix the Days Per Week control, improve the Start From Template layout, and adopt template-oriented copy. **UI + light state only — NO SwiftData schema changes.**

Authoritative 8-point spec is in the originating request. This task implements the parts that do NOT require schema/model/content changes; three sub-items are explicitly DEFERRED to Phase 7 (see below).
</domain>

<decisions>
## Implementation Decisions (LOCKED — do not revisit)

### Scope: UI-only, defer 3 Phase-7-overlap items
The following collide with the deferred V6→V7 template/active split (`.planning/backlog/block-template-active-split.md` items #8, #9, #10) and are OUT OF SCOPE for this task:
- **Preset → phase population for the 4 undefined presets** (Linear Strength, Powerbuilding, Off-Season, Pre-Meet have NO phase content defined anywhere). Do NOT fabricate training content.
- **"FIX PHASES ↑" disabled CTA state** — no phase-validity concept exists; requires a model change. Defer.
- **"CHECK WEEKS ↑" disabled CTA state** — `BlockDraft.totalWeeks` is a computed sum of phase weeks (can't mismatch); requires decoupling into a stored field. Defer.

What presets DO on selection in this task: set `draft.name` + `draft.daysPerWeek`, and populate phases ONLY for Hypertrophy Meso (it has real data via `BlockTemplates.hypertrophy`). The other presets set name + days/week and leave existing phases untouched. BLANK clears the name as today.

The only CTA disabled state in this task is the existing **"NAME FIRST ↑"** (empty name). Do not add FIX PHASES / CHECK WEEKS.

### Save behavior: Save INACTIVE template
- `saveIfValid()` must set `draft.isActive = false` (today it sets `true`). Saving creates a reusable template, NOT an active block.
- Also stop the default/preset activation: `BlockDraft.newBlock()` line 26, `applyPreset` and `applyHypertrophyPreset` currently set `isActive = true` — remove those so the New Block flow never activates.
- Other activation paths remain intact and are the way to activate: `BlockOverviewScreen.swift:618`, `BlockContextBand.swift:143`. Do NOT touch those.
- Accept the trade-off: Today tab shows the "No active block" `StartBlockCTA` empty state until the user activates a block elsewhere. This is correct/intended.

### Section restructure (task #1)
Reorder into 4 clear sections, top→bottom:
1. **BLOCK NAME** — editable name field, visually dominant. Remove the badge row beneath it entirely (see declutter).
2. **BLOCK SETTINGS** — Total Weeks + Days Per Week, both editable with matching −/+ stepper controls.
3. **STARTING POINT** — compact selected-template summary row ("{Preset Name}" + a "CHANGE" action). Not a permanent full chip section.
4. **PHASES** — preview bar + phase editor rows + Add Phase (the main body).

### Days Per Week control (task #2)
- `draft.daysPerWeek` is already a stored `Int` (default 4) — no schema change.
- Add −/+ stepper buttons visually identical to the Total Weeks `NewBlockStepperButton` pattern.
- Clamp to 1...7. Keep "3–6" only as a *recommended-range* helper hint, not the hard limit (or drop if it reads as the allowed range).
- Preview/validation must reflect changes (it already binds via `@Bindable draft`).

### Template selection: bottom sheet (task #3, user's PREFERRED option)
- Replace the permanent inline horizontal chip row with a compact "STARTING POINT" summary row + "CHANGE" action.
- "CHANGE" opens a bottom sheet (`.sheet`) titled **"Start From Template"**, helper text **"Choose a preset or build from scratch."**
- Options (vertical list or wrapping/2-col grid so labels NEVER truncate): Blank, Hypertrophy Meso, Linear Strength, Powerbuilding, Off-Season, Pre-Meet. POWERBUILDING must show in full.
- Selecting applies the preset (per scope rules above), dismisses the sheet, and the summary row shows the selection.

### Declutter / hierarchy (tasks #5, #7)
- Remove the `activeChips` row in `NewBlockNameBand` (the red "WILL ACTIVATE ON SAVE" badge AND the "{n} DAYS / WK" badge). Days/week now lives only in BLOCK SETTINGS — no duplication.
- Selected preset appears once (STARTING POINT row), not duplicated against the name field + a highlighted chip.
- Distinct section headers vs editable content; consistent spacing via the existing `NewBlockScreenTokens` rhythm scale (microGap/tightGap/rowGap/sectionGap); name field stays dominant; template selection clearly secondary.

### Bottom clipping (task #6)
- `NewBlockScreenTokens.scrollBottomInset` is currently 12 while the bottom bar (`bottomActionHeight`) is 60 and overlays the scroll content in a `ZStack(alignment: .bottom)`. Increase the scroll bottom padding to ≈ bottomActionHeight + bottom safe-area inset so the Add Phase dashed slot and last phase row clear the CTA. Read safe-area via a GeometryReader/safeAreaInsets, not a hardcoded guess.

### Bottom action bar (task #8)
- Keep CANCEL left, primary right (existing split layout is acceptable as the intentional primary-split pattern). Ensure balanced tap targets (both full-height, equal width via the existing `maxWidth: .infinity` halves).
- Enabled primary: filled ink bg, white text, "SAVE TEMPLATE ▸" (new) / "SAVE CHANGES ▸" (editing) — already present.
- Disabled primary: legible-but-subtle; keep current muted treatment. Disabled label: "NAME FIRST ↑" only.
- Remove the top-bar "SAVE" affordance only if it now duplicates the bottom CTA confusingly — otherwise leave; orchestrator note: low priority, planner's discretion.

### Tests
- Existing copy/fidelity suites reference CTA strings and structure: `BlockBuilderViewCopyTests`, `NewBlockBuilderFidelityTests`, `ProgramViewFidelityTests`. Update assertions that reference the removed "WILL ACTIVATE ON SAVE" badge / activation behavior, and add coverage for the Days Per Week stepper (increment/decrement/clamp) and `saveIfValid` no longer activating. Keep all suites GREEN.
</decisions>

<specifics>
## Specific Ideas

- Stepper reuse: factor Total Weeks + Days Per Week onto the same `NewBlockStepperButton` so they're visually identical (task #2 acceptance: "control visually matches Total Weeks").
- Days Per Week edit is a direct `draft.daysPerWeek` clamp (1...7) — unlike Total Weeks which edits phase weeks via `adjustTotalWeeks`.
- Bottom sheet detent: medium is fine for 6 short options.
</specifics>

<canonical_refs>
## Canonical References

- `.planning/backlog/block-template-active-split.md` — defines what is deferred to Phase 7 (items #3, #8, #9, #10). This task must NOT implement those.
- `.planning/quick/training-block-spec/spec.md` — originating spec (background only; full template/active split is Phase 7).
- Current implementation: `fitbod/Periodization/BlockBuilderView.swift`, `BlockDraft.swift`, `BlockTemplates.swift`.
</canonical_refs>
