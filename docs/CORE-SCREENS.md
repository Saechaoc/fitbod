# Core screens and interactions

Current behavior reference, reconciled 2026-11-08. Approved future Today/Program
layouts live in [design-map/redesign](design-map/redesign/); their delivery and
acceptance live in [ROADMAP.md](ROADMAP.md). Historical captures describe their
stated build and do not prove current acceptance.

The identity is **BRU**: warm paper, architectural ink panels, a single orange
action accent, condensed display headings and monospaced training data. The
existing Claude Design export is the visual reference, not a replacement app.
Native code is SwiftUI and SwiftData.

## Terminology and navigation

**Routine** is an ordered group of sessions (`Split`). **Session** is a workout
template (`SessionTemplate`) with ordered exercises and targets. **Workout** is
a logged snapshot (`Session`). A block schedules a routine across phases.
The core journey can start from a session without creating a block.

Four persistent tabs: Today, Program, Progress, Library. Settings opens from
Today. Each tab owns its navigation stack. This follows the supplied design
assets. Completed history opens from Progress → Workouts. Program/session/Live
Activity entry requests the logger on Today's stack; Back returns to Today.

## Reference → native mapping

| Screen | Claude Design asset | Native implementation |
| --- | --- | --- |
| Exercise library | `phase-1--library.png` | `ExerciseLibraryView`, `ExerciseRow`, filter sheets |
| Exercise detail | `phase-1--exercise-detail.png` | `ExerciseDetailView`, previous performance, muscle stimulus and instructions |
| Custom exercise | `phase-1--custom-exercise.png` | `CustomExerciseEditor`, `CustomExerciseDraft` |
| Session builder | `phase-2--routine-builder.png`, `phase-2--new-routine-empty.png` | `RoutineBuilderView`, `RoutineExerciseCard`, `PrescriptionEditorRow` |
| Active workout | `phase-2--active-session.png` | `SessionLoggerView`, `SessionExerciseCard`, `SetRow`, `RestTimerOverlay` |
| Workout history | `phase-2--history.png` | `SessionHistoryView`, `SessionHistoryRow`, `SessionDetailView` |
| Settings | `phase-6--settings.png` | `SettingsView`, DEBUG component gallery |

Assets live in `bru-screens/Fitbod-Session/screens/`. Preserve those exports as
source designs; runtime screenshots are separately recorded verification
evidence. The design system's component table maps native primitives to each
reference screen. Use supplied exports, current approved layouts and native previews.

## Exercise library

| State | Content and behavior |
| --- | --- |
| Loading | Preparation message while local catalog seeding runs. |
| Populated | Search field, muscle/equipment/mechanic facets, letter sections and exercise rows. Tapping a row opens details; picker mode selects it and returns. |
| Filtered | Active facets are visible; Clear filters resets them. Search is debounced by 150 ms and composed with the filters in a SwiftData predicate. |
| No matches | A clear empty-state explanation with actions to clear search/filters or create a custom exercise. |
| Detail | Exercise name, equipment, muscles, instructions and previous completed performance. Custom records expose Edit; catalog records can be copied as custom. |
| Custom editing | Name, primary and assisting muscles, equipment, mechanic and optional local photo. Save validates the trimmed name and a primary muscle with stimulus ≥0.5. |
| Validation error | Save keeps the form open and identifies the missing name or primary muscle in words. Persistence errors keep edits available for retry. |

The pattern facet is hidden because the bundled catalog has no pattern values.
Do not expose a facet whose options cannot return meaningful matches.

## Routine and session builder

| State | Content and behavior |
| --- | --- |
| Empty Program | New routine creates a reachable routine; the block flow is also available. |
| Empty routine | A wrapping name field and Add session path. New sessions attach to the routine. |
| Populated routine | Ordered sessions; open to view targets and Start workout. Edit mode supports reordering and removal. |
| Empty session | Name, intent and progression controls, Add exercise slot, visible Save action. Invalid Save explains the missing fields. |
| Populated session | Ordered exercise cards with target sets, rep range, rest, optional tempo and warm-up settings. Shared BRU controls replace ad hoc form controls where implemented. |
| Reordering exercises | The trailing 44pt handle opens Move up/down. Boundary moves are disabled; saving writes contiguous order indices. The same actions are available in the card's context menu. |
| Editing | Save updates the template. Duplicate saves what the editor shows as a separate session; with unsaved changes it asks first, and they go into the copy only. Archive removes it from new-workout pickers. Active-block editing explains that future prescriptions use the change. |
| Validation error | A missing name or empty exercise list is explained before persistence. Archive conflicts list affected routines. |

Realistic review content: **Push A · Strength and accessory work** with Barbell
Bench Press — 3 × 5–8, rest 3:00; Incline Dumbbell Press — 3 × 8–12, rest 2:00;
Cable Rope Triceps Pushdown — 2 × 12–15, rest 1:30. Include long labels such as
**Chest Supported Dumbbell Row with Neutral Grip** when checking wrapping.

## Active workout and completion

| Interaction | Contract |
| --- | --- |
| Start | Copy template/session/exercise names and prescription into a workout instance. Reject a second active workout and offer Resume. Explain start failures. |
| Weight and reps | Editable numeric fields start from prescription/previous values. Persist edits and completion. Keep the keyboard from obscuring the action being used. |
| Complete / reopen | Completing a valid set records its values and starts rest. A completion glyph exposes both states and a word label. Reopening retains the entered weight/reps. |
| Input validation | Reps must be positive and weight finite. Loaded exercises require positive weight; bodyweight may record zero added load, and signed assistance loads follow the shared validation rule. Invalid completion is disabled with an explanatory accessibility hint. |
| Add / remove set | Append a planned working set; removing a set renumbers the survivors. The change affects this workout. |
| Previous | Display performance from a finished earlier workout of the matching intent; exclude this workout and unfinished workouts. |
| Rest | Countdown derives from an absolute deadline. ±15 seconds changes that deadline; Skip ends rest. Rest survives backgrounding, leaving the logger and relaunch. |
| Resume | Today exposes the unfinished workout with accurate completed-set count and elapsed time. Relaunch must preserve entered values and rest deadline. |
| Discard | Today and the logger menu permit discard. Empty workouts discard immediately; logged sets require confirmation naming what will be lost. Program's visible discard row remains planned in RM-012. |
| Finish | The BRU paper sheet shows logged-set count/elapsed time, Finish (Discard if empty) and Keep logging. Finishing opens the summary; History rows reopen it. |

One-handed use prioritizes full-row set targets, 44pt controls and a prominent
action near the active set. Long content scrolls; fixed chrome uses safe-area
insets. At accessibility text sizes, labels wrap and compact groups reflow.
VoiceOver receives action names, values, selection and completion states.

The session builder owns its draft for the whole presentation. Nested exercise
pickers do not replace the unsaved name or targets. Unsaved exercise rows use
stable presentation identities until their persisted IDs are assigned.

## Product assumptions

- Preserve the existing iOS-only SwiftUI/SwiftData stack and offline storage.
- Preserve established BRU assets and bundled font licenses.
- Keep baseline schema reset/recoverable store move-aside behavior from the
  prior authorized handoff; this is not a historical-data migration promise.
- Preserve the current program graph and frozen-workout contracts in
  [ARCHITECTURE.md](../ARCHITECTURE.md); remaining block refinements have RM owners.
- The supplied reference filenames retain the older “routine builder” name;
  native UI copy uses “session” according to the established glossary.
- Physical-device haptics, notification permission, lock-screen activity and
  actual VoiceOver navigation need their own evidence. A simulator screenshot
  or accessibility-tree query does not prove those behaviors.
