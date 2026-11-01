# Assumptions

What the design map takes as given.
Each item is a statement that can be checked.

## Source of truth

- The code is the truth.
  Where a document and the code disagree, the code wins and the screen file records the difference.
- The map shows the app as built at commit `61353088`, which was `origin/main` on 2026-10-31.
- The May mock-ups in `bru-screens/` use older names: their "Routine" is today's Session, and their "Routines" tab is today's Program.
- The mock-ups' colours differ from the shipped tokens, and the tokens in `fitbod/Design/Color+BRU.swift` win.

## Words

The map uses the app's words, as listed in [conventions.md](conventions.md#words).

## Phones and captures

| | iPhone 17e | iPhone 17 Pro Max |
|---|---|---|
| Simulator | `design-iPhone 17e` | `design-iPhone 17 Pro Max` |
| Width | 390 pt | 440 pt |
| Runtime | iOS 26.5 | iOS 26.5 |
| Light, default text | every screen and state | every screen and state but two |
| AX3 text | main states | main states |
| Dark | main states | not captured |

- Xcode 26.5 builds the `fitbod` scheme in Debug from a private worktree copy of the base commit.
  The tour in `tools/DesignTourUITests.swift.txt` is copied into that copy's UI test folder, so no file in the repository's targets changes.
- The status bar shows 9:41, a full battery, full Wi-Fi and four cellular bars.
- Default text is the Large content size.
  AX3 is the Accessibility Extra Large content size, which the tour passes as a launch argument.
- Each screen file's `captured` field holds its capture date.
  The seeds count days back from the launch, so a weekday or date shown in a screenshot depends on the day it was taken.
  US daylight saving time ends on 2026-11-01, during the capture runs.
- Every capture took place on 2026-10-31, apart from the reruns below, which took place on 2026-11-01.
  So a screen that shows the date reads Saturday, October 31, except in these reruns, where it reads Sunday, November 1.
  - iPhone 17e at AX3, `testMainToday` and `testMainLoggerSheets`: block-review, dialog-discard-workout-slab, dialog-remove-exercise, dialog-workout-menu, history, library-picker, per-muscle-detail, pinned-note, session-template-detail, swap-exercise, today, today--empty, today--volume, weekly-recap, workout-notes and workout-summary.
  - iPhone 17 Pro Max at AX3, `testMainLibrary`: custom-exercise, dialog-custom-exercise-discard, dialog-delete-exercise, equipment-picker, exercise-detail, exercise-history, filter-picker, library and muscle-picker.
- Two states have no Pro Max screenshot.
  - The open plate stack, `logger--plate-stack`: no tap opens it, and the tour shoots it only when it opens.
    The 17e image of that name comes from the first run, before the tour checked, and shows the logger after the taps.
  - The notification prompt, `notification-permission`: it first came up in `testMainLogger`, which does not expect it.
    That test's set-logged screenshot shows it; XCUITest's interruption handler then answered it, so `testMainToday`, which shoots it, found none.

## How each state is reached

Every launch starts from an empty store (`-fitbod-reset-store`) with at most one seed.
Seeds clash when they share a launch, because only one workout can be in progress and only one block can be active.
A seed runs after the 702-exercise catalog import, which can finish after the tab bar appears, so the tour waits for an element the seed creates.
The walks W01 to W16 follow the state matrix in [plan.md](plan.md#state-matrix-seed-walk---screens-and-states).

| Walk | Launch arguments | What the store holds |
|---|---|---|
| W01 fresh | none | the catalog and nothing else |
| W02 settings | none | the catalog, then the settings the walk changes |
| W03 demo | `-fitbod-seed-demo-workout` | a "Push A" session with one finished workout earlier this week, and today's Push A in progress |
| W04 stalled | `-fitbod-seed-stalled-exercise` | a "Bench Stall" session whose bench press repeats one top set across its plateau window, and today's workout in progress |
| W05 calibrating | `-fitbod-seed-calibrating-set` | a "Calibrating Bench" session run by RPE with one short finished workout, and today's workout in progress |
| W06 counts | `-fitbod-seed-empty-between` | Push A workouts logged six days and one day ago, with an empty one three days ago |
| W07 recap | `-fitbod-seed-recap-with-empty -fitbod-start-program` | last week's logged Push A and an empty Pull B, with this week's recap due |
| W08 active block | `-fitbod-seed-active-block` | a "Live Routine" routine with the "Live Push" session, on an active "Live Block" with nothing logged |
| W09 ended block | `-fitbod-seed-ended-block-recap -fitbod-start-program` | the same block started the week before last, with one finished workout, then ended, with its review and this week's recap due |
| W10 block states | `-fitbod-seed-block-states` | a "States Routine" routine with an active, a ready and a draft block |
| W11 past plan | `-fitbod-seed-block-states-past-plan` | the same blocks, with the active block's four-week plan over |
| W12 powerbuilding | `-fitbod-seed-powerbuilding` | an "Upper Lower" routine and two blocks named "Powerbuilding", one active and one draft |
| W13 progress | `-fitbod-seed-progress-history` | four weekly "Bench & Squat" workouts |
| W14 tonnage | `-fitbod-seed-weekly-tonnage 8` | eight Sunday workouts of "Tonnage Weeks" |
| W15 routines | none | the routines and sessions the walk builds |
| W16 blocks | none | the blocks the walk builds |

Each seed's own header in `fitbod/App/` describes it in full.
W03 runs as three tests.
The third, `testW03cWorkoutInProgress`, uses the W09 launch for the Workout in progress alert and the resume after a relaunch, because the demo's Push A belongs to no routine and no screen offers to start it a second time.

## States not captured

Most of these states need data that no seed creates and that no short walk through the app reaches.
The iPhone 17e runs in light mode confirmed this list on 2026-10-31.

- The "Preparing library…" splash, which never reaches the screen.
  A screen recording of a launch on a reset store shows the white launch screen and then Today, with no splash frame between them.
- The deload advisory banner on Today and the Fatigue Signals sheet, which need three finished workouts with a fatigue signal.
- The stalled chips DROP INTENSITY, TRY VARIATION and CONSIDER DELOAD, because the stalled seed always suggests ADD VOLUME.
- The ALL HISTORY expansion on Program, which needs four finished blocks.
- A block review with e1RM changes.
- A finished block whose archive cannot be read.
- The state shown when a seed fails.
- The restore errors other than "Finish your session first", such as an unreadable file, because every backup the tour can make is a good one.
- A session with no exercises, because a session cannot be saved without one.
- The rest timer's Live Activity.
- The open plate stack under a set, because no tap opens it, an app problem that the audit records.

## Built but unreachable

- `BlockCard` and `BlockPickerMenu` are never drawn.
- `RoutinesListView`, with its New folder and Move routine sheets, appears only in Xcode previews.

## Open tickets that will change screens

The tickets in `docs/conway-specs/tickets/` were open at the base commit.
When one merges, the screens it names change.
[audit.md](audit.md) has one row for each ticket that covers a problem the map found, and that row names the screens where the map found it.

- Copy and polish: T34 (done), T35 (done), T36 (done), T37 (done), T38 (done), T85 (done) and T98 (done).
- The session editor: T110 (done), T111 (done) and T115 (done).
- Other screens: T106 (done), T107 (done), T108 (done), T109 (done), T113 (done), T114 (done), T116 (done), [T118](../conway-specs/tickets/T118-weekly-tonnage-label-and-rows.md), [T120](../conway-specs/tickets/T120-new-block-toast-and-duration-steppers.md) and [T122](../conway-specs/tickets/T122-routine-session-drag-slots.md).
- The whole look: [T43](../conway-specs/tickets/T43-design-refresh.md), a design refresh from a newer export.
- Tickets that overlap the map itself: [T46](../conway-specs/tickets/T46-screenshot-tour.md), whose screenshot names the map's names match so its tour can replace the images one for one, and [T48](../conway-specs/tickets/T48-product-docs-roadmap-gallery.md).
