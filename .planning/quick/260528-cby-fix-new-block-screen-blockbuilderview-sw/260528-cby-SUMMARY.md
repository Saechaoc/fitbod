---
phase: quick
plan: 260528-cby
subsystem: periodization
tags: [bru, new-block, vertical-rhythm, spacing-tokens, name-field, fidelity]
dependency_graph:
  requires:
    - quick/260527-th4 (BlockNameField tap-to-focus contract)
    - quick/260528-c6i (NewBlockNameBand → BlockNameField extraction; folded into task-2 commit)
  provides:
    - "NewBlockScreenTokens vertical-rhythm scale: microGap=4 / tightGap=6 / rowGap=8 / sectionGap=10"
    - "Single-font 44pt BebasNeue name-field input (no first-keystroke shrink)"
  affects:
    - fitbod/Periodization/BlockNameField.swift
    - fitbod/Periodization/BlockBuilderView.swift
tech_stack:
  added: []
  patterns:
    - "Named-token vertical rhythm — bare CGFloat literals in band internals collapsed to one of 4 NewBlockScreenTokens entries so the whole screen tunes from one place"
key_files:
  created:
    - fitbod/Periodization/BlockNameField.swift  # tracked for the first time; ternary-fixed at commit time
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
decisions:
  - "BlockNameField.swift was untracked in the working tree at task start; committed in Task 1 with the ternary fix already applied (one new tracked file, not 'modified one tracked file')."
  - "Task 2 commit also folds in the pre-existing uncommitted extraction of NewBlockNameBand → BlockNameField from sibling quick task 260528-c6i. The two changes share one BlockBuilderView.swift diff and cannot be split without rewriting history. Flagged as Rule 1 - Plan reconciliation."
metrics:
  duration_minutes: 6
  completed: "2026-05-28T16:02:00Z"
  task_count: 2
  files_touched: 2
  commits: 2
---

# Quick Task 260528-cby: Fix New Block screen (BlockBuilderView + BlockNameField) Summary

**One-liner:** Killed the name-field's first-keystroke 44→39pt font shrink and tightened the whole New Block screen via a named 4-step spacing scale (microGap/tightGap/rowGap/sectionGap) on `NewBlockScreenTokens`.

---

## Files Changed

### `fitbod/Periodization/BlockNameField.swift` (NEW tracked file, 76 lines)

- **TextField `.font(...)`**: ternary `text.isEmpty ? displayLarge : display` → single literal `BlockNameFieldType.displayLarge` (44pt BebasNeue). Placeholder Text already used `displayLarge`; both now share font + baseline so the input is visually quiet on first keystroke.
- 260527-th4 `@FocusState` + `.contentShape(Rectangle())` + `.onTapGesture { isFocused = true }` wiring preserved verbatim.
- Unused `display` (39pt) entry on `BlockNameFieldType` left in place per plan (not in scope for this quick task).

### `fitbod/Periodization/BlockBuilderView.swift` (32 +, 57 −)

Per-band changes (mock-side-by-side):

| Band / Struct | Change |
|---|---|
| `NewBlockScreenTokens` enum | Added 4 named CGFloat constants: `microGap=4`, `tightGap=6`, `rowGap=8`, `sectionGap=10`. |
| `NewBlockNameBand` | `presetRows`/`activeChips` `.padding(.top, 10)` → `.padding(.top, tightGap)` — tighter gap between name field and chip rows. |
| `NewBlockMetricsBand` (col 1: TOTAL WEEKS) | `VStack(spacing: 6)` → `spacing: tightGap`; `.padding(.vertical, 10)` → `sectionGap`. |
| `NewBlockMetricsBand` (col 2: DAYS PER WEEK) | `VStack(spacing: 6)` → `spacing: tightGap`; `.padding(.vertical, 10)` → `sectionGap`. |
| `NewBlockTimelinePreview` | Outer `VStack(spacing: 10)` → `spacing: sectionGap`; `.padding(.top, 14)` → `sectionGap`; `.padding(.bottom, 10)` → `tightGap` — tightens PHASES bar ↔ PREVIEW label ↔ first phase card. |
| `NewBlockPhaseEditorRow` | Outer `VStack(spacing: 14)` → `sectionGap`; header `HStack(spacing: 14)` → `sectionGap`; subtitle `VStack(spacing: 4)` → `microGap` (pulls BUILD VOLUME / BUILD STRENGTH / RECOVER subtitle close to phase title); `.padding(.top, 14)` → `sectionGap`; `.padding(.bottom, 12)` → `rowGap`. |
| `NewBlockPhaseMetricCell` | `Text(label).padding(.top, 6)` → `tightGap`; cell `.padding(.horizontal, 10)` → `sectionGap`. |
| `NewBlockAddPhaseSlot` | Outer `.padding(.horizontal, 12)` → `tightGap`; `.padding(.vertical, 8)` → `microGap` — single biggest visual change; dashed ADD PHASE box now hugs the last phase row. |

**Pre-existing extraction folded in (sibling quick task 260528-c6i):**
- `NewBlockNameBand` body inline `ZStack` + `@FocusState isNameFocused` + helper `nameFont` REPLACED with a single `BlockNameField(title:placeholder:text:)` call. Removed: 39 lines of inlined name-field plumbing in `NewBlockNameBand`. This change was already present as uncommitted working-tree state when the executor started; staging `BlockBuilderView.swift` for Task 2 inherits it.

**Preserved exactly per STEP C:**
- All 10 band heights (`topBarRowHeight`, `nameBandHeight`, `metricsHeight`, `phasesHeaderHeight`, `previewHeight`, `phaseRowHeight`, `metricCellHeight`, `addPhaseSlotHeight`, `bottomActionHeight`, `bottomButtonHeight`).
- Divider thicknesses (`rule = 1`, `heavyRule = 3`) and placements (NewBlockInkRule overlays, in-band vertical rule, bottom heavyRule on metrics band, bottom hair rule on preview + phase rows, top NewBlockInkRule on linked-routines band, top heavyRule on bottom action bar).
- `NewBlockType.display = BebasNeue 39pt` (still consumed by NewBlockMetricsBand TOTAL WEEKS / DAYS PER WEEK numerals).
- Outer `ScrollView`'s `VStack(spacing: 0)` chain — band-to-band gap is owned by each band's fixed height, not by stack spacing.
- All 24+ verbatim copy strings (NEW BLOCK, BLOCK NAME, NAME YOUR BLOCK, TOTAL WEEKS, DAYS PER WEEK, PHASES · N, + ADD PHASE, PREVIEW, BUILD VOLUME / BUILD STRENGTH / RECOVER, WEEKS / VOL / INT, ↘ PRESETS, ROUTINES · N LINKED, + LINK, CANCEL, NAME FIRST ↑, SAVE CHANGES ▸, CREATE + ACTIVATE ▸, < PROGRAM, SAVE, WILL ACTIVATE ON SAVE, {N} DAYS / WK, DELOAD).

---

## Test Results

Build + 3 named test suites run on `iPhone 17` simulator (iOS 26.4 / SDK 26.5):

```
xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:fitbodTests/BlockBuilderViewCopyTests \
  -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
  -only-testing:fitbodTests/ProgramViewFidelityTests \
  test
```

Result: `** TEST SUCCEEDED **`

| Test Suite | Result |
|---|---|
| `BlockBuilderViewCopyTests` | 1/1 passed — `verbatimCopyStringsArePresentInSource()` |
| `NewBlockBuilderFidelityTests` | 5/5 passed — `newBlockDraftMatchesBlankModalDefaults()`, `programNewBlockRoutePresentsFullScreenBuilder()`, `timelinePreviewKeysUnsavedPhasesByDraftIdentity()`, `blockBuilderViewDoesNotRenderFakeRecordingStatusChrome()`, `blockBuilderViewExposesNewBlockMockStructureAndCopy()` |
| `ProgramViewFidelityTests` | 6/6 passed — `bruTabBarCarriesMockupMetrics()`, `programNewUsesBRUActionPopover()`, `programViewRegistersAndUsesMockupFonts()`, `noProgramHeroPinsMockupHeadlineMetrics()`, `programViewUsesCompactMockupChrome()`, `programViewPinsExactMockupCopy()` |

Build succeeded with zero errors. SourceKit emitted no stale "Cannot find type" diagnostics on this pass (the `project_sourcekit_stale_widget_diagnostics` memory was relevant prep, but didn't fire on this edit).

---

## Deviations from Plan

### `[Rule 1 — Plan reconciliation]` BlockNameField.swift was untracked at start

- **Found during:** Task 1 staging step (`git status` showed `?? fitbod/Periodization/BlockNameField.swift`).
- **Issue:** The plan assumes `BlockNameField.swift` is a tracked file with the `text.isEmpty ? displayLarge : display` ternary. In reality the file was untracked — created in working-tree state by sibling quick task `260528-c6i-extract-reusable-blocknamefield-swiftui-`, but never committed.
- **Fix:** Applied Task 1's edit (ternary → single `displayLarge` literal) directly in the working tree, then `git add fitbod/Periodization/BlockNameField.swift` for the first time. Commit shows up as `create mode 100644` instead of a normal modification. End-state code is identical to what the plan asked for.
- **Files modified:** `fitbod/Periodization/BlockNameField.swift` (newly tracked).
- **Commit:** `8f699ac`.

### `[Rule 1 — Plan reconciliation]` Task 2 commit folds in the 260528-c6i extraction

- **Found during:** Task 2 pre-staging review (`git diff fitbod/Periodization/BlockBuilderView.swift`).
- **Issue:** `BlockBuilderView.swift` carried 44 lines of pre-existing uncommitted working-tree changes from sibling quick task 260528-c6i — the extraction of `NewBlockNameBand`'s inlined ZStack into a single `BlockNameField(…)` call. These edits are entangled with the new spacing-token work in the same file; splitting them out would have required a rewrite + stage-by-hunk dance that risked introducing a non-compiling intermediate state.
- **Fix:** Staged `BlockBuilderView.swift` as a single diff — Task 2's commit therefore includes both (a) the extraction and (b) the named-token rhythm pass. The commit message explicitly calls out the folded-in extraction so a future bisect or code-archaeology pass can see what happened.
- **Files modified:** `fitbod/Periodization/BlockBuilderView.swift` (32 insertions, 57 deletions — the deletions are mostly the inlined name-field plumbing being replaced by the `BlockNameField(…)` call).
- **Commit:** `4097d3a`.

### Step-B walkbacks

- **None.** Every Step-B substitution applied as planned. No divider visibly shifted, no band height was tempted, no copy string was touched. The `xcodebuild test` pass was green on the first try.

### Authentication gates

- **None.**

---

## Self-Check: PASSED

**Files exist:**

- `fitbod/Periodization/BlockNameField.swift` — FOUND (76 lines, single 44pt `displayLarge` literal; tracked since commit `8f699ac`).
- `fitbod/Periodization/BlockBuilderView.swift` — FOUND (4 new spacing tokens + 18 token consumption sites; modified by commit `4097d3a`).

**Commits exist:**

- `8f699ac` — FOUND: `fix(new-block): kill name-field font shrink (260528-cby task 1)`
- `4097d3a` — FOUND: `fix(new-block): tighten vertical rhythm via spacing tokens (260528-cby task 2)`

**Plan grep verifiers re-run post-commit:**

- 4 named token constants present in `BlockBuilderView.swift`: OK.
- Token consumption count: 18 (threshold ≥ 10): OK.
- 7 sampled verbatim copy strings (`NEW BLOCK`, `BLOCK NAME`, `NAME YOUR BLOCK`, `TOTAL WEEKS`, `PHASES · `, `+ ADD PHASE`, `CREATE + ACTIVATE ▸`): all present.
- All 10 band height constants intact: OK.
- `rule = 1` / `heavyRule = 3` intact: OK.
- `NewBlockType.display = BebasNeue 39` intact: OK.

**Out-of-scope files (NOT staged in either commit):**

- `.planning/` — untracked, untouched.
- `.claude/` — untracked, untouched.
- `.mcp.json` — untracked, untouched.
- `.repowise/` — untracked, untouched.
- `bru-screens/New-block/`, `bru-screens/New-modal/` — untracked, untouched.
- `fitbod/Design/BRUActionPopover.swift` — untracked, untouched.
- `fitbodUITests/NewBlockModalUITests.swift` — untracked, untouched.

---

## Known Stubs

None. Both files are end-state code: the name-field input has a real backing `@Binding` and the spacing tokens are consumed at real call sites. No placeholder text, no hardcoded empty arrays, no "coming soon" copy was introduced.

---

## Threat Flags

None. This change is pure UI-spacing + font-literal cleanup on an existing form view that has no new network endpoints, no auth path changes, no file access surface, and no schema delta. The `NewBlockScreenTokens` enum stays `fileprivate` to `BlockBuilderView.swift` (no new public API).
