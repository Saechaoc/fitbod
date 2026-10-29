---
phase: quick-260610-hcv
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - fitbod/Periodization/BlockBuilderView.swift
autonomous: false
requirements: []
must_haves:
  truths:
    - "Phase row titles render in full without ellipsis on a 393–402pt iPhone (Accumulation / Intensification / Peak / Deload)"
    - "Phase row subtitles render in full without ellipsis (BUILD VOLUME / BUILD STRENGTH / SHARPEN OUTPUT / RECOVER)"
    - "Three stat columns (WEEKS / VOL / INT) with hairline dividers remain visible and left-anchored against the title block"
    - "Chevron, ⋮⋮ drag handle, swipe-to-delete, and tap-to-edit affordances all remain functional"
  artifacts:
    - path: "fitbod/Periodization/BlockBuilderView.swift"
      provides: "NewBlockPhaseEditorRow.cardSurface layout + NewBlockReadOnlyStatColumn + NewBlockPhaseText.subtitle width-tightening edits"
      contains: "NewBlockReadOnlyStatColumn"
  key_links:
    - from: "NewBlockPhaseEditorRow.cardSurface"
      to: "NewBlockReadOnlyStatColumn"
      via: "stat-grid HStack instantiation"
      pattern: "NewBlockReadOnlyStatColumn"
---

<objective>
Fix phase row text cut-off in the New Block phase cards (BlockBuilderView) so the title and subtitle render in full, matching `bru-screens/New-block/final-design.png`.

Purpose: On a 393–402pt iPhone, the title VStack only gets ~38pt because fixed elements (badge, stat trio, chevron, handle, gaps) consume ~282pt of the ~320pt content width. "Intensification" / "BUILD STRENGTH" truncate with ellipsis. Reclaim horizontal space by tightening spacings and shrinking the stat trio so the title block gets enough room.

Output: Width-tightening edits to NewBlockPhaseEditorRow.cardSurface, NewBlockReadOnlyStatColumn, the subtitle Text, and phaseRowDivider — no copy changes, no struct renames, no removed affordances.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

# Target reference image — open before/after to compare against the prescribed layout
bru-screens/New-block/final-design.png

# Source under edit (the only file this plan touches)
@fitbod/Periodization/BlockBuilderView.swift

<recon>
<!-- Ground truth from orchestrator — do NOT re-investigate. -->
DIAGNOSIS: On a 393–402pt iPhone, NewBlockPhaseEditorRow's usable content width is ~320pt.
Fixed elements consume ~282pt: 36pt badge, stat trio (3 dividers + 3×38pt fixed columns + 5×8pt gaps = 157pt),
~9pt chevron, 22pt ⋮⋮ handle, five 12pt HStack gaps + 10pt Spacer minLength. The title VStack gets ~38pt —
"Intensification" (Geist 18 semibold) and subtitle "BUILD STRENGTH" (SpaceGrotesk-Bold 10, tracking 1.2) truncate.

TARGET (final-design.png): full title + subtitle visible, three tight left-anchored stat columns
(WEEKS/VOL/INT) with hairline dividers, chevron at trailing edge. Stat values render smaller than current Bebas 22.
</recon>

<interfaces>
<!-- Exact current source the executor edits. Lines approximate — match on the literal tokens, not line numbers. -->

cardSurface inner content stack (BlockBuilderView.swift ~1388–1452):
- `HStack(alignment: .center, spacing: 12) { ... }` wraps badge + title VStack + Spacer + stat grid + chevron + drag handle
- Title VStack: `Text(NewBlockPhaseText.title(for: draft.kind))` with `.lineLimit(1)` `.minimumScaleFactor(0.75)`
- Subtitle: `Text(NewBlockPhaseText.subtitle(for: draft.kind))` `.font(NewBlockType.label)` `.tracking(1.2)` `.lineLimit(1)`
- `Spacer(minLength: 10)`
- Stat grid: `HStack(alignment: .top, spacing: 8) { phaseRowDivider; NewBlockReadOnlyStatColumn(...) ×3 interleaved }`
- Chevron: `Image(systemName: "chevron.right")`
- Drag handle: `Text("⋮⋮")` `.frame(width: 22, height: 44)` `.highPriorityGesture(reorderGesture)`

NewBlockReadOnlyStatColumn (BlockBuilderView.swift ~1554–1573):
- label Text `.font(NewBlockType.micro)` `.tracking(1.2)`
- value Text `.font(Font.custom("BebasNeue-Regular", size: 22))` `.lineLimit(1)` `.minimumScaleFactor(0.8)`
- container `.frame(width: 38, alignment: .center)`

phaseRowDivider: a vertical hairline currently `height 34` (search for `phaseRowDivider` declaration in the same file).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Tighten phase-row layout to reclaim title width</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
Apply these eight prescribed width-tightening edits to BlockBuilderView.swift. Each is a numeric/modifier tweak — no structural rewrites, no copy changes, no struct renames, no removed affordances.

In `NewBlockPhaseEditorRow.cardSurface`:
1. The inner content `HStack(alignment: .center, spacing: 12)` → change spacing from 12 to 8.
2. `Spacer(minLength: 10)` → change minLength from 10 to 6.
3. The stat-grid `HStack(alignment: .top, spacing: 8)` → change spacing from 8 to 5.
5. The drag-handle `Text("⋮⋮")` `.frame(width: 22, height: 44)` → change width from 22 to 18. KEEP height 44 (touch target). Keep `.highPriorityGesture(reorderGesture)` and `.accessibilityHidden(true)`.
6. The subtitle `Text(NewBlockPhaseText.subtitle(for: draft.kind))` → change `.tracking(1.2)` to `.tracking(0.7)`, and add `.minimumScaleFactor(0.8)` immediately after `.lineLimit(1)`.
7. The title `Text(NewBlockPhaseText.title(for: draft.kind))` keeps its font and existing `.minimumScaleFactor(0.75)` — no change (listed for completeness).

In `NewBlockReadOnlyStatColumn`:
4. Container `.frame(width: 38, alignment: .center)` → change width from 38 to 32. Value Text `Font.custom("BebasNeue-Regular", size: 22)` → change size from 22 to 19. Label Text `.tracking(1.2)` → change to `.tracking(0.8)`.

For `phaseRowDivider`:
8. Find its declaration in BlockBuilderView.swift (the vertical hairline used between stat columns) and change its `height` from 34 to 30 (proportional to the smaller value font).

HARD CONSTRAINTS — source-introspection guardrail tests fail otherwise. Do NOT touch any of these:
- Keep `Text("⋮⋮")`, `Image(systemName: "chevron.right")`, `LongPressGesture`, `DragGesture`, `Button(role: .destructive)`, `commitDelete`, `onReorderBegan`/`onReorderEnded`, `move(fromOffsets:`.
- Keep verbatim copy strings: "Accumulation", "BUILD VOLUME", "Intensification", "BUILD STRENGTH", "Deload", "RECOVER".
- Do NOT rename any NewBlock* struct (NewBlockPhaseEditorRow, NewBlockReadOnlyStatColumn, NewBlockPhaseText, NewBlockType, NewBlockScreenTokens all keep their names).

These are pure SwiftUI layout-constant edits; no new types, no logic, no concurrency surface — Swift 6 strict-concurrency unaffected.
  </action>
  <verify>
    <automated>xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:fitbodTests/NewBlockBuilderFidelityTests -only-testing:fitbodTests/BlockBuilderViewCopyTests -only-testing:fitbodTests/BRUPeriodizationAuditTests -only-testing:fitbodTests/BRUPeriodizationRegressionTests 2>&1 | tail -30</automated>
  </verify>
  <done>
All four suites GREEN in one run (NewBlockBuilderFidelityTests, BlockBuilderViewCopyTests, BRUPeriodizationAuditTests, BRUPeriodizationRegressionTests). Build succeeds. If 'iPhone 17 Pro' is unavailable, list with `xcrun simctl list devices available | grep iPhone` and use the newest Pro model.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
Tightened the New Block phase-row layout (smaller stat trio, reduced inter-element spacing, slightly smaller subtitle tracking + minimumScaleFactor) so the title VStack reclaims ~30–40pt of horizontal space and full titles/subtitles render without ellipsis. All affordances and copy preserved; four source-introspection guardrail suites pass.
  </what-built>
  <how-to-verify>
1. Run the visual UI test that attaches a "New Block blank modal" screenshot:
   `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:fitbodUITests/NewBlockModalUITests/testProgramNewBlockOpensBlankBuilder 2>&1 | tail -20`
2. Extract the attached PNG from the .xcresult (use `xcrun xcresulttool` or locate the attachments dir under DerivedData) and open it.
3. Confirm against `bru-screens/New-block/final-design.png`:
   - Phase row titles render in full — "Intensification" is NOT ellipsized.
   - Subtitles render in full — "BUILD STRENGTH" / "BUILD VOLUME" are NOT ellipsized.
   - Three stat columns (WEEKS / VOL / INT) with hairline dividers are still visible and left-anchored.
   - Chevron sits at the trailing edge; ⋮⋮ handle still present.
4. (Optional sanity) Run the modal in the simulator and add a couple of phases to confirm reorder + swipe-to-delete + tap-to-edit still work.
  </how-to-verify>
  <resume-signal>Type "approved" if titles/subtitles render in full and the layout matches final-design.png, or describe what still truncates/looks off.</resume-signal>
</task>

</tasks>

<verification>
- Build + four source-introspection guardrail suites GREEN (Task 1 automated verify).
- Visual screenshot confirms no ellipsis on titles or subtitles (Task 2 human-verify).
- No copy strings, struct names, or affordances changed (guarded by the audit/copy suites).
</verification>

<success_criteria>
- "Intensification" and "BUILD STRENGTH" (and all other phase titles/subtitles) render in full with no ellipsis on a 393–402pt iPhone.
- Stat trio (WEEKS/VOL/INT) with hairline dividers remains visible and left-anchored; chevron at trailing edge.
- All four guardrail suites pass; reorder/swipe/tap affordances intact.
- Layout matches `bru-screens/New-block/final-design.png`.
</success_criteria>

<output>
Create `.planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/260610-hcv-SUMMARY.md` when done.
</output>
