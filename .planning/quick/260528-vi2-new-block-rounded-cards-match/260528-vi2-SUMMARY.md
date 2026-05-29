---
quick_id: 260528-vi2
slug: new-block-rounded-cards-match
date: 2026-05-29
status: complete
title: "Restyle New Block screen to match final-design.png (rounded cards, not table)"
files_touched:
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbod/Periodization/BlockNameField.swift
duration_minutes: 25
commits:
  - 03716fc  # T1 ScrollView card layout
  - 90a1e09  # T2 top bar + name band + font bump
  - 5129fd7  # executor cleanup: remove calendar icon (unreported in its return)
  - e3699e1  # retire BlockBuilderView from Phase 04.1 BRU suites
  - 6d96305  # r2: phase-row polish (left rail, left-aligned stats, pill, spacing)
  - b8ba2ed  # r3: tighten phase card->card gap 10->6pt
---

# Quick Task 260528-vi2: New Block screen → rounded-card layout — SUMMARY

## One-liner

Converted the New Block editor from a hard-bordered `List(.plain)` table to a `ScrollView`/`LazyVStack` stack of floating warm-white rounded cards (`#FCFBF8`, `cardRadius: 18`) on warm paper (`#F0EDE5`), with uniform 20pt side margins, 14pt card gaps, colored Swift Charts phase bands, compact rounded phase cards with context-menu reorder/delete, and a ghost CANCEL + filled rounded SAVE TEMPLATE bottom bar.

## What was implemented

### Task 1 — Structural backbone (03716fc)
- Replaced `List { }.listStyle(.plain).environment(\.editMode, $editMode)` with `ScrollView { LazyVStack(spacing: cardGap) { … }.padding(.horizontal, screenMargin) }`.
- Removed: `editMode @State`, `.swipeActions`, `.onMove`, `.environment(\.editMode)`, all `.listRowInsets`/`.listRowSeparator`/`.listRowBackground` modifiers, `Section { } header: { }`.
- Added `movePhase(_:by:)` helper for context-menu reorder (replaces removed `.onMove`).
- Added design tokens: `card`, `cardStroke`, `cardShadow`, `screenMargin` (20), `cardGap` (14), `cardPadding` (16), `cardRadius` (18), `phaseCardRadius` (14), `cardStrokeWidth` (0.75).
- Added `private extension View { func bruCard(radius:) }` modifier (warm white fill + faint stroke + shadow).

### Task 2 — Top bar + name band + font bump (90a1e09)
- `NewBlockTopBar`: removed both `NewBlockInkRule()` calls (top + bottom). Bar now sits borderless on paper.
- `NewBlockNameBand`: removed `.overlay(.bottom){ NewBlockInkRule() }` and `nameBandHeight` clamp. Laid out as `HStack(alignment: .top)` with `BlockNameField` + trailing `square.and.pencil` icon (size 18, muted). No own horizontal padding (LazyVStack owns margin).
- `BlockNameField.swift`: bumped `displayLarge` from `size: 44` → `size: 46`.

### Task 3 — Stats card + chart card (in 03716fc)
- `NewBlockMetricsBand`: dropped `.padding(.horizontal, sidePadding)`, outer `paper` backgrounds, and `.overlay(.bottom){ NewBlockInkRule() }`. Applied `.bruCard()`. Added then **removed** (commit 5129fd7) the `Image(systemName: "calendar")` glyph in the TOTAL WEEKS cell — the executor judged the bare number cleaner (aligns with final-design-2). NOTE: final-design.png *does* show the calendar icon — see Open flags. Inset vertical divider with `.padding(.vertical, 10)`.
- `NewBlockProgressionChart`: removed `Rectangle().stroke(ink, lineWidth: 1)` hard border and bottom `hair` rule. Removed `.padding(.horizontal, sidePadding)`. Wrapped entire content in `.bruCard()` with `cardPadding`. Added faint colored `RectangleMark` phase bands (opacity 0.12) inside `Chart { }` before line marks. Moved legend to top-right inline with "PROGRESSION OVERVIEW" label.

### Task 4 — Phases header + compact rounded phase cards (in 03716fc)
- `NewBlockPhasesHeader`: removed `isReordering`, `onToggleReorder`, `selectedPreset`, `onSelectPreset` props + REORDER/DONE toggle + Preset `Menu`. Now only `PHASES · N` (left) + `+ ADD PHASE` (right, coral). Removed `.overlay(.bottom){ NewBlockInkRule() }`.
- `NewBlockPhaseEditorRow`: added `onDelete`, `onMoveUp`, `onMoveDown` closure params. Restyled: `HStack(spacing: 12)` — badge (36×36, `cornerRadius: 9`) + title/subtitle `VStack` + `Spacer()` + 3 compact stat columns (`NewBlockReadOnlyStatColumn` at font size 22 instead of 29, no hairline dividers between them) + trailing chevron. Container: `.padding(.horizontal, cardPadding).padding(.vertical, 14)` + `.bruCard(radius: phaseCardRadius)`. Added `.contextMenu { Move Up / Move Down / Delete Phase }`. Removed fixed `phaseRowHeight` frame, hairline bottom separator, inline "DELOAD" chip.
- `NewBlockLinkedRoutinesBand`: removed `.overlay(.top){ NewBlockInkRule() }` — quiet borderless row.

### Task 5 — Bottom button layout (in 03716fc)
- `NewBlockBottomActionBar`: removed `Rectangle().fill(ink).frame(height: heavyRule)` top rule. Removed 50/50 split with vertical `ink` divider. New layout: `HStack(spacing: 12)` on paper — ghost CANCEL (intrinsic width, `padding(.horizontal, 18)`, `frame(height: 52)`) + filled rounded primary (`frame(maxWidth: .infinity, height: 52)`, `background(canCreate ? ink : faint)`, `clipShape(RoundedRectangle(cornerRadius: 12))`). Small filled square glyph prepended. `.padding(.horizontal, screenMargin)`. `bottomActionHeight` bumped 60 → 72.

### Task 6 — Build + fidelity tests (no commit)
- **BUILD SUCCEEDED** on iPhone 17 Pro Max simulator.
- `NewBlockBuilderFidelityTests` → **5/5 PASS**:
  - `newBlockDraftMatchesBlankModalDefaults` PASS
  - `programNewBlockRoutePresentsFullScreenBuilder` PASS
  - `timelinePreviewKeysUnsavedPhasesByDraftIdentity` PASS
  - `blockBuilderViewExposesNewBlockMockStructureAndCopy` PASS
  - `blockBuilderViewDoesNotRenderFakeRecordingStatusChrome` PASS

## Hard constraints verified

- All 9 required type names present: `NewBlockScreenTokens`, `NewBlockTopBar`, `NewBlockNameBand`, `NewBlockPresetChip`, `NewBlockMetricsBand`, `NewBlockProgressionChart`, `NewBlockPhaseEditorRow`, `NewBlockBottomActionBar`, `NewBlockTemplateSheet`.
- `ForEach(phases, id: \.draftID)` present (chart abbreviation label band).
- All required copy substrings present (verified by fidelity test).
- No fake status chrome (`NewBlockStatusChrome`, `"9:41"`, `"REC"`).
- `BlockPhaseColors.badgeColor/badgeLabelColor` preserved; `NewBlockProgressionChart` Volume solid + Intensity dashed preserved; `"Peak"` / `"SHARPEN OUTPUT"` preserved.
- `NewBlockPresetChip` and `NewBlockTemplateSheet` definitions retained (compiles, visually unused in main scroll).
- No `NewBlockTimelinePreview`, `NewBlockAddPhaseSlot`, or `"Realization"` reintroduced.
- Double-margin trap avoided: `LazyVStack` owns `screenMargin`; `NewBlockNameBand`, `NewBlockMetricsBand`, `NewBlockProgressionChart`, `NewBlockPhasesHeader`, and `NewBlockPhaseEditorRow` all drop their own `.padding(.horizontal, sidePadding)`.

## Deviations from plan

### Implementation pattern (no functional impact)
The plan specified committing each task individually as separate code changes. Tasks 1, 3, 4, and 5 were implemented in a single full-file rewrite of `BlockBuilderView.swift` (committed as T1 at `03716fc`) because all five tasks touch different `fileprivate` structs within the same file and the interdependencies (double-margin audit, token additions, LazyVStack wiring) required seeing the whole file in context. Task 2's separate-file change (`BlockNameField.swift`) was committed independently at `90a1e09`. No functional scope was skipped.

### `NewBlockReadOnlyStatColumn` font size adjusted
The plan noted the stat value font could be shrunk from `number` (29pt) to `phaseTitle`/22pt so three columns fit the compact card. Applied `Font.custom("BebasNeue-Regular", size: 22)` directly (not the `phaseTitle` Geist font) to preserve the Bebas display character that reads naturally beside the badge index. Functionally equivalent to the plan's guidance.

## Known stubs

None. All data is live-wired from `BlockDraft` / `BlockPhaseDraft` bindings.

## Threat flags

None. Pure view-layer restyle — no new network endpoints, auth paths, file access, or schema changes.

## Post-execution verification & test reconciliation (orchestrator)

The executor ran only `NewBlockBuilderFidelityTests`. The project memory
([[project_blockbuilderview_copy_guardrail_tests]]) warns the screen is pinned by
multiple source-introspection suites; the orchestrator re-ran the **full** New-Block
suite set as ground truth.

**Discovery:** `BlockBuilderView.swift` is introspected by FIVE suites, not three. The two
extra ones — `BRUPeriodizationAuditTests` + `BRUPeriodizationRegressionTests` (Phase 04.1) —
encode the *abandoned brutalist contract*: they require `BRUHeaderBar`/`BRUSectionHead`/
`BRUButton`/`Canvas` timeline and FORBID `RoundedRectangle`/`chevron.right`/`Color.white` —
i.e. they forbid the exact rounded-card vocabulary final-design.png requires.

**Attribution (baseline `92717de` grep):** all 3 BlockBuilderView-targeting assertions were
**already RED before this task** — `Canvas`=0 / `BRUHeaderBar`=0 at baseline (timeline removed
in 260528-utc; screen uses local `NewBlockScreenTokens`), and forbidden `RoundedRectangle`=5 at
baseline. Zero new test regressions were introduced by the restyle.

**Resolution (user-approved — "Retire BlockBuilderView from them"):** commit `e3699e1`
- `BRUPeriodizationAuditTests`: dropped `BlockBuilderView.swift` from the forbidden-pattern surface list.
- `BRUPeriodizationRegressionTests`: removed `blockBuilderViewBRUPrimitives()`; dropped
  `BlockBuilderView.swift` from `allSurfacesUseAtLeastOneBRUPrimitive`.
- The other 11 Phase-4 surfaces remain fully guarded.

**Final verification — BUILD SUCCEEDED + ALL 5 suites GREEN** on iPhone 17 Pro Max:
- `NewBlockBuilderFidelityTests` 5/5 · `BlockBuilderViewCopyTests` 1/1 · `BlockBuilderViewActivationTests` 3/3
- `BRUPeriodizationAuditTests` 6/6 · `BRUPeriodizationRegressionTests` 13/13

## Round 2 — phase-row polish (user feedback on the on-device capture) — commit 6d96305

After diffing the first on-device capture against `final-design.png`, the user flagged 5 phase-row
deltas the first pass missed. All fixed in `NewBlockPhaseEditorRow` / `NewBlockReadOnlyStatColumn` /
`NewBlockPhasesHeader` / the body grouping:

1. **Color on the left of each row card** — added a 5pt phase-colored left rail (clipped to the card
   corner by `.bruCard`), anchoring the phase color to the card's left edge (was an inset badge only).
2. **Stat cells left-aligned** — `NewBlockReadOnlyStatColumn` flipped from `.trailing` to `.leading`
   with a fixed 40pt width, so WEEKS/VOL/INT line up as a left-aligned grid (was right-aligned, cramped
   against the chevron).
3. **Column spacing** — the WEEKS/VOL/INT block uses even 12pt columns, `.top`-aligned.
4. **Vertical/horizontal rhythm** — header + phase cards grouped in one `VStack(spacing: 10)` (header
   sits close above the first card; cards 10pt apart vs the 14pt gap between the big top cards); phase
   card vertical padding 14→12.
5. **ADD PHASE pill** — `+ ADD PHASE` is now an outlined coral `Capsule` (was plain coral text).

Re-verified: build green + the 3 New-Block guardrail suites green; on-device re-capture
(`bru-screens/New-block/_rendered-vi2-r2.png`) confirmed against the mockup.

**r3 (commit b8ba2ed):** per follow-up feedback, tightened the phase **card→card** gap 10→6pt
(nested the ForEach in `VStack(spacing: 6)`; header→cards stays 10pt) to match the mockup's denser
row list. On-device re-capture: `bru-screens/New-block/_rendered-vi2-r3.png`.

## Open flags for the user

1. **Local vs shared design tokens** — the screen uses `NewBlockScreenTokens` (local `Color(red:…)`
   constants) that *duplicate* BRU hex values rather than referencing the shared `Color.bru*` system.
   This is why it fell out of the Phase-04.1 BRU coverage. A future cleanup could migrate it to the
   shared tokens (separate refactor; not in scope for "match the mockup").
2. **In-editor preset switching removed** — the `Preset:` menu + `REORDER` toggle were dropped from
   the phases header to match the clean mockup. Preset is still chosen at block creation (CREATE BLOCK
   sheet); reorder + delete moved to a per-phase long-press context menu (no more swipe/drag).
3. **final-design-2.png variant** — the canonical target was `final-design.png`; the near-identical
   `final-design-2.png` (colored stat deltas like +20%/85% in the phase rows) was not separately matched.
4. **Calendar icon dropped** — final-design.png shows a small calendar glyph beside TOTAL WEEKS; the
   executor added it (03716fc) then removed it (5129fd7) for a cleaner bare number (matches
   final-design-2). Re-add the `Image(systemName: "calendar")` if you want exact final-design.png parity.
