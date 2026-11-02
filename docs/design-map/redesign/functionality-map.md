# Functionality map

Every capability Today and Program hold now, where it lives in the source, and where it goes.
"Kept" means the same control in the same place.
Phase numbers refer to [plan.md](plan.md).
Hidden, dead and unwired capabilities are listed too, because the brief asks for every existing capability.
Identifiers, settings gates and side effects the rebuild must keep have their own rows.

## Today

| Capability | Now | Proposed | Phase |
| --- | --- | --- | --- |
| Settings sheet | BRUHeaderBar left action, `fitbod/Views/TodayView.swift` | Kept | - |
| Date with weekday | Header right text, "SAT · OCT 31" | Kept as is | - |
| Deload week banner: "▲ DELOAD WEEK", "recover, don't load", "Working sets cut by ~50%" | `fitbod/Periodization/DeloadWeekBanner.swift`, shown when the phase is deload | Removed. The plan line ends "· DELOAD", the hero's second caption reads "DELOAD WEEK · LIGHTER SETS", and the hero's set count and the exercise sublines show the counts the logger will generate (see "Prescribed set counts"). | 1 |
| Deload advisory: tap → signals sheet, × dismisses for the week | `fitbod/Fatigue/DeloadAdvisoryBanner.swift`, `DeloadAdvisor.evaluate`, `DeloadSignalDetailSheet` | One notice row under the plan line, same sheet, a DISMISS text button with the same week-long dismissal (the glyph table has no close mark). Hidden while the current phase is a deload (new rule) and while a workout is in progress. | 1 |
| Deload advisory setting gate | `UserSettings.deloadAlertEnabled`, read at `TodayView.swift:684` | Kept: the notice row shows only when the setting is on | 1 |
| Deload advisory weekly dismissal | `UserSettings.deloadAdvisoryDismissedWeekStart` | Kept, same field | 1 |
| Day streak | `TodayStatStrip`, computed by `TodayView.dayStreak` | Removed (O-1) | 1 |
| All-time workout count, tap → history | `TodayStatStrip` SESSIONS cell, `SessionHistoryRoute.list` | Removed from Today. History stays on Progress › History; the T-DONE slab opens today's workout. The CLAUDE.md baseline line "History opens from Today → Sessions or Progress → Workouts" changes in the same step. | 1 |
| `today.sessions` identifier, used by seven UI suites as the "Today has loaded" signal | `TodayStatStrip.swift:167` | Replaced by `today.root` on the header bar, present in every state | 1 |
| Block week, trend arrow or phase label | `TodayStatStrip` third cell, `TodayView.currentTrend`, `TrendDirection` in `TodayStatStrip.swift:18` | Week and phase move to the plan line. The trend arrow goes; `TrendDirection` and `currentTrend` are deleted with the strip. The Volume screen keeps the week-over-week delta. | 1 |
| This week workout count without a block | `TodayStatStrip` | This-week row: "2 workouts · 20 sets", raw counts (see the volume rows) | 1 |
| PLAN COMPLETE | `TodayStatStrip` and `BlockContextBand` chip, `PlanWeek.of` in `fitbod/Periodization/BlockOverviewScreen.swift` | The plan line's second line reads "PLAN COMPLETE" and opens Block overview, where END BLOCK stays. No notice and no End block on Today (O-10). | 1 |
| Block band: BLOCK chip, name, phase chip, week cells with deload marks, tap → Block overview | `fitbod/Views/BlockContextBand.swift`, `fitbod/Views/WeekTickerCells.swift`, `BlockOverviewRoute.summary` | Plan line: a two-line Button row, "SPRING BLOCK" over "WEEK 2 OF 6 · ACCUMULATION ›", same destination. Week cells stay on Block overview only. | 1 |
| Resume slab: resume, discard with confirmation when sets exist; identifiers `resumeSlab.resume`, `resumeSlab.discard` | `fitbod/Views/ResumeWorkoutSlab.swift` | Kept, with the plan line above it (T-RESUME). Identifiers kept; eight UI suites use them. | - |
| Discard clears the rest timer | `ResumeWorkoutSlab.swift:163-166`, `RestTimerEngine` | Kept; the Program banner's visible Discard calls the same path | 1 |
| Next slab: NEXT, DAY n / m, session name, summary, START WORKOUT ▸ | `fitbod/Views/BlackSlabCTA.swift` | Hero: label "TODAY" (weekday) or "NEXT UP · 2 OF 3" (rotation), no day counter; name, summary and button kept; the set count comes from the prescribed-count helper | 1 |
| Prescribed set counts | `BlackSlabCTA.swift:53` sums raw `targetSets`; `LiftListRow.swift:50-51` shows raw `targetSets` and a fixed "2 warm-up". The logger (`SessionFactory.swift:290-297`) cuts working sets to `max(1, floor(targetSets × volumeMultiplier))` in a deload phase, and `WarmupRamp.shouldGenerate` skips warm-ups then. | New: `workingSetCount(targetSets:phase:)` returns the working sets the factory will generate; the hero, the sublines and the factory call it, so the three cannot drift. Warm-ups stay in the factory: the sublines read "3 × 5-8" on every row, the format `LiftListRow` already uses for rows without a ramp. | 1 |
| Warm-up count in the lift list | `LiftListRow.swift:50`: a fixed "2 warm-up" when `generateWarmups` is on; the factory never reads that flag and ramps only the first qualifying compound (`SessionFactory.swift:253-258`), 4 sets for a barbell and 2 for dumbbells | Removed; the logger shows the real ramp | 1 |
| Start a workout: started, already in progress, empty template, failed | `TodayView.startWorkout` → `fitbod/Routines/WorkoutStarter.swift` | Kept. "Already in progress" cannot happen from the hero because an open workout always takes the hero. "Empty template" cannot happen from the hero because an empty session is T-FIX. | 1 |
| "Workout in progress" alert | `TodayView` `startConflict`, dead (D-236) | Deleted | 1 |
| "Couldn't start workout" alert | `TodayView` | Kept | - |
| "Add at least one exercise" alert | `TodayView.swift:612-613` | Unreachable from the hero (T-FIX) and from the sheet (empty rows are disabled); kept for `WorkoutStarter`'s other callers | 1 |
| No workout scheduled: "Build a routine or pick one from your library", + NEW ROUTINE | `TodayView.noWorkoutScheduledEmptyState` | Split by cause. Rest day → T-REST slab naming the next training day. No block → T-PICK or T-FIRST. | 1 (slabs), 2 (next day) |
| Routine has no sessions: GO TO ROUTINE ▸ | `EmptySplitFixIt`, `TodayView.swift:726`, `SplitDetailRoute` | T-FIX slab, same destination | 1 |
| Scheduled session has no exercises | The hero shows "0 EXERCISES" and START WORKOUT ▸ ends in the alert; `LiftListSection.swift:46` shows "Add an exercise to begin." | T-FIX variant "PUSH B HAS NO EXERCISES" with ADD EXERCISES ▸ → `SessionTemplateDetailView`, and "Choose another session ›". The placeholder goes with the case; `LiftListSection` has no other caller. | 1 |
| Active block without a routine | `.noBlock` while a block is active → the empty state | T-ATTACH slab, OPEN BLOCK ▸ → Block overview, where END BLOCK is the one action (the overview already shows attach only on draft and ready blocks) | 1 |
| Session picker: sessions grouped by routine, row → session detail, START ▸ (unslotted), START disabled for sessions without exercises | `fitbod/Views/TodaySessionPicker.swift`, `SessionTemplateDetailView`, `WorkoutStarter` with `slot: nil` | Session sheet behind the ghost rows, each session once in the order of its first slot. Rows start on tap: with the resolver's next slot, or the first after it that holds the session, when the session is in the active block's routine (O-2); with its routine slot under the same rule when no block is active; unslotted otherwise. The resolver's next slot is marked NEXT; in a rotation block the other rows of that routine say what they skip. Rows for empty sessions are disabled, "No exercises yet". | 1 |
| Session detail for sessions other than the hero (preview, edit, last workout) | Picker row → `SessionTemplateDetailView` | Removed from Today; reached from Program › routine › session. The hero's detail stays behind the Exercises head's "View ›". | 1 |
| Sessions in no routine | Not startable from Today (D-24) | "Other sessions" group in the sheet | 1 |
| Picker empty state: "Build your first routine", + New routine | `TodaySessionPicker` | T-FIRST, the only thing on a fresh Today; a "Start a workout ›" ghost when a session with exercises sits in no live routine (D-24) | 1 |
| New routine | `TodayView.startNewRoutine` → `NewRoutineRoute.name` | Kept, from T-FIRST | - |
| Start a block (opens a blank block builder) | `fitbod/Periodization/StartBlockCTA.swift` → `BlockBuilderView` with `BlockTemplates.blank`, origin `.today` | Removed. T-READY starts the ready block with `BlockLifecycleService.start` and shows "Couldn't start block" if it throws. Today never creates a block (O-12). | 1 |
| Lift list: index, name, set subline, COMPOUND or WORK chip | `fitbod/Views/LiftListSection.swift`, `fitbod/Views/LiftListRow.swift` (rows are not tappable) | Exercises section: head "Exercises · 5" with "View ›", rows without chips, sublines "3 × 5-8" with working sets from the helper, still not tappable (O-11) | 1 |
| Volume summary slab: working sets this week, delta vs last week, stimulus-weighted note | `fitbod/Fatigue/FatigueSurfaceView.swift` summary slab | Progress › Volume, unchanged. Today's this-week row shows raw counts instead: finished workouts with logged sets this week (`countedWorkouts`), and their working sets from `FatigueModel.completedWorkingSets` filtered to those workouts, in a `.task(id:)` keyed on the finished workout IDs and the week start. | 1 |
| Volume legend, 17 muscle bars with MEV, MAV and MRV, zone chips, advisory ring, tap → muscle detail | `FatigueSurfaceView`, `fitbod/Fatigue/MuscleVolumeBar.swift`, `isAdvisoryActive` from Today's `currentAdvisory`, `MuscleSlugRoute.detail` | Progress › Volume inside a new `VolumeScreen`, which evaluates `DeloadAdvisor` on appear so the ring survives. Muscles with no sets collapse into one expandable row in Phase 2. | 1 (move), 2 (collapse) |
| Heatmap FRONT and BACK, week label "W44 / 53" | `FatigueSurfaceView`, `fitbod/Fatigue/BodySilhouetteView.swift` | Progress › Volume, labelled with the week's dates | 1 (move), 2 (label) |
| Volume empty state "No sets logged this week" | `FatigueSurfaceView` (shows only when no muscle has a MEV target) | Progress › Volume, unchanged. Today's this-week row reads "0 workouts · 0 sets"; T-FIRST has no row. | 1 |
| Empty workouts excluded from counts | `TodayView.swift:387-395`, `emptyWorkoutIDs` | Kept: the this-week row and T-DONE count only workouts with logged sets | 1 |
| Block review sheet, opens by itself once; "Start next ▸" acknowledges and opens the builder; "Plan custom" and Back dismiss without acknowledging (D-06); identifiers `blockReview.*` | `TodayView` `.sheet(item: $pendingBlockReview, onDismiss: showRecapAfterReview)`, `BlockReviewStatistics.pendingReviewBlocks` and `acknowledge` in `fitbod/Periodization/BlockReviewView.swift`, dead `acknowledgeAndDismiss` | Nothing opens by itself. A notice row "SUMMER BLOCK FINISHED · REVIEW ›" on every state without an active block except T-RESUME opens the review as a sheet; closing it by any route acknowledges (the sheet's `onDismiss` calls `acknowledge`, guarded on `reviewedAt == nil`; `acknowledgeAndDismiss` is deleted). "Start next ▸" still opens the builder from the review's own sheet (`pendingNextBlockBuilder`). Identifiers kept. `pendingReviewBlocks` is unchanged, so no notice shows while a block is active, including right after START BLOCK ▸ (O-5). | 2 |
| Weekly recap sheet, once per week; `markRecapSeen` on appear; deferred while a review is pending | `fitbod/Fatigue/WeeklyRecapSheet.swift`, `TodayView.checkWeeklyRecap` | Kept (O-4), shown on first appear when due; it no longer waits for the review | 2 |
| Block builder sheet from Today | `TodayView` `pendingBlockBuilder`: `.template` set only by StartBlockCTA (`:206`); `.edit` set only by Block overview's `onEdit` on Today's stack (`:267`, D-11) | `.edit` kept, because the plan line pushes Block overview, whose EDIT BLOCK ▸ opens the builder this way. `.template` deleted with StartBlockCTA. The review's "Start next ▸" uses BlockReviewView's own `pendingNextBlockBuilder`, not this state. | 1 |
| Navigation destinations: logger, muscle detail, Block overview, routine detail, history, session detail | `TodayView` `navigationDestination` for `SessionRoute`, `MuscleSlugRoute`, `BlockOverviewRoute`, `SplitDetailRoute`, `SessionHistoryRoute`, `openedTemplate` | Kept. Adds `VolumeRoute` for the this-week row. | 1 |
| DEBUG seeds the UI tests launch with | `fitbod/App/*Seed.swift`, dispatched from `RootView` | Kept. Three new seeds: a ready block with none active, a session with no exercises, a workout finished today under a block. `-fitbod-seed-powerbuilding` (a long block name), `-fitbod-seed-empty-workout` (a workout finished today, no block) and `-fitbod-seed-ended-block-recap` (routines, no live block) already cover the rest. | 1 |
| Live Activity deep link | Unhandled on Today (design map, workflows/today.md) | Unchanged, out of scope | - |
| Re-tapping the Today tab pops to the root | Not implemented for Today and Program; Progress and Library do pop (`fitbod/App/RootView.swift:175`, D-158) | Unchanged, out of scope | - |

## Program

| Capability | Now | Proposed | Phase |
| --- | --- | --- | --- |
| Header "+ NEW" popover: + New block, + New routine | `ProgramChromeHeader`, `fitbod/Periodization/ProgramView.swift:1021`, `BRUActionPopover`, positioned by a measured header height | BRUHeaderBar with `HeaderAction("+ New")` on the right (ink), same popover, same two items, same height measurement | 1 |
| New block: Blank block or Use preset → From scratch or a preset → block builder | `NewBlockStartChoiceSheet` (`ProgramView.swift:750`), `NewBlockPresetPickerSheet` (`:866`), staged through `presentingStartChoice`, `presentingPresetPicker` and `stagedBuilder`; `BlockBuilderView` full-screen cover with origin `.program` | Kept as is, in ProgramView.swift, with "CREATE BLOCK" | - |
| New routine | `newRoutineDestination`, `NewRoutineRoute.name` | Kept | - |
| Resume banner: resume; discard by long press, always confirms | `fitbod/Sessions/ResumeWorkoutBanner.swift` | A paper row with RESUME ▸ and a visible ghost DISCARD, same confirmation | 1 |
| Empty hero: ACTIVE BLOCK · NONE, NO PROGRAM, paragraph, + DEFINE BLOCK ▶, four chips | `NoProgramHero`, `ProgramView.swift:1128` | P-EMPTY: "Start with a routine", one paragraph, + NEW ROUTINE, the archived routines entry when any exist | 1 |
| Templates: "Or start from a template", preset rows → block builder | `ProgramTemplateSection`, `ProgramView.swift:1339` | Removed from Program. Presets stay in + New block › Use preset (O-8). | 1 |
| Blocks section head and "No blocks yet. + DEFINE BLOCK ▶" | `ProgramView.blocksSection`, `noBlocksRow` | "No block yet. + NEW BLOCK" when routines exist and no block is live; "No block planned." when only completed blocks exist | 1 |
| Block cards: ACTIVE, READY, DRAFT, DONE chips, name, "Week 1 of 4 · Accumulation" or PLAN COMPLETE, tap → Block overview | `BlockStatusCard`, `ProgramView.swift:573`, `ProgramView.activeBlockWeek` | Active → the Now slab (label row with Open ›, name, position, routine). Ready and draft → Planned cards with outlined ink chips and "Saved Oct 3" or the missing piece. Done → the Past blocks list. | 1 |
| Done blocks capped at three with ALL HISTORY ▸ | `ProgramView.blocksSection` | "Past blocks · 3 ›" row → pushed list with name, weeks, dates and workout count | 1 |
| Routine rows: name, "n sessions", block-name chips, › → routine detail | `RoutineSplitRow` (`ProgramView.swift:650`), `UsageTagFlow` (`:720`), `SplitDetailRoute` | Rows with a muted subline "3 sessions · used by Spring Block" | 1 |
| "+ NEW ROUTINE" row under routines | `ProgramView.routinesSection` | Only as the empty-section line "No routines yet. + NEW ROUTINE" | 1 |
| Archived routines entry with count | `archivedRoutinesEntry`, `ArchivedRoutinesRoute.list` | Kept, muted, hidden at zero, shown in every state including P-EMPTY | 1 |
| Start a ready block | Only from Block overview, with the "Start Block?" swap confirmation when another block is active | P-PLANNED's slab carries START BLOCK ▸ when nothing is active, with no confirmation and a "Couldn't start block" alert; starting while another block runs stays on Block overview | 1 |
| Navigation destinations: logger, Block overview, routine detail, archived routines, new routine | `ProgramView` | Kept. Adds the past blocks list and, in Phase 2, history detail for This week rows. | 1, 2 |
| This week day rows | Not built; in the user's mock-up `phase-2--program.png` | New section under the Now slab: weekday rows for weekday blocks with logged workouts on the day they happened and an ink "TODAY ▸" action; a rotation strip with "NEXT ▸" for rotation blocks | 2 |
| Routine folders, search, New Folder, Move, active-session conflict alert | `fitbod/Routines/RoutinesListView.swift`, not wired into any tab; its file also declares `SessionRoute`, the logger route both tabs push | Stays unwired (O-7). Deleting the file is a Phase 3 cleanup, after `SessionRoute` moves out. | 3 |
| Legacy block card with ••• Edit Block and End Block; legacy block row with delete | `fitbod/Periodization/BlockCard.swift` (no app caller), `fitbod/Periodization/BlockRow.swift` (called by `RoutinesListView.swift:315`; `BlockRow.sortedForDisplay` used by `BlockPickerMenu.swift:64`) | Deleted in Phase 3 after RoutinesListView; `sortedForDisplay` moves to BlockPickerMenu | 3 |

## Block overview, where both tabs lead

| Capability | Now | Proposed | Phase |
| --- | --- | --- | --- |
| Week strip header "W2 / 6"; "n / m SESSIONS DONE" | `BlockOverviewScreen.swift:583`, `:809` | `BlockPosition.label`, and "n / m WORKOUTS DONE" | 1 |
| START BLOCK ▸ with the "Start Block?" swap confirmation, EDIT BLOCK ▸, END BLOCK with the "End block?" alert | `fitbod/Periodization/BlockOverviewScreen.swift`, `SwapConfirmSheet` (`:1395-1411`) | Kept. The End block alert's body becomes "Ends Spring Block and saves its plan to history. New workouts will not count toward it." | 2 |
| + ATTACH ROUTINE ▸ on draft and ready blocks | `BlockOverviewScreen.swift:299-302` shows the band only for those statuses, button at `:925-937`; `attachSplit` refuses active blocks | Kept as is | - |
| Review a completed block | Not reachable after the automatic sheet (D-40); `BlockReviewView` hard-codes origin `.today` | "Review ›" on a completed block's overview opens `BlockReviewView` as a sheet with the origin passed in | 2 |
| Next training day | `BlockOverviewScreen.nextTrainingDay` (static, `:463`) | Shared with Today's T-REST and T-DONE next lines | 2 |
| Archived config | `ArchivedBlockConfig` (name, dates, mode, days, phases; no workout data) | Kept | - |

## Progress, what it gains

| Capability | Now | Proposed | Phase |
| --- | --- | --- | --- |
| Muscle volume and heatmap | Only at the bottom of Today | "Volume" entry on `fitbod/Progress/ProgressHomeView.swift` pushing `VolumeScreen`; `VolumeRoute` and `MuscleSlugRoute` registered on the Progress stack | 1 |
| History | Progress › History and Today's SESSIONS cell | Progress › History only | 1 |
