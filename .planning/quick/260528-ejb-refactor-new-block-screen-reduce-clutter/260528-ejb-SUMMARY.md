---
quick_id: 260528-ejb
status: incomplete
date: 2026-05-28
tasks_total: 6
tasks_done: 1
---

# Quick Task 260528-ejb — Refactor New Block screen (PARTIAL)

**Status: 1 of 6 tasks committed. Resume needed.**

## Why partial
The `gsd-executor` agent ran out of context window twice before completing the
plan — this project's `CLAUDE.md` is very large and `BlockBuilderView.swift` is
976 lines, so the executor's baseline + file reads + a full `xcodebuild test`
run do not fit in one executor context. The orchestrator banked Task 1's
(correct, build-plausible) edits directly. Tasks 2–6 remain.

## Done — Task 1 (commit `a532157`)
"Save inactive template + strip New Block activation + delete badge row":
- `BlockDraft.newBlock()` — removed `isActive = true`.
- `BlockBuilderView.saveIfValid()` — `isActive = true` → `false` (saving creates a reusable template, never activates).
- `applyHypertrophyPreset()` — now delegates to `applyPreset(.hypertrophyMeso)`.
- `applyPreset(_:)` — removed `isActive = true`; sets `daysPerWeek = 4`; for `.hypertrophyMeso` populates `draft.phases` from `BlockTemplates.hypertrophy.phases`. (This pulled Task 3's `applyPreset` rewrite forward.)
- `NewBlockNameBand` — deleted the `activeChips` row + computed property (killed "WILL ACTIVATE ON SAVE" badge and the duplicate "{n} DAYS / WK" badge).

**Known transient RED (fix in Task 6):**
- `BlockBuilderViewCopyTests` (~line 33) asserts "WILL ACTIVATE ON SAVE" — string is gone.
- `NewBlockBuilderFidelityTests` (~line 36) asserts `draft.isActive == true` — now `false`.
- Task 1 was NOT build-verified (committed without an xcodebuild run to conserve context). First action on resume: build once to confirm it compiles, then proceed.

## Remaining — Tasks 2–6 (see `260528-ejb-PLAN.md`)
- **Task 2** — Days Per Week −/+ stepper reusing `NewBlockStepperButton`, clamp 1...7; recommended-range hint only. (`daysPerWeek` is a stored Int — no schema change.)
- **Task 3** — STARTING POINT summary row + "Start From Template" bottom sheet (6 options, NO truncation, POWERBUILDING full). NOTE: the `applyPreset` body is already done (Task 1); Task 3 now only needs the summary row + sheet UI + wiring `selectedPreset`/`CHANGE`. Keep `NewBlockPresetChip` symbol + the 5 preset label strings alive (fidelity-test-anchored); reuse the chip for sheet rows.
- **Task 4** — 4-section restructure (BLOCK NAME / BLOCK SETTINGS / STARTING POINT / PHASES) + hierarchy + runtime safe-area scroll-padding fix (`scrollBottomInset` is 12, bar is 60 → Add Phase clips).
- **Task 5** — Bottom action bar polish (balanced tap targets, legible-subtle disabled, "SAVE TEMPLATE ▸"; only "NAME FIRST ↑" disabled state).
- **Task 6** — Update `BlockBuilderViewCopyTests` + `NewBlockBuilderFidelityTests` assertions; add activation test (saveIfValid → isActive false); add Days Per Week stepper test. Build + run `BlockBuilderViewCopyTests`, `NewBlockBuilderFidelityTests`, `ProgramViewFidelityTests` + new suite GREEN.

## Resume guidance (IMPORTANT)
`/gsd-quick resume refactor-new-block-screen-reduce-clutter`, BUT execute in
**small chunks** so the executor doesn't blow its context:
- Chunk A: Tasks 2 + 3 (code) → commit each.
- Chunk B: Tasks 4 + 5 (code) → commit each.
- Chunk C: Task 6 (tests + build) → fresh executor, filter xcodebuild output (`2>&1 | grep -E "error:|Test Suite .*(passed|failed)|Executed [0-9]|\*\* (BUILD|TEST)"`).
- Tell each executor to SKIP reading the large `./CLAUDE.md` (rules are in `260528-ejb-CONTEXT.md`).

## Manual visual check (after Task 6)
- Bottom sheet: POWERBUILDING (and all 6) labels show in full, no truncation.
- Add Phase dashed slot + last phase row are NOT clipped by the bottom CTA.
- Section order reads cleanly: BLOCK NAME → BLOCK SETTINGS → STARTING POINT → PHASES.

## Locked scope (do not drift)
UI-only, NO schema changes. Don't fabricate phase content for Linear Strength /
Powerbuilding / Off-Season / Pre-Meet. Only "NAME FIRST ↑" disabled CTA (no FIX
PHASES / CHECK WEEKS). Don't touch `BlockOverviewScreen.swift`,
`BlockContextBand.swift`, `ProgramView.swift`. See `260528-ejb-CONTEXT.md`.
