# Architecture

Current contracts, checked against `ba27f304` on 2026-11-08.
Priorities, product decisions and unfinished work belong in [the roadmap](docs/ROADMAP.md).
This replaces the program-graph spec and training-model handoff; their historical migration/execution plans are not current contracts.

## Terminology and ownership

| UI term | Code entity | Responsibility |
|---|---|---|
| Session | `SessionTemplate` | Exercises/base prescription; session-level intent/progression |
| Routine | `Split` | Ordered sessions through `SplitSessionSlot` |
| Block | `Block` | One routine's schedule/phases |
| Workout | `Session` | Logged instance with frozen prescription and correctable actuals |

Use UI terms in product copy. Templates may occur in multiple routines, twice in one routine, and routines in multiple blocks. Only one block may be active.

## Persistence baseline and entities

`SchemaV7` is the sole VersionedSchema, explicitly listing 19 production models.
`FitbodModelContainer` builds it without a custom migration plan.
SwiftData may apply compatible additive changes automatically in place; the historical V1–V6/custom V6→V7 chain was removed.
Incompatible stores move recoverably, with -wal/-shm/support directory, into IncompatibleStores/&lt;timestamp&gt;; the seed stamps are cleared so the fresh store is seeded.
SwiftData throws the same error for every failed open, so `FitbodModelContainer` asks Core Data, read-only, for the reason.
A store is incompatible only when Core Data reports that it cannot infer a migration (NSCocoaErrorDomain 134140).
Every other failed open leaves all store files in place and throws `FitbodModelContainer.StoreOpenError`; the app shows a retry screen, and a later open uses the same store ([RM-001](docs/ROADMAP.md#rm-001)).
A move-aside that fails partway puts the moved files back and throws.

| Entity | Role and relationships |
|---|---|
| `Exercise` | Bundled/custom catalog, stable external ID, prescription/history/stimulus links; optional family/variant/aliases, tracking type, brand/loading and hidden flag |
| `MuscleGroup` | Catalog muscles with stimulus links/volume targets |
| `ExerciseMuscleStimulus` | Exercise↔muscle join, stimulus weight, primary/secondary role |
| `SessionTemplate` | Name, intent/progression and owned prescription children |
| `SessionExerciseTemplate` | Exercise targets/rest/warmup/tempo options, a cardio plan and stored overrides |
| `Split` | Routine with slots and inverse block references |
| `SplitSessionSlot` | Routine↔template join, explicit position, optional references, workout inverse |
| `Block` | Start/end/active state, split, mode, stored days, phases/archive |
| `BlockPhase` | Ordered kind/weeks/volume/intensity owned by block |
| `Session` | Workout timestamps, template/name snapshot, block/optional slot, exercises |
| `SessionExercise` | Frozen evaluated prescription/name and cardio plan, actual sets and the optional machine it was done on |
| `MachineProfile` | A machine the lifter named: optional maker and model; nullified on its logs when deleted |
| `SetEntry` | Weight/reps/RPE/completion/type/notes/tempo/partial/cluster actuals; optional start, duration, distance, level, treadmill speed and incline |
| `MuscleVolumeTarget` | Per-muscle MV/MEV/MAV/MRV |
| `PlateInventory` | Equipment bar/plates/counts/increments |
| `UserSettings` | Units/calibration/fatigue thresholds/presentation settings |
| `RoutineFolder` | Schema retained; folder UI removed |
| `SupersetGroup` | Template exercise grouping |
| `RoutineExerciseSetOverride` | Storage retained, not applied by logger; editor hidden |

SessionTemplate.block/Block.legacyTemplates remain deprecated schema edges; prescription uses the active program graph.
Removing them requires future compatibility work, not the old migration plan.
Auxiliary model names are accepted naming debt.
Persist enums as raw values with typed accessors.
Export/backup use DTOs and shared ExportSnapshot mapping, not Codable on models.
Restore validates before mutation and retains a pre-restore backup.
Restore refuses a backup whose format is newer than the build writes (`ExportDocument.currentFormatVersion`), because it would drop fields the build does not know.
Restore clears the exercise seed stamp, so the next launch re-seeds the restored catalog in place: it applies the bundled curation, adds rows the backup predates, matches each catalog exercise's stimulus rows to its muscle credits and retires the shoulders muscle (RM-065).
Workouts and custom exercises stay.
`Exercise.tracking` reads the stored tracking type; unset, bodyweight and weighted-bodyweight equipment track reps with optional load and everything else tracks weight and reps, so custom and uncurated rows need no stored value.
The importer writes a seeded row's tracking from `curation.json` alone, so a row curation stops listing returns to the derived value.
`Exercise.timedValues` names what a timed set records beside its time: an optional load for a hold or carry that is not bodyweight, a distance, a machine level, or a treadmill's speed and incline.
A stair machine's number is its speed: `Tracking.durationStepSpeed` stores it as a level and names it speed wherever the set or its plan is shown, so older stair logs read as speed too.
A custom copy of an exercise carries its stored tracking, so a copy of a timed exercise stays timed.
`ExerciseCatalog` resolves the three seed files into the rows the importer writes: `exercises.json` (the upstream snapshot, byte for byte), `additions.json` (local rows) and `curation.json` (the overlay: name, family, variant, equipment, tracking, brand, loading, aliases, hidden, import).
Seed checks read the same entries with no store, so they cannot drift from the importer.
A row curation hides is in no list: `FilterState.applyPostFetchFilters(to:)` drops it for the Library and every picker, and a hidden duplicate's name is an alias of the row that stays.
The importer keeps a hidden row listed while a routine or a logged workout uses it, so a row the lifter picked stays findable.
A row outside the strength categories is in the catalog only when curation imports it.
A cardio row gets no stimulus rows and an empty `primaryMuscleSlugsJoined`, so cardio adds no muscle volume.
Unset, a cardio machine tracks time and distance (`Tracking.implied(by:)`).
A custom exercise stores a tracking choice only when it differs from what its equipment implies; one that tracks a time with a distance, a level, a stair speed or a speed and incline is cardio and needs no primary muscle.
Code finds a catalog row by its `externalID`, never by its name, because curation renames rows: the debug seeds are keyed by ID, and `muscles.json` keys its variant overrides by ID.
A catalog exercise's stimulus rows match its muscle credits exactly (RM-065): `muscles.json` gives each family, and each variant that differs, its primary muscles (1.0 of a set) and secondary muscles (0.5 or 0.25); a row it does not cover keeps the upstream tags at 1.0 and 0.5.
The muscles are the 17 upstream slugs with "shoulders" split into front, side and rear delts; a seed moves the shoulders credit of an exercise outside the catalog (a custom one, or a row a newer dataset dropped) to the delt its family credits most, or to the front delts, and deletes the shoulders muscle.
A seed may delete stimulus rows, so `RootView` shows the library splash, not the tabs, while a newer catalog is seeded.
Volume bars count stimulus-weighted sets per muscle; the week's total on Today and Progress counts the working sets logged of exercises that train a muscle, so cardio stays out (RM-038).
A muscle whose weighted sets round to 0 this week reads NOT TRAINED on its bar, its heatmap tile and its detail screen, whatever its zone; `MuscleVolumeBar.chip(sets:target:)` is the one chip rule for the bar and the detail screen.

## Program graph

SessionTemplate adds exercises/prescription, Split adds bundling/order, Block adds scheduling/phases.
Edges stay live while training: editing upcoming templates/routines does not rewrite already-started workouts.
Live-edit banners explain this; there is no freeze at block start.

Block.derivedStatus orders completed (endDate), active (isActive), ready (no missing piece), draft.
Current readiness requires a nonempty name, at least one phase, a routine with at least one slot and, for fixedWeekly, one day per slot.
That is stricter than the original spec's slot-only gate.

BlockLifecycleService owns start/end/handover/attach/swap/deletable-block operations.
Start stamps the actual startDate; before that it represents creation, not a planned start.
Editing a started block must not move its start.
Handover ends/archives the old block and activates the new one in one save.
End writes endDate/archive in the same save.
Attach/swap requires draft/ready; active scheduling mode/days remain editable.
Only draft/ready blocks delete in the UI; active blocks end and completed blocks stay history.
Saves throw and restore model state on failure.

TrainingDaysWriter sorts Calendar weekday numbers once at write using firstWeekday.
trainingDaysJoined stores the order; readers never re-sort, so a region change cannot remap slots.

TodayResolver guards zero slots before modulo.
Rotation anchors on the latest finished workout by startedAt in that block with a live slot on its current split; next is current position + 1 modulo count.
Unslotted/deleted-slot/other-split/open workouts do not anchor.
fixedWeekly maps today's weekday to its index in stored days modulo current slots.
Absent weekdays rest; missed days do not shift.
Empty shared routines show repair.
TodayState derives precedence using the environment calendar and refreshes on foreground/significant time change.
Every start goes through `WorkoutStarter.start(_:in:)` with the routine it came from, and the pure `StartSlot` picks the slot at the tap ([RM-006](docs/ROADMAP.md#rm-006)).
NEXT is the resolver's slot in a rotation block; in a fixedWeekly block it is today's slot until a counted workout starts today, then the next training day's.
With no block, a routine's NEXT follows its newest counted slotted workout, wraps and skips sessions with no exercises.
A start credits NEXT when NEXT holds the session, otherwise the session's first slot after NEXT, so a session slotted twice never moves the rotation backwards.
A start from no routine, an archived routine or a routine other than the active block's is unslotted.
With no block, Today's hero is `StartSlot.suggestion`: the NEXT of the routine trained most recently, else of the routine edited most recently, else the most recently edited session in no live routine.
The session sheet reads the same rules through the pure `SessionSheetContent`: one row per session of each live routine, at most one usable NEXT mark, and the sessions a start skips (never in a fixedWeekly block).
A sheet row starts its workout on the tap; a session in no live routine opens its detail instead.
Today renders one resolved state: first-run offers an empty workout first and routine/block planning second, empty sessions/routines offer repair on Today's stack, and rest/missing-routine states retain alternate-session access.
No-block repair names the routine with the newest session edit, otherwise the newest routine, with deterministic ties.
DONE lists all counted workouts started today, newest first, as paper rows opening their own history detail; PR counts use History's replay and refresh after corrections.
READY names the oldest ready block, creation date and ready count; Start calls the lifecycle service, with Retry/Open on failure.
Block creation stays on Program and the review's next-block flow. Today retains existing-block editing; its only empty-workout start is first-run's.
Today's week board (`TodayWeek`) shows the user's calendar week: each day's counted workouts and their `countsAsWork` sets, so open, empty and warm-up work never count.
It is counted in a `.task(id:)` keyed on the finished workout IDs, the week start and `HistoryEdits.version`, never per render; the full per-muscle model runs only when Volume opens from the board or Progress.
Deload advice has one evaluator, `DeloadAdvisor.evaluate`: Today's notice asks it on appear, and Volume asks it on appear to ring its bars, so `deloadAlertEnabled` off and a dismissed week hide both.
`BlockBuilderRoute.template` remains in use by Program's empty-state template cards until their Program redesign migration.

## Snapshots and corrections

Two deliberate freeze points:

1. At workout start, or exercise add/swap, copy evaluated prescription, targets, intent/progression context and display names into the logged graph.
   Template/block/history edits never recompute those values.
   A workout logged before name snapshots existed gets its exercise's name at the next seed, before any curated rename, so a rename never changes History.
   Pending inputs/actuals remain editable.
   WHY presents the frozen prescribed weight and notes live divergence.
2. At block end, write ArchivedBlockConfig v1 once: name/start/end/mode/days/phases/routine/ordered slots/exercise prescriptions.
   Archived overview reads that payload, never current templates.
   Decode failure is explicit; no live-template fallback.
   Configuration freezes; review statistics still read correctable workouts.

Pending working sets show weight and rep offers from their frozen prescription and completed performance. Programmed block targets take priority. Otherwise an earlier working set on the same lift and machine in this workout takes priority over the corresponding set from the last finished matching-intent workout.
RPE/hybrid offers use the upper rep target until current-workout performance takes priority; editing only the load does not change that target. Current-workout actual reps carry unchanged outside a block, including reps outside the programmed range.
Entered values, including numbers stored by older versions, take priority per field. The checkmark saves the chosen weight, reps, and completion together. Unaccepted offers stay outside the store, and each set records its own effort.
Swapping after logging keeps completed sets attached to the original lift and applies a fresh prescription to the replacement's pending sets.
Timed and assisted exercises have no load to progress: `SessionFactory.prescription` returns no weight without calling a strategy, and no warm-up ramp is built.
A pending timed set is offered the time, and the load, distance or level its row shows, of the set just completed, else of the same set in the last finished matching-intent workout.
A cardio bout is offered its frozen plan first, value by value: a planned time, level or stair speed, or treadmill speed and incline wins over last time's.
An assisted set follows the rep offers above and carries its assistance forward.

Cardio (`Exercise.isCardio`) is one bout with a plan, never sets and rest (RM-062).
A routine row plans a time and the machine's level or stair speed, or a treadmill's speed and incline, in place of sets and rest; `SessionFactory.start` copies the plan to the logged exercise and makes one bout, whatever sets the row stores.
The logger shows a cardio bout with no set number, offers no Add set row while a bout exists, and starts no rest on Done.
Planned and logged set counts leave bouts out (`SessionExerciseTemplate.workingSetCount(phase:)`, `SessionSummary.workingSetCount`, `SessionHistoryFormat.setCount(of:)`, `TodayWeek.workingSets(in:)`), as Volume does, and History and Edit workout call a cardio entry a bout.
A workout in progress counts the same way on the resume banner and slab and the Finish sheet (`SessionHistoryFormat.inProgressSetCount(of:)`), which show its time alone once only bouts are logged; the discard and remove warnings name bouts apart from sets (`SessionHistoryFormat.discardWarning(for:)`).
`Session.loggedSetCount` still counts a bout, because it decides whether a workout logged anything: Finish or Discard workout, and whether a discard asks first.
A swap to cardio keeps one pending row; Undo restores the rows it removed.
The next prescription reads earlier sets only in the shape the exercise tracks now, a time for a timed exercise and reps otherwise; Last time shows the latest logged set in any shape.

A workout's place in time is Session.startedAt; completedAt marks finish/duration.
A date correction shifts start, finish and all set timestamps one delta, rejects a resulting finish after now and preserves set times inside the workout.
Membership is the started block whose half-open interval [startDate, endDate) contains that start (active end unbounded); draft/ready blocks hold no workouts.
SessionEditService.block(runningAt:in:) picks the latest applicable start.
Date correction may rewrite Session.block, never Session.slot; the resolver ignores a slot outside the block's split.
Other frozen fields stay unchanged.

SessionEditService.save validates one WorkoutEdit before applying weight/reps/RPE, a timed set's time/distance/level/speed/incline, additions/deletions/reindexing and date movement in one transaction.
Only changed and added sets are validated: a changed set by the shape it was logged in, an added set by what its exercise tracks now.
A set left alone is never judged again, so an old set cannot block a correction to the rest of its workout.
New sets get ordered timestamps clamped inside the workout.
Exercise membership/order and duration are not editable.
Delete/finish/remove use throwing SessionSetActions paths.
SessionSetActions.rollBack restores context/visible saved values on failure; no partial correction may leak into the next save.

Records, next prescription, calibration, volume, plateau/deload advice, comparison, counts and review statistics derive from current evidence.
Successful correction bumps environment HistoryEdits and invalidates finished/empty-workout caches in Today/Progress/History/summaries.
Correcting history can change an ended review without changing archived configuration or frozen prescription.

Comparable performances share exercise/session intent/machine and finished workouts.
Progression also requires completed non-warmup positive reps/weight; records add rep bucket/kind; Compare adds template identity and a 14-day window.
Progression kind is not a comparability key.
Do not widen one reader alone.

A logged exercise may name the machine it was done on (`SessionExercise.machine`, [RM-066](docs/ROADMAP.md#rm-066)); a maker or model is never an exercise of its own, and a pick changes only that workout's log.
Last time, the prescription, in-workout offers, records, the stall check and Compare read only sets on the same machine, and sets with no machine form their own group.
With none on that machine, the card names the latest matching workout on another machine (or with none) and Last time shows its sets for reference; no load, progression or offer carries over.
A new log starts on the machine of the exercise's latest log with a finished working set, in the workout in progress or a finished one, only for equipment that takes a machine (machine, Smith machine, cable, cardio machine).
Machines are one machine when they show the same name, whatever the case, spacing or split between maker and model.
Changing the machine mid-workout relabels the log with its finished sets, or keeps those sets on a copy of the log under the old machine; the log is then represcribed.
Progress charts, volume, tonnage, workout counts, the weekly recap and the PR list stay exercise-level aggregates across machines; exercise history can filter by machine.
Backup format 4 carries the machines and each log's machine, and formats 1 to 3 still restore; CSV adds a machine column.
Backup format 5 carries the cardio plan on routine rows and logged exercises and a treadmill set's speed and incline, and formats 1 to 4 still restore; CSV adds `speed_kmh` and `incline_pct` at the end (RM-062).
Order workouts by start even when finish order differs; the former handoff's proposed universal equal-order invariant is not required by the current resolver.

## Units and aggregates

Units relabel stored numbers, never implicitly convert; exercise overrides win.
Workout load fields parse the entire ungrouped decimal in the current locale, including signed assistance, and format it in that same locale. History corrections retain their nonnegative/range validation; parsing a load does not change set-completion rules.
Plate inventory readers expose one finite positive denomination per weight, combining legacy duplicate counts without rewriting saved bytes. New plate additions validate before mutation and roll back failed saves; the editor keeps the entered text for retry.
Session-editor and logger tempo writes share `TempoParts.join`: exactly four parts, blank positions preserved, no pasted dash inside a part. A rejected paste leaves the previous tempo unchanged and explains the required input.
There is no per-set unit provenance yet; do not call mixed-unit totals converted/comparable ([RM-021](docs/ROADMAP.md#rm-021)).
Distance and a treadmill's speed are the exception: `SetEntry.distanceMeters` is stored in meters and `SetEntry.speedKmh` in km/h, each converted for entry and display (miles and mph with lb, kilometers and km/h with kg), so neither needs provenance.
A treadmill set's distance shows worked out from its speed and time when none was logged.

`SessionSetActions.isValidSet` is the one rule for completing a set, by what its exercise tracks.
Weight and reps need both above zero; bodyweight reps take zero or more added load; assisted reps take a weight of zero or less, because assistance is stored negative; a timed set needs a time and stores zero reps.
With no exercise, reps or a time is enough.
A stored set is read by its own values, never by what its exercise tracks now: zero reps with a time is a timed set (`SetEntry.isTimed`), and History, exercise history, Last time, CSV and Edit workout print it that way (`SetText.result`).
A row that curation later retags keeps its history exactly as logged.
An exercise history made of timed sets alone shows the longest time in place of tonnage and leaves out the e1RM and the weight and reps footer.

A set's start and duration are written at Done (RM-062).
The rest timer keeps the rest it last ended, and `RestTimerEngine.setStart(doneAt:)` starts the set at the earlier of that rest's deadline and the moment it was stopped, or of the deadline and Done while the rest still runs.
A START tap on the set's own row wins over the rest.
`SessionSetActions.complete` stores the start and duration in the same save, only for a set with no time of its own, and only when the set lasted from one second to an hour; otherwise both stay unknown.
Known limit: a set lifted after resting past the timer, including an exercise's first set after the walk to it, gets a time that includes the extra rest; tapping its time corrects it.
A typed time and a re-checked set keep theirs, and a swap clears only a pending set's START.
A load set with a duration is still a rep set, because `SetEntry.isTimed` needs zero reps.
An exercise's time runs from its first working set's start, or that set's Done when its start is unknown, to its last Done (`SessionSetActions.exerciseSeconds`); the logger's card and History show it.

SetEntry.countsAsWork means complete, neither warmup flag nor warmup type.
Drop/failure/rest-pause count.
`SetEntry.hasResult` means reps or a time; the workout summary, Last time and carry-forward count those sets.
Tonnage is positive weight × positive reps; assistance/bodyweight/timed sets add none.
Timed and assisted sets count as logged sets and toward muscle volume.
e1RM, records, load progression, plateau and Compare need positive weight and reps, so they skip both; deload's missed-rep-range signal still reads an assisted set's reps.
Counted workouts exclude empty finished workouts; readers promising finished history exclude open workouts.
Weekly tonnage bins by set completion time, rotation/history by workout start.
Muscle volume uses weighted stimulus; contributions need not equal physical count.
Muscle tonnage stacks may overlap ([RM-041](docs/ROADMAP.md#rm-041)).

Every e1RM display uses OneRepMaxEstimator: Brzycki 1–6, Epley 7–10, no estimate above 10 or nonpositive weight/reps.
RPE progression separately uses Tuchscherer/calibration.
Calendar arithmetic handles production week/DST/block days.
Deload working sets use PeriodizationEngine.workingSetCount: max(1, floor(target × volumeMultiplier)) in deload, otherwise target.
Deload holds last top weight.
Fatigue advice never mutates schedule.

## Deletion and ordering

- Workout → exercises → sets cascades.
- Exercise deletion uses `ExerciseDeletion.delete` to explicitly clear logged/template exercise links before deleting the catalog row; workouts, sets and snapshot names survive. `Exercise` has no archive flag.
- Template → prescription children → overrides cascades; logged template/slot links nullify.
- Split → slots cascades; slot deletion nullifies Session.slot. Block → phases cascades; independent history survives graph deletion.
- Slot→template declares deny, but runtime enforcement is [open RM-050](docs/ROADMAP.md#rm-050); services unlink/guard, and an expected failure is not proof.
- Split archive/delete is denied while non-completed blocks reference it; completed blocks use archives.
- Positions stay contiguous by reindex-on-write/tests. No uniqueness on (split, position): SwiftData upsert collisions could merge slots.

## UI and state layers

Exercise photos are static PNG pixels with source metadata removed and orientation/mirroring baked in, within a 64MP/16,384px decode bound. Pick/save, startup upgrade, backup and restore use `ExercisePhoto`; each stored original remains until its replacement saves. Restore prepares all image bytes before deleting current rows. Backup entries retain their compatible `images/<UUID>.jpg` blob names. Startup preparation failures show a Retry/Later notice.

Volume surfaces render immutable `RPVolumeLandmarks.Landmark` values from persisted targets or defaults. Rendering never constructs a target model or attaches one to a muscle; explicit creation saves one target and rolls back failure.

Session-editor changes, including new superset IDs, stay in `RoutineDraft` until Save.
`persist(into:context:)` writes the session and its used new groups in one save; failure rolls back the store while keeping the draft for retry. Discard writes no groups.

Four native tab containers preserve stacks: Today, Program, Progress, Library.
Settings is a Today sheet; workout History opens from Progress.
BRU draws visible tabs, hidden in logger/while editing.
Logger belongs only to Today: ResumeWorkoutRequest routes Program/session/Live Activity there, and Back returns to Today.

Persistent state is SwiftData queried directly by @Query.
Cross-view ephemeral state uses @Observable environment objects (HistoryEdits, ResumeWorkoutRequest); local state uses @State/@Bindable.
Do not mirror @Query in a view model.
Swift Charts handles data; Canvas/paths handle the body.
See [conventions](CONVENTIONS.md) and [development policy](docs/DEVELOPMENT.md).
