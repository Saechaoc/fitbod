---
quick_id: 260528-ejb
status: complete
date: 2026-05-28
tasks_total: 6
tasks_done: 6
---

# Quick Task 260528-ejb — Refactor New Block screen (COMPLETE)

**Status: 6 of 6 tasks committed. Build green; all four named test suites green.**

New Block now saves a reusable INACTIVE template, has an editable Days Per Week stepper, a "Start From Template" bottom sheet, a 4-section layout with no bottom clipping, and a decluttered name band. UI-only — no SwiftData schema changes.

## Commits (on `main`)
| Task | Commit | What |
|------|--------|------|
| 1 | `1ac99ce` | Save inactive (`isActive=false`) + strip New Block activation + delete "WILL ACTIVATE ON SAVE"/days badge row + Hypertrophy Meso phase population |
| 2 | `d1b52cd` | Editable Days Per Week −/+ stepper (reuses `NewBlockStepperButton`), clamp `1...7`; "3–6" hint dropped (didn't fit the 74pt band; CONTEXT permits) |
| 3 | `003d3e3` | Replaced inline preset chips with STARTING POINT summary row + CHANGE → `NewBlockTemplateSheet` (`.sheet`, title "Start From Template", 6 full-width non-truncating rows, `.medium` detent); `NewBlockTemplatePresetsBand` removed; `NewBlockPresetChip` kept |
| 4 | `8f47162` | `NewBlockSettingsSectionHeader` ("BLOCK SETTINGS"); 4-zone order; bottom-clip fix via `GeometryReader` → `.padding(.bottom, bottomActionHeight + geo.safeAreaInsets.bottom + sectionGap)` (runtime, not hardcoded); `draftID` keying preserved |
| 5 | `f2f8622` | Bottom bar polish: balanced full-height halves, `ctaTracking` token (killed bare literal), legible disabled "NAME FIRST ↑"; `SAVE TEMPLATE ▸` / `SAVE CHANGES ▸` / top-bar `SAVE` byte-identical |
| 6 | `0a7ec78` | Tests: removed WILL-ACTIVATE copy anchor (+ added STARTING POINT / Start From Template anchors); flipped fidelity `draft.isActive` → `!isActive`; swapped required-type `NewBlockTemplatePresetsBand` → `NewBlockStartingPointBand`; new `BlockBuilderViewActivationTests` (save-inactive + clamp) |

## Verification (independently re-run by orchestrator)
- `xcodebuild build` → **BUILD SUCCEEDED** (iPhone 17 Pro Max sim; iPhone 16 not installed on this machine).
- `xcodebuild test`, four suites → **TEST SUCCEEDED**, all green:
  - `BlockBuilderViewCopyTests` (1)
  - `NewBlockBuilderFidelityTests` (5) — incl. flipped `newBlockDraftMatchesBlankModalDefaults` + swapped-type `blockBuilderViewExposesNewBlockMockStructureAndCopy`
  - `BlockBuilderViewActivationTests` (3, new) — `newBlockIsInactive`, `savingNewBlockPersistsInactiveBlock`, `daysPerWeekClampsToOneThroughSeven`
  - `ProgramViewFidelityTests` (6)
- Source guards: `isActive = true` 0/0 in New Block files; external activation sites intact (`BlockContextBand.swift:143`, `BlockOverviewScreen.swift:618` — 1 each); badge strings gone; `NewBlockPresetChip` kept.

## Execution notes
- Run as 3 chunked executors (Tasks 2+3, 4+5, 6) on `main`, each told to **skip the large `./CLAUDE.md`** (design rules were in CONTEXT.md). This avoided the context-exhaustion that stalled the original single-executor attempts.
- SourceKit emitted phantom "cannot find type BlockDraft/Block/…" and "No such module 'Testing'" diagnostics throughout the edits; all proved to be index staleness — build + tests compiled clean. Trust xcodebuild over SourceKit here.

## Manual visual check — STILL NEEDS HUMAN EYES (cannot be automated)
Run the New Block screen in Simulator / Xcode Preview and confirm:
1. 4 sections in order: BLOCK NAME → BLOCK SETTINGS → STARTING POINT → PHASES; name field dominant.
2. Days Per Week stepper looks identical to Total Weeks; taps clamp at 1 and 7.
3. CHANGE opens "Start From Template" sheet (helper "Choose a preset or build from scratch.") with 6 options; POWERBUILDING fully visible, no truncation/shrink.
4. Hypertrophy Meso fills name + phases; the other presets set name + days only; Blank clears the name.
5. Last phase row + Add Phase dashed slot fully visible/tappable above the bottom bar (no clipping).
6. Disabled CTA reads "NAME FIRST ↑" (legible-subtle); enabled "SAVE TEMPLATE ▸"; no red "WILL ACTIVATE ON SAVE" badge anywhere.
7. After SAVE TEMPLATE: the block saves as an inactive template; Today/active-block state is unchanged (StartBlockCTA empty state persists until a block is activated elsewhere — intended trade-off).

## Locked scope honored
UI-only, no schema changes. No fabricated phase content for Linear Strength / Powerbuilding / Off-Season / Pre-Meet (name + `daysPerWeek` only; phases only for Hypertrophy Meso). Only the "NAME FIRST ↑" disabled CTA state. Untouched: `BlockOverviewScreen.swift`, `BlockContextBand.swift`, `ProgramView.swift`, `BlockDraft` schema. FIX PHASES / CHECK WEEKS / the template-active split remain deferred to Phase 7 (`.planning/backlog/block-template-active-split.md`).
