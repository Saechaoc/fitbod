---
quick_id: 260528-gox
status: complete
date: 2026-05-28
tasks_total: 3
tasks_done: 3
---

# Quick Task 260528-gox — New Block preset selection → "Both" model (COMPLETE)

**Status: 3 of 3 tasks committed. Build green; all three named unit suites green (independently re-run).**

Preset selection is now PRIMARY before the editor and SECONDARY (low-emphasis) inside it. The permanent STARTING POINT / FROM SCRATCH / CHANGE row is gone. UI + light wiring only — no SwiftData schema changes.

## Commits (on `main`)
| Task | Commit | What |
|------|--------|------|
| 1 | `56c10ff` | Shared seam + in-editor SECONDARY: promote `NewBlockPreset` `fileprivate`→`internal`; add `init(draft:editing:initialPreset:)` (applies once via `.task`); delete `NewBlockStartingPointBand` (struct + call site); add low-emphasis "APPLY PRESET" by the PHASES header + repoint "↘ PRESETS" — both open the shared `NewBlockTemplateSheet`; destructive "Apply Preset?" confirm gated on `preset == .hypertrophyMeso && !draft.phases.isEmpty` |
| 2 | `808f28e` | PRIMARY pre-editor flow in ProgramView: `PendingBlockBuilder.newBlock(NewBlockPreset?)`; start-choice sheet "Create New Block / How do you want to start?" (Start From Scratch / Use Preset → "Choose Preset" 6-option list) → seeds draft via `initialPreset:` → preserved `.fullScreenCover(item: $pendingBlockBuilder)`; both New Block entry points rerouted; `ProgramTemplateSection` untouched |
| 3 | `cac8c9c` | Re-anchored `BlockBuilderViewCopyTests` (−STARTING POINT, +APPLY PRESET, +Apply Preset?), `NewBlockBuilderFidelityTests` (requiredType NewBlockStartingPointBand→NewBlockTemplateSheet; +Create New Block), `ProgramViewFidelityTests` (fixed routing assertion+message; +start-choice copy), and `NewBlockModalUITests` (tap Start From Scratch first) |

## Seam (single source of truth)
- Option list = `NewBlockPreset.all`; apply logic = `BlockBuilderView.applyPreset` only. ProgramView never re-implements apply — it picks a preset and hands it to the editor via `initialPreset:`, which the editor applies once on `.task`.
- `NewBlockPreset` promoted to `internal` (file-level, not public). Init dropped `public` (a public init can't expose an internal-typed param) — fine, single module; the other six `BlockBuilderView(...)` call sites use the `nil` default and compile unchanged (build confirms).

## ProgramView sheet→cover sequencing (Task 2 step 6)
`@State stagedBuilder: PendingBlockBuilder?` staging slot: the sheet button sets `stagedBuilder` + dismisses; the start-choice sheet's `onDismiss:` assigns `pendingBlockBuilder = stagedBuilder` then nils it — so the full-screen editor cover fires only after the sheet stack is fully torn down (avoids the iOS present-cover-over-sheet no-op). The preset picker is a nested `.sheet` inside the start-choice content.

## Verification (independently re-run by orchestrator)
- `xcodebuild build` → **BUILD SUCCEEDED** after each code task (iPhone 17 Pro Max sim; iPhone 16 not installed).
- `xcodebuild test` three suites → **TEST SUCCEEDED**: BlockBuilderViewCopyTests (1), NewBlockBuilderFidelityTests (5), ProgramViewFidelityTests (6).
- Source guards: `NewBlockStartingPointBand` gone; `internal enum NewBlockPreset` + `initialPreset:` present; APPLY PRESET / Apply Preset? present; `saveIfValid` keeps `isActive=false`; external activation sites (BlockOverviewScreen:618, BlockContextBand:143) untouched; `.fullScreenCover(item: $pendingBlockBuilder)` preserved.

## Decisions / notes
- "Start From Template" copy anchor KEPT — `NewBlockTemplateSheet` (and its `.navigationTitle("Start From Template")`) survives as the shared in-editor picker.
- Optional Use-Preset XCUITest SKIPPED (documented iOS 26 simulator tap flakiness on List rows). The scratch-path UI test was updated (tap "Start From Scratch" before asserting the editor); UI tests were NOT executed by the executor — run on device when convenient.
- `NewBlockModalUITests.swift` was previously untracked; it's now committed as part of Task 3 (the flow change broke its old assumption, so it's a legitimate test of this feature).
- No RULE deviations beyond the intentional `public`→`internal` init access change.

## Manual check — NEEDS HUMAN EYES (run in Simulator/device)
1. Tap New Block (hero CTA and "+ NEW" → "+ New block") → "Create New Block" sheet appears with "Start From Scratch" + "Use Preset".
2. Start From Scratch → blank editor (3 default phases), no preset UI clutter.
3. Use Preset → "Choose Preset" list, all 6 labels full (POWERBUILDING not truncated) → selecting one seeds the editor (Hypertrophy Meso fills phases; others set name + days).
4. In-editor: low-emphasis "APPLY PRESET" by the PHASES header (and "↘ PRESETS") opens the same picker; applying Hypertrophy Meso over existing phases prompts "Apply Preset? / This will replace your current phases and settings." (Cancel / Apply).
5. No permanent STARTING POINT row anywhere. Saving creates an INACTIVE block.

## Locked scope honored
No schema changes; no fabricated phase content for Linear Strength / Powerbuilding / Off-Season / Pre-Meet; no FIX PHASES / CHECK WEEKS states; activation sites untouched; `ProgramTemplateSection` (the separate "start from a template" list) left as-is.
