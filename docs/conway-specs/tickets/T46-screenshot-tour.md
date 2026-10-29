---
id: T46
title: Screenshot tour
phase: 6
items: []
depends_on: [T45]
size: L
sim: both
owns: [new:fitbodUITests/MilestoneScreenTourUITests.swift]
---

# T46: Screenshot tour

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The plan asks for a hands-on look at every milestone screen on both phones, at default text and AX3, in light and dark mode.
No test captures every screen, so nobody has seen them all since the fixes landed.

## Target

The 33 screens below, in eight configurations: two phones, default text and AX3, light and dark.

| Name | Main view |
|---|---|
| today | `TodayView` with an active block |
| today-empty | `TodayView` on a fresh store |
| settings | `SettingsView` |
| volume-targets | `MuscleVolumeTargetEditor` |
| plate-inventory | `PlateInventoryEditor` |
| history | `SessionHistoryView` |
| workout-summary | `SessionDetailView` |
| program | `ProgramView` with routines and a block |
| program-empty | `ProgramView` on a fresh store |
| block-overview | `BlockOverviewScreen` |
| new-block | `BlockBuilderView` |
| new-routine | the name step from T21 |
| routine-editor | `SplitDetailView` |
| archived-routines | the archived routines list from T20 |
| session-editor | `RoutineBuilderView` |
| logger | `SessionLoggerView` with one set logged |
| warmup-ramp | `SessionLoggerView` with a warm-up ramp showing |
| rest-timer | `RestTimerOverlay` |
| why-this-weight | `WhyThisWeightSheet` |
| plate-calculator | `PlateCalculatorSheet` |
| workout-notes | `WorkoutNotesSheet` |
| pinned-note | `PinnedNoteSheet` |
| progress | `ProgressHomeView` |
| exercise-progress | `ExerciseProgressView` |
| prs | `ExercisePRsView` |
| weekly-tonnage | `WeeklyTonnageView` |
| compare | `SessionComparisonView` |
| volume | `FatigueSurfaceView` |
| library | `ExerciseLibraryView` |
| exercise-detail | `ExerciseDetailView` |
| exercise-history | `ExerciseHistoryView` |
| custom-exercise | `CustomExerciseEditor` |
| muscle-picker | `MusclePickerSheet` |

## Change

1. Write `MilestoneScreenTourUITests`.
   It reaches every screen in the table and saves one screenshot per screen, named after the table's name column.
   One test per tab is fine.
   Each test launches with a fresh, seeded store, so no test depends on another.
2. Run the tour in eight configurations, in this order: the small phone at default text in light, default text in dark, AX3 in light and AX3 in dark, then the same four on the large phone.
3. Export each run's screenshots, and name each file `<phone>-<size>-<appearance>-<screen>.png`.
   Phone is `17e` or `17promax`, size is `default` or `ax3`, and appearance is `light` or `dark`.
4. Look at every screenshot at full size.
   After each configuration, append its section to `findings.md` and its lines to `notes.md` before you start the next one, so a retry can continue where you stopped.
5. In `findings.md`, write one row per defect: the screen, the configuration, what is wrong, the severity and the screenshot file.
   Look for clipped or truncated text, overlaps, mid-word breaks, controls cut off or off screen, low contrast, stock iOS styling on a BRU screen, code names or wrong plurals in copy, and anything misaligned.
6. Do not fix anything.
   The coordinator turns each finding into a new ticket.

## Constraints

- Use these severities: P0 loses data or crashes, P1 is a control that does not work or cannot be reached, P2 is text or a control that is clipped, overlapping or unreadable, and P3 is polish.
- The tour only navigates and captures.
  It asserts only that each screen appeared.
- Change no app behavior.
- At the end, set both phones back to default text and light mode.

## Ownership

You may create the tour test, and DEBUG-only seed helpers next to `fitbod/App/DemoWorkoutSeed.swift` if a screen needs data.
Ask before you edit anything else.

## Repro first

There is no bug to reproduce.
The screenshots are the evidence.

## Observable acceptance

- The tour passes in all eight configurations.
- `screens/` holds 264 screenshots, one per screen per configuration, named as in step 3.
  A screen that cannot be reached in some configuration is a P1 finding, not a missing file.
- `findings.md` has one section per configuration, with its defects or the words "no defects".
- `notes.md` has one line per screenshot.

## Hints

- Use the T01 launch helpers to pass the DEBUG flags `-fitbod-seed-demo-workout` and `-fitbod-start-program`.
- Give each screenshot attachment the keepAlways lifetime.
- Reuse the navigation helpers that other UI tests already use for deep screens such as the muscle picker.
- `docs/CORE-SCREENS.md` describes the states each screen should show.
