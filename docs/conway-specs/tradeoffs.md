# Engineering calls

Each entry is a call the senior dev made, with the options rejected and why.
Tickets point here by entry title.
Product decisions are in [decisions.md](decisions.md), and they win over this file.

## Run setup

### Serial dispatch in the main checkout

- Call: one code worker at a time, in `/Users/chrissaechao/Desktop/fitbod` on `main`, in ticket id order.
- Rejected: parallel workers in separate worktrees.
- Why: there are only two dedicated simulators, and UI tests cannot share them.
  Many tickets touch the same hot files (`ProgramView.swift`, `BlockBuilderView.swift`, `SessionExerciseCard.swift`).
  GitNexus `detect_changes` reads only the main checkout.
- Exception: T31 needs no simulator and edits no repo file, so it may run beside a code worker.

### Workers skip GSD

- Call: workers never run `/gsd-*`; the tickets and [run-log.md](run-log.md) are the planning record.
- Rejected: one `/gsd-quick` per ticket inside each worker.
- Why: it would run a second orchestrator inside the first one, and GSD executors have already run out of context on this repo's large `CLAUDE.md` and hot files.
- Condition: the project `CLAUDE.md` forbids edits outside GSD unless the user says so, so the coordinator needs the user's explicit approval first.

## Session editor

### Reps entry

- Call: two `BRUStepper` controls for low and high reps.
  The range is 1 to 30, unless the model already defines one.
  The low stepper can never go above the current high value, and the high stepper can never go below the current low value.
- Rejected: text fields that select all on focus.
- Why: steppers suit gym use, need no keyboard, and make the low-to-high rule impossible to break.

### RPE entry

- Call: one BRU toggle labeled "Target RPE", plus one `BRUStepper` from 6.0 to 10.0 in steps of 0.5.
  Off means no target.
  Turning it on starts at 8.0.
- Rejected: `InlineRPEChipRow`, because it offers whole numbers only, while the rest of the app uses half steps (`TuchschererTable`, `DecimalRPEPickerSheet`).
- Rejected: typing 0 to clear, because a hidden meaning for 0 is not discoverable.

### Rest time format

- Call: rest time shows as minutes and seconds everywhere, such as "3:00", matching the rest timer.
- Rejected: "180s" and "3 min rest", which the app shows today in different places.

### Reorder control

- Call: replace the "⋮⋮" glyph with a labeled BRU text control, such as "MOVE", that opens the same menu.
  The row stops merging its accessibility children, so element identifiers stay unique.
- Rejected: real drag-to-reorder, because it is a new interaction and outside this milestone.
- Why: "⋮⋮" looks like a drag handle, but it opens a menu.

## Workout logger

### Skip warm-ups done state

- Call: after a skip, the ramp collapses to one "WARM-UPS SKIPPED" line with an UNDO action.
- Rejected: done styling on every ramp row, which adds noise and still looks like work to do.

### Visible WHY control

- Call: a small "WHY" text control in the weight cell of each incomplete work set that has an explanation.
  It has a 44pt target, fits the 390pt phone at default text and AX3, and has the VoiceOver action "Why this weight".
  The long-press path is removed.
  Use writes the suggested weight, clears the manual-override flag and closes the sheet.
  Override closes the sheet and focuses the weight field.
- Rejected: the long press, because the text field swallows it and nobody can discover it.
- Rejected: an SF Symbol info button, because BRU screens use text labels.

### Empty prescribed weight

- Call: a prescribed weight of 0 means no prescription, so the field shows its empty placeholder.

## Program and blocks

### One template catalog

- Call: `BlockTemplates.swift` is the only catalog.
  Its order is Hypertrophy Meso, Generic Strength Meso, Powerlifting Peak, then 5/3/1 Cycle.
  New Block adds Blank as its own "start empty" choice.
  Program rows show only facts the template holds: name, total weeks and phases.
  The cadence and level text and the POPULAR tag go, because no data backs them.
  5/3/1 Cycle uses the same per-kind multipliers as the other templates.
- Rejected: keeping the hand-written row text, because it describes blocks the app does not build.

### Preset name rule

- Call: picking a preset sets the block name only when the name is empty or still equals the previous preset's name.
- Why: decision 2 says a preset sets the name, but overwriting a name the user typed would lose their input.

### Two saves

- Call: the top action reads "SAVE DRAFT" and needs only a name.
  The bottom action reads "SAVE AS READY" and is enabled only when the block would be ready once saved.
  Ready means the existing derived-status rule: a name, at least one phase, and a routine with at least one session, whose training days match its sessions under fixed weekly scheduling.
  While the bottom action is disabled, its label names the first missing piece, in the style of today's "NAME FIRST".
  In edit mode, only the bottom "SAVE CHANGES" shows.
- Rejected: the bottom action keeping today's rule (a name and one phase), because it would label a draft as ready.
- Why: block status is derived (completed, active, ready, draft), so "ready" must mean what `Block.derivedStatus` says.

### Block numbers

- Call: blocks are numbered in start-date order, with ties broken by name.
- Rejected: the ISO week number, which shows "#41" in October.
- Why: `Block` has a start date but no creation timestamp, and a schema change is not allowed.
  A number can shift when a start date changes, and that is acceptable.

### Archived routines

- Call: Program shows an "Archived routines" entry only when at least one routine is archived.
  It opens a list with RESTORE on each row.
  Every other routine query leaves archived routines out.
  A block that already uses an archived routine keeps working.
- Rejected: a Settings entry, because users look for routines on Program.

### New routine flow

- Call: "+ New routine" opens a name-first step modeled on `BruNewRoutineScreen` in `bru-screens/create-flows.jsx`.
  The routine is inserted only when the user saves the name.
  The routine editor then replaces the name step.
  The full inline creator from that mockup goes on the roadmap.
- Rejected: deleting an untouched "Untitled routine" when the user leaves, because the heuristic is fragile and the empty routine still flashes in lists.
- Rejected: building the full inline creator now, because it is a large new design surface.

## Gestures and sheets

### Dirty editors and swipe-down

- Call: editors with unsaved changes resist swipe-down with SwiftUI's standard interactive-dismiss modifier, tied to their dirty state.
  CANCEL still asks before it discards.
- Rejected: a UIKit presentation-delegate bridge that shows the Discard dialog on swipe, because it adds UIKit glue for a small gain.
- Note: notes sheets do not resist, because decision 4 says swipe-down discards.

### Swipe-back everywhere

- Call: one app-wide fix lets the edge swipe go back whenever a navigation stack holds more than one screen, even when the screen hides the system bar.
  A screen that asks before leaving turns the swipe off while it has unsaved changes.
- Rejected: per-screen fixes, because about 36 files hide the bar.
- Rejected: showing the system bar again, because it breaks the BRU headers.

### Sheet close labels

- Call: sheets that edit data close with "CANCEL", sheets that only show information close with "DONE", and pushed screens go back with "‹ BACK".

## Heatmap

### Exact hit areas

- Call: each heatmap block's tap area is its exact drawn rectangle, with no padding.
  This is an explicit exception to the 44pt rule.
- Why: the blocks tile a grid, so padding can only steal a neighbor's taps.
  The volume list on the same screen gives every muscle a full-width row, and that list is the large-target path.

### Heatmap VoiceOver

- Call: one VoiceOver element per muscle.
  The left half carries the label and value, and the right half is hidden from VoiceOver.
  NECK is decorative, so it is hidden and is not a button.
- Rejected: hiding the whole grid, because the per-muscle values are useful to VoiceOver users.

## Progress and history

### Shared counts

- Call: one shared rule counts logged work sets (completed, not warm-up), and one shared rule says a finished workout is empty when it has no logged work sets.
  The count is `Session.loggedSetCount`, which the parallel effort added in `4d7e07e`.
  The empty-workout rule builds on that count, in `SessionSetActions`.
  One small plural helper in `fitbod/Design/` formats count labels, following the `count == 1 ?` pattern in `ProgressHomeView.swift`.
- Rejected: String Catalog plural variants, because the app is not localized and the extra machinery buys nothing yet.

### Compare

- Call: Compare uses the latest finished workout that has logged work sets and the previous one that also has them.
  With fewer than two, it shows its existing locked state.
  Exercise names are left-aligned.

### Weekly Tonnage weeks

- Call: the chart bins weeks with the aggregator's rule, which is the user's week-start setting (`weekStartsMonday`, Monday by default).
  The chart uses a fixed week domain that covers the selected range, so one week of data does not fill the whole chart.
- Why: the aggregator and Today already follow that setting, while the chart's bins follow the device calendar, which starts weeks on Sunday in the US.

### Per-week rate

- Call: PER WEEK shows up to two decimals with trailing zeros trimmed, such as 0.25, 0.5 or 2.
- Rejected: "1 every 4 weeks", which is longer and harder to fit at AX3.

### Today's third stat

- Call: when the week trend is flat, the value under "W1 / 5" shows the current phase's short label, such as "ACCUM", instead of a dash.
  Up and down arrows stay as they are, and VoiceOver reads the full phase name.
- Rejected: the dash, which reads as missing data, most often in a block's first week.
- Rejected: the phase and the arrow together, which do not fit a third of the 390pt phone at default text.

## Export and backup

### One-tap share

- Call: Export CSV, Export JSON and CREATE backup each use one `ShareLink` whose `Transferable` file renders when the share sheet asks for it.
  SwiftData reads happen on the main actor, and only value snapshots cross to other threads.
- Rejected: render first, then swap the card to a `ShareLink`, which needs two taps.

### Backup keeps routines (finding N1)

- Call: backups include every routine, archived or not, with its ordered slots, and each slot names its session by id.
  Each block names its routine by id, and each logged workout names its slot by id.
  The new list is named after `Split`, because the existing `routines` list holds sessions, from the naming before Schema V7.
- Call: restore deletes slots and routines before everything else, so no slot ever points at a deleted session.
  It then rebuilds them and relinks blocks and logged workouts by id.
- Call: the backup format version goes from 1 to 2.
  The new fields are optional, so older backups still decode.
  Restoring an older backup leaves no routines, because restore replaces everything and an older backup holds none.
- Call: the JSON export shares the same document, so it gains the routines too.
- Rejected: keeping the current routines when an older backup is restored, and relinking their slots by session id.
  Restore promises to replace everything, and a mix of old routines and restored sessions is hard to predict.
- Why: today a backup holds no routines, and restore deletes every session while old slots still point at them.

## Library

### Muscle picker labels

- Call: each muscle picker row shows only the muscle's display name, and rows sort by display name.
  The region text goes.
- Rejected: changing Lower Back's stored region, because the region is seeded data that the Library filters also read.
- Why: the region adds little to a 17-row list, and "Lower Back · Upper" reads as an error.

### Muscle weight control

- Call: each muscle row in the custom exercise editor uses the design's four weight ticks: 25%, 50%, 75% and 100%.
  The row also shows the current percent.
  A stored weight that is not on a tick stays as it is until the user taps a tick.
- Rejected: keeping the stock slider, because BRU has no slider and the design shows ticks.
- Why: the editor's defaults are 100% for a primary muscle and 50% for a secondary one, and both are ticks.

## Design references

### Which design to build from

- Call: build from the Oct 2 snapshot in `bru-screens/Fitbod-Session/`, unless T31 finds a newer export.
- Why: the build already follows that snapshot, and the newer export had not landed when this bundle was written.
