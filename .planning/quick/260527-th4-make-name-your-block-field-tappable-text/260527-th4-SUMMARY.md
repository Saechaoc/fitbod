---
status: complete
quick_id: 260527-th4
date: 2026-05-28
commit: 210edb9
---

# Quick Task 260527-th4 — Summary

**Description:** Make "Name your block" field in `BlockBuilderView` feel like a real text input — replace the static-looking `NewBlockNameBand` with a focusable, tap-anywhere-to-focus surface while preserving the BRU brutalist visual.

## Outcome

The `NewBlockNameBand` in `fitbod/Periodization/BlockBuilderView.swift` is now an obviously interactive text input:

- Added `@FocusState private var isNameFocused: Bool` to the band.
- Applied `.focused($isNameFocused)` to the existing `TextField("", text: $draft.name)`.
- Wrapped the inner ZStack with `.contentShape(Rectangle())` + `.onTapGesture { isNameFocused = true }` so taps anywhere on the name row (not just on the invisible TextField rect) raise the keyboard. Preset chips stay independently tappable because the gesture is scoped to the ZStack, not the whole 152pt band.
- Gated the 2×38 ink cursor `Rectangle()` on `if isNameFocused` — appears only when the field has focus, matching standard text-input expectations.

Visual contract preserved end-to-end: muted 44pt BebasNeue "NAME YOUR BLOCK" placeholder, 152pt band height, 39pt typed text, preset chips, and the swap to "WILL ACTIVATE ON SAVE" / "{N} DAYS / WK" chips on non-empty name all unchanged.

## Files changed (in this commit)

Per the user-confirmed scope decision, the commit lumps the pre-existing fidelity-rewrite WIP with the name-band fix in one atomic commit on `main`:

- `fitbod/Periodization/BlockBuilderView.swift` — `NewBlockNameBand` rewrite + the broader BRU brutalist redesign of the full-screen builder.
- `fitbod/Periodization/BlockDraft.swift` — draft-model adjustments for the new-block redesign.
- `fitbod/Periodization/ProgramView.swift` — full-screen presentation route to `BlockBuilderView`.
- `fitbodTests/BlockBuilderViewCopyTests.swift` — updated copy anchors.
- `fitbodTests/ProgramViewFidelityTests.swift` — updated fidelity anchors.
- `fitbodTests/NewBlockBuilderFidelityTests.swift` — new fidelity suite (5 tests) covering draft defaults, full-screen route, timeline draft-id keying, structure/copy presence, and removal of fake status chrome.

Out of scope (intentionally NOT staged): `.claude/`, `.mcp.json`, `.repowise/`, `bru-screens/New-block/`, `bru-screens/New-modal/`, `fitbod/Design/BRUActionPopover.swift`, `fitbodUITests/NewBlockModalUITests.swift`.

## Verification

- `xcodebuild build` (scheme `fitbod`, destination `iPhone 17` Simulator — `iPhone 16` was the plan default but only the iPhone 17 family is installed locally; equivalent SDK target): **PASS**, zero errors, zero warnings.
- `BlockBuilderViewCopyTests` + `NewBlockBuilderFidelityTests`: **6/6 PASS** (run twice across both `fitbodTests` and simulator configs).
- Grep gates: `@FocusState private var isNameFocused` (line 272), `.focused($isNameFocused)` (line 290), `.onTapGesture { isNameFocused = true }` (line 309), `"NAME YOUR BLOCK"` count = 1, `"BLOCK NAME"` count = 1 — **ALL PASS**.
- Human verify in simulator: confirmed by user ("continue" reply after the checkpoint).

## Notes for future sessions

- SourceKit indexer flagged phantom "Cannot find type 'BlockDraft'/'Block'/'BlockPhaseDraft'" errors on the BlockBuilderView edit during the executor pass. These are stale-indexer false positives — `xcodebuild build` succeeded and all tests passed. Matches the known pattern in `project_sourcekit_stale_widget_diagnostics` memory: trust xcodebuild over SourceKit when they disagree.
- One-commit scope was the user's call — the WIP fidelity rewrite was natural-fit context for the name-band fix since both target the same screen. Future quick tasks against this file can safely use the standard pattern (scoped `git add`, single-file commit).

## Commit

`210edb9` — `fix(new-block): name band tappable + full-screen redesign`
