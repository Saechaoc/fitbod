---
quick_id: 260528-ejb
type: execute
autonomous: false
files_modified:
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbod/Periodization/BlockDraft.swift
  - fitbodTests/BlockBuilderViewCopyTests.swift
  - fitbodTests/NewBlockBuilderFidelityTests.swift
  - fitbodTests/BlockBuilderViewActivationTests.swift
requirements: [QUICK-260528-ejb]

must_haves:
  truths:
    - "Saving from the New Block screen creates an INACTIVE block (draft.isActive == false); Today tab keeps showing the No-active-block empty state."
    - "The New Block flow never sets isActive=true on any path (default, preset chip, Add-Phase preset)."
    - "Days Per Week has a stepper visually identical to Total Weeks, clamped 1...7, with a recommended-range helper hint only."
    - "Start From Template is a compact STARTING POINT summary row + CHANGE that opens a bottom sheet titled 'Start From Template'; all 6 options (incl. POWERBUILDING) show in full with no truncation."
    - "Selecting a preset sets name + daysPerWeek; only Hypertrophy Meso also populates phases; BLANK clears the name."
    - "The red 'WILL ACTIVATE ON SAVE' badge and the duplicate '{n} DAYS / WK' badge are both gone."
    - "The last phase row and the Add Phase dashed slot clear the bottom action bar (no clipping)."
    - "The only disabled primary-CTA state is 'NAME FIRST', with the up-arrow glyph; no FIX PHASES / CHECK WEEKS states exist."
    - "BlockBuilderViewCopyTests, NewBlockBuilderFidelityTests, ProgramViewFidelityTests + the new activation/stepper tests are all GREEN."
  artifacts:
    - path: "fitbod/Periodization/BlockBuilderView.swift"
      provides: "Restructured 4-section New Block screen (BLOCK NAME / BLOCK SETTINGS / STARTING POINT / PHASES), template bottom sheet, save-inactive."
    - path: "fitbod/Periodization/BlockDraft.swift"
      provides: "newBlock() no longer sets isActive=true."
    - path: "fitbodTests/BlockBuilderViewActivationTests.swift"
      provides: "Coverage for save-inactive + Days Per Week stepper inc/dec/clamp."
  key_links:
    - from: "BlockBuilderView.saveIfValid"
      to: "draft.isActive = false"
      via: "explicit set before draft.save(into:)"
    - from: "STARTING POINT CHANGE action"
      to: "NewBlockTemplateSheet"
      via: ".sheet(isPresented:)"
---

<objective>
Refactor the New Block screen (`fitbod/Periodization/BlockBuilderView.swift` + its fileprivate bands, plus one line in `BlockDraft.swift`) to reduce clutter, fix the Days Per Week control, move template selection into a bottom sheet, adopt template-oriented copy, and stop activating the block on save.

Purpose: Saving from New Block should create a reusable INACTIVE template, not an active block. The screen currently double-renders days/week, shows a misleading red "WILL ACTIVATE ON SAVE" badge, has a read-only Days Per Week, crams template chips inline, and clips the last phase row behind the bottom bar.

Output: A cleaner 4-section screen with an editable Days Per Week stepper, a template bottom sheet, no activation, no clipping, and all named test suites GREEN.

SCOPE GUARDRAILS (LOCKED — do NOT cross):
- NO SwiftData @Model / schema / migration changes. `daysPerWeek` is already a stored Int — editing it is free.
- Do NOT fabricate phase/volume/intensity content for Linear Strength, Powerbuilding, Off-Season, or Pre-Meet. Only Hypertrophy Meso populates phases (via `BlockTemplates.hypertrophy`).
- Do NOT add "FIX PHASES" or "CHECK WEEKS" CTA states. The ONLY disabled CTA label is the existing "NAME FIRST" up-arrow string.
- Do NOT touch the other activation sites: `BlockOverviewScreen.swift:618`, `BlockContextBand.swift:143`. Those remain the way to activate a block.
- Do NOT touch `ProgramView.swift` (its `.fullScreenCover` / `startBlank()` wiring is covered by ProgramViewFidelityTests and is out of scope).
- Keep all new UI in the BRU brutalist idiom already in the file: `NewBlockScreenTokens` (paper/ink/muted/hair/faint/signal), `NewBlockType` fonts (Bebas/SpaceGrotesk/Geist), hard rectangles, no rounded corners. Reuse the `microGap/tightGap/rowGap/sectionGap` rhythm scale — no bare CGFloat literals in new band internals.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/quick/260528-ejb-refactor-new-block-screen-reduce-clutter/260528-ejb-CONTEXT.md
@.planning/backlog/block-template-active-split.md

# Primary edit targets
@fitbod/Periodization/BlockBuilderView.swift
@fitbod/Periodization/BlockDraft.swift
@fitbod/Periodization/BlockTemplates.swift

<interfaces>
BlockDraft (fitbod/Periodization/BlockDraft.swift) — @Observable @MainActor final class:
  var name: String
  var startDate: Date
  var isActive: Bool          // class default false; newBlock() currently flips it true at line 26
  var daysPerWeek: Int        // STORED Int, default 4 — edit freely, NO schema change
  var phases: [BlockPhaseDraft]
  var isValid: Bool           // non-empty trimmed name && !phases.isEmpty
  var totalWeeks: Int         // COMPUTED sum of phase weeks (cannot mismatch — do not try to validate it)
  static func newBlock() -> BlockDraft   // line 26 sets draft.isActive = true (REMOVE that line)
  func save(into: ModelContext)          // persists; the single-active-block fetch is gated on `if isActive`

BlockPhaseDraft init used by presets:
  BlockPhaseDraft(kind: BlockPhaseKind, weeks: Int, volumeMultiplier: Double, intensityMultiplier: Double)

BlockTemplates (fitbod/Periodization/BlockTemplates.swift):
  static let hypertrophy: BlockTemplate   // name "Hypertrophy Meso"; THE ONLY preset with real phase data
                                          // phases: Accum 5w 1.0/0.75, Inten 2w 0.85/0.88, Deload 1w 0.5/0.75
  BlockTemplate.phases: [(kind, weeks, volumeMultiplier, intensityMultiplier)]

Key fileprivate symbols already in BlockBuilderView.swift:
  enum NewBlockScreenTokens   — paper/ink/muted/hair/faint/signal; sidePadding=16; rule=1; heavyRule=3;
                                labelTracking=2.2; chipTracking=2.1; microGap=4; tightGap=6; rowGap=8;
                                sectionGap=10; metricsHeight=74; bottomActionHeight=60; bottomButtonHeight=54;
                                scrollBottomInset=12 (currently too small — clips last row)
  enum NewBlockType           — chrome/chip/label/micro/display/displayLarge/number/phaseIndex/phaseTitle fonts
  enum NewBlockPreset         — .blank/.hypertrophyMeso/.linearStrength/.powerbuilding/.offSeason/.preMeet;
                                .chipLabel, .displayName, static .all, static matching(name:)
  struct NewBlockStepperButton(label:action:) — the minus/plus control to REUSE for Days Per Week
  struct NewBlockNameBand     — holds activeChips (the badge row to delete)
  struct NewBlockMetricsBand  — Total Weeks (stepper) + Days Per Week (read-only "3 to 6") — becomes BLOCK SETTINGS
  struct NewBlockTemplatePresetsBand — inline horizontal chip row to REPLACE with summary row + sheet
  struct NewBlockPresetChip   — the chip view; KEEP this symbol alive (a fidelity test asserts its literal name)
  struct NewBlockBottomActionBar(canCreate:isEditing:onCancel:onPrimary:)
                              — primaryTitle: "NAME FIRST" up-arrow / "SAVE CHANGES" / "SAVE TEMPLATE"
  struct NewBlockAddPhaseSlot(addPhase:addPreset:) — "+ ADD PHASE" / "PRESETS"; addPreset == applyHypertrophyPreset

Caller NOT in scope: ProgramView.swift presents via `.fullScreenCover` + `startBlank()` / `BlockDraft.newBlock()`.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Save inactive, strip activation from the New Block flow, delete the badge row</name>
  <files>fitbod/Periodization/BlockBuilderView.swift, fitbod/Periodization/BlockDraft.swift</files>
  <behavior>
    - After saveIfValid runs on a valid draft, draft.isActive == false (template, not active block).
    - BlockDraft.newBlock() returns a draft with isActive == false.
    - No code path in the New Block flow (default, applyPreset, applyHypertrophyPreset) sets isActive = true.
    - The "WILL ACTIVATE ON SAVE" badge and the days-per-week badge no longer render.
  </behavior>
  <action>
    In `BlockBuilderView.saveIfValid()` change `draft.isActive = true` (line ~123) to `draft.isActive = false`. Keep the rest of the do/catch and `dismiss()` intact.
    In `applyHypertrophyPreset()` remove the `draft.isActive = true` line (line ~133); keep the name + daysPerWeek assignments.
    In `applyPreset(_:)` remove the `draft.isActive = true` line (line ~139); keep name + selectedPreset assignment.
    In `BlockDraft.newBlock()` remove `draft.isActive = true` (line 26); the class default of `false` now stands.
    In `NewBlockNameBand`, delete the `activeChips` computed property AND the `if !draft.name...{ activeChips }` block (lines ~361-393). The name band becomes just the `BlockNameField`. Leave the band frame/background/bottom-rule intact for now; height adjustments are owned by Task 4.
    Do NOT modify BlockOverviewScreen.swift, BlockContextBand.swift, or any other isActive site. Leave `BlockDraft.save(into:)`'s single-active-block fetch unchanged (it is gated on `if isActive` and is simply skipped for templates).
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && grep -nc 'isActive = true' fitbod/Periodization/BlockBuilderView.swift fitbod/Periodization/BlockDraft.swift</automated>
    Expect 0 in both files. Then run: grep -n 'WILL ACTIVATE ON SAVE' fitbod/Periodization/BlockBuilderView.swift (expect no output). Then confirm the two untouched sites still match: grep -n 'isActive = true' fitbod/Periodization/BlockOverviewScreen.swift fitbod/Views/BlockContextBand.swift (expect one match each).
  </verify>
  <done>Both target files free of `isActive = true`; `saveIfValid` sets it false; the activeChips badge row is deleted; the two untouched activation sites still read `isActive = true`.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Days Per Week stepper (reuse NewBlockStepperButton), clamp 1...7</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <behavior>
    - Tapping plus on Days Per Week increments draft.daysPerWeek; tapping minus decrements.
    - daysPerWeek clamps to inclusive 1...7 (minus at 1 stays 1; plus at 7 stays 7).
    - Total Weeks stepper behavior is unchanged (still edits phase weeks via adjustTotalWeeks).
    - The recommended-range hint reads as a recommendation, not the allowed range.
  </behavior>
  <action>
    Add a private method to `BlockBuilderView`: `adjustDaysPerWeek(by delta: Int)` that sets `draft.daysPerWeek = min(7, max(1, draft.daysPerWeek + delta))`. Direct clamp on the stored Int — do NOT route through adjustTotalWeeks (that one edits phase weeks).
    Pass two new closures into `NewBlockMetricsBand`: `decrementDays: { adjustDaysPerWeek(by: -1) }` and `incrementDays: { adjustDaysPerWeek(by: 1) }`. Update the `NewBlockMetricsBand(...)` call site in `body`.
    In `NewBlockMetricsBand`: add `let decrementDays: () -> Void` and `let incrementDays: () -> Void`. In the Days Per Week column, replace the static `Text("3 to 6")` trailing element with the same `HStack(spacing: 6) { NewBlockStepperButton(label: "minus-glyph", action: decrementDays); NewBlockStepperButton(label: "plus", action: incrementDays) }` pattern Total Weeks uses, so the two controls are visually identical. Keep the `\(draft.daysPerWeek)` number in `NewBlockType.display`.
    Recommended-range hint: keep a small muted `NewBlockType.micro` (or .label) text that clearly reads as a recommendation (e.g. "REC 3 to 6"), not a hard limit. If it does not fit cleanly inside the band, drop it entirely (CONTEXT permits dropping it).
    The "BLOCK SETTINGS" section header is owned by Task 4 — do not add it here. Keep Task 2 to the stepper wiring + clamp.
    Use `NewBlockScreenTokens` spacing tokens — no bare literals.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && grep -n 'adjustDaysPerWeek\|incrementDays\|decrementDays' fitbod/Periodization/BlockBuilderView.swift</automated>
    Expect the new method + both closures wired. Build is verified in Task 6's xcodebuild run; inc/dec/clamp behavior is asserted by the new test added in Task 6.
  </verify>
  <done>Days Per Week renders a stepper identical to Total Weeks; `adjustDaysPerWeek(by:)` clamps 1...7; Total Weeks logic untouched.</done>
</task>

<task type="auto">
  <name>Task 3: STARTING POINT summary row + "Start From Template" bottom sheet (no truncation)</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
    Replace the inline `NewBlockTemplatePresetsBand` (the permanent horizontal chip ScrollView) with a compact STARTING POINT summary row + a CHANGE action that opens a `.sheet`.
    Add fileprivate `struct NewBlockStartingPointBand`: section header "STARTING POINT" (muted `NewBlockType.label`, `labelTracking`); a row showing the selected preset label on the left (use `selectedPreset.chipLabel`; for `.blank` show "FROM SCRATCH") and a "CHANGE" button on the right (ink, `NewBlockType.chrome`, `chipTracking`). Hard-rectangle styling, bottom ink/heavy rule consistent with the other bands. Props: `selectedPreset: NewBlockPreset`, `onChange: () -> Void`.
    Add fileprivate `struct NewBlockTemplateSheet`: a NavigationStack (or VStack) titled "Start From Template" with helper text "Choose a preset or build from scratch." Render the 6 `NewBlockPreset.all` options as a VERTICAL list (one full-width row each) so labels NEVER truncate — POWERBUILDING must show in full (do NOT use `lineLimit(1)` + `minimumScaleFactor` shrink like the old chips). Each row: full `preset.chipLabel`, tappable, with a selected-state marker in the BRU idiom (ink fill or check). Selecting a row calls `onSelect: (NewBlockPreset) -> Void` then dismisses. Use `.presentationDetents([.medium])` (CONTEXT: medium is fine for 6 short options). Props: `selected: NewBlockPreset`, `onSelect: (NewBlockPreset) -> Void`.
    In `BlockBuilderView`: add `@State private var presentingTemplateSheet = false`. Replace the `NewBlockTemplatePresetsBand(...)` call in `body` with `NewBlockStartingPointBand(selectedPreset: selectedPreset, onChange: { presentingTemplateSheet = true })`. Attach `.sheet(isPresented: $presentingTemplateSheet) { NewBlockTemplateSheet(selected: selectedPreset, onSelect: { applyPreset($0); presentingTemplateSheet = false }) }`.
    Update `applyPreset(_:)` per CONTEXT scope rules: always set `draft.name = preset.displayName` and `selectedPreset = preset`; set `draft.daysPerWeek` to a recommended value (Hypertrophy Meso = 4; for the 4 undefined presets use 4 and do NOT fabricate phases); for `.hypertrophyMeso` ALSO replace `draft.phases` with drafts built from `BlockTemplates.hypertrophy.phases` (map each tuple into `BlockPhaseDraft(kind:weeks:volumeMultiplier:intensityMultiplier:)`). `.blank` clears the name (displayName is "") and leaves phases untouched, matching today's BLANK behavior. The 4 undefined presets set name + daysPerWeek only and leave existing phases as-is. Do NOT set isActive (already stripped in Task 1).
    Remove the now-unused `NewBlockTemplatePresetsBand`. KEEP the `NewBlockPresetChip` struct definition alive — NewBlockBuilderFidelityTests asserts the literal "NewBlockPresetChip" is present in the file. Prefer reusing `NewBlockPresetChip` (or a non-truncating variant of it) for the sheet rows so the symbol stays live, and ensure the preset label strings "HYPERTROPHY MESO"/"LINEAR STRENGTH"/"POWERBUILDING"/"OFF-SEASON"/"PRE-MEET" remain present (they come free from `NewBlockPreset.chipLabel`).
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && grep -n 'NewBlockStartingPointBand\|NewBlockTemplateSheet\|Start From Template\|presentingTemplateSheet\|struct NewBlockPresetChip' fitbod/Periodization/BlockBuilderView.swift</automated>
    Expect the new band + sheet + state + sheet title present, AND `NewBlockPresetChip` still defined. The no-truncation visual is a MANUAL simulator/preview check (see verification section).
  </verify>
  <done>STARTING POINT row + CHANGE opens a bottom sheet titled "Start From Template" with 6 non-truncating options; applyPreset follows scope rules (phases only for Hypertrophy Meso); NewBlockPresetChip + all preset label strings remain in the file.</done>
</task>

<task type="auto">
  <name>Task 4: Section restructure (BLOCK NAME / BLOCK SETTINGS / STARTING POINT / PHASES) + hierarchy + bottom scroll-padding fix</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
    Reorder the `ScrollView` VStack children in `body` into the 4 locked sections, top to bottom:
      1. BLOCK NAME — `NewBlockNameBand` (name field dominant; badge row already removed in Task 1).
      2. BLOCK SETTINGS — `NewBlockMetricsBand` (Total Weeks + Days Per Week, both steppers after Task 2). Add the "BLOCK SETTINGS" section header treatment here (this task owns it): either a header row above the two-column band or a header label integrated into the band, consistent with the other section headers (muted `NewBlockType.label`, `labelTracking`). Adjust `metricsHeight` (or wrap in a VStack) so the header fits without clipping the steppers.
      3. STARTING POINT — `NewBlockStartingPointBand` (from Task 3).
      4. PHASES — `NewBlockPhasesHeader` + `NewBlockTimelinePreview` + the `ForEach` phase rows + `NewBlockAddPhaseSlot` (+ the conditional `NewBlockLinkedRoutinesBand` and `errorBand` as today).
    Hierarchy: the name field stays the visually dominant element (largest type via `NewBlockType.display`/`displayLarge`); STARTING POINT is clearly secondary (muted header, compact row). Use the `microGap/tightGap/rowGap/sectionGap` rhythm scale for inter-section spacing — no bare CGFloat literals.
    Bottom clipping fix: the bottom bar (`bottomActionHeight = 60`) overlays scroll content in the `ZStack(alignment: .bottom)`, but `scrollBottomInset = 12` is too small and clips the Add Phase dashed slot + last phase row. Read the bottom safe-area inset at runtime (GeometryReader `safeAreaInsets.bottom`, or a safe-area-inset reader) and set the scroll content `.padding(.bottom, ...)` to approximately `bottomActionHeight + safeAreaBottom`. Do NOT hardcode the safe-area value. Replace the static `.padding(.bottom, NewBlockScreenTokens.scrollBottomInset)` (line ~77) accordingly. Acceptance: the Add Phase slot and last phase row are fully visible and tappable, not hidden behind the CTA.
    Do NOT change phase-row order/identity or the timeline keying — `ForEach(phases, id: \.draftID)` must stay (NewBlockBuilderFidelityTests guards it). Keep the "PRESETS" affordance + "+ ADD PHASE" strings in `NewBlockAddPhaseSlot` (fidelity-guarded copy).
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && grep -n 'BLOCK SETTINGS\|STARTING POINT\|safeAreaInsets\|draftID' fitbod/Periodization/BlockBuilderView.swift</automated>
    Expect BLOCK SETTINGS + STARTING POINT headers present, a runtime safe-area read, and the draftID ForEach keying intact. Section order + no-clipping are confirmed by the MANUAL simulator/preview check.
  </verify>
  <done>Body renders the 4 sections in the locked order; BLOCK SETTINGS header present; scroll bottom padding derived from bottomActionHeight + runtime safe-area; phase-row identity keying unchanged.</done>
</task>

<task type="auto">
  <name>Task 5: Bottom action bar polish (balanced tap targets, legible-subtle disabled, SAVE TEMPLATE)</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
    In `NewBlockBottomActionBar`, keep the split layout: CANCEL left, primary right (the intentional primary-split pattern). Both halves stay full-height and equal width via the existing `maxWidth: .infinity` / `maxHeight: .infinity` frames so tap targets are balanced. Keep the center ink divider rule.
    Enabled primary: filled ink background, white text — already present. Labels already correct: "SAVE TEMPLATE" (new) / "SAVE CHANGES" (editing), each with the trailing arrow glyph. Leave these strings byte-identical (fidelity + copy tests anchor them).
    Disabled primary: keep the current muted treatment (paper bg + `NewBlockScreenTokens.muted` text). Verify it reads as legible-but-subtle on the paper background; if it is too faint, nudge to a slightly darker muted token while staying clearly disabled. Disabled label stays exactly "NAME FIRST" with the trailing up-arrow glyph — do NOT add FIX PHASES / CHECK WEEKS.
    Top-bar "SAVE" affordance: per CONTEXT this is planner's discretion / low priority. KEEP the top-bar SAVE button as-is — `BlockBuilderViewCopyTests` and `NewBlockBuilderFidelityTests` both assert the bare "SAVE" string is present, and removing it would break those guards for no scope benefit.
    No bare CGFloat literals — reuse tokens.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && grep -n 'SAVE TEMPLATE\|NAME FIRST\|maxWidth: .infinity' fitbod/Periodization/BlockBuilderView.swift</automated>
    Expect SAVE TEMPLATE + NAME FIRST strings intact and both bar halves using maxWidth .infinity. Legibility of the disabled state is part of the MANUAL visual check.
  </verify>
  <done>Bottom bar keeps CANCEL/primary split with balanced full-height halves; enabled = ink fill + SAVE TEMPLATE; disabled = legible-subtle NAME FIRST only; top-bar SAVE retained.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 6: Update + add tests, then run the build and the named suites GREEN</name>
  <files>fitbodTests/BlockBuilderViewCopyTests.swift, fitbodTests/NewBlockBuilderFidelityTests.swift, fitbodTests/BlockBuilderViewActivationTests.swift</files>
  <behavior>
    - Copy/fidelity guards no longer require the removed badge string and no longer assert the New Block draft is active.
    - New tests pin: saveIfValid produces an inactive block; newBlock() is inactive; adjustDaysPerWeek increments, decrements, and clamps at 1 and 7.
  </behavior>
  <action>
    BlockBuilderViewCopyTests.swift: REMOVE the assertion `#expect(builder.contains("\"WILL ACTIVATE ON SAVE\""))` (line ~33). Leave the rest (NEW BLOCK, BLOCK NAME, NAME YOUR BLOCK, TOTAL WEEKS, DAYS PER WEEK, PHASES, + ADD PHASE, PREVIEW, ROUTINES, NAME FIRST, SAVE TEMPLATE, Couldn't save block, Discard Changes?, Discard, Keep Editing, CANCEL, SAVE) intact — those strings all survive this refactor. Optionally add `#expect(builder.contains("\"STARTING POINT\""))` and `#expect(builder.contains("\"Start From Template\""))` as new copy anchors.
    NewBlockBuilderFidelityTests.swift: in `newBlockDraftMatchesBlankModalDefaults`, change `#expect(draft.isActive)` (line ~36) to `#expect(!draft.isActive)` — the New Block draft is now an inactive template. Keep all other assertions (daysPerWeek == 4, totalWeeks == 5, the 3 phase rows, the required-type list incl. "NewBlockPresetChip", and the required-copy list incl. the 5 preset labels + "PRESETS" + "SAVE TEMPLATE" + "NAME FIRST"). If you renamed/removed `NewBlockTemplatePresetsBand`, swap that entry in the required-type list for the surviving symbol (e.g. "NewBlockStartingPointBand"); do NOT remove "NewBlockPresetChip".
    Create fitbodTests/BlockBuilderViewActivationTests.swift (Swift Testing, `@Suite`, `@testable import fitbod`, `@MainActor` where touching BlockDraft):
      - test: a fresh `BlockDraft.newBlock()` has `isActive == false`.
      - test: build a valid draft (non-empty name + at least one phase), call `draft.save(into:)` on an in-memory ModelContext after setting `isActive = false` (mirroring saveIfValid), then fetch the persisted Block and assert `block.isActive == false`. Use the same in-memory `ModelContainer` pattern as existing model tests (see BlockDraftSaveTests for the container/context setup to copy).
      - test(s): Days Per Week stepper math — assert the clamp directly. Since `adjustDaysPerWeek` is private to the view, replicate its formula in a tiny local helper OR (preferred) drive `draft.daysPerWeek` through the same `min(7, max(1, value + delta))` expression and assert: 7 + 1 clamps to 7; 1 - 1 clamps to 1; 4 + 1 == 5; 4 - 1 == 3. (Keeps coverage at the data layer without exposing private view internals.)
    Then BUILD and TEST. Build: `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` (substitute an installed simulator name from `xcrun simctl list devices available` if iPhone 16 is absent). Run the named suites plus the new one. Confirm all GREEN; if any unrelated suite regresses, fix the cause (do not weaken assertions to pass).
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests/BlockBuilderViewCopyTests -only-testing:fitbodTests/NewBlockBuilderFidelityTests -only-testing:fitbodTests/ProgramViewFidelityTests -only-testing:fitbodTests/BlockBuilderViewActivationTests 2>&1 | tail -40</automated>
    Expect "TEST SUCCEEDED" / all four suites passing. Substitute the simulator name if needed.
  </verify>
  <done>WILL-ACTIVATE assertion removed; fidelity draft assertion flipped to inactive; new activation + stepper-clamp tests added; xcodebuild build succeeds and all four suites are GREEN.</done>
</task>

</tasks>

<verification>
Build + named suites (run after Task 6):
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` succeeds (substitute an available simulator from `xcrun simctl list devices available`).
- BlockBuilderViewCopyTests, NewBlockBuilderFidelityTests, ProgramViewFidelityTests, BlockBuilderViewActivationTests all GREEN.

Source guards (cheap greps):
- `grep -nc 'isActive = true' fitbod/Periodization/BlockBuilderView.swift fitbod/Periodization/BlockDraft.swift` returns 0/0.
- `grep -n 'isActive = true' fitbod/Periodization/BlockOverviewScreen.swift fitbod/Views/BlockContextBand.swift` still returns one match each (untouched activation sites).
- `grep -n 'WILL ACTIVATE ON SAVE\|DAYS / WK' fitbod/Periodization/BlockBuilderView.swift` returns nothing.
- `grep -n 'struct NewBlockPresetChip' fitbod/Periodization/BlockBuilderView.swift` still returns a match (fidelity symbol kept alive).

MANUAL visual check (executor MUST run in Simulator or Xcode Preview and report) — these cannot be automated:
1. New Block screen shows 4 sections in order: BLOCK NAME, BLOCK SETTINGS, STARTING POINT, PHASES. Name field is the dominant element.
2. Days Per Week shows a minus/plus stepper visually identical to Total Weeks; tapping clamps at 1 and 7.
3. CHANGE opens a bottom sheet titled "Start From Template" with helper "Choose a preset or build from scratch." and 6 options; "POWERBUILDING" is fully visible with NO truncation/shrink.
4. Selecting Hypertrophy Meso fills name + phases; selecting another preset sets name + days only; selecting Blank clears the name.
5. The last phase row and the Add Phase dashed slot are fully visible and tappable above the bottom bar (no clipping).
6. Disabled primary CTA reads "NAME FIRST" (up-arrow) and is legible-but-subtle; enabled reads "SAVE TEMPLATE" (arrow). No red "WILL ACTIVATE ON SAVE" badge anywhere.
</verification>

<success_criteria>
- New Block saves an INACTIVE block; no New Block path sets isActive=true; the two external activation sites are untouched.
- Days Per Week is an editable stepper clamped 1...7, visually matching Total Weeks.
- Template selection is a STARTING POINT summary row + "Start From Template" bottom sheet with 6 non-truncating options; presets apply per scope rules (phases only for Hypertrophy Meso).
- The screen is restructured into the 4 locked sections with the name field dominant; the activeChips badge row is gone; nothing clips behind the bottom bar.
- Only the "NAME FIRST" disabled CTA state exists; no schema/model changes were made; no phase content was fabricated for the 4 undefined presets.
- xcodebuild build passes and all four named test suites are GREEN; the manual visual check above is reported by the executor.
</success_criteria>

<output>
Create `.planning/quick/260528-ejb-refactor-new-block-screen-reduce-clutter/260528-ejb-SUMMARY.md` when done.
</output>
