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

`SchemaV7` is the sole VersionedSchema, explicitly listing 18 production models.
`FitbodModelContainer` builds it without a custom migration plan.
SwiftData may apply compatible additive changes automatically in place; the historical V1–V6/custom V6→V7 chain was removed.
Incompatible stores move recoverably, with -wal/-shm/support directory, into IncompatibleStores/&lt;timestamp&gt;; a fresh store resets seed stamps.
The current catch also classifies transient open failures as incompatibility: an open data-integrity issue ([RM-001](docs/ROADMAP.md#rm-001)), not a safe error-classification guarantee.

| Entity | Role and relationships |
|---|---|
| `Exercise` | Bundled/custom catalog, stable external ID, prescription/history/stimulus links |
| `MuscleGroup` | Catalog muscles with stimulus links/volume targets |
| `ExerciseMuscleStimulus` | Exercise↔muscle join, stimulus weight, primary/secondary role |
| `SessionTemplate` | Name, intent/progression and owned prescription children |
| `SessionExerciseTemplate` | Exercise targets/rest/warmup/tempo options and stored overrides |
| `Split` | Routine with slots and inverse block references |
| `SplitSessionSlot` | Routine↔template join, explicit position, optional references, workout inverse |
| `Block` | Start/end/active state, split, mode, stored days, phases/archive |
| `BlockPhase` | Ordered kind/weeks/volume/intensity owned by block |
| `Session` | Workout timestamps, template/name snapshot, block/optional slot, exercises |
| `SessionExercise` | Frozen evaluated prescription/name and actual sets |
| `SetEntry` | Weight/reps/RPE/completion/type/notes/tempo/partial/cluster actuals |
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
The session sheet and the no-block hero that read these rules are still planned under RM-006.

## Snapshots and corrections

Two deliberate freeze points:

1. At workout start, or exercise add/swap, copy evaluated prescription, targets, intent/progression context and display names into the logged graph.
   Template/block/history edits never recompute those values.
   Pending inputs/actuals remain editable.
   WHY presents the frozen prescribed weight and notes live divergence.
2. At block end, write ArchivedBlockConfig v1 once: name/start/end/mode/days/phases/routine/ordered slots/exercise prescriptions.
   Archived overview reads that payload, never current templates.
   Decode failure is explicit; no live-template fallback.
   Configuration freezes; review statistics still read correctable workouts.

A workout's place in time is Session.startedAt; completedAt marks finish/duration.
A date correction shifts start, finish and all set timestamps one delta, rejects a resulting finish after now and preserves set times inside the workout.
Membership is the started block whose half-open interval [startDate, endDate) contains that start (active end unbounded); draft/ready blocks hold no workouts.
SessionEditService.block(runningAt:in:) picks the latest applicable start.
Date correction may rewrite Session.block, never Session.slot; the resolver ignores a slot outside the block's split.
Other frozen fields stay unchanged.

SessionEditService.save validates one WorkoutEdit before applying weight/reps/RPE, additions/deletions/reindexing and date movement in one transaction.
New sets get ordered timestamps clamped inside the workout.
Exercise membership/order and duration are not editable.
Delete/finish/remove use throwing SessionSetActions paths.
SessionSetActions.rollBack restores context/visible saved values on failure; no partial correction may leak into the next save.

Records, next prescription, calibration, volume, plateau/deload advice, comparison, counts and review statistics derive from current evidence.
Successful correction bumps environment HistoryEdits and invalidates finished/empty-workout caches in Today/Progress/History/summaries.
Correcting history can change an ended review without changing archived configuration or frozen prescription.

Comparable performances share exercise/session intent and finished workouts.
Progression also requires completed non-warmup positive reps/weight; records add rep bucket/kind; Compare adds template identity and a 14-day window.
Progression kind is not a comparability key.
Do not widen one reader alone.
Order workouts by start even when finish order differs; the former handoff's proposed universal equal-order invariant is not required by the current resolver.

## Units and aggregates

Units relabel stored numbers, never implicitly convert; exercise overrides win.
There is no per-set unit provenance yet; do not call mixed-unit totals converted/comparable ([RM-021](docs/ROADMAP.md#rm-021)).

SetEntry.countsAsWork means complete, neither warmup flag nor warmup type.
Drop/failure/rest-pause count.
Tonnage is positive weight × positive reps; assistance/bodyweight adds none.
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

Four native tab containers preserve stacks: Today, Program, Progress, Library.
Settings is a Today sheet; workout History opens from Progress.
BRU draws visible tabs, hidden in logger/while editing.
Logger belongs only to Today: ResumeWorkoutRequest routes Program/session/Live Activity there, and Back returns to Today.

Persistent state is SwiftData queried directly by @Query.
Cross-view ephemeral state uses @Observable environment objects (HistoryEdits, ResumeWorkoutRequest); local state uses @State/@Bindable.
Do not mirror @Query in a view model.
Swift Charts handles data; Canvas/paths handle the body.
See [conventions](CONVENTIONS.md) and [development policy](docs/DEVELOPMENT.md).
