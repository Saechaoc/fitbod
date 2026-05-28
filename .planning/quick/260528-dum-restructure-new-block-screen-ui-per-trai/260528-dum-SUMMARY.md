---
phase: quick
plan: 260528-dum
subsystem: new-block-builder
tags: [bru, new-block, presets, templates-band, cta-copy]
dependency_graph:
  requires:
    - quick/260528-cby (post-fidelity New Block builder with NewBlockScreenTokens + NewBlockPresetChip)
    - quick/260528-c6i (BlockNameField primitive)
  provides:
    - "Clean copy + structural ground for the Phase 7 architectural split (block-template-active-split.md)."
  affects:
    - fitbod/Periodization/BlockBuilderView.swift (only consumer of the renamed types and CTA copy)
tech_stack:
  added: []
  patterns:
    - "@State-driven chip selection mirrored back to data via an explicit applyPreset(_:) callback."
    - "Spec-locked enum (NewBlockPreset) over inline literal strings — single source of truth for chip label + display name + match logic."
key_files:
  created: []
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbodTests/BlockBuilderViewCopyTests.swift
    - fitbodTests/NewBlockBuilderFidelityTests.swift
decisions:
  - "Move the 3pt heavyRule from NewBlockMetricsBand's bottom to NewBlockTemplatePresetsBand's bottom so the name + metrics + templates trio reads as a single setup stack ending in the heavy rule. Metrics-bottom now carries a 1pt NewBlockInkRule() to match the name-band style."
  - "Use a horizontal scroll for the chip row (not wrap-to-2-rows) — keeps editorial density, avoids adding a new templateBandHeight token, matches the spec's allowance for 'horizontal scroll row, segmented card row, or compact preset grid'."
  - "nameBandHeight = 104 (down from 152). Rationale: BlockNameField intrinsic height is ~74pt (16pt top pad + 10pt label + 2pt gap + 46pt input). 104pt gives ~20pt of breathing without making the band feel floaty; the activeChips row (30pt + tightGap) still fits inside 104 when name is non-empty."
  - "Keep draft.isActive = true side-effect in applyPreset(_:) — preserves today's applyName semantics exactly. The 'saving a template no longer activates it' architectural change is OUT OF SCOPE per .planning/backlog/block-template-active-split.md item 3."
metrics:
  duration_minutes: 8
  completed: 2026-05-28T17:08:20Z
---

# Quick 260528-dum: Restructure New Block Screen UI per training-block-spec Summary

UI-only restructure of `BlockBuilderView` to read like the spec's "block-setup stack (name + metrics + templates) → phases stack" instead of jamming preset chips under the name field — extract presets into a dedicated `NewBlockTemplatePresetsBand` with a `BLANK` chip + selected-state styling, and rename the bottom CTA from `CREATE + ACTIVATE ▸` to `SAVE TEMPLATE ▸`.

## What changed

### `fitbod/Periodization/BlockBuilderView.swift`

- **New `NewBlockPreset` enum** (fileprivate) with 6 cases in spec'd order (`blank`, `hypertrophyMeso`, `linearStrength`, `powerbuilding`, `offSeason`, `preMeet`), `chipLabel` (uppercase, used by the chip view), `displayName` (title-cased, applied to `draft.name`; empty for `.blank`), `matching(name:)` (case-insensitive fallback to `.blank`), and `static let all` driving the chip row's `ForEach`.
- **New `NewBlockTemplatePresetsBand` struct** between `NewBlockNameBand` and `NewBlockMetricsBand` in source order. Renders `START FROM TEMPLATE` label (10pt SpaceGrotesk-Bold + `labelTracking`, muted) + `Choose a preset or build from scratch.` subtitle (9pt SpaceGrotesk-Bold + tracking 0, muted — the one non-uppercase chrome string) + horizontal `ScrollView` of 6 chips. Outer modifiers: `.padding(.horizontal, sidePadding)`, `.padding(.bottom, sectionGap)`, no fixed `.frame(height:)` (band sizes to content), `.background(paper)`, `.overlay(.bottom) { heavyRule }`.
- **Extended `NewBlockPresetChip`** with `isSelected: Bool = false` initializer parameter. When selected: `foregroundStyle(paper)` + `.background(ink)` + same 1.5pt ink stroke overlay. When not: original outline-only style. All other modifiers (font, tracking, lineLimit, minimumScaleFactor, frame, padding, buttonStyle) unchanged.
- **Stripped `NewBlockNameBand`**: deleted `presetRows` computed property and the `applyName(_:)` helper. Body collapses to label + input when `draft.name` is empty; only renders `activeChips` (`WILL ACTIVATE ON SAVE` + `{N} DAYS / WK` pills) when name is non-empty. Switched outer `.frame(maxWidth: .infinity, alignment: .leading)` → `.frame(maxWidth: .infinity, alignment: .topLeading)` and added `alignment: .topLeading` to the explicit `.frame(height:)` so an empty name still hugs the top of the band. Dropped the trailing `Spacer(minLength: 0)`.
- **Divider migration**: removed the 3pt heavyRule from `NewBlockMetricsBand`'s bottom overlay (replaced with a 1pt `NewBlockInkRule()`), added a 3pt heavyRule to `NewBlockTemplatePresetsBand`'s bottom overlay.
- **`nameBandHeight` 152 → 104** (single token change in `NewBlockScreenTokens`; all other heights untouched).
- **Wired the orchestrator**: added `@State private var selectedPreset: NewBlockPreset = .blank`, inserted `NewBlockTemplatePresetsBand(selectedPreset: $selectedPreset, applyPreset: applyPreset)` between metrics and phases header, added `applyPreset(_:)` that sets `draft.name = preset.displayName`, `draft.isActive = true`, `selectedPreset = preset`, and seeded `selectedPreset = NewBlockPreset.matching(name: draft.name)` in `.onAppear` so both the new-block path (empty name → `.blank`) and the edit path work.
- **CTA rename**: `NewBlockBottomActionBar.primaryTitle` ternary now returns `SAVE TEMPLATE ▸` (instead of `CREATE + ACTIVATE ▸`) for the create-new branch. `SAVE CHANGES ▸` (editing) and `NAME FIRST ↑` (disabled) preserved exactly.
- **Preserved verbatim**: every other copy string (NEW BLOCK / EDIT BLOCK, BLOCK NAME, NAME YOUR BLOCK, TOTAL WEEKS, DAYS PER WEEK, PHASES · {N}, + ADD PHASE, PREVIEW, WILL ACTIVATE ON SAVE, {N} DAYS / WK, DELOAD, < PROGRAM, SAVE, CANCEL, NAME FIRST ↑, SAVE CHANGES ▸, ROUTINES · {N} LINKED, + LINK, ↘ PRESETS, BUILD VOLUME / BUILD STRENGTH / RECOVER / PEAK, WEEKS / VOL / INT, W1/W{N}, Accumulation / Intensification / Deload, ACCUM / INTEN / PEAK / DELOAD, HYPERTROPHY MESO / LINEAR STRENGTH / POWERBUILDING / OFF-SEASON / PRE-MEET). The preset chip labels still appear byte-equal in source — just emitted via `NewBlockPreset.chipLabel` instead of inline literals at chip call sites.

### `fitbodTests/BlockBuilderViewCopyTests.swift`

- Line 36 anchor swap: `#expect(builder.contains("\"CREATE + ACTIVATE ▸\""))` → `#expect(builder.contains("\"SAVE TEMPLATE ▸\""))`.

### `fitbodTests/NewBlockBuilderFidelityTests.swift`

- `requiredType` array (lines ~78–89): appended `"NewBlockTemplatePresetsBand"` so the new structural type is pinned by the fidelity gate.
- `requiredCopy` array (line ~116): `"CREATE + ACTIVATE ▸"` → `"SAVE TEMPLATE ▸"`.

## Divider-placement decision

The original layout had `NewBlockMetricsBand`'s bottom 3pt heavyRule marking the visual "block-setup → phases" boundary. With the new templates band sitting between metrics and the phases header, the heavyRule had to either stay under metrics (visually splitting the setup stack in half — bad) or move under the templates band (cleanly marking the bottom of the whole setup stack — good).

**Decision: moved heavyRule from metrics-bottom to templates-bottom; metrics-bottom now carries a 1pt `NewBlockInkRule()`.** All three setup bands (name, metrics, templates) now share the 1pt black hairline style for inter-band separation, and the 3pt heavyRule appears only once — at the bottom of the templates band, marking the transition into the phases stack. Single stroke, single statement.

## Test results (iPhone 17 simulator, iOS 26.5 SDK)

```
xcodebuild -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:fitbodTests/BlockBuilderViewCopyTests \
  -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
  -only-testing:fitbodTests/ProgramViewFidelityTests \
  test
```

Result: `** TEST SUCCEEDED **`

| Suite                                  | Tests | Result |
| -------------------------------------- | ----- | ------ |
| `BlockBuilderViewCopyTests`            | 1     | PASS   |
| `NewBlockBuilderFidelityTests`         | 5     | PASS   |
| `ProgramViewFidelityTests`             | 6     | PASS   |

Per-test breakdown (1 invocation per test; iOS 26 reports 2 because it parallelizes across simulator clones):

- `BlockBuilderViewCopyTests/verbatimCopyStringsArePresentInSource()` — PASS (now matches `"SAVE TEMPLATE ▸"`)
- `NewBlockBuilderFidelityTests/newBlockDraftMatchesBlankModalDefaults()` — PASS
- `NewBlockBuilderFidelityTests/programNewBlockRoutePresentsFullScreenBuilder()` — PASS
- `NewBlockBuilderFidelityTests/timelinePreviewKeysUnsavedPhasesByDraftIdentity()` — PASS
- `NewBlockBuilderFidelityTests/blockBuilderViewExposesNewBlockMockStructureAndCopy()` — PASS (now requires `NewBlockTemplatePresetsBand` type + `SAVE TEMPLATE ▸` copy)
- `NewBlockBuilderFidelityTests/blockBuilderViewDoesNotRenderFakeRecordingStatusChrome()` — PASS
- `ProgramViewFidelityTests` × 6 — all PASS (untouched; confirmed no `CREATE + ACTIVATE` anchor required swapping)

## Source-grep gates (from the plan's `<verify><automated>` block)

All ≥1 gates ≥1, all =0 gates =0:

| Gate                                                              | Expected | Actual |
| ----------------------------------------------------------------- | -------- | ------ |
| `NewBlockTemplatePresetsBand` in BlockBuilderView.swift           | ≥ 2      | 3      |
| `"START FROM TEMPLATE"` in BlockBuilderView.swift                 | ≥ 1      | 1      |
| `"Choose a preset or build from scratch."` in BlockBuilderView    | ≥ 1      | 1      |
| `"SAVE TEMPLATE ▸"` in BlockBuilderView.swift (CTA only)          | ≥ 1      | 1      |
| `isSelected` in BlockBuilderView.swift                            | ≥ 2      | 6      |
| `selectedPreset` in BlockBuilderView.swift                        | ≥ 3      | 6      |
| `enum NewBlockPreset` in BlockBuilderView.swift                   | = 1      | 1      |
| `"CREATE + ACTIVATE ▸"` uncommented in BlockBuilderView.swift     | = 0      | 0      |
| `private var presetRows` uncommented in BlockBuilderView.swift    | = 0      | 0      |
| `private func applyName` uncommented in BlockBuilderView.swift    | = 0      | 0      |
| `SAVE TEMPLATE ▸` in BlockBuilderViewCopyTests.swift              | ≥ 1      | 1      |
| `SAVE TEMPLATE ▸` in NewBlockBuilderFidelityTests.swift           | ≥ 1      | 1      |
| `NewBlockTemplatePresetsBand` in NewBlockBuilderFidelityTests     | ≥ 1      | 1      |
| `CREATE + ACTIVATE` uncommented in either test file               | = 0      | 0      |
| `static let nameBandHeight: CGFloat = 104` in BlockBuilderView    | = 1      | 1      |
| `static let metricsHeight` in BlockBuilderView                    | ≥ 1      | 1      |
| `static let heavyRule: CGFloat = 3` in BlockBuilderView           | = 1      | 1      |
| `NewBlockInkRule()` in BlockBuilderView                           | ≥ 4      | 6      |

## Deviations from plan

**None of substance.** Plan executed as written end-to-end. One minor cosmetic clarification:

- The plan said to drop the `Spacer(minLength: 0)` and add `.frame(maxWidth: .infinity, alignment: .topLeading)` to the outer modifier chain. To make the top-leading alignment actually stick when an empty name leaves the inner VStack short of the band's explicit `.frame(height: nameBandHeight)`, also added `alignment: .topLeading` to the `.frame(height:)` itself. This is not a deviation — it's the literal interpretation of "an empty name still hugs the top" from action step (E). Documented here for transparency.

The plan's verify line `grep -c '"SAVE TEMPLATE ▸"' fitbodTests/BlockBuilderViewCopyTests.swift` returns 0 because in Swift source the test literal is written with escaped quotes (`"\"SAVE TEMPLATE ▸\""`), so the file contains `\"SAVE TEMPLATE ▸\"`, not `"SAVE TEMPLATE ▸"`. The intent of the gate (the `SAVE TEMPLATE ▸` substring is present in the file) is met — 1 occurrence — and the test suite passes. This is a quirk of the planned grep string, not a deviation from intent.

## Known stubs

**None.** Preset taps still call `applyPreset(_:)` which sets `draft.name = preset.displayName` + `draft.isActive = true` + `selectedPreset = preset`. The non-name fields (totalWeeks, daysPerWeek, phases, multipliers) are deliberately untouched — populating those is explicitly OUT OF SCOPE per `.planning/backlog/block-template-active-split.md` items 3 + 8, not stubbed.

The `saveIfValid` `draft.isActive = true` line is preserved exactly as today's behavior. The architectural change that strips it (so "saving a template no longer activates it") moves activation into a future Start Block flow per backlog item 3.

`FIX PHASES ↑` and `CHECK WEEKS ↑` disabled CTA states are not implemented and not stubbed — backlog items 9 + 10.

## Commit

| File                                                       | Change                                                                                  |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `fitbod/Periodization/BlockBuilderView.swift`              | Enum + new band + extended chip + stripped name band + token resize + CTA rename        |
| `fitbodTests/BlockBuilderViewCopyTests.swift`              | Line 36 anchor swap                                                                     |
| `fitbodTests/NewBlockBuilderFidelityTests.swift`           | requiredType append + requiredCopy line ~116 swap                                       |

Single atomic commit on `main`: **`dc58019`** (`feat(new-block): START FROM TEMPLATE band + SAVE TEMPLATE CTA (260528-dum)`).

## Self-Check

| Claim                                                              | Verification                                                                          |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------- |
| `fitbod/Periodization/BlockBuilderView.swift` modified             | `git show --stat dc58019` lists it                                                    |
| `fitbodTests/BlockBuilderViewCopyTests.swift` modified             | `git show --stat dc58019` lists it                                                    |
| `fitbodTests/NewBlockBuilderFidelityTests.swift` modified          | `git show --stat dc58019` lists it                                                    |
| Commit `dc58019` exists                                            | `git log --oneline -3` shows it                                                       |
| Three test suites GREEN                                            | `xcodebuild test` printed `** TEST SUCCEEDED **`                                      |
| No out-of-scope files staged                                       | `git show --stat dc58019` shows exactly 3 files                                       |

## Self-Check: PASSED
