---
phase: quick
plan: 260528-cby
type: execute
wave: 1
depends_on: []
files_modified:
  - fitbod/Periodization/BlockNameField.swift
  - fitbod/Periodization/BlockBuilderView.swift
autonomous: true
requirements:
  - QUICK-260528-cby-01  # Name field placeholder/typed font shrink fix
  - QUICK-260528-cby-02  # BlockBuilderView vertical-rhythm tightening
must_haves:
  truths:
    - "Tapping the NAME YOUR BLOCK area focuses the text input and shows the cursor."
    - "Typing the first character does NOT shrink the visible text — placeholder and typed text share the same 44pt BebasNeue size and the same baseline."
    - "Vertical gaps across the BlockBuilderView read like the mock: dense editorial layout, not airy cards."
    - "Phase rows (01 / 02 / 03) stack tightly with subtitle close to title and metric boxes close to subtitle."
    - "ADD PHASE dashed box sits close to the last phase row."
    - "All divider lines (1pt black, 3pt heavy, 1pt hair) are preserved exactly — no extra padding above or below them."
    - "All verbatim copy still present (NEW BLOCK, BLOCK NAME, NAME YOUR BLOCK, TOTAL WEEKS, DAYS PER WEEK, PHASES · N, + ADD PHASE, PREVIEW, BUILD VOLUME/BUILD STRENGTH/RECOVER, WEEKS/VOL/INT, ↘ PRESETS, ROUTINES · N LINKED, + LINK, CANCEL, NAME FIRST ↑, SAVE CHANGES ▸, CREATE + ACTIVATE ▸, < PROGRAM, SAVE, WILL ACTIVATE ON SAVE, {N} DAYS / WK, DELOAD)."
  artifacts:
    - path: "fitbod/Periodization/BlockNameField.swift"
      provides: "Single-size 44pt BebasNeue placeholder + typed text (no font swap on keystroke)"
    - path: "fitbod/Periodization/BlockBuilderView.swift"
      provides: "Named NewBlockScreenTokens spacing constants applied consistently across every band/row"
  key_links:
    - from: "BlockNameField.swift — TextField .font(...)"
      to: "BlockNameFieldType.displayLarge (44pt)"
      via: "single font literal, no ternary based on text.isEmpty"
      pattern: "\\.font\\(BlockNameFieldType\\.displayLarge\\)"
    - from: "BlockBuilderView.swift — every VStack/HStack spacing + .padding(.top/.bottom/.vertical) inside a section struct"
      to: "NewBlockScreenTokens spacing constant (microGap / tightGap / rowGap / sectionGap)"
      via: "named-constant reference, not a bare CGFloat literal"
      pattern: "NewBlockScreenTokens\\.(microGap|tightGap|rowGap|sectionGap)"
---

<objective>
Fix the New Block screen (`fitbod/Periodization/BlockBuilderView.swift` + its helper `BlockNameField.swift`) so it matches the bru-screens mock:

1. **Name field — kill the visible font shrink.** Today, the placeholder "NAME YOUR BLOCK" uses BebasNeue 44pt but the typed text falls back to BebasNeue 39pt the instant the user types a character. Both must be 44pt so the band is visually quiet — the bar replaces the placeholder text at the same size and baseline.
2. **Vertical rhythm — tighten the whole screen.** Replace the per-row magic-number paddings (`spacing: 6`, `spacing: 10`, `spacing: 14`, `padding(.top, 14)`, `padding(.bottom, 12)`, etc.) with a small, named spacing scale on the existing `NewBlockScreenTokens` enum (`microGap`, `tightGap`, `rowGap`, `sectionGap`) and apply it consistently across each band so the screen reads like the editorial mock.

Purpose: The screen feels airy and inconsistent today; the named-spacing pass is the lever the user wants to be able to tune the whole layout from one place going forward.
Output: Two modified files, zero new files, all three named test suites GREEN.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md
@.planning/STATE.md

@fitbod/Periodization/BlockBuilderView.swift
@fitbod/Periodization/BlockNameField.swift
@fitbodTests/BlockBuilderViewCopyTests.swift
@fitbodTests/NewBlockBuilderFidelityTests.swift
@fitbodTests/ProgramViewFidelityTests.swift
@.planning/quick/260527-th4-make-name-your-block-field-tappable-text/260527-th4-SUMMARY.md

<interfaces>
<!-- Key source contracts the executor needs. No exploration required. -->

From fitbod/Periodization/BlockNameField.swift (current state — file is small, ~76 lines):
- `fileprivate enum BlockNameFieldType` exposes `label` (SpaceGrotesk-Bold 10), `display` (BebasNeue 39), `displayLarge` (BebasNeue 44).
- `BlockNameField.body` ZStack picks `.font(text.isEmpty ? displayLarge : display)` on the inner `TextField` — this is the ternary that causes the 44→39pt shrink on first keystroke.
- The placeholder `Text(placeholder)` already uses `displayLarge` unconditionally.
- The ZStack already has `.contentShape(Rectangle()).onTapGesture { isFocused = true }` and the inner `TextField` already has `.focused($isFocused)`. The tap/focus wiring from quick task 260527-th4 is intact — do NOT touch focus state, hit-shape, or `@FocusState`.

From fitbod/Periodization/BlockBuilderView.swift (current state — ~873 lines, all section structs fileprivate to this file):
- `NewBlockScreenTokens` enum (≈ line 182) currently holds: paper/ink/muted/hair/faint/signal colors, sidePadding=16, rule=1, heavyRule=3, labelTracking=2.2, chipTracking=2.1, topBarRowHeight=50, nameBandHeight=152, metricsHeight=74, phasesHeaderHeight=36, previewHeight=104, phaseRowHeight=108, metricCellHeight=36, addPhaseSlotHeight=70, bottomActionHeight=60, bottomButtonHeight=54, scrollBottomInset=12.
- `NewBlockType` enum (≈ line 209) holds the font scale; do NOT touch the `display` (39pt) entry — it's still consumed by `NewBlockMetricsBand` for the TOTAL WEEKS / DAYS PER WEEK numerals.
- Scrolling content stack is `VStack(spacing: 0)` (≈ line 38) — band-to-band vertical gap is owned by each band's own `frame(height:)`, `padding(.top:)`, `padding(.bottom:)`, and bottom-aligned `overlay(NewBlockInkRule())`. That is why the dividers don't move when you change a band's internal spacing.
- `NewBlockNameBand` (≈ line 270): `VStack(alignment: .leading, spacing: 0)` → `BlockNameField` → `presetRows` or `activeChips` with `.padding(.top, 10)`. Outer band locked to `nameBandHeight = 152`.
- `NewBlockMetricsBand` (≈ line 367): two `VStack(alignment: .leading, spacing: 6)` columns with `.padding(.vertical, 10)`; band locked to `metricsHeight = 74` + bottom 3pt heavyRule overlay.
- `NewBlockPhasesHeader` (≈ line 454): `phasesHeaderHeight = 36`, bottom 1pt black NewBlockInkRule overlay.
- `NewBlockTimelinePreview` (≈ line 482): `VStack(alignment: .leading, spacing: 10)` with `.padding(.top, 14)` + `.padding(.bottom, 10)`; band locked to `previewHeight = 104` + bottom 1pt hair overlay.
- `NewBlockPhaseEditorRow` (≈ line 579): `VStack(alignment: .leading, spacing: 14)` with header `HStack(alignment: .top, spacing: 14)` + inner title/subtitle `VStack(alignment: .leading, spacing: 4)`; row locked to `phaseRowHeight = 108`, `.padding(.top, 14)`, `.padding(.bottom, 12)` + bottom 1pt hair overlay.
- `NewBlockPhaseMetricCell` (≈ line 644): `VStack(alignment: .leading, spacing: 0)` with `Text(label).padding(.top, 6)`, cell height = `metricCellHeight = 36`.
- `NewBlockAddPhaseSlot` (≈ line 723): outer wrapper `.padding(.horizontal, 12)` + `.padding(.vertical, 8)` + `.frame(height: addPhaseSlotHeight = 70)`. The 8pt vertical padding here is the gap above-and-below the dashed dotted box.

From fidelity tests:
- `BlockBuilderViewCopyTests` (`fitbodTests/BlockBuilderViewCopyTests.swift`) — string-presence anchors only, NO height/spacing/font assertions. Touches `BlockBuilderView.swift` for top-level copy and a separate file `BlockPhaseEditorRow.swift` (NOT modified by this plan) for the WEEKS/VOL/INT row copy on the BlockCard surface. Will stay GREEN as long as all 18 verbatim copy strings remain present.
- `NewBlockBuilderFidelityTests` (`fitbodTests/NewBlockBuilderFidelityTests.swift`) — draft-default + ProgramView route + structure/copy anchors only. NO spacing/font assertions. Will stay GREEN as long as the `NewBlockScreenTokens` + `NewBlockNameBand` + … type names remain present, the 24 verbatim copy strings remain present, and no `NewBlockStatusChrome`/`"9:41"`/`"REC"` is reintroduced.
- `ProgramViewFidelityTests` (`fitbodTests/ProgramViewFidelityTests.swift`) — guards `ProgramView.swift` + `BRUTabBar` height constants. Does NOT read `BlockBuilderView.swift` and is unaffected by this plan.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix Name field font shrink — single-size placeholder + typed text in BlockNameField.swift</name>
  <files>fitbod/Periodization/BlockNameField.swift</files>
  <action>
In `fitbod/Periodization/BlockNameField.swift`, change exactly one site: the `TextField("", text: $text)` inside `BlockNameField.body`. Today its `.font(...)` is a ternary that returns `displayLarge` when empty and `display` (39pt) when typed — replace the ternary with the single literal `.font(BlockNameFieldType.displayLarge)` so typed text renders at 44pt BebasNeue identical to the placeholder.

Do NOT touch: the placeholder `Text(placeholder).font(BlockNameFieldType.displayLarge)` block (already correct), `.textInputAutocapitalization(.words)`, `.foregroundStyle`, `.tint`, `.focused($isFocused)`, `.frame(height: 46)`, the outer ZStack `.contentShape(Rectangle())` or `.onTapGesture { isFocused = true }`. The 260527-th4 tap/focus wiring stays intact.

Do NOT delete the unused `display` entry from `BlockNameFieldType` — leave it in place. Removing it is unrelated cleanup and out of scope for this quick task. (The shared `NewBlockType.display` 39pt entry in `BlockBuilderView.swift` MUST stay — it's consumed by `NewBlockMetricsBand` numerals.)

Verify the placeholder `Text(placeholder)` rendering path is unchanged (still uses `displayLarge`). Verify the ZStack's `alignment: .leading` is unchanged so placeholder + typed text share the same leading baseline.
  </action>
  <verify>
<automated>
cd /Users/chrissaechao/Desktop/fitbod &amp;&amp; \
  grep -c '\.font(BlockNameFieldType\.displayLarge)' fitbod/Periodization/BlockNameField.swift &amp;&amp; \
  ! grep -q 'text\.isEmpty ? BlockNameFieldType\.displayLarge : BlockNameFieldType\.display' fitbod/Periodization/BlockNameField.swift &amp;&amp; \
  grep -q '\.focused(\$isFocused)' fitbod/Periodization/BlockNameField.swift &amp;&amp; \
  grep -q '\.onTapGesture { isFocused = true }' fitbod/Periodization/BlockNameField.swift &amp;&amp; \
  grep -q '\.contentShape(Rectangle())' fitbod/Periodization/BlockNameField.swift
</automated>
Expected: grep count for `displayLarge` is `>= 2` (one for placeholder Text, one for TextField). The ternary substring MUST be absent. `.focused`, `.onTapGesture`, `.contentShape` lines all still present.
  </verify>
  <done>
- TextField's `.font(...)` is a single literal `BlockNameFieldType.displayLarge` (no ternary).
- Placeholder Text still uses `displayLarge`.
- @FocusState wiring untouched (260527-th4 contract preserved).
- Build succeeds and tapping the field on device/sim does not cause a visible font-size shift on the first keystroke.
  </done>
</task>

<task type="auto">
  <name>Task 2: Tighten BlockBuilderView vertical rhythm via named NewBlockScreenTokens spacing constants</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
Do this in one editor pass. Single file. Three logical steps:

**STEP A — Extend `NewBlockScreenTokens`** (the existing fileprivate enum near line 182) with a small, named spacing scale. Add exactly these four entries near the existing CGFloat block (`sidePadding`, `rule`, `heavyRule`, etc.) — do NOT delete or rename anything:

```
static let microGap:   CGFloat = 4
static let tightGap:   CGFloat = 6
static let rowGap:     CGFloat = 8
static let sectionGap: CGFloat = 10
```

(Values chosen as a denser editorial scale than the current ad-hoc `4 / 6 / 10 / 14`; if any divider visibly shifts in the simulator after applying, walk back individual call sites — not these constants.)

**STEP B — Rewrite each section's internal padding/spacing to consume the named constants**, mock-side-by-side. Do these edits exactly:

1. `NewBlockNameBand` (≈ line 270) — `.padding(.top, 10)` on both `presetRows` and `activeChips` → `.padding(.top, NewBlockScreenTokens.tightGap)`. This reduces the gap between the large name field row and the chips row underneath it. Keep `frame(height: nameBandHeight)` and the bottom `NewBlockInkRule()` overlay unchanged.

2. `BlockNameField` is in a separate file (`BlockNameField.swift`) — leave it alone in Task 2. The internal `padding(.top, 16)` between "BLOCK NAME" label and the field is owned there. If the gap still reads too large to the user after Task 2 lands, that's a follow-up; do not change it here without an explicit token-mirror update.

3. `NewBlockMetricsBand` (≈ line 367) — both `VStack(alignment: .leading, spacing: 6)` columns → `spacing: NewBlockScreenTokens.tightGap`. Both `.padding(.vertical, 10)` → `.padding(.vertical, NewBlockScreenTokens.sectionGap)`. Keep `padding(.leading, sidePadding)` / `padding(.trailing, sidePadding)` and the in-band vertical 1pt black divider, the bottom 3pt heavyRule overlay, and `frame(height: metricsHeight)` all unchanged.

4. `NewBlockTimelinePreview` (≈ line 482) — outer `VStack(alignment: .leading, spacing: 10)` → `spacing: NewBlockScreenTokens.sectionGap`. `.padding(.top, 14)` → `.padding(.top, NewBlockScreenTokens.sectionGap)`. `.padding(.bottom, 10)` → `.padding(.bottom, NewBlockScreenTokens.tightGap)`. This tightens the gap between PHASES · N bar and PREVIEW label AND between the preview bar and the first phase card. Keep `frame(height: previewHeight)` and the bottom 1pt hair overlay unchanged.

5. `NewBlockPhaseEditorRow` (≈ line 579) — outer `VStack(alignment: .leading, spacing: 14)` → `spacing: NewBlockScreenTokens.sectionGap`. Header `HStack(alignment: .top, spacing: 14)` → `spacing: NewBlockScreenTokens.sectionGap`. Title/subtitle inner `VStack(alignment: .leading, spacing: 4)` → `spacing: NewBlockScreenTokens.microGap` (pulls subtitle "BUILD VOLUME" / "BUILD STRENGTH" / "RECOVER" closer to phase title). `.padding(.top, 14)` → `.padding(.top, NewBlockScreenTokens.sectionGap)`. `.padding(.bottom, 12)` → `.padding(.bottom, NewBlockScreenTokens.rowGap)`. Keep `frame(height: phaseRowHeight)` and the bottom 1pt hair overlay unchanged.

6. `NewBlockPhaseMetricCell` (≈ line 644) — `Text(label).padding(.top, 6)` → `.padding(.top, NewBlockScreenTokens.tightGap)`. Cell `.padding(.horizontal, 10)` → `.padding(.horizontal, NewBlockScreenTokens.sectionGap)`. Keep `frame(height: metricCellHeight)` unchanged. (The metric cells already render close to the row header — these are token-mirror swaps only, not visual changes.)

7. `NewBlockAddPhaseSlot` (≈ line 723) — outer wrapper `.padding(.horizontal, 12)` → `.padding(.horizontal, NewBlockScreenTokens.tightGap)` (keeps the dashed box visually inset like the mock) and `.padding(.vertical, 8)` → `.padding(.vertical, NewBlockScreenTokens.microGap)`. This is the single biggest visual change in the file: it pulls the dashed ADD PHASE box much closer to the last phase row above it. Keep `frame(height: addPhaseSlotHeight)` and the dashed `Rectangle().stroke(... dash: [7, 4])` overlay unchanged.

**STEP C — DO NOT TOUCH**, even when tempted:
- Any `frame(height: ...)` constant for a band (nameBandHeight, metricsHeight, phasesHeaderHeight, previewHeight, phaseRowHeight, addPhaseSlotHeight, bottomActionHeight, bottomButtonHeight, topBarRowHeight, metricCellHeight). The dividers are anchored to these heights and the user explicitly wants the rules intact.
- Any `NewBlockInkRule()` placement, `Rectangle().fill(NewBlockScreenTokens.ink).frame(height: heavyRule)` overlay, or `.fill(NewBlockScreenTokens.hair).frame(height: rule)` overlay. They are the "1pt black / 3pt heavy / 1pt hair" rules the user wants preserved.
- `NewBlockTopBar`, `NewBlockBottomActionBar`, `NewBlockLinkedRoutinesBand`, `NewBlockPhasesHeader` internals. The vertical rhythm asks don't target these and they're already tight against the 36/50/60pt fixed heights.
- Any verbatim copy string. Every string in the file stays character-for-character identical.
- `NewBlockType` font enum (especially `display = BebasNeue 39pt` consumed by metrics numerals).
- The outer `VStack(spacing: 0)` inside the `ScrollView` (≈ line 38). Inter-band spacing is owned by each band's own `frame(height:)` + bottom divider overlay; do not introduce a positive spacing here.

After the edits, do a single full pass over the file and confirm: every bare CGFloat literal you find in `.padding(.top, N)` / `.padding(.bottom, N)` / `.padding(.vertical, N)` / `VStack(spacing: N)` / `HStack(spacing: N)` inside the listed structs is either (a) a `NewBlockScreenTokens.{microGap|tightGap|rowGap|sectionGap}` reference, (b) intentionally preserved per STEP C (band heights, divider thicknesses), or (c) a literal you decided NOT to touch with a brief inline rationale comment if it surprised you.
  </action>
  <verify>
<automated>
cd /Users/chrissaechao/Desktop/fitbod &amp;&amp; \
  grep -q 'static let microGap:   CGFloat = 4' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q 'static let tightGap:   CGFloat = 6' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q 'static let rowGap:     CGFloat = 8' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q 'static let sectionGap: CGFloat = 10' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  test "$(grep -c 'NewBlockScreenTokens\.\(microGap\|tightGap\|rowGap\|sectionGap\)' fitbod/Periodization/BlockBuilderView.swift)" -ge 10 &amp;&amp; \
  grep -q 'NEW BLOCK' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q 'BLOCK NAME' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q 'NAME YOUR BLOCK' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q 'TOTAL WEEKS' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q 'PHASES · ' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q '+ ADD PHASE' fitbod/Periodization/BlockBuilderView.swift &amp;&amp; \
  grep -q 'CREATE + ACTIVATE ▸' fitbod/Periodization/BlockBuilderView.swift
</automated>

Then run the full build + the three named test suites:

<automated>
cd /Users/chrissaechao/Desktop/fitbod &amp;&amp; \
  xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:fitbodTests/BlockBuilderViewCopyTests \
    -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
    -only-testing:fitbodTests/ProgramViewFidelityTests \
    test 2>&amp;1 | tail -40
</automated>

Expected: build succeeds with zero errors; all three test suites finish with `** TEST SUCCEEDED **`. If the local simulator name is different from `iPhone 17` (the 260527-th4 SUMMARY noted only iPhone 17 family is installed locally — iPhone 16 may not exist on this Mac), the executor should fall back to whatever `xcrun simctl list devices | grep Booted` returns or the iPhone 17 family entry that exists. Do NOT fail this task on a simulator-naming mismatch — flag and retry with an available device.

**Manual visual check (record in SUMMARY, do not block on)**: In `#Preview("New Block — blank")` and `#Preview("New Block — named")`, confirm in Xcode Previews: (a) tapping the field and typing a character does not visually shrink the text, (b) the dashed ADD PHASE box hugs the last phase row, (c) all dividers remain visible at the expected weights, (d) the gap between PHASES · 3 bar and PREVIEW label is noticeably tighter than before. If any divider visibly shifts position relative to the mock, that's a regression — walk back the offending Step-B substitution before committing.
  </verify>
  <done>
- `NewBlockScreenTokens` exposes `microGap`, `tightGap`, `rowGap`, `sectionGap`.
- Every targeted band/row in STEP B references the named constants instead of bare CGFloat literals.
- All three test suites (`BlockBuilderViewCopyTests`, `NewBlockBuilderFidelityTests`, `ProgramViewFidelityTests`) GREEN.
- `xcodebuild build` clean (zero errors, ideally zero warnings).
- Verbatim copy strings all present.
- Dividers and band heights unchanged.
- Xcode Preview shows: no first-keystroke font shrink (Task 1), denser editorial rhythm (Task 2), ADD PHASE box close to last phase row.
  </done>
</task>

</tasks>

<verification>
After both tasks are complete, run the build + the three named test suites once more from a clean state to confirm:

```
cd /Users/chrissaechao/Desktop/fitbod && \
  xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:fitbodTests/BlockBuilderViewCopyTests \
    -only-testing:fitbodTests/NewBlockBuilderFidelityTests \
    -only-testing:fitbodTests/ProgramViewFidelityTests \
    test
```

Expected: `** TEST SUCCEEDED **`, zero failures across all three suites.

Trust `xcodebuild` over any SourceKit "Cannot find type" diagnostic that flashes during the edit pass — per `project_sourcekit_stale_widget_diagnostics` memory, the indexer is known to lag on this file and the build truth is in the simulator run.
</verification>

<success_criteria>
- Name field placeholder and typed text both render at 44pt BebasNeue with zero visible size or baseline shift on first keystroke.
- `NewBlockScreenTokens` enum carries 4 new named spacing constants (`microGap`, `tightGap`, `rowGap`, `sectionGap`) and the targeted bands consume them.
- Vertical rhythm of the screen matches the mock more closely: tighter gaps between BLOCK NAME label, name field, chips row, TOTAL WEEKS / DAYS PER WEEK band, PHASES · 3 bar, PREVIEW label, preview bar, phase rows, subtitle, metric boxes, and ADD PHASE box.
- All divider lines (1pt black, 3pt heavy, 1pt hair) preserved exactly at their existing positions and weights.
- All verbatim copy strings preserved character-for-character.
- `BlockBuilderViewCopyTests`, `NewBlockBuilderFidelityTests`, `ProgramViewFidelityTests` all GREEN.
- `xcodebuild build` clean.
- Two files touched: `fitbod/Periodization/BlockNameField.swift` + `fitbod/Periodization/BlockBuilderView.swift`. No new files. No test rewrites.
</success_criteria>

<output>
Create `.planning/quick/260528-cby-fix-new-block-screen-blockbuilderview-sw/260528-cby-SUMMARY.md` when done. SUMMARY should include: the two file diffs at a glance (one-line description per band touched), the three test suite results, any deviations against this plan (Rule 1 / Rule 3 with rationale), and a one-line note flagging any individual Step-B substitution you walked back during the visual check.
</output>
