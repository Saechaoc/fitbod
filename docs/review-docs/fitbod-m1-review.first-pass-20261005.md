# Milestone 1 review: bugs and visual defects

For: Codex, passed on by the user.
From: Claude, as reviewer only.
I did not change, commit, or push anything in the repo.

## Scope and method

- Code: `main` at `27687f8` plus the uncommitted working tree as it stood at 07:51 PDT on 2026-10-05.
  No source file changed after that.
  I checked again at 13:39 PDT.
- Devices: iOS 26.5 simulators.
  "Small" is an iPhone 17e, 390pt wide.
  "Large" is an iPhone 17 Pro Max, 440pt wide.
- Extra passes: accessibility text size AX3 ("accessibility extra large") on the small phone, and dark mode on the large phone.
- Method: review-only XCUITests in a private copy of the project, plus reading the code.
  I saw every item below on screen.
  "Verified fix" means I applied the change in the private copy and re-ran the probe.
  The repo does not contain those changes.
- Evidence: the screenshots sit next to this file, and paths are relative to it.
  Strips read left to right, so "frame 2" means the second screen in a strip.

## Ground rules for the fixes

- Reproduce each bug end to end on a simulator first, the way a user would hit it, then fix it, then re-run the same steps.
- Use BRU tokens and components (`Color.bru*`, `BRUFont`, `BRUButton`, `BRUStepper`, `.toggleStyle(.bru)`).
  Do not add literal colors.
- Unit tests go in Swift Testing (`fitbodTests/`).
  UI tests go in XCTest (`fitbodUITests/`).
- Run simulator tests serially (`-parallel-testing-enabled NO`) on dedicated simulators.
- If you touch `BlockBuilderView.swift`, run all three guardrail suites together: `NewBlockBuilderFidelityTests`, `BlockBuilderViewCopyTests`, and `BlockBuilderViewActivationTests`.
- The DEBUG launch flags `-fitbod-reset-store -fitbod-seed-demo-workout` give a clean store with an in-progress demo workout.
  Most repro steps below start there.
- Text size for repros: `xcrun simctl ui <device> content_size accessibility-extra-large`, or the launch argument `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL` in UI tests.
  Dark mode: `xcrun simctl ui <device> appearance dark`.

## Priorities

- P0: blocks a core task.
- P1: breaks or badly hurts a core task, or is a very visible defect.
- P2: a clear visual or usability defect.
- P3: polish.

## Summary

| # | P | Where | Problem |
|---|---|---|---|
| 1 | P0 | Library | Copy and Edit open a blank sheet on the first tap |
| 2 | P1 | Logger | Skip warm-ups does nothing, and once fixed, skipped warm-ups count as logged sets |
| 3 | P1 | Editor sheets | Swiping a sheet down throws away unsaved edits with no warning |
| 4 | P1 | Logger | "Why this weight" cannot be opened |
| 5 | P1 | Session editor | Typing target reps corrupts the value (6 becomes 16) |
| 6 | P1 | Session editor | Target RPE looks like a range, but both fields are one value |
| 7 | P1 | Today | Muscle heatmap blocks overlap and spill out, and taps open the wrong muscle |
| 8 | P1 | Program, large text | Empty Program screen draws text over itself, and the Resume pill breaks |
| 9 | P2 | Program, dark mode | Program tab stays light in dark mode |
| 10 | P2 | Logger, large text | Warm-up ramp labels and numbers break |
| 11 | P2 | History, large text | Stat strips split words and numbers |
| 12 | P2 | Session editor, large text | Labels clipped, split, or stuck at a tiny fixed size |
| 13 | P2 | Session editor | Exercise index shows "•••" instead of "01" at default text size |
| 14 | P2 | Settings | Backup footer makes Restore the primary action |
| 15 | P2 | Program, Today | "+ New routine" then Back leaves an "Untitled routine" and hides the first-run screen |
| 16 | P2 | Design system | BRUButton fill bleeds into the home indicator area |
| 17 | P2 | Session editor | Toggles use iOS green instead of the BRU toggle |
| 18 | P2 | Logger | "M" badge spills into the reps column, and a new exercise shows weight 0 |
| 19 | P2 | Library | "Create custom exercise" from a failed search ignores the search text |
| 20 | P2 | Library | Custom exercise editor and muscle picker are stock iOS, not BRU |
| 21 | P2 | Muscle detail | Exercise names show as lowercase search keys |
| 22 | P3 | Today | Volume rows: tick labels crowd the muscle name |
| 23 | P3 | Rest timer | The half-height rest sheet cuts off SKIP |
| 24 | P3 | Various, large text | Smaller large-text problems |
| 25 | P3 | Various | Copy and consistency nits |

## Details

### 1. P0: Copy and Edit open a blank sheet on the first tap

**What you see.**
On an exercise detail screen, tap COPY on a built-in exercise, or EDIT on a custom one.
The first tap opens an empty sheet.
You must swipe it away and tap again, and the second tap works.
This is the custom exercise bug from the walkthrough.

**Repro.**
Library, open "Barbell Bench Press - Medium Grip", and tap COPY once.

**Evidence.**
On the large phone, `l-c.png` frame 4 shows the blank sheet after EDIT, and `l-d.png` frame 1 shows the Copy editor on the second try.
On the small phone, probe tests G and H (`probe/small/`) show the same thing.

**Cause.**
`fitbod/ExerciseLibrary/ExerciseDetailView.swift:146-155` presents with `.sheet(isPresented: $presentingCustomEditor)` and reads `draftFromCopy` only inside the sheet closure (`if let draft = draftFromCopy { ... }`).
`openEditor(editing:)` at lines 158-168 sets `draftFromCopy` and `presentingCustomEditor = true` in the same update.
The view body never reads `draftFromCopy`, so SwiftUI builds the first sheet with the old value, `nil`, and the `if let` renders nothing.

**Fix.**
Drive the sheet with the draft itself and delete `presentingCustomEditor`.

```swift
@State private var editorDraft: CustomExerciseDraft?

.sheet(item: $editorDraft) { draft in
    NavigationStack {
        CustomExerciseEditor(draft: draft)
    }
}

private func openEditor(editing: Bool) {
    let draft = makeDraft(from: exercise)
    if editing {
        draft.name = exercise.name
        draft.imageData = exercise.imageData
        draft.editingExisting = exercise
    }
    editorDraft = draft
}
```

`CustomExerciseDraft` is a `final class` (`CustomExerciseDraft.swift:82`), so `extension CustomExerciseDraft: Identifiable {}` gets its `id` for free.

**Test.**
UI test: open a built-in exercise, tap COPY once, and assert that `customExercise.name` exists within 3 seconds.
Repeat with EDIT on a custom exercise.

### 2. P1: Skip warm-ups does nothing

**What you see.**
In the workout, SKIP WARM-UPS under the warm-up ramp does nothing.
It fails whether you tap the words or the space just above them.

**Repro.**
Launch with the demo flags, tap RESUME on Today, tap SKIP WARM-UPS, and tap Back.
The Today slab still says "0 SETS LOGGED".

**Evidence.**
Probe R2 on the small phone.
`probe/r2-small/zz-issues.txt` stays at "0 SETS LOGGED" after both taps.
`probe/r2-fixed/zz-issues.txt` shows "4 SETS LOGGED" with the fix below.
Probe R measured the tappable frame at 102 x 15pt.

**Cause.**
Two things combine.
`fitbod/Sessions/SessionExerciseCard.swift:252-258` puts `.onTapGesture { if !bannerDismissed { bannerDismissed = true } }` on the whole header row, and that row also holds the warm-up ramp (mounted at lines 175-185).
`fitbod/Sessions/WarmupRampRows.swift:236-250` builds the skip `Button` with no `buttonStyle`, inside a `List` row, and applies `.frame(maxWidth: .infinity, minHeight: 44)` outside the button.
In a List row, the parent tap gesture beats a default-styled button, so the action never runs.
The frame outside the button also does not grow the tappable area.

**Fix (verified).**

```swift
Button {
    onSkip()
} label: {
    Text("SKIP WARM-UPS")
        .font(BRUFont.labelSmall)
        .foregroundStyle(Color.bruMuted)
        .textCase(.uppercase)
        .tracking(1.2)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
```

With this change, both a tap on the words and a tap 14pt above them worked.
Check every other `Button` inside that header row for the same problem.

**Follow-up A: no feedback after a skip.**
After a skip, the ramp rows look exactly the same, because `WarmupRampRows` never reads `isComplete`.
Show a done state, or collapse the ramp to a single "WARM-UPS SKIPPED" line with an undo.

**Follow-up B: skipped warm-ups count as logged sets.**
`handleSkipWarmups()` at `SessionExerciseCard.swift:529-534` sets `isComplete = true` on every warm-up.
These counts include warm-ups: `fitbod/Views/ResumeWorkoutSlab.swift:53-57`, `fitbod/Sessions/ResumeWorkoutBanner.swift:138-143`, and `loggedSetCount` at `fitbod/Sessions/SessionLoggerView.swift:271-275`.
That is why the slab jumps to "4 SETS LOGGED" before a single work set.
It also changes the Finish logic, which checks `loggedSetCount == 0` at `SessionLoggerView.swift:247`.
It contradicts the button's own hint, "Marks warm-ups as done without logging them."
Make one shared "logged work sets" count that skips `isWarmup` sets and use it everywhere.
Also confirm that volume, PRs, and progression ignore skipped warm-ups.

**Test.**
UI test: resume the demo workout, tap SKIP WARM-UPS, assert that the ramp shows its skipped state, go back, and assert that the slab still says "0 SETS LOGGED".
Unit test for the shared count.

### 3. P1: Swiping a sheet down throws away unsaved edits

**What you see.**
In the session editor sheet, make a change and drag the sheet down.
The sheet closes with no warning, and the change is gone.
The Back and Cancel buttons do ask before discarding, so only the swipe is unprotected.

**Evidence.**
`d17-swipe-small.png`: before the swipe, after the swipe, reopened with the edit gone, and the Back button path for comparison.

**Cause.**
The app has no `.interactiveDismissDisabled` anywhere.
The editors already track changes: `fitbod/Routines/RoutineBuilderView.swift:522` (`hasUnsavedChanges`, with dialogs at 177, 236, and 245) and `fitbod/ExerciseLibrary/CustomExerciseEditor.swift:252` (`isDirty`, with a dialog at 137).

**Fix.**
Add `.interactiveDismissDisabled(hasUnsavedChanges)` (or `isDirty`) to each editor's root view inside the sheet.
Check `BlockBuilderView` and the workout notes editor for the same gap.
If you want a swipe to show the same Discard dialog instead of only resisting, bridge `UIAdaptivePresentationControllerDelegate.presentationControllerDidAttemptToDismiss`.

**Test.**
UI test: open the session editor, change the name, drag down from the sheet's top edge, and assert that the editor is still on screen.

### 4. P1: "Why this weight" cannot be opened

**What you see.**
The weight explanation sheet is meant to open on a long press of the prescribed weight in the workout.
A long press only focuses the weight field, and no other control opens the sheet.

**Evidence.**
`s-probes.png` frames 2 and 3: before and after a long press, with the caret in the field and no sheet.
Codex's two failing `WhyThisWeightSheetBRUUITests` fail for this reason.

**Cause.**
`fitbod/Sessions/PrescriptionWeightCell.swift:117` puts `.onLongPressGesture(minimumDuration: 0.4)` on a cell that contains a `TextField`.
The UIKit text field takes the touch, so the SwiftUI long press never fires.
`SetRow.swift:129` also adds an `.onTapGesture` on the same cell.

**Fix.**
Add a visible control, for example a small BRU "WHY" text button next to the weight with a 44pt hit area, that sets `showWhySheet = true`.
Add `.accessibilityAction(named: "Why this weight")` so VoiceOver users can reach it.

**Test.**
Point the two existing WhyThisWeight UI tests at the new control.
They should pass.

### 5. P1: Typing target reps corrupts the value

**What you see.**
In the session editor's prescription details, tap the high reps field that shows 6 and type 1.
The field becomes 16.
One tap puts the caret before the existing number, so new digits go in front of it.
In the full walkthrough, 4 became 64 and 6 became 106, and the set rows then read "×64 @8".
The tappable area is only 48 x 19pt.
The floating DISCARD / SAVE SESSION bar rides on top of the keyboard and can cover the field you are editing.
The number pad has no Done key.
Nothing stops a low value above the high value.

**Evidence.**
`s-a.png` frames 1 and 2 (4–6 before, 64–106 after).
`s-probes.png` frame 4 (the chip reads "4-16 reps" after typing one digit).
`s-reps-cell.png`.
Codex's failing journey test (`"106"` is not `"10"`) is this bug.

**Cause.**
`fitbod/Routines/PrescriptionEditorRow.swift:150-192` uses `TextField(value: $draft.targetRepsLow, format: .number)` with `.frame(width: 48)`, and then `.frame(minHeight: 44)` outside the field.
A frame outside a `TextField` does not make the UIKit field taller, so the hit area stays at the text height.

**Fix.**
Replace both reps fields with `BRUStepper` (`fitbod/Design/BRUStepper.swift`).
Steppers suit gym use, avoid the keyboard, and make validation simple.
If you keep text entry, select all on focus, add a keyboard toolbar Done button, keep the focused field above the save bar, and enforce low ≤ high.

**Test.**
UI test: change reps from 6 to 8 and assert that the field reads 8.
Unit test for the validation rule.
Then fix the journey test's text helper so it does not depend on caret position.

### 6. P1: Target RPE looks like a range, but both fields are one value

**What you see.**
Prescription details show "Target RPE 8 – 8" with two fields.
Changing either field changes both.

**Evidence.**
`s-a.png` frame 1, `ax2-c.png` frame 4, `dk2-c.png` frames 4 and 5.

**Cause.**
`fitbod/Routines/PrescriptionEditorRow.swift:205-232`: both fields bind to `draft.targetRPE` (getters at lines 208 and 225).
The model has a single `targetRPE`.

**Fix.**
Show one RPE control.
The logger's `InlineRPEChipRow` (6 to 10) would match the rest of the app.
Typing 0 now silently clears the target (`set: { draft.targetRPE = $0 == 0 ? nil : $0 }`), so give "no target" its own explicit choice.

**Test.**
UI test: assert a single RPE control, change it, save, reopen, and assert the new value.

### 7. P1: Muscle heatmap blocks overlap and spill out, and taps open the wrong muscle

This one is new in this pass.

**What you see.**
On Today, scroll down to MUSCLE HEATMAP.
The blocks sit off the grid and overlap each other.
DELT hides under BICEP, NECK hides under the chest blocks, TRI covers LAT so it reads "TRILAT", GLUTE covers LOWER BACK, and UPPER BACK is cut to "PPER BACK".
The right TRI block sticks out past the BACK frame, and the bottom CALF row is cut by the frame.
Tapping NECK opens the CHEST detail screen.

**Repro.**
Launch with the demo flags, scroll Today to MUSCLE HEATMAP, and tap NECK.

**Evidence.**
`heatmap.png`: the heatmap on the small phone, and the CHEST screen that opened after tapping NECK.
Probe S, `probe/s-small/`.

**Cause.**
`fitbod/Fatigue/BodySilhouetteView.swift:140-146`:

```swift
.frame(width: r.width, height: r.height)
.frame(
    minWidth: needsHitPadding(region: region) ? 44 : 0,
    minHeight: needsHitPadding(region: region) ? 44 : 0
)
.contentShape(Rectangle())
.offset(x: r.minX, y: r.minY)
```

Every region is smaller than 44pt in at least one direction (a two-cell block is 27pt), so each one gets a box at least 44pt wide and tall, with the colored block centered inside it.
The offset places the box, not the block.
So each block draws up to 8.5pt right of its cell and up to 15.5pt below it, depending on its size.
The 44pt boxes also overlap each other at 28pt spacing, and the region drawn last wins the tap.
That is why NECK opens CHEST.

VoiceOver has two more problems.
The decorative NECK is announced as a button with the hint "Tap to see details.", and it does nothing (lines 151-154 and 179-182).
Left and right halves are separate elements, so VoiceOver reads "Chest" twice, "Biceps" twice, and so on.

**Fix.**
Draw each block at its exact rect, and drop the hit padding.
The blocks tile the grid, so padding can only steal a neighbor's taps.

```swift
ZStack { ... }
    .frame(width: r.width, height: r.height)
    .contentShape(Rectangle())
    .position(x: r.midX, y: r.midY)
```

Remove `needsHitPadding`.
Each muscle already has a full-width row in the volume list on the same screen, and that list is the large-target path.
For VoiceOver, expose one element per muscle (merge left and right), or hide the grid and rely on the list.
Hide NECK from accessibility and drop its button trait and hint.

**Test.**
UI test: read every heatmap button frame, assert that no two frames intersect and that each lies inside its FRONT or BACK box, and assert that tapping NECK does not navigate.

### 8. P1: Empty Program screen draws text over itself at large text, and the Resume pill breaks

**What you see.**
At AX3, the empty Program screen piles text on top of itself.
The heading is cut to "NO PROGR…".
The description runs under the "+ DEFINE BLOCK" button.
The WEEKS, PHASES, DELOAD OPTIONAL, and CUSTOM chips print over each other.
The template rows overlap their own subtitle lines, and the POPULAR chip is cut to "PO…".
The active-workout pill on the same screen wraps as "RESU" over "ME ▸".

**Evidence.**
`ax-b.png` frame 4, `ax-c.png` frame 3, `ax-d.png` frame 3.

**Cause.**
`fitbod/Periodization/ProgramView.swift` uses fixed font sizes and fixed frames tuned to the mockup: font sizes at lines 821-872, and frames at 986, 997, 1019-1020, 1043, 1077, 1245, 1253, 1266-1267, 1275-1276, and 1285.
SwiftUI does not clip text that overflows a fixed frame, so the text draws over its neighbors.
The pill is a `BRUPillButton("Resume ▸")` squeezed into an `HStack` at `fitbod/Sessions/ResumeWorkoutBanner.swift:65-93`.

**Fix.**
Replace fixed heights with minimum heights or none.
Scale custom sizes with `@ScaledMetric`, or use `BRUFont` roles.
At accessibility sizes, switch the hero and the template rows to a vertical layout, using the same `dynamicTypeSize.isAccessibilitySize` branch that `TodayStatStrip` uses (`TodayStatStrip.swift:196-201`).
In the banner, stack the pill under the text at accessibility sizes, so "RESUME" never breaks mid-word.

**Test.**
Run the Program empty-state UI test at AX3 and assert that the frames of the heading, the description, and the CTA do not intersect.

### 9. P2: Program tab stays light in dark mode

**What you see.**
In dark mode every tab turns dark except Program.
Program keeps its light paper background and stands out as a bright block.

**Evidence.**
`dark-c.png` frames 3 and 4, `dk2-c.png` frame 1.

**Cause.**
`fitbod/Periodization/ProgramView.swift:813-817` defines its own colors from fixed RGB values (`screenBackground`, `ink`, `muted`, and `lightRowDividerColor`), and line 844 does the same for `ctaColor`.
New Block uses the same pattern: `BlockBuilderView.swift:296-305` and `:2357`, plus `BlockNameField.swift:20-21`.
I did not capture New Block in dark mode, but it will behave the same way.

**Fix.**
Use the adaptive tokens from `Color+BRU.swift` (`bruPaper`, `bruInk`, `bruMuted`, `bruHair`, `bruFaint`, `bruSignal`).
`BlockPhaseColors.swift` also uses literal colors, and they may be fine if they are phase hues that read well on both backgrounds.

**Test.**
A source test that fails on `Color(red:` in these files, mirroring the existing source-introspection suites.
Then check Program and New Block in dark mode by eye.

### 10. P2: Warm-up ramp labels and numbers break at large text

**What you see.**
At AX3 the set labels wrap as "W" over "1", and weights can break as "9" over "0".
Codex's own large-phone evidence shows W3 and W4 as "•••" and the plate text as "10+10+2/.5".

**Evidence.**
`ax-a.png` frame 5 (W4 shows "9" over "0"), `ax-c.png` frames 1 and 2, and `codex-ax.png` frame 2, which is `verification/iphone-pro-max-ax3-dark-workout.png` from the repo.

**Cause.**
`fitbod/Sessions/WarmupRampRows.swift:163-166` fixes the label to `.frame(width: 36)`.
Lines 171-173 use a fixed 22pt weight font next to a `PlateStackViz` that takes `maxWidth: .infinity`.

**Fix.**
At accessibility sizes, stack each warm-up row: label and weight on one line, then reps, RPE, and plates on the next.
Let the label size to fit, and give the plate text its own line.

**Test.**
Add the ramp to the AX3 gallery pass and check it by eye.
A UI test can also assert that the `W1` label frame is wider than it is tall.

### 11. P2: History and workout summary stat strips split words and numbers at large text

**What you see.**
At AX3 the three-column strips break words and numbers across lines: "SESSI" over "ONS", "TONNA" over "GE", "4,23" over "0", "DURAT" over "ION", and "VOLUM" over "E".

**Evidence.**
`ax2-a.png` frame 5 (History) and `ax2-b.png` frame 1 (workout summary).

**Cause.**
`fitbod/Sessions/SessionHistoryStatStrip.swift:44-72` and `fitbod/Sessions/SessionDetailView.swift:119-134` always use a three-column `HStack`.
`TodayStatStrip.swift:196-201` already has an accessibility branch that stacks the columns.

**Fix.**
Reuse the Today pattern, ideally as one shared stat strip component.

**Test.**
AX3 UI test asserting that each stat value is a single line.

### 12. P2: Session editor labels are clipped, split, or stuck at a tiny size at large text

**What you see.**
At AX3, the per-set overrides count is clipped at the right edge.
The set labels ("S1", "S2") stay at a tiny fixed size while everything around them grows.
"WORK" breaks as "WOR" over "K", "+ ADD EXERCISE" breaks as "EXERCIS" over "E", "Track partial reps" is cut to "Track partial r…", and the exercise index "01" shows as "0".

**Evidence.**
`ax2-c.png` frames 1 and 3 to 6, `ax2-overrides.png`, `ax2-setrows.png`.

**Cause.**
- `fitbod/Routines/PrescriptionEditorRow.swift:353-365`: the overrides label uses `.lineLimit(1).fixedSize(horizontal: true, vertical: false)`, so it pushes past the edge.
- `fitbod/Routines/SetRowsContainer.swift:94-105`: the set label uses `.system(size: 10, design: .monospaced)` in a 24pt column, and "WORK" sits in a 60pt column.
- `fitbod/Routines/PerSetOverrideRow.swift:39`: the same fixed 10pt font.
- `PrescriptionEditorRow.swift:299`: "Track partial reps" has no room to wrap.

**Fix.**
Use `BRUFont` roles so labels scale, drop the fixed widths at accessibility sizes, and let toggle labels wrap.

**Test.**
Add the session editor to the AX3 screenshot pass.

### 13. P2: Exercise index shows "•••" instead of "01" at default text size

**What you see.**
In the session editor, each exercise row shows "•••" where its number ("01", "02") should be.
This happens at default text size on both phones, in light and dark mode.

**Evidence.**
`large-reorder.png` frames 1 to 3 (large phone), `s-a.png` frame 1 (small phone), and `dk2-c.png` frames 2 to 5 (dark mode).

**Cause.**
`fitbod/Routines/RoutineExerciseCard.swift:130-138` sets the index in 26pt grotesk inside a 28pt-wide frame, so "01" does not fit and truncates.

**Fix.**
Size the column to the text (or use `@ScaledMetric` for the width), and drop the font size if the design allows.

**Test.**
UI test asserting that the first row's index label reads "01".

### 14. P2: Backup footer makes Restore the primary action

**What you see.**
In Settings, BACKUP shows "No backup yet" and "Create a backup to protect your data".
Below that, CREATE is a plain ghost button, and RESTORE is the filled orange primary.
Restore replaces data, so the design steers the user to the risky action.

**Evidence.**
`dark-c.png` frame 6 and `dk2-c.png` frame 6.

**Cause.**
`fitbod/Settings/SettingsView.swift:386-467` gives RESTORE the `bruSignal` fill and CREATE the ghost style.
The copy at lines 507 and 512 asks for a backup.

**Fix.**
Make CREATE BACKUP the primary action and RESTORE a secondary one, and keep the existing confirmation before restore.

### 15. P2: "+ New routine" then Back leaves an "Untitled routine" and hides the first-run screen

**What you see.**
On Program, tap "+ NEW", then "+ New routine", then Back without typing anything.
ROUTINES now lists "Untitled routine, 0 sessions".
The first-run screen (NO PROGRAM, + DEFINE BLOCK, and the four templates) is gone for good.
What remains is a BLOCKS heading with nothing under it.

**Evidence.**
`s-probes.png` frame 1 (Program after Back) and `l-d.png` frame 2 (the untitled routine).

**Cause.**
`fitbod/Periodization/ProgramView.swift:284-288` and `fitbod/Views/TodayView.swift:561-565` call `RoutineCreator.create(context:)` before the user enters anything.
The comment there says this is on purpose, so an untitled routine is never orphaned.
The hero only shows while there are no blocks and no routines (`ProgramView.swift:127-140`), so one stray tap removes it.

**Fix.**
Delete the routine when the user leaves it untouched (default name and no sessions), or create it on first save.
Give the empty BLOCKS section its own empty state.

**Test.**
UI test: "+ New routine", Back, and assert that ROUTINES has no untitled routine and the first-run screen still shows.

### 16. P2: BRUButton fill bleeds into the home indicator area

**What you see.**
When the DISCARD / SAVE SESSION bar sits at the bottom of a sheet, the SAVE SESSION fill continues below the bar into the home indicator area.
This happens on both phones, enabled or disabled.

**Evidence.**
`s-a.png` frame 1, `l-d.png` frame 4, `large-reorder.png` frames 1 to 3, `ax2-c.png` all frames.

**Cause.**
`fitbod/Design/BRUButton.swift:172` uses `.background(fillColor(pressed: pressed))`.
With a `ShapeStyle`, `.background` ignores the safe area by default, so the fill extends into it.

**Fix.**
`.background(fillColor(pressed: pressed), ignoresSafeAreaEdges: [])`, or `.background { Rectangle().fill(fillColor(pressed: pressed)) }`.
Check the other BRU components that use `.background(Color...)` at screen edges.

**Test.**
UI test on the session editor: assert that the save button frame ends above the bottom safe area inset.
Then check it by eye.

### 17. P2: Prescription toggles use iOS green

**What you see.**
"Track tempo", "Track partial reps", and "Auto warm-up" are stock iOS switches that turn green when on.

**Evidence.**
`ax2-c.png` frames 4 to 6, `dk2-c.png` frames 4 and 5.

**Cause.**
`fitbod/Routines/PrescriptionEditorRow.swift:249`, `:298`, and `:314` have no toggle style.
`ExerciseDetailView.swift:492` already uses `.toggleStyle(.bru)`.

**Fix.**
Add `.toggleStyle(.bru)` to all three.

### 18. P2: "M" badge spills into the reps column, and a new exercise shows weight 0

**What you see.**
After you change a prescribed weight, a small "M" appears and lands flush against the reps value, so the row reads "185 M5".
For an exercise with no history, the weight field shows "0", which reads like a real target of 0 lb.

**Evidence.**
`s-a.png` frames 3 and 4, `s-b.png` frames 1, 3, and 4, `s-c.png` frames 1, 3, and 4.

**Cause.**
`fitbod/Sessions/SetRow.swift:127` fixes the weight cell to 60pt.
Inside it, `fitbod/Sessions/PrescriptionWeightCell.swift:83` gives the field a 60pt minimum width and then adds the "M" badge after it (lines 105-112), so the badge overflows into the REPS column.
The "0" comes from `onAppear` at lines 139-150, which copies a prescribed weight of 0 into the field.

**Fix.**
Make the badge part of the weight cell's own width (or mark an override with color or an underline), and give it an accessibility label such as "changed from prescription".
Treat a prescribed weight of 0 as "no prescription" so the field shows its empty placeholder.

### 19. P2: "Create custom exercise" from a failed search ignores the search text

**What you see.**
Search the Library for "Zercher", get no match, and tap CREATE CUSTOM EXERCISE.
The Name field is empty and shows the placeholder "e.g. Cambered Bar Bench Press".

**Evidence.**
`l-b.png` frames 1 and 2.

**Cause.**
`fitbod/ExerciseLibrary/ExerciseLibraryView.swift:117` presents `CustomExerciseEditor(draft: CustomExerciseDraft())` from `.sheet(isPresented:)`, which builds a fresh draft inside the sheet closure.
Today, picking a muscle keeps the typed name (probe M), but any re-render of the parent while the sheet is up can rebuild the draft and wipe the user's input.

**Fix.**
Use `@State private var newCustomDraft: CustomExerciseDraft?` with `.sheet(item:)`, the same pattern as item 1.
Fill `draft.name` with the trimmed search text when it comes from the no-match state.

**Test.**
UI test: search for a made-up name, tap CREATE CUSTOM EXERCISE, and assert that the Name field holds the search text.

### 20. P2: Custom exercise editor and muscle picker are stock iOS, not BRU

**What you see.**
The custom exercise editor is a stock `Form`, with rounded cells, segmented controls, a menu picker, and SF Symbols.
The muscle picker is a stock `List` with the system navigation bar and a glass "Cancel" pill.
Both look like a different app next to the BRU screens.
A muscle row reads "Lower Back · Upper", which looks wrong.
A copied exercise lists its secondary muscles before its primary one (Triceps, Shoulders, then Chest).

**Evidence.**
`l-b.png` frames 2 to 4, `l-c.png` frame 1, `l-d.png` frame 1.

**Cause.**
`fitbod/ExerciseLibrary/CustomExerciseEditor.swift` and `fitbod/ExerciseLibrary/MusclePickerSheet.swift` use system components.
The region label comes from `MusclePickerSheet.swift:57`.

**Fix.**
Rebuild both screens with BRU components to match the reference design, `bru-screens/Fitbod-Session/screens/phase-1--custom-exercise.png` and `bru-screens/custom-exercise.jsx`.
Sort muscles primary first.
Fix the region label for Lower Back.

### 21. P2: Muscle detail shows exercise names as lowercase search keys

This one is new in this pass.

**What you see.**
Open a muscle from Today.
CONTRIBUTING EXERCISES lists "barbell bench press - medium grip" in lowercase, while every other screen says "Barbell Bench Press - Medium Grip".
The same screen shows ADJUST TARGETS as the section heading and again as the only row.

**Evidence.**
`heatmap.png`, right frame.

**Cause.**
`fitbod/Fatigue/PerMuscleDetailView.swift:309` uses `exercise.canonicalName`, which is the lowercased search key.
`fitbod/Fatigue/WeeklyRecapSheet.swift:766` and `:776` do the same.
The repeated label comes from lines 230 and 240.

**Fix.**
Use `exercise.name` for display in all three places.
Rename or remove the duplicate row label.

### 22. P3: Volume rows: tick labels crowd the muscle name

**What you see.**
In VOLUME THIS WEEK on Today, the MEV, MAV, and MRV tick labels sit right against the muscle name, and the MRV label lands under "SETS".
On the small phone in light mode, the divider under the CHEST row is stepped: its left part sits a few pixels higher than the rest.

**Evidence.**
`dark-a.png` frames 1 to 3 for the tick labels.
I saw the stepped divider during the small-phone walkthrough, but I have no crop of it.

**Fix.**
Give the tick labels their own row above the bar with enough space below the name, and keep them inside the bar's width.
Find the source of the stepped divider.

### 23. P3: The half-height rest sheet cuts off SKIP

**What you see.**
Tap the rest bar to expand it.
At the half-height detent, -15s and +15s show, but SKIP is cut off below the visible part of the sheet.
You have to drag the sheet up to reach it.

**Evidence.**
`s-b.png` frame 2 (small phone), `dk2-rest-bottom.png` and `dk2-a.png` frame 2 (large phone, dark mode).

**Cause.**
`fitbod/Sessions/RestTimer/RestTimerOverlay.swift:60-62` offers `[.medium, .large]`, and the content with 52pt controls (line 202) is taller than the medium detent.

**Fix.**
Make the content fit the medium detent (smaller ring, controls in one row), or use a custom height detent measured from the content.

### 24. P3: Smaller large-text problems

- Today header at AX3: the left and right items run together as "SETTINGS MON · OCT 5" (`fitbod/Design/BRUHeaderBar.swift:190-199`).
  Evidence: `ax-a.png` frame 1.
- Today slab at AX3: "RESUME ▶" wraps the arrow to its own line.
  Evidence: `ax-a.png` frame 2.
- RPE chips at AX3: "10" touches its border, because the chip is `.frame(minWidth: 44, minHeight: 44)` with no padding (`fitbod/Sessions/InlineRPEChipRow.swift:41-50`).
  Evidence: `ax-b.png` frame 1.
- Exercise detail at AX3: "RECENT PERFORMANCE" breaks as "PERFORMANC" over "E".
  Evidence: `ax2-b.png` frame 4.
- Today legend (UNDER MEV, MEV → MAV, MRV) wraps awkwardly at AX3.
  Evidence: `ax-a.png` frames 2 and 3.

### 25. P3: Copy and consistency nits

- "1 sets": the Resume banner on Program (`fitbod/Sessions/ResumeWorkoutBanner.swift:80`) and the Finish dialog (`fitbod/Sessions/SessionLoggerView.swift:157`) do not handle the singular.
  The Today slab already gets it right ("1 SET LOGGED").
  Evidence: `s-c.png` frame 4 (Finish dialog), `dk2-c.png` frame 1 (banner reads "13:41 · 1 sets"), and `s-c.png` frame 2 (Today slab).
- The Finish dialog shows only "Finish".
  On iOS 26 the `.cancel` role button ("Keep logging") is hidden, so the only way back is a tap outside.
  The same applies to the Discard dialogs.
  If you want a visible way back, add a non-cancel "Keep logging" or "Keep editing" button.
- Rest time is written in several formats: "180S" in the exercise subtitle, "3 min rest" in the chip, and "180s" in the stepper (`RoutineExerciseCard.swift:200` is one source).
  Pick one format.
- Sheets close with "‹ BACK" in the session editor but with "CANCEL" in Add Session and the exercise editor.
  Use one style for sheets; a back chevron suggests a pushed screen.
- The Library shows a lone section header "3" for "3/4 Sit-Up" (`ExerciseLibraryView.swift:343`).
  Group digits under "#".
- Exercise detail: "View all history >" uses an ASCII ">" in the body font, unlike other navigation rows.
  Evidence: `ax2-b.png` frame 5.
- The Library search placeholder is very faint.
- The reorder control "⋮⋮" looks like a drag handle but opens a menu.
  `.accessibilityElement(children: .combine)` at `RoutineExerciseCard.swift:177` also merges the row so its identifiers repeat.
- The warm-up ramp reads poorly in VoiceOver ("Plates: ." on a bar-only row, "2 10", "1 reps"), and the bar-only row shows no plate text.
  Show "BAR" there.
- History "PER WEEK 0.2" rounds 0.25 down.
  Use two decimals, or say "1 every 4 weeks".
  Evidence: `ax2-a.png` frame 5.
- The first set ever logged for an exercise fires all four PRs at once ("WEIGHT PR · REP PR · VOLUME PR · E1RM PR").
  Consider no PR banner when there is no history.
  Evidence: `s-b.png` frame 1.
- Today empty state, "No active block." card: `fitbod/Periodization/StartBlockCTA.swift:43-45` applies `.padding(16)` and then `.padding(.horizontal, 16)`, so its content is inset 32pt and misaligns with the 16pt edges around it.
  Its sentence-case heading clashes with the card above it, and its link uses `bruSignal` on paper, which is hard to read at small sizes.
  Use `bruSignalText`.
  Evidence: `l-a.png` frame 1.
- Stat values use the grotesk font (`fitbod/Design/BRUReadout.swift:85`), while the mockup's readout uses the display font (`bru-screens/Fitbod-Session/bru-theme.jsx:149`).
  Confirm which one is intended.
- In dark mode, the inverse (light) slabs on Today glare against the dark page.
  This is a design call, so I am only noting it.
  Evidence: `dark-a.png` frame 1.

## Codex's failing tests

Codex's last full run on this snapshot had 1026 tests, with 1021 passing, 4 failing, and 1 expected failure.

| Test | Verdict |
|---|---|
| `MilestoneOneJourneyUITests/testAuthorRoutineLogRelaunchFinishAndHistory` | App bug, item 5. The field read "106" instead of "10". Its text helper also relies on caret position. |
| `WhyThisWeightSheetBRUUITests/testWhyThisWeightHeroSlabAppearsAfterLongPress` | App bug, item 4. |
| `WhyThisWeightSheetBRUUITests/testWhyThisWeightSectionHeadVisible` | App bug, item 4. |
| `SessionLoggerBRUUITests/testBRUHeaderBarMenuActionsAccessibleInActiveSession` | Test bug. It taps "Cancel" in a confirmation dialog, and iOS 26 shows no Cancel button there. Dismiss the dialog another way, or tap a visible "Keep logging" button if you add one (item 25). |

## Docs that need a correction

- `docs/VERIFICATION.md:138-141` says honestly that large-text runtime checks covered only the logger and the component gallery.
  Program, History, the workout summary, and the session editor fail at that size (items 8, 11, and 12).
  Either extend the checks to them or list them as known gaps.
- `docs/VERIFICATION.md:156` links `verification/iphone-pro-max-ax3-dark-workout.png` as passing evidence, but that image shows the item 10 defect ("•••" and "10+10+2/.5").
- The dark mode screenshots do not include Program, which stays light (item 9).

## Checked, and not a bug

- In the new custom exercise sheet, picking a muscle keeps the typed name today (probe M).
  The fragile sheet pattern is still worth fixing (item 19).
- Program's "+ NEW" has a working 44pt tap area even though its visible text is small (probe R).
- The expanded rest sheet does have SKIP; it is cut off, not missing (item 23).
- A SpringBoard crash in one run came from the XCTest infrastructure, not the app.
- Not verified, so not reported as bugs: the "HIDE DETAILS" text button, the Today hero's "3" next to "+2" comparison, and whether the muscle picker announces the selected state to VoiceOver.

## Evidence index

Small phone (iPhone 17e, default text, light):

- `s-a.png`: prescription details (items 5, 6, 13, and 16), reps after editing "64 – 106" (item 5), workout start with weight 0 (item 18), entry with the keyboard up.
- `s-reps-cell.png`: close-up of the reps entry cell.
- `s-b.png`: PR banner and rest bar, half-height rest sheet without SKIP (item 23), added set, a long press that opened nothing (item 4).
- `s-c.png`: More menu, Today resume slab, resumed workout, Finish dialog with "1 sets" (item 25).
- `s-probes.png`: Program after "+ New routine" and Back (item 15), long press before and after (item 4), reps chip "4-16" (item 5).
- `d17-swipe-small.png`: swipe-down discards edits (item 3).
- `heatmap.png`: muscle heatmap overlap, and CHEST opened by a tap on NECK (items 7 and 21).

Large phone (iPhone 17 Pro Max, default text, light):

- `l-a.png`: Today empty, Today scrolled, Library, Library filtered.
- `l-b.png`: no-match search, new custom exercise from no-match (item 19), validation, stock muscle picker (item 20).
- `l-c.png`: custom exercise after picking a muscle, custom detail, detail scrolled, blank sheet after EDIT (item 1).
- `l-d.png`: Copy editor on the second try (items 1 and 20), "Untitled routine" (item 15), Add Session sheet, empty session with disabled save bleeding into the safe area (item 16).
- `large-reorder.png`: session editor with "•••" indexes (item 13), save bleed (item 16), Add Session sheet.

Large phone, dark mode:

- `dark-a.png`: Today in dark mode (items 22 and 25), workout with the warm-up ramp.
- `dark-b.png`: workout scrolled, and the More menu.
- `dark-c.png`: workout with the warm-up ramp, Program staying light (item 9), Settings with the backup footer (item 14).
- `dk2-a.png`: rest bar, expanded rest sheet (item 23), Progress screens.
- `dk2-b.png`: History, a past workout, Library, exercise detail.
- `dk2-c.png`: Program staying light, with "1 sets" in the Resume banner (items 9 and 25), session editor in dark mode (items 6, 13, 16, and 17), Settings (item 14).
- `dk2-rest-bottom.png`: bottom of the expanded rest sheet, with SKIP cut off (item 23).

Small phone at AX3:

- `ax-a.png`: Today (item 24) and the workout warm-up ramp (item 10).
- `ax-b.png`: workout with the RPE chips (item 24), More menu, Program (item 8), Settings.
- `ax-c.png`: workout warm-up ramp (item 10), Program templates (item 8), Settings.
- `ax-d.png`: workout warm-up ramp (item 10), and Program (item 8).
- `ax2-a.png`: Progress and History (item 11).
- `ax2-b.png`: workout summary (item 11), Library, exercise detail (items 24 and 25).
- `ax2-c.png`: session editor (items 6, 12, 16, 17).
- `ax2-d.png`: session editor (items 12, 16, and 17) and Settings.
- `ax2-overrides.png` and `ax2-setrows.png`: close-ups for item 12.
- `codex-ax.png`: Codex's own AX3 evidence from `verification/`, including the item 10 defect.

Probe results (`probe/`): each folder holds the screenshots, UI trees, and a `zz-issues.txt` with the measured values.
