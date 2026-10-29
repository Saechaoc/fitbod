---
quick_id: 260528-gox
type: quick
title: Relocate New Block preset selection to a "Both" model
files_modified:
  - fitbod/Periodization/BlockBuilderView.swift
  - fitbod/Periodization/ProgramView.swift
  - fitbodTests/BlockBuilderViewCopyTests.swift
  - fitbodTests/NewBlockBuilderFidelityTests.swift
  - fitbodTests/ProgramViewFidelityTests.swift
  - fitbodUITests/NewBlockModalUITests.swift

must_haves:
  truths:
    - "Tapping New Block (hero CTA or + NEW popover) first shows a 'Create New Block' start-choice sheet with 'Start From Scratch' and 'Use Preset'."
    - "Start From Scratch opens the editor with a blank BlockDraft.newBlock() draft (3 default phases)."
    - "Use Preset shows the 6-option Choose Preset list; selecting one seeds the draft, then opens the editor."
    - "The editor no longer renders the permanent STARTING POINT row."
    - "The editor exposes a low-emphasis APPLY PRESET action near the PHASES header that reuses the existing preset picker sheet."
    - "Applying a preset in-editor that would replace existing phases (Hypertrophy Meso + non-empty phases) shows a destructive confirm; otherwise applies directly."
    - "Saving still creates an INACTIVE block (draft.isActive stays false)."
  artifacts:
    - path: "fitbod/Periodization/BlockBuilderView.swift"
      provides: "internal NewBlockPreset enum + applyPreset (single source of truth); init(draft:editing:initialPreset:); in-editor APPLY PRESET action; NewBlockStartingPointBand deleted"
      contains: "initialPreset"
    - path: "fitbod/Periodization/ProgramView.swift"
      provides: "pre-editor start-choice sheet that picks a NewBlockPreset (or scratch) before the fullScreenCover"
      contains: "Create New Block"
  key_links:
    - from: "fitbod/Periodization/ProgramView.swift"
      to: "BlockBuilderView(draft:initialPreset:)"
      via: "fullScreenCover passes the chosen preset into the editor init"
      pattern: "initialPreset:"
    - from: "fitbod/Periodization/BlockBuilderView.swift"
      to: "applyPreset"
      via: ".task applies initialPreset once on appear"
      pattern: "applyPreset\\("
---

<objective>
Move New Block preset selection to the user-decided "Both" model:

- PRIMARY (before the editor, in ProgramView): tapping New Block shows a start-choice bottom sheet — "Start From Scratch" (blank draft) or "Use Preset" (the 6 NewBlockPreset options). The full-screen editor cover appears AFTER this choice.
- SECONDARY (inside the editor, in BlockBuilderView): delete the permanent STARTING POINT row + its struct; add a low-emphasis APPLY PRESET action near the PHASES header that reuses the existing NewBlockTemplateSheet picker, with a destructive confirm only when the chosen preset would actually replace existing phases.

Purpose: presets are a starting choice, not permanent editor chrome. The pre-editor sheet makes "scratch vs preset" the first decision; the in-editor action keeps presets reachable without occupying a dedicated section.

Output: a faithful "Both" flow with a SINGLE source of truth for the preset option list + apply logic, no schema changes, all copy/fidelity suites GREEN, and a clean device-installed build + test run.

UI + light wiring only. NO SwiftData @Model / schema / migration changes.
</objective>

<seam_decision>
## Architectural seam (RESOLVED): pass an optional initial preset into BlockBuilderView.init

Chosen: **`init(draft:editing:initialPreset:)`** with `initialPreset: NewBlockPreset? = nil`.

Rationale (verified against the codebase):
- `NewBlockPreset` + `applyPreset(_:)` already live in `BlockBuilderView.swift` and are the only place apply logic exists. Keeping them there preserves ONE source of truth — ProgramView never re-implements apply.
- ProgramView only needs to (a) name the 6 options for its picker and (b) hand the chosen one to the editor. Promoting `NewBlockPreset` from `fileprivate` → `internal` (file-level, NOT `public`) lets ProgramView reference the enum for its picker; the editor still owns apply.
- The editor applies the passed preset exactly once on `.task` (or `.onAppear` guarded by a flag), reusing the same `applyPreset(_:)` the in-editor APPLY PRESET button calls.
- `initialPreset` defaults to `nil`, so the other SIX `BlockBuilderView(...)` call sites (TodayView ×2, BlockPickerMenu, BlockCard, BlockReviewView, RoutinesListView ×2, plus the 2 previews) compile UNCHANGED. Verified: those files reference `pendingBlockBuilder`/comments, never the `NewBlockPreset` symbol — promotion is purely additive.

Rejected alternative (free seeding helper on BlockDraft): would split apply logic across BlockDraft (phase seeding) and BlockBuilderView (chip-selection sync via `selectedPreset`), creating two places that must agree on "what a preset does." The init-param seam keeps it in one method.

Net seam surface: promote `NewBlockPreset` to `internal`, add one optional init param, one `.task` apply call. ProgramView reads `NewBlockPreset.all` for its picker.
</seam_decision>

<context>
@.planning/STATE.md
@.planning/quick/260528-ejb-refactor-new-block-screen-reduce-clutter/260528-ejb-CONTEXT.md

<interfaces>
<!-- Contracts the executor needs — extracted from the codebase. Do NOT re-explore. -->

BlockBuilderView.swift (current — fileprivate symbols to touch):
- `public init(draft: BlockDraft, editing: Block? = nil)` — ADD `initialPreset: NewBlockPreset? = nil`.
- `@State private var selectedPreset: NewBlockPreset = .blank` — stays (drives the picker's checkmark + the in-editor sheet `selected:`).
- `@State private var presentingTemplateSheet = false` — stays (now opened by the new APPLY PRESET action instead of STARTING POINT's CHANGE).
- `fileprivate enum NewBlockPreset: Hashable, CaseIterable` — PROMOTE to `internal enum NewBlockPreset` (drop `fileprivate`). Has: `.blank/.hypertrophyMeso/.linearStrength/.powerbuilding/.offSeason/.preMeet`, `chipLabel`, `displayName`, `static func matching(name:)`, `static let all`.
- `private func applyPreset(_ preset: NewBlockPreset)` — sets `draft.name = preset.displayName`, `draft.daysPerWeek = 4`, `selectedPreset = preset`, and ONLY for `.hypertrophyMeso` maps `BlockTemplates.hypertrophy.phases` into `draft.phases`. Does NOT set isActive. KEEP this exact behavior.
- `private func applyHypertrophyPreset()` — calls `applyPreset(.hypertrophyMeso)`; currently wired to `NewBlockAddPhaseSlot.addPreset`.
- `fileprivate struct NewBlockStartingPointBand` (lines ~438-484) — DELETE entirely (struct + the call site at lines ~54-58).
- `fileprivate struct NewBlockTemplateSheet` — KEEP (the shared picker: title "Start From Template", `ForEach(NewBlockPreset.all)`, calls `onSelect(preset)`).
- `fileprivate struct NewBlockPresetChip` — KEEP (referenced by NewBlockBuilderFidelityTests requiredType list).
- `fileprivate struct NewBlockPhasesHeader { let phaseCount: Int; let addPhase: () -> Void }` — the PHASES header where the new APPLY PRESET action belongs.
- `fileprivate struct NewBlockAddPhaseSlot { let addPhase; let addPreset }` — currently renders "↘ PRESETS" wired to applyHypertrophyPreset.
- `saveIfValid()` sets `draft.isActive = false` then `draft.save(into: ctx)` — KEEP (do not reintroduce isActive=true).
- Tokens to use (NO bare CGFloat literals in new band internals): `NewBlockScreenTokens.paper/ink/muted/hair/faint/signal`, `.microGap(4)/.tightGap(6)/.rowGap(8)/.sectionGap(10)`, `.sidePadding(16)`, `.labelTracking(2.2)/.chipTracking(2.1)`, `.rule(1)/.heavyRule(3)`. Fonts: `NewBlockType.chrome/chip/label/micro`.

ProgramView.swift (current — entry point to touch):
- `@State private var pendingBlockBuilder: PendingBlockBuilder? = nil` — stays; `.fullScreenCover(item: $pendingBlockBuilder)` STAYS (tests anchor it).
- `private enum PendingBlockBuilder: Identifiable { case newBlock; case template(BlockTemplate) }` — its cover body builds `BlockBuilderView(draft: BlockDraft.newBlock())` / `BlockBuilderView(draft: BlockDraft(template:))`. This is where `initialPreset:` gets threaded through.
- `private func startBlank()` sets `pendingBlockBuilder = .newBlock` — currently called by BOTH NoProgramHero's defineAction AND the "+ New block" popover item. Both must now route through the start-choice sheet first.
- `ProgramTemplateSection` + `ProgramView.templatePresets` (4 hardcoded `BlockTemplate` rows: Hypertrophy meso / Linear strength / Powerbuilding / 5-3-1) — this is a SEPARATE existing surface (the "Or start from a template" list). DO NOT conflate it with the 6 NewBlockPreset options or remove it. Leave it as-is.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Promote the preset seam, delete STARTING POINT, add in-editor APPLY PRESET (BlockBuilderView)</name>
  <files>fitbod/Periodization/BlockBuilderView.swift</files>
  <action>
This task establishes the shared seam (so ProgramView can use it in Task 2) and does the SECONDARY in-editor changes.

1. Promote the seam: change `fileprivate enum NewBlockPreset` to `internal enum NewBlockPreset` (just drop the `fileprivate` keyword — the rest of the enum is unchanged). Required so ProgramView's picker (Task 2) can reference `NewBlockPreset.all` without duplicating the option list.

2. Add the init param: change the initializer to `public init(draft: BlockDraft, editing: Block? = nil, initialPreset: NewBlockPreset? = nil)`. Store it in a private let (e.g. `private let initialPreset: NewBlockPreset?`). The `nil` default keeps the other six call sites compiling (verified: TodayView, BlockPickerMenu, BlockCard, BlockReviewView, RoutinesListView, previews — none pass it).

3. Apply the initial preset once: add a `.task` modifier on the NavigationStack body (alongside the existing `.onAppear`) that, if `initialPreset != nil` and it is not `.blank`, calls `applyPreset(initialPreset!)`. Use a `@State private var didApplyInitialPreset = false` guard so it runs exactly once. (`.blank` means "from scratch" — no seeding; the editor already shows BlockDraft.newBlock() defaults.) Keep the existing `.onAppear` `selectedPreset = NewBlockPreset.matching(name:)` logic — when an initialPreset is applied, applyPreset already sets selectedPreset, so ordering is fine; if the onAppear matching overrides it, gate the matching call behind `initialPreset == nil`.

4. DELETE the permanent STARTING POINT section: remove the `NewBlockStartingPointBand(...)` call (the block at lines ~54-58 in body) AND delete the entire `fileprivate struct NewBlockStartingPointBand` (lines ~438-484). The "STARTING POINT" / "FROM SCRATCH" / "CHANGE" surface is gone.

5. Add the in-editor APPLY PRESET action near the PHASES header: extend `NewBlockPhasesHeader` to take an `applyPreset: () -> Void` closure and render a small, LOW-EMPHASIS "APPLY PRESET" button between the "PHASES · N" label and the "+ ADD PHASE" button (keep + ADD PHASE present and dominant). Style it muted: `NewBlockType.label` (or `.chip`), `foregroundStyle(NewBlockScreenTokens.muted)`, `tracking(NewBlockScreenTokens.chipTracking)`, no filled background — clearly secondary to + ADD PHASE. Use only token spacing (no bare CGFloat literals). Wire its action in the body to a new `private func presentPresetPicker()` that sets `presentingTemplateSheet = true`.
   - The existing `↘ PRESETS` button inside `NewBlockAddPhaseSlot` (wired to applyHypertrophyPreset): KEEP the `↘ PRESETS` string and the slot (NewBlockBuilderFidelityTests anchors "↘ PRESETS"), but REPOINT its `addPreset` action to ALSO open the shared picker via `presentPresetPicker()` instead of jumping straight to Hypertrophy. (Change the `addPreset:` closure passed to NewBlockAddPhaseSlot from `applyHypertrophyPreset` to `presentPresetPicker`. Then delete the now-unused `applyHypertrophyPreset` helper to avoid a warning, OR keep it — your call.) Both the header APPLY PRESET and the slot's ↘ PRESETS now open the same NewBlockTemplateSheet.

6. Destructive confirm on in-editor apply: the `.sheet(isPresented: $presentingTemplateSheet)` currently calls `applyPreset(preset)` directly in `onSelect`. Change `onSelect` so it does NOT apply immediately. Instead:
   - Compute the predicate: a preset would REPLACE existing work only when `preset == .hypertrophyMeso && !draft.phases.isEmpty` (per LOCKED scope, ONLY Hypertrophy Meso repopulates phases; other presets set name + daysPerWeek and leave phases untouched, so they never destroy phase work). Put it in a `private func presetWouldReplacePhases(_:) -> Bool` for clarity.
   - If true: dismiss the sheet, stash the pending preset in `@State private var pendingPresetToApply: NewBlockPreset? = nil`, set `@State private var presentingApplyPresetConfirm = true`.
   - Otherwise: apply directly (`applyPreset(preset)`) and dismiss.
   - Add a `.confirmationDialog("Apply Preset?", isPresented: $presentingApplyPresetConfirm, titleVisibility: .visible)` with message "This will replace your current phases and settings." (via the `message:` closure or a Text, mirroring the existing "Discard Changes?" dialog), a `Button("Apply", role: .destructive) { if let p = pendingPresetToApply { applyPreset(p) }; pendingPresetToApply = nil }`, and a `Button("Cancel", role: .cancel) { pendingPresetToApply = nil }`.

Do not touch: saveIfValid (isActive stays false), the bottom action bar copy, BlockDraft, BlockTemplates, activation sites. No schema changes.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && B=fitbod/Periodization/BlockBuilderView.swift; rg -q "internal enum NewBlockPreset" "$B" && rg -q "initialPreset:" "$B" && rg -q "applyPreset\(" "$B" && rg -q "Apply Preset\?" "$B" && rg -q "This will replace your current phases" "$B" && rg -q "APPLY PRESET" "$B" && rg -q "↘ PRESETS" "$B" && rg -q "draft.isActive = false" "$B" && ! rg -q "NewBlockStartingPointBand" "$B" && ! rg -q "fileprivate enum NewBlockPreset" "$B" && echo TASK1_GREP_OK</automated>
  </verify>
  <done>NewBlockPreset is internal; init accepts initialPreset (default nil); NewBlockStartingPointBand struct + its call site are gone; an in-editor APPLY PRESET action opens the shared NewBlockTemplateSheet; the ↘ PRESETS slot opens the same sheet; selecting Hypertrophy Meso with non-empty phases routes through an "Apply Preset?" destructive confirm while other presets apply directly; saveIfValid still sets isActive=false. Grep gate prints TASK1_GREP_OK.</done>
</task>

<task type="auto">
  <name>Task 2: Pre-editor start-choice sheet (ProgramView)</name>
  <files>fitbod/Periodization/ProgramView.swift</files>
  <action>
Depends on Task 1 (NewBlockPreset must be internal). This is the PRIMARY pre-editor flow.

1. Thread the preset into the cover: extend `PendingBlockBuilder` so the blank/preset path carries an optional `NewBlockPreset`. Simplest faithful approach: change `case newBlock` to `case newBlock(NewBlockPreset?)` (or add `case preset(NewBlockPreset)` alongside `newBlock`). In `.fullScreenCover(item: $pendingBlockBuilder)`, the blank/preset case builds `BlockBuilderView(draft: BlockDraft.newBlock(), initialPreset: chosenPreset)` — pass the carried preset (nil for scratch). Keep the `.template(BlockTemplate)` case unchanged (it uses `BlockDraft(template:)` and does NOT take a preset). Update the enum's `id` to stay unique per case (include the preset rawValue/displayName or a stable string). `.fullScreenCover(item: $pendingBlockBuilder)` MUST remain (ProgramViewFidelity + NewBlockBuilderFidelity anchor that exact string).

2. Add the start-choice state: `@State private var presentingStartChoice = false` and `@State private var presentingPresetPicker = false` (a two-step flow: start-choice → optional preset list). Do NOT immediately set pendingBlockBuilder from the hero/popover anymore.

3. Re-route the two New Block entry points to the start-choice sheet:
   - `NoProgramHero(defineAction: { ... })` → set `presentingStartChoice = true` (instead of `startBlank()`).
   - The "+ New block" `BRUActionPopoverItem` action → `showingNewPopover = false` then `presentingStartChoice = true` (instead of `startBlank()`).
   - You may keep a `startBlank()` helper that now sets the start-choice flag, OR replace callers directly. The "+ New routine" popover item and `startNewRoutine()` are UNCHANGED. The separate `ProgramTemplateSection` rows are UNCHANGED.

4. Build the start-choice sheet — `.sheet(isPresented: $presentingStartChoice)` presenting a small BRU-idiom view (a fileprivate `NewBlockStartChoiceSheet` struct in this file, OR an inline NavigationStack). Required copy (testable source strings):
   - Title: "Create New Block"
   - Prompt: "How do you want to start?"
   - Choice 1: "Start From Scratch" + subtitle "Build your own phases manually." → on tap: stage the blank path (no preset) and dismiss; present the editor cover after dismissal.
   - Choice 2: "Use Preset" + subtitle "Start from Hypertrophy, Strength, Powerbuilding, etc." → on tap: transition to the preset list (set `presentingPresetPicker = true`; a second `.sheet(isPresented: $presentingPresetPicker)` is acceptable).
   Use ProgramScreenTokens (screenBackground/ink/muted) + the existing Program typography (SpaceGrotesk-Bold / Geist). Hard rectangles, no rounded chrome. No bare magic numbers where a ProgramScreenTokens value exists.

5. Build the preset list step — present the 6 `NewBlockPreset.all` options (reachable now the enum is internal). Title: "Choose Preset". Render each as a full-width row using `preset == .blank ? "FROM SCRATCH" : preset.chipLabel` (all 6 labels show, POWERBUILDING in full, no truncation — `lineLimit(1)` + `minimumScaleFactor` only as a safety net). On selecting a row: stage `pendingBlockBuilder = .newBlock(preset)` (preset path) so the editor seeds via Task 1's `.task` applyPreset; dismiss both sheets. (You may copy the visual ROW chrome from BlockBuilderView's NewBlockTemplateSheet, but since that struct is fileprivate to its file, build a local equivalent here — duplicating ~20 lines of row chrome is fine; the APPLY LOGIC stays single-sourced in BlockBuilderView.applyPreset via the initialPreset seam. Do NOT duplicate applyPreset.)

6. Sheet/cover sequencing: the start-choice + preset sheets must fully dismiss before the `.fullScreenCover` editor appears (presenting a fullScreenCover while a sheet is up can no-op on iOS). Clean pattern: stash the chosen builder in `@State private var stagedBuilder: PendingBlockBuilder?` inside the sheet button, dismiss the sheet, then assign `pendingBlockBuilder = stagedBuilder` from the sheet's `.onDisappear` (or via `presentingStartChoice`/`presentingPresetPicker` going false). State which pattern you used in the SUMMARY.

Do not touch: ResumeWorkoutBanner, ProgramChromeHeader, the chip flow, ProgramTemplateSection rows/presets, BlockBuilderView (Task 1 owns it). No schema changes.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && P=fitbod/Periodization/ProgramView.swift; rg -q "Create New Block" "$P" && rg -q "How do you want to start\?" "$P" && rg -q "Start From Scratch" "$P" && rg -q "Use Preset" "$P" && rg -q "Choose Preset" "$P" && rg -q "NewBlockPreset" "$P" && rg -q "initialPreset:" "$P" && rg -q 'fullScreenCover\(item: \$pendingBlockBuilder\)' "$P" && echo TASK2_GREP_OK</automated>
  </verify>
  <done>Tapping the hero CTA or "+ New block" opens a "Create New Block" start-choice sheet ("How do you want to start?") with "Start From Scratch" (→ blank editor) and "Use Preset" (→ "Choose Preset" list of all 6 NewBlockPreset options → seeds draft → editor). The .fullScreenCover(item: $pendingBlockBuilder) string is preserved and now passes initialPreset through. ProgramTemplateSection is untouched. Grep gate prints TASK2_GREP_OK.</done>
</task>

<task type="auto">
  <name>Task 3: Update tests, then build + test on the installed iPhone 17 simulator</name>
  <files>fitbodTests/BlockBuilderViewCopyTests.swift, fitbodTests/NewBlockBuilderFidelityTests.swift, fitbodTests/ProgramViewFidelityTests.swift, fitbodUITests/NewBlockModalUITests.swift</files>
  <action>
Update the suites to match the new "Both" flow, then build + run on the device-installed simulator. Do NOT just delete coverage — re-anchor it.

A. BlockBuilderViewCopyTests.swift (verbatim anchors on BlockBuilderView.swift):
   - REMOVE the `"STARTING POINT"` anchor (the band is deleted). The `NewBlockTemplateSheet` struct + its `.navigationTitle("Start From Template")` are KEPT in Task 1, so `"Start From Template"` MAY still be present — verify against the actual source: if the string survives, leave its anchor; if you removed it, drop the anchor too.
   - ADD `#expect(builder.contains("\"APPLY PRESET\""))` (new in-editor surface) and `#expect(builder.contains("\"Apply Preset?\""))` (destructive confirm title).
   - Keep all other anchors (NEW BLOCK, BLOCK NAME, NAME YOUR BLOCK, TOTAL WEEKS, DAYS PER WEEK, PHASES, + ADD PHASE, PREVIEW, NAME FIRST ↑, SAVE TEMPLATE ▸, dialog strings, CANCEL, SAVE).

B. NewBlockBuilderFidelityTests.swift:
   - In the `requiredType` list, REPLACE `"NewBlockStartingPointBand"` (deleted) with `"NewBlockTemplateSheet"` (the picker the in-editor action reuses). KEEP `"NewBlockPresetChip"`. All other requiredType entries stay.
   - KEEP the 5 preset label copy anchors (HYPERTROPHY MESO / LINEAR STRENGTH / POWERBUILDING / OFF-SEASON / PRE-MEET) and "↘ PRESETS" — they still exist.
   - `programNewBlockRoutePresentsFullScreenBuilder` asserts `.fullScreenCover(item: $pendingBlockBuilder)` and `BlockDraft.newBlock()` in ProgramView — both still present. Strengthen it by also asserting `source.contains("Create New Block")` to lock the new pre-editor surface.
   - `newBlockDraftMatchesBlankModalDefaults` (name empty, !isActive, daysPerWeek 4, totalWeeks 5, 3 phases) is UNCHANGED — confirm it still holds (BlockDraft untouched).

C. ProgramViewFidelityTests.swift:
   - The + NEW popover assertions (`showingNewPopover`, `presentingNewRoutine`, BRUActionPopover, "+ New block", "+ New routine", `RoutineBuilderView(draft: RoutineDraft())`) must STILL pass. The test currently asserts `programSource.contains("startBlank()")` with the message "The New block action should route directly to a blank block builder." — under the new flow "+ New block" routes to the start-choice sheet, NOT directly to a blank builder. UPDATE that assertion to match what you wrote in Task 2 (e.g. `programSource.contains("presentingStartChoice = true")`) and correct the message to "The New block action should open the start-choice sheet." (If you kept a `startBlank()` helper that now sets the flag, you may keep the `startBlank()` anchor but the message MUST be truthful.)
   - ADD `#expect(programSource.contains("Create New Block"))` and `#expect(programSource.contains("How do you want to start?"))`.
   - Do not weaken existing token/font/copy anchors.

D. NewBlockModalUITests.swift (uncommitted XCUITest — currently expects "+ New block" to land directly on "NEW BLOCK"):
   - The flow now inserts a start-choice sheet. In `testProgramNewBlockOpensBlankBuilder`, after `tapElement(label: "+ New block", ...)`, ADD `tapElement(label: "Start From Scratch", in: app, timeout: 5)` BEFORE asserting `app.staticTexts["NEW BLOCK"]`. The post-tap assertions (NEW BLOCK, NAME YOUR BLOCK, PHASES · 3, NAME FIRST ↑) then hold for the scratch path. Keep the screenshot attachment.
   - OPTIONAL (only if cheap + stable): add `testProgramNewBlockUsePresetSeedsEditor` tapping "+ NEW" → "+ New block" → "Use Preset" → "HYPERTROPHY MESO", asserting the editor shows "NEW BLOCK". STATE.md documents iOS 26 simulator tap flakiness on List rows/Toggles — if the preset-row tap is fragile, SKIP this test and rely on source anchors + the scratch-path UI test. State the decision in the SUMMARY.

E. Build + test on the INSTALLED simulator (iPhone 17 family — iPhone 16 is NOT installed). Booted device: iPhone 17 Pro Max, id `85A62D29-2C1F-4247-BCC4-D52CA005DF1A`. Confirm the scheme name first with `xcodebuild -list 2>&1 | rg -A20 Schemes` (likely `fitbod`). Build, then run the affected unit suites. ALWAYS pipe xcodebuild through rg filters — never dump full build logs.
   - Build: `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,id=85A62D29-2C1F-4247-BCC4-D52CA005DF1A' build 2>&1 | rg -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -40`
   - Unit suites: `xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,id=85A62D29-2C1F-4247-BCC4-D52CA005DF1A' test -only-testing:fitbodTests/BlockBuilderViewCopyTests -only-testing:fitbodTests/NewBlockBuilderFidelityTests -only-testing:fitbodTests/ProgramViewFidelityTests 2>&1 | rg -E "error:|Test Suite|Executed|failed|\*\* (TEST|BUILD)" | tail -60`
   - UI tests (NewBlockModalUITests) are slower — run them only if the unit suites pass and context budget allows; otherwise note the UI source was updated and should be run by the developer.
  </action>
  <verify>
    <automated>cd /Users/chrissaechao/Desktop/fitbod && ! rg -q "NewBlockStartingPointBand" fitbodTests/NewBlockBuilderFidelityTests.swift && rg -q "NewBlockTemplateSheet" fitbodTests/NewBlockBuilderFidelityTests.swift && rg -q "NewBlockPresetChip" fitbodTests/NewBlockBuilderFidelityTests.swift && ! rg -q '"STARTING POINT"' fitbodTests/BlockBuilderViewCopyTests.swift && rg -q "APPLY PRESET" fitbodTests/BlockBuilderViewCopyTests.swift && rg -q "Create New Block" fitbodTests/ProgramViewFidelityTests.swift && rg -q "Start From Scratch" fitbodUITests/NewBlockModalUITests.swift && echo TASK3_GREP_OK && xcodebuild -scheme fitbod -destination 'platform=iOS Simulator,id=85A62D29-2C1F-4247-BCC4-D52CA005DF1A' test -only-testing:fitbodTests/BlockBuilderViewCopyTests -only-testing:fitbodTests/NewBlockBuilderFidelityTests -only-testing:fitbodTests/ProgramViewFidelityTests 2>&1 | rg -E "error:|Test Suite|Executed|failed|\*\* (TEST|BUILD)" | tail -60</automated>
  </verify>
  <done>The three unit suites are re-anchored to the new flow (STARTING POINT/NewBlockStartingPointBand anchors removed; APPLY PRESET + Create New Block + start-choice anchors added; the "+ New block" routing assertion + message corrected) and pass on the iPhone 17 Pro Max simulator; the UI test taps "Start From Scratch" before asserting the editor; build succeeds. Grep gate prints TASK3_GREP_OK and the filtered test run shows the suites Executed with 0 failures.</done>
</task>

</tasks>

<verification>
- `BlockBuilderView.swift`: `NewBlockPreset` is `internal`; `init(...initialPreset:)` present; `NewBlockStartingPointBand` deleted; in-editor APPLY PRESET opens `NewBlockTemplateSheet`; "Apply Preset?" destructive confirm gated on `preset == .hypertrophyMeso && !draft.phases.isEmpty`; `saveIfValid` keeps `isActive = false`.
- `ProgramView.swift`: start-choice sheet ("Create New Block" / "How do you want to start?" / "Start From Scratch" / "Use Preset" / "Choose Preset") routes both New Block entry points; `.fullScreenCover(item: $pendingBlockBuilder)` preserved and threads `initialPreset:`; `ProgramTemplateSection` untouched.
- The other six `BlockBuilderView(...)` call sites (TodayView, BlockPickerMenu, BlockCard, BlockReviewView, RoutinesListView, previews) compile unchanged (initialPreset defaulted nil).
- LOCKED scope respected: no fabricated phase content for Linear Strength / Powerbuilding / Off-Season / Pre-Meet; no FIX PHASES / CHECK WEEKS states; activation sites (BlockOverviewScreen, BlockContextBand) untouched; no schema/migration changes.
- Build + the three unit suites pass on iPhone 17 Pro Max (id 85A62D29-2C1F-4247-BCC4-D52CA005DF1A) with filtered xcodebuild output.
</verification>

<success_criteria>
- Tapping New Block (hero CTA or + NEW → + New block) presents the start-choice sheet first; Start From Scratch opens a blank editor (3 default phases), Use Preset → Choose Preset list of all 6 options → seeds the draft → editor.
- The editor has NO permanent STARTING POINT row; presets are reachable via a low-emphasis APPLY PRESET action near the PHASES header (and the surviving ↘ PRESETS slot), both opening the shared picker.
- In-editor apply that would replace phases (Hypertrophy Meso + non-empty phases) prompts "Apply Preset? / This will replace your current phases and settings." with destructive Apply + Cancel; other presets apply directly.
- Single source of truth: option list = `NewBlockPreset.all`; apply logic = `BlockBuilderView.applyPreset` (reached pre-editor via the `initialPreset` init seam, in-editor via the picker). No duplicated apply logic.
- Saving creates an INACTIVE block. No schema changes. All four updated test files GREEN; build + unit suites pass on the installed iPhone 17 simulator.
</success_criteria>

<output>
Create `.planning/quick/260528-gox-relocate-new-block-preset-selection-to-b/260528-gox-SUMMARY.md` when done. In it, record: (1) which sheet/cover sequencing pattern you used in ProgramView (Task 2 step 6); (2) whether you kept or dropped the `"Start From Template"` copy anchor; (3) whether you added the optional Use-Preset UI test or skipped it for iOS 26 tap flakiness; (4) any RULE deviations.
</output>
