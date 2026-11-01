# Handoff: training-model coherence under months of real use

Written 2026-11-01 after an investigation of how live-editable plans, frozen snapshots, historical corrections and adaptive prescriptions compose.
Read this with `CLAUDE.md`, `docs/DEVELOPMENT.md`, the product decisions in `docs/ROADMAP.md` and the approved `docs/design-map/mockups/history-editing.html`.
The product decisions this work needs are proposed in `docs/ROADMAP.md` under "Decisions awaiting product direction" and are not repeated here.

## Conclusion

The model is coherent today only because history is append-only.
Workouts start one at a time, finish in start order, and are never edited, so three readers that key time on three different fields always agree, and two readers that answer "which block" two different ways always agree.
The approved history-editing screen removes that guarantee.
Nothing in the schema or the services puts it back, so the first implementation step is one rule for a workout's time and block membership, enforced by one edit service, before any editing UI exists.

A second defect is live today.
The prescription freezes when a workout starts, but the WHY sheet recomputes from live history and the live block every time it renders.
Editing the active block mid-workout makes the sheet explain a weight the pending sets do not hold.
Every history correction would do the same to an in-progress workout.

Everything else held up.
Template edits never reach logged workouts (`SessionSnapshotFidelityTests`), the block archive holds configuration only, every record, volume and progression value is derived on read with no stored copy to go stale, and rotation survives slot removal, reordering and templates used twice.

## Evidence

A throwaway Swift Testing suite ran once on 2026-11-01 on the `fitbod-logger iPhone 17` simulator and passed 3 of 3, which means every behavior below is reproduced, not inferred.
The suite was deleted; the scenarios are the acceptance tests in the implementation steps.

- **X1, reproduced defect.** Baseline squat 100 kg a week ago, active block one day old with a 0.9 accumulation phase, block-periodized template.
  `SessionFactory.start` froze `prescribedWeight = 90`.
  `BlockDraft(block:)` plus `save(into:)`, the path Today's EDIT BLOCK takes (`TodayView.swift:267`, `ProgramView.swift:201`), set the phase to 1.0.
  `SessionFactory.prescription` for the same session now returned 100 while `prescribedWeight` stayed 90.
  `SessionExerciseCard.currentExplanation()` (`SessionExerciseCard.swift:475`) runs that same step at render time, so the WHY sheet shows 100 over sets pre-filled with 90.
- **X2, demonstrated limitation.** Two-slot rotation block, A logged on day 1 at 100 kg, B on day 3 at 105 kg.
  Every reader agreed B was latest.
  Moving only `startedAt` of B to day 0, which is what a Date picker bound to `startedAt` would do, split them: `PreviousMatchingIntent` now called A's 100 the last session and `SessionSummary.prsBySession` moved the record to B, but `TodayResolver` kept B as the anchor through `completedAt` and offered A again.
  Moving `completedAt` and every `SetEntry.completedAt` by the same delta restored agreement.
- **X3, demonstrated limitation.** A finished empty workout cached as empty by `SessionSetActions.emptyWorkoutIDs` stayed empty in the cache after a set was logged into it, while `isEmptyWorkout` said otherwise.
  The shortcut comment at `SessionSetActions.swift:163` states the assumption the edit screen breaks: "a finished workout's sets never change in the app".

GitNexus impact (index rebuilt 2026-11-01) rates every reader named below CRITICAL by transitive count (about 540 symbols each, mostly tests and screens).
The direct callers are small and listed per step.

## The time and membership map

| Reader | Orders or windows by | Gate | Where |
|---|---|---|---|
| Rotation anchor | `Session.completedAt` desc | finished, slot in the block's split | `TodayResolver.swift:109-110` |
| Previous session for progression | `Session.startedAt` desc, no bound against the current session | finished, same intent, not the current session | `PreviousMatchingIntent.swift:171-184` |
| RPE calibration history | `SetEntry.completedAt` desc, newest 50, and the time kernel's date | finished, same intent, complete, reps and weight > 0 | `SessionFactory.swift:522-533` |
| In-workout PR table seed | `SetEntry.completedAt` asc | complete, not warm-up; no finished gate | `SessionFactory.swift:660-687` |
| Workout summary and history PR marks | `Session.startedAt` | finished | `SessionSummary.swift:125,141` |
| Block review volume, set and session counts, e1RM deltas | `SetEntry.completedAt` in `[block.startDate, block.endDate ?? now]` | complete, not warm-up; no finished gate, no `Session.block` check | `BlockReviewView.swift:20-21,523-536` |
| Block review PRs | replay by (`Session.startedAt`, `SetEntry.completedAt`, order), counted by `SetEntry.completedAt` in the window | finished | `BlockReviewView.swift:478-514` |
| Weekly volume and fatigue | `Session.startedAt` window | | `FatigueModel.swift:313` |
| Plateau and deload advice | `Session.startedAt` desc | finished | `PlateauDetector.swift:246`, `DeloadAdvisor.swift:552-561` |
| Compare | `Session.startedAt` within 14 days, same template, exercise and intent | counted workouts | `SessionComparator.swift` |
| Block membership for rotation | `Session.block` edge, set at start | | `TodayResolver.swift:90-143` |
| Block membership for review | the block's date window | | `BlockReviewView.swift:20-21` |

Block windows never overlap: `BlockLifecycleService.start` sets `startDate = now` and ends every other active block at `now` (`BlockLifecycleService.swift:94-102`), and `end` sets `endDate = now`.
That makes "the block whose dates contain a start time" unique or none, which the contract below relies on.
`BlockDraft.save` rewrites `startDate` for any saved block (`BlockDraft.swift:151`); the builder does not show that field for an active block today, so it is a guard to add, not a reproduced defect.

## Behavioral contract

1. A workout's place in time is `Session.startedAt`.
   `completedAt` marks it finished and equals the start plus its duration.
   Every `SetEntry.completedAt` lies inside `[startedAt, completedAt]`.
   Moving a workout moves all three by one delta and never into the future.
2. A workout belongs to the block whose dates contain its start.
   `Session.block` is that block, written at start and rewritten by a date edit.
   Rotation, reviews and volume read the same membership.
   `Session.slot` is never rewritten; the resolver already ignores a slot outside the block's split.
3. A prescription freezes per exercise when the workout starts, or when the exercise is swapped in or added.
   Frozen: targets, `prescribedWeight`, `exerciseNameSnapshot`, `templateName`, `intentRaw`, `progressionKindRaw`, `wasManualOverride`, the block and slot edges.
   No correction, template edit or block edit rewrites them.
   The WHY sheet presents the frozen weight as the fact and says when the live computation differs.
4. Logged evidence is correctable: set weight, reps, RPE and completion, the set list, and the workout's start time.
   Every derived value (next prescription, records, volume, plateau and deload advice, review statistics, Compare, counts) is a pure function of current evidence and recomputes on read.
   Nothing derived is stored, so a correction leaves no stale derived state except view caches, which the correction must drop.
5. Two performances are comparable when they share the exercise and the session intent and come from finished workouts; for progression a set must be complete, not a warm-up, with reps and weight above zero; for records the rep bucket joins the key; for Compare the template id joins the key within 14 days.
   Progression kind is not part of comparability.
   This is already the code's rule; it is stated so nobody widens or narrows one reader alone.
6. The archive at block end holds configuration only.
   Review statistics always read live evidence, so a correction to a workout of an ended block changes that block's review.
7. Every correction is one `context.transaction` that throws; no `try?`.

### Invariants for tests

- I1: for every finished workout, `startedAt <= completedAt`, and every complete set's `completedAt` is within that range.
- I2: ordering finished workouts by `startedAt` and by `completedAt` gives the same order.
- I3: for every workout, `block` is the block whose `[startDate, endDate ?? .distantFuture]` contains `startedAt`, or nil when none does.
- I4: for every workout, `TodayResolver`, `PreviousMatchingIntent`, `SessionSummary.prsBySession` and `BlockReviewStatistics` agree on which finished workout is latest and on which block holds it.
- I5: after any correction, `prescribedWeight` and the other frozen fields of every workout are unchanged.
- I6: after any correction, `SessionSetActions.isEmptyWorkout` and the cached `emptyWorkoutIDs` agree.

## Worked examples

| Sequence | Stays unchanged | Recomputes | Feeds the next prescription |
|---|---|---|---|
| Fix a fat-fingered 225 to 255 on last Monday's top set | Monday's `prescribedWeight` and targets, `wasManualOverride`, block and slot | Monday's record marks, weekly volume, plateau signal, any unacknowledged block review | Yes: next workout's previous-session line and calibration read 255 |
| Log a forgotten workout today, then date it last Tuesday | Its frozen prescription (computed from history as of today), slot | Rotation anchor (Tuesday is no longer latest), weekly volume moves a week, block membership becomes the block that held Tuesday | Only through Tuesday's sets, like any other past workout |
| Delete a mistaken workout while another is in progress | The in-progress workout's frozen prescription | Records, counts, rotation anchor (moves back one workout) | The in-progress WHY shows the frozen weight with the "changed since" line; the next start reads the corrected history |
| Edit the active block's phases mid-workout (X1) | Frozen prescription and the deload set cut chosen at start | Today's deload banner, the live part of the WHY sheet, the next start | The next start uses the edited phase |
| End a block, edit its former templates, then correct one of its workouts | The archive, the workout's snapshot names and targets | The ended block's review if it is still pending, records, volume | Yes, like any past workout |
| Remove the slot of the in-progress workout | The workout and its sets | The workout's `slot` becomes nil, so it never anchors rotation; the resolver falls back to the previous anchored workout | Nothing |
| Miss a phase boundary with an unfinished workout, then finish | The phase chosen at start for weight and set count | Nothing on finish; Today's banner reads the live week | The next start reads the live phase |

## Implementation steps, in dependency order

### 1. One time key for the rotation anchor

- Change the anchor sort in `TodayResolver.resolveRotation` from `completedAt` to `startedAt` (`TodayResolver.swift:110`); keep the `completedAt != nil` gate.
- Direct callers: `TodayView.todaysResolution`, `TodayResolverTests`, `SessionFactoryTests.rotationAdvancesEndToEnd`.
  They all set `completedAt = startedAt + 1h`, so they keep passing.
- Acceptance: a test that two finished workouts whose `completedAt` order differs from their `startedAt` order anchor on the later `startedAt`.
  Add I2 as a test over a seeded history built with `SessionFactory.start`, `SessionSetActions.complete` and finish.

### 2. `SessionEditService`

New `fitbod/Sessions/SessionEditService.swift`, a `@MainActor public enum` like `SessionSetActions`, each operation one `context.transaction` that throws.

- `move(_ session: Session, startedAt newStart: Date, now: Date = .now, context:)`: refuse a start after `now` (typed error); delta = `newStart - startedAt`; shift `startedAt`, `completedAt` and every `SetEntry.completedAt` by delta; set `session.block` to the block whose `[startDate, endDate ?? .distantFuture]` contains `newStart`, or nil; never touch `slot`.
- `update(_ set: SetEntry, weight:reps:rpe:context:)`: validate with `SessionSetActions.canComplete` rules; write the three fields; leave `completedAt`, `isComplete` and `wasManualOverride` alone.
- `addSet(to: SessionExercise, context:)`: copy the last working set's weight, reps and RPE (the mock-up's rule), `isComplete = true`, `orderIndex = max + 1`, `completedAt` = the last set's `completedAt` plus one second, clamped to the workout's `completedAt`.
- `deleteSet(_:context:)`: delete and reindex the exercise's `orderIndex` values.
- `deleteWorkout(_:context:)`: `context.delete(session)`; the cascade removes exercises and sets.
- Acceptance: I1, I3, I5 after each operation; X2 as a test that after `move` the four readers in I4 agree; a workout moved into an ended block's window counts in `BlockReviewStatistics.workingSetCount` for that block and in no other; a move to a future date throws and changes nothing; a failed transaction leaves every field as it was.
- GitNexus: new symbols, no callers yet; run `gitnexus_impact` on `TodayResolver.resolveRotation` and `BlockReviewStatistics.completedWorkingSets` before touching them in step 1 and step 3.

### 3. Block windows stay true

- In `BlockDraft.save`, write `startDate` only when `existing == nil` or the block has never started (`isActive == false && endDate == nil`) (`BlockDraft.swift:151`).
- Acceptance: `BlockDraft(block:)` plus `save` on an active block leaves `startDate` unchanged; `BlockLifecycleServiceTests` unchanged.

### 4. The WHY sheet tells the truth about a frozen prescription

- Add `frozenPrescriptionLine: String?` to `PrescriptionExplanation` (`fitbod/Prescription/ProgressionStrategy.swift`, a value type, no schema change).
- In `SessionExerciseCard.currentExplanation()` set it when the recomputed weight differs from `sessionExercise.prescribedWeight`: "Prescribed at start: 90 kg. Your history or block changed since."
  Render it in `WhyThisWeightSheet` above the formula lines.
  Pending sets keep the frozen weight.
- Direct callers of `currentExplanation`: `SessionExerciseCard` only.
- Acceptance: X1 as a unit test on `SessionFactory.prescription` versus `prescribedWeight` after `BlockDraft.save`; a small test that the line is nil when the two weights match and names both weights when they differ.
  No copy-pinning test (deferred class).

### 5. Caches drop on a correction

- Add `@Observable final class HistoryEdits { var version = 0 }` in the environment at the app root.
- The edit screen increments it after a successful save.
- `TodayView` (`TodayView.swift:64`) and `ProgressHomeView` (`ProgressHomeView.swift:79`) reset their `emptyWorkoutIDs` cache `onChange(of:)` the version; `SessionHistoryView` adds the version to its `.task(id:)` key (`SessionHistoryView.swift:99`).
- Rewrite the shortcut comment at `SessionSetActions.swift:163` to name the edit screen and the ledger.
- Acceptance: X3 inverted at the view-model level: after `emptyWorkoutIDs` with a stale `known`, a reset gives the fresh answer; the existing `EmptyWorkoutCountTests` stay green.

### 6. The history-editing screen

- Build the approved mock-up on `SessionEditService` with the rules decided in `docs/ROADMAP.md`: Date and Start move the whole workout; Duration is read-only; sets can be edited, added and deleted; exercises are not added, removed or reordered; "Was" shows the pre-edit value inside the form and is not stored; Delete workout confirms first.
- Every save error is shown and leaves the workout as it was.
- This closes design-map blocker D-04.

### 7. Same class, not reproduced: silent lifecycle saves

- `SessionLoggerView.finish()` sets `completedAt` then `try? ctx.save()` (`SessionLoggerView.swift:342-345`); the resume slab's discard does the same (`TodayView.swift:152-153`).
  On a failed save the workout looks finished or gone until the next launch.
- Fix with the service pattern from step 2: a transaction that throws, an error the lifter sees, and the model reset on failure.
  This is D-155's class; do it when touching the logger.

## What remains unproven

- No save failure was reproduced; steps 2 and 7 are written from the code, not from a failing store.
- Relaunch during an edit was not exercised; step 2's transaction is what protects it.
- The view caches (X3, `SessionHistoryView`) were shown stale at the function level, not on screen.
- Reviews counting by date window after membership is re-derived (I3 and I4) follows from the code read, not from a run.
- No independent adversarial reviewer ran; the harness rule against unrequested subagents applied, so this is the author's own attack on the design.

## Annex: fixture used by the experiments

Each scenario built an in-memory `FitbodModelContainer`, one barbell `Exercise.previewSample`, a strength `SessionTemplate` with one 3x5 exercise, and logged workouts through the real path: `SessionFactory.start(template:slot:activeBlock:on:context:)`, set weight, reps and RPE on each planned working set, `SessionSetActions.complete(set, at: start + offset, context:)`, then `completedAt = start + 3600` and save.
Blocks were inserted with `isActive = true` and a `startDate` set directly, as `TodayResolverTests` does, except X1 which also inserted one `BlockPhase` (accumulation, 4 weeks, intensity 0.9).
Readers were called as the app calls them: `TodayResolver.resolve(block:context:)`, `PreviousMatchingIntent.fetchTopWorkingSet(exerciseID:intentRaw:context:)`, `SessionSummary.prsBySession(_:)`, `SessionSetActions.emptyWorkoutIDs(among:known:in:)`, and `SessionFactory.prescription(for:targetRepsLow:targetRepsHigh:targetRPE:in:strategy:userSettings:context:)` with `ProgressionStrategyFactory.make(for:)`.
