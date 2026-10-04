# CI verification summary

- Generated: 2026-10-04T06:37:00+00:00
- Xcode: Xcode 26.6 Build version 17F113
- Simulator runtime: iOS 26.5
- Small device: iPhone SE (3rd generation) · Large device: iPhone 17 Pro Max

## ui-large — Passed

Total 4 · passed 4 · failed 0 · skipped 0

<details><summary>All test cases</summary>

- ✅ LayoutAuditUITests › testTourAccessibilityText()
- ✅ LayoutAuditUITests › testTourDarkLargestText()
- ✅ LayoutAuditUITests › testTourDefaultText()
- ✅ WorkoutJourneyUITests › testEndToEndWorkoutJourneySurvivesRelaunch()

</details>

Screenshots (69): A01-today.png, A02-routines.png, A03-routine-detail.png, A04-library.png, A05-exercise-detail.png, A06-history.png, A07-history-detail.png, A08-settings.png, A09-gallery-1.png, A09-gallery-2.png, A09-gallery-3.png, A09-gallery-4.png, A10-workout.png, A11-set-row-ready.png, A12-rest-dock.png, A13-rest-sheet.png, B-ax01-today.png, B-ax02-routines.png, B-ax03-routine-detail.png, B-ax04-library.png, B-ax05-exercise-detail.png, B-ax06-history.png, B-ax07-history-detail.png, B-ax08-settings.png, B-ax09-gallery-1.png, B-ax09-gallery-2.png, B-ax09-gallery-3.png, B-ax09-gallery-4.png, B-ax10-workout.png, B-ax11-set-row-ready.png, B-ax12-rest-dock.png, B-ax13-rest-sheet.png, C-dark01-today.png, C-dark02-routines.png, C-dark03-routine-detail.png, C-dark04-library.png, C-dark05-exercise-detail.png, C-dark06-history.png, C-dark07-history-detail.png, C-dark08-settings.png, C-dark09-gallery-1.png, C-dark09-gallery-2.png, C-dark09-gallery-3.png, C-dark09-gallery-4.png, C-dark10-workout.png, C-dark11-set-row-ready.png, C-dark12-rest-dock.png, C-dark13-rest-sheet.png, J00-today-first-launch.png, J01-library-search.png, J02-library-filtered.png, J03-exercise-detail.png, J04-library-no-match.png, J05-custom-exercise-validation.png, J06-custom-exercise-saved.png, J07-routines-empty.png, J08-routine-validation.png, J09-routine-builder.png, J10-routines-list.png, J11-workout-start.png, J12-set-logged-rest-timer.png, J13-set-validation-error.png, J14-relaunch-resumed.png, J15-summary.png, J16-history.png, J17-history-detail.png, J18-history-after-rename.png, J19-previous-performance.png, J20-today-after-discard.png

## ui-small — Passed

Total 4 · passed 4 · failed 0 · skipped 0

<details><summary>All test cases</summary>

- ✅ LayoutAuditUITests › testTourAccessibilityText()
- ✅ LayoutAuditUITests › testTourDarkLargestText()
- ✅ LayoutAuditUITests › testTourDefaultText()
- ✅ WorkoutJourneyUITests › testEndToEndWorkoutJourneySurvivesRelaunch()

</details>

Screenshots (69): A01-today.png, A02-routines.png, A03-routine-detail.png, A04-library.png, A05-exercise-detail.png, A06-history.png, A07-history-detail.png, A08-settings.png, A09-gallery-1.png, A09-gallery-2.png, A09-gallery-3.png, A09-gallery-4.png, A10-workout.png, A11-set-row-ready.png, A12-rest-dock.png, A13-rest-sheet.png, B-ax01-today.png, B-ax02-routines.png, B-ax03-routine-detail.png, B-ax04-library.png, B-ax05-exercise-detail.png, B-ax06-history.png, B-ax07-history-detail.png, B-ax08-settings.png, B-ax09-gallery-1.png, B-ax09-gallery-2.png, B-ax09-gallery-3.png, B-ax09-gallery-4.png, B-ax10-workout.png, B-ax11-set-row-ready.png, B-ax12-rest-dock.png, B-ax13-rest-sheet.png, C-dark01-today.png, C-dark02-routines.png, C-dark03-routine-detail.png, C-dark04-library.png, C-dark05-exercise-detail.png, C-dark06-history.png, C-dark07-history-detail.png, C-dark08-settings.png, C-dark09-gallery-1.png, C-dark09-gallery-2.png, C-dark09-gallery-3.png, C-dark09-gallery-4.png, C-dark10-workout.png, C-dark11-set-row-ready.png, C-dark12-rest-dock.png, C-dark13-rest-sheet.png, J00-today-first-launch.png, J01-library-search.png, J02-library-filtered.png, J03-exercise-detail.png, J04-library-no-match.png, J05-custom-exercise-validation.png, J06-custom-exercise-saved.png, J07-routines-empty.png, J08-routine-validation.png, J09-routine-builder.png, J10-routines-list.png, J11-workout-start.png, J12-set-logged-rest-timer.png, J13-set-validation-error.png, J14-relaunch-resumed.png, J15-summary.png, J16-history.png, J17-history-detail.png, J18-history-after-rename.png, J19-previous-performance.png, J20-today-after-discard.png

## unit — Passed

Total 275 · passed 275 · failed 0 · skipped 0

<details><summary>All test cases</summary>

- ✅ ActiveSessionConflict › firstStartSucceeds — no active session exists → start returns a Session with completedAt == nil
- ✅ ActiveSessionConflict › secondStartThrowsActiveSessionAlreadyExists — RESEARCH §6 Pitfall 7
- ✅ ActiveSessionConflict › startAfterFinishingPriorSessionSucceeds — finished sessions don't count as active
- ✅ ActiveSessionConflict › startAfterDiscardingPriorSessionSucceeds — discard branch of the conflict alert
- ✅ AddUnplannedExercise › appendsSessionExerciseToActiveSession — SE.orderIndex past existing count
- ✅ AddUnplannedExercise › doesNotMutateSourceRoutine — appending only affects session.exercises
- ✅ AddUnplannedExercise › seedsThreeDefaultSetsWithMatchingIntentHint — 3 planned sets at hint weight
- ✅ CascadeRules › deleting an Exercise cascades into its ExerciseMuscleStimulus rows
- ✅ CascadeRules › deleting an Exercise NULLIFIES the linked SessionExercise.exercise (LIB-05)
- ✅ CascadeRules › deleting a Session cascades into SessionExercise and SetEntry rows
- ✅ CascadeRules › deleting a Routine cascades into its RoutineExercise rows
- ✅ Chalkline tokens › every text pair is at least 4.5:1 in light, dark and Increase Contrast
- ✅ Chalkline tokens › the accent fill is at least 3:1 against paper
- ✅ Chalkline tokens › Increase Contrast never lowers a secondary ink's contrast
- ✅ Chalkline tokens › durations, clocks, weights, RPE and volume
- ✅ Chalkline tokens › the set table needs 320 pt at default text — and fits a 375 pt iPhone row
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Empty name → invalid
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Whitespace-only name → invalid
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › No muscles → invalid
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Only secondary muscle → invalid (PITFALLS #5)
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Primary muscle with weight < 0.5 → invalid
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Name + primary muscle (weight=0.5) → valid (threshold)
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Name + primary muscle (weight=1.0) → valid (full)
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Multiple primaries → still valid
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Materialize inserts Exercise + stimulus rows with isCustom=true
- ✅ CustomExerciseDraft validation (LIB-04 / FOUND-07 / PITFALLS #5) › Snapshot equality detects dirty state
- ✅ Exercise → SessionExercise nullify on delete (LIB-05 — editor surface) › Deleting a custom Exercise nullifies any SessionExercise reference (LIB-05)
- ✅ ExerciseDTO decoding › Bundled exercises.json decodes into [ExerciseDTO]
- ✅ ExerciseDTO decoding › Strength filter retains at least 600 exercises
- ✅ ExerciseDTO decoding › SEED_VERSION.txt is bundled and equals 2
- ✅ ExerciseDTO decoding › EquipmentMapper covers the 12 known dataset values + nil + empty
- ✅ ExerciseDTO decoding › EquipmentMapper handles nil input
- ✅ ExerciseDTO decoding › EquipmentMapper covers every raw equipment value in the bundled dataset
- ✅ ExerciseDTO decoding › Region map handles all 17 dataset slugs
- ✅ ExerciseDTO decoding › Region map bucket sizes match RESEARCH Open Q #3 (10/6/1)
- ✅ ExerciseDTO decoding › Display names handle multi-word slugs and special cases
- ✅ ExerciseDTO decoding › ExerciseDTO round-trips through JSONEncoder/JSONDecoder
- ✅ DoubleProgressionStrategy › bumpWhenAllSetsHitTopOfRange
- ✅ DoubleProgressionStrategy › noBumpWhenAnySetMissesTop
- ✅ DoubleProgressionStrategy › noBumpWhenWarmupsExcluded
- ✅ DoubleProgressionStrategy › noBumpFirstSessionUsesPriorHint
- ✅ DoubleProgressionStrategy › smallestIncrementHonored
- ✅ EmptyLibraryView copy selection (UI-SPEC § Empty states) › Empty searchText → 'No exercises match' + 'Clear filters'
- ✅ EmptyLibraryView copy selection (UI-SPEC § Empty states) › Non-empty searchText → 'No exercises match "X"' + 'Create Custom Exercise'
- ✅ EmptyLibraryView copy selection (UI-SPEC § Empty states) › Whitespace-only searchText is a valid no-query input shape
- ✅ EnumPersistence › Equipment cases round-trip through Exercise.equipmentRaw
- ✅ EnumPersistence › Mechanic cases round-trip through Exercise.mechanicRaw
- ✅ EnumPersistence › Force cases round-trip through Exercise.forceRaw
- ✅ EnumPersistence › Level cases round-trip through Exercise.levelRaw
- ✅ EnumPersistence › Pattern cases round-trip through Exercise.patternRaw
- ✅ EnumPersistence › Intent cases round-trip through SessionExercise.intentRaw
- ✅ EnumPersistence › ProgressionKind cases round-trip through SessionExercise.progressionKindRaw
- ✅ EnumPersistence › MuscleRegion cases round-trip through MuscleGroup.regionRaw
- ✅ EnumPersistence › WeightUnit cases round-trip through UserSettings.unitsRaw
- ✅ EnumPersistence › BlockPhaseKind cases round-trip through BlockPhase.nameRaw
- ✅ EnumPersistence › SetType cases round-trip through SetEntry.setTypeRaw
- ✅ Enums › Intent has exactly 5 cases
- ✅ Enums › ProgressionKind has exactly 4 cases
- ✅ Enums › Equipment has exactly 9 cases (LIB-06)
- ✅ Enums › Mechanic has exactly 2 cases
- ✅ Enums › Force has exactly 3 cases
- ✅ Enums › Level has exactly 3 cases
- ✅ Enums › Pattern has exactly 9 cases
- ✅ Enums › MuscleRegion has exactly 3 cases
- ✅ Enums › WeightUnit has exactly 2 cases
- ✅ Enums › BlockPhaseKind has exactly 4 cases
- ✅ Enums › SetType has exactly 5 cases
- ✅ Enums › Every enum's static `default` is one of its cases
- ✅ ExerciseHistoryIntentSplit › allFilterReturnsBoth — nil intent ⇒ both Monday + Thursday visible
- ✅ ExerciseHistoryIntentSplit › strengthFilterReturnsMondayOnly — ROUTINE-08 separates strength stream
- ✅ ExerciseHistoryIntentSplit › hypertrophyFilterReturnsThursdayOnly — ROUTINE-08 separates hypertrophy stream
- ✅ ExerciseHistoryIntentSplit › powerFilterReturnsEmpty — no power sessions logged ⇒ empty result
- ✅ ExerciseHistoryIntentSplit › differentExerciseReturnsEmpty — predicate isolates per-exercise history
- ✅ ExerciseHistoryIntentSplit › incompleteSetsExcludedFromVisibleSets — view-layer filter pin
- ✅ ExerciseHistoryViewCopy › verbatimCopy — UI-SPEC § Exercise history strings present in source
- ✅ ExerciseLibraryPickerMode (plan 03-02 — RESEARCH § Pattern 5) › pickerInitCompilesAndInvokesClosure
- ✅ ExerciseLibraryPickerMode (plan 03-02 — RESEARCH § Pattern 5) › defaultInitStillExists
- ✅ ExerciseStore + DemoData (milestone 1) › deleting a custom exercise keeps history, removes routine lines, renumbers
- ✅ ExerciseStore + DemoData (milestone 1) › demo history: finished workouts with climbing weights, seeded once
- ✅ ExerciseStore + DemoData (milestone 1) › demo history needs a library
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › Empty filter returns every exercise
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › Search 'bench' returns only Bench Press
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › SwiftData predicate applies search before post-fetch muscle filtering
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › Equipment=dumbbell returns Dumbbell Curl only
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › Mechanic=isolation returns Dumbbell Curl only
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › Muscle=chest returns Bench Press only (denormalized slug match)
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › Equipment=barbell AND Mechanic=compound returns Bench + Squat
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › Multi-select within muscle facet ORs: chest+biceps → 2 rows
- ✅ FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:) › Facet selections do not constrain the SwiftData fetch
- ✅ Indexed queries on Exercise › canonicalName.contains query stays under 200ms at seeded scale
- ✅ Indexed queries on Exercise › primaryMuscleSlugsJoined.contains query stays under 200ms at seeded scale
- ✅ ManualOverride › manualOverrideFlagSetWhenWeightDiverges
- ✅ ManualOverride › manualOverrideFlagFalseWhenWeightMatchesPrescription
- ✅ ManualOverride › nextSessionReadsActualNotPrescribed
- ✅ ManualOverride › userSettingsMinCalibrationSetsHonored
- ✅ MidSessionSwap › swapMutatesSessionExerciseOnly — SE.exercise = new; RE.exercise unchanged
- ✅ MidSessionSwap › swapResetsPendingSetsToNewHint — pending sets adopt the new exercise's hint
- ✅ MidSessionSwap › swapLeavesCompletedSetsAlone — committed sets retain weight/reps/rpe
- ✅ MidSessionSwap › swapDoesNotAffectRoutineTemplate — PITFALLS-doc #1 / ROUTINE-07
- ✅ NotesPersistence › sessionNotesRoundTrip — session.notes writes + reads through SwiftData
- ✅ NotesPersistence › pinnedNoteRoundTrip — sessionExercise.pinnedNote writes + reads through SwiftData
- ✅ NotesPersistence › setEntryNoteRoundTrip — setEntry.notes writes + reads through SwiftData
- ✅ NotesPersistence › emptyStringNotesPersistAsNil — Binding(get:set:) empty-string set maps to nil
- ✅ OptionalRowRendering › tempoRowRendersWhenSnapshottedFlag — gated on sessionExercise.tracksTempo
- ✅ OptionalRowRendering › partialsRowRendersWhenSnapshottedFlag — gated on sessionExercise.tracksPartialReps
- ✅ OptionalRowRendering › clusterChipRowRendersWhenSetTypeRestPause — gated on set.setType == .restPause
- ✅ PlateCalculator › solve100kgWith20kgBar
- ✅ PlateCalculator › roundDown102_5kgWith2_5kgIncrement
- ✅ PlateCalculator › belowBarReturnsBar
- ✅ PlateCalculator › epsilonFloatDriftGuard
- ✅ PlateCalculator › noSolutionReturnsNil
- ✅ PlateInventory › jsonRoundTripPreservesAllFields — weight, countPerSide, color survive encode/decode
- ✅ PlateInventory › emptyPlateArraySerializesAsEmptyJSON — empty assignment decodes back to []
- ✅ PlateInventory › equipmentKindAccessorFallbackOnBadRaw — unknown raw value returns .barbell
- ✅ PlateInventory › equipmentKindAccessorRoundTrip — set .ezBar writes 'ez_bar' raw; get returns .ezBar
- ✅ PrescriptionDefaults (ROUTINE-09 + CONTEXT.md Area 1) › compoundBarbellStrength — Bench Press → strength + 4-6 reps + 180s rest
- ✅ PrescriptionDefaults (ROUTINE-09 + CONTEXT.md Area 1) › compoundDumbbellHypertrophy — DB Press → hypertrophy + 8-12 reps + 180s rest
- ✅ PrescriptionDefaults (ROUTINE-09 + CONTEXT.md Area 1) › isolationHypertrophy — Curl → hypertrophy + 8-12 reps + 90s rest
- ✅ PrescriptionDefaults (ROUTINE-09 + CONTEXT.md Area 1) › restMatchesMechanic — sweep — every compound → 180s, every isolation → 90s
- ✅ PrescriptionExplanation › constructionExposesAllFields
- ✅ PrescriptionExplanation › calibrationStatusEquatable
- ✅ PrescriptionExplanation › sendableSafe
- ✅ PrescriptionExplanation › bumpOccurredFalseByDefault
- ✅ PrescriptionExplanation › rangeNilByDefault
- ✅ PreviousColumnQuery › previousColumnReturnsHintWhenPriorExists — matching-intent prior yields hit
- ✅ PreviousColumnQuery › previousColumnReturnsNilWhenNoPrior — empty store yields nil
- ✅ PreviousColumnQuery › previousColumnRespectsIntentSplit — strength ignored when querying hypertrophy
- ✅ PreviousMatchingIntent › returnsNilWhenNoPriorSession — empty DB yields no hit
- ✅ PreviousMatchingIntent › findsTopWorkingSetExcludesWarmupsAndZeroReps — filters to committed working sets
- ✅ PreviousMatchingIntent › intentSplitRespectsIntentFilter — strength session ignored when querying hypertrophy
- ✅ PreviousMatchingIntent › mostRecentSessionByStartedAtWins — sorted by Session.startedAt desc
- ✅ PreviousMatchingIntent › nilExerciseIDReturnsNil — defensive guard
- ✅ PreviousMatchingIntent › ignoresIncompleteSets — planned-but-not-logged rows skipped
- ✅ ProgressionRounding › exerciseIncrementOverridesGlobal
- ✅ ProgressionRounding › globalDefaultUsedWhenNil
- ✅ ProgressionRounding › kgVsLbUnitOverride
- ✅ ProgressionRounding › microplateIncrement
- ✅ ProgressionRounding › roundingDownNeverExceedsTarget
- ✅ RPEAutoregStrategy › calibratingBelowThresholdShowsRange
- ✅ RPEAutoregStrategy › calibratedAboveThresholdReturnsPointEstimate
- ✅ RPEAutoregStrategy › nilRPEInHistoryIsExcluded
- ✅ RPEAutoregStrategy › emptyHistoryReturnsFirstSessionExplanation
- ✅ RPEAutoregStrategy › tuchschererBackCalcUsedBelowThreshold
- ✅ RestTimerActivityController › noopControllerSwallowsAllCalls
- ✅ RestTimerActivityController › liveControllerSilentFallbackOnSimulator
- ✅ RestTimerActivityController › updateDebounceCoalesces
- ✅ RestTimerEngine › notRunningInitially
- ✅ RestTimerEngine › startSetsStartedAtAndTarget
- ✅ RestTimerEngine › startSchedulesNotificationOnce
- ✅ RestTimerEngine › plus15IncreasesTargetAndReschedulesFromOriginalStart
- ✅ RestTimerEngine › minus15DecreasesTarget
- ✅ RestTimerEngine › adjustClampsTargetAtZero
- ✅ RestTimerEngine › adjustNoopWhenNotRunning
- ✅ RestTimerEngine › stopCancelsAndResets
- ✅ RestTimerEngine › dateMathSurvivesSimulatedBackground
- ✅ RestTimerEngine › restartReplacesPriorState
- ✅ RestTimerNotificationScheduler › notificationIDConstantIsStable
- ✅ RestTimerNotificationScheduler › liveSchedulerConformsToProtocol
- ✅ RestTimerNotificationScheduler › liveSchedulerScheduleAccepts1SecondMinimum
- ✅ RestTimerOverlayCopy › verbatimCopyAnchors — rest timer strings present in source
- ✅ RestTimerOverlayCopy › reduceMotionWiredThroughEnvironment
- ✅ RestTimerOverlayCopy › timelineViewTickEverySecond
- ✅ RestTimerOverlayCopy › countdownText — clock and spoken values, including overtime
- ✅ RestTimerPersistence (milestone 1) › start persists the absolute deadline; a relaunched engine shows the same remaining time
- ✅ RestTimerPersistence (milestone 1) › time keeps running while the app is away — restore past the deadline shows overtime, not a reset
- ✅ RestTimerPersistence (milestone 1) › a timer that ended long ago is dropped on restore
- ✅ RestTimerPersistence (milestone 1) › ±15 s and presets persist and keep the original start
- ✅ RestTimerPersistence (milestone 1) › stop clears the persisted timer
- ✅ RestTimerPersistence (milestone 1) › stop(ifBelongsTo:) only stops the workout's own timer
- ✅ RestTimerPersistence (milestone 1) › UserDefaults store round-trips the snapshot and clears it
- ✅ RoutineBuilderCopy › verbatimCopy — routine builder strings present in source
- ✅ RoutineBuilderCopy › RoutineDraft issues — name and exercises, in display order
- ✅ RoutineDraftValidation (plan 03-02) › emptyDraftIsInvalid
- ✅ RoutineDraftValidation (plan 03-02) › noExercisesIsInvalid
- ✅ RoutineDraftValidation (plan 03-02) › validDraft
- ✅ RoutineDraftValidation (plan 03-02) › pruneOverridesOnTargetSetsShrink
- ✅ RoutineDraftValidation (plan 03-02) › saveRoundTrip — fields persist + recover
- ✅ RoutineDuplication (plan 03-03) › nameSuffixedWithCopy
- ✅ RoutineDuplication (plan 03-03) › deepCopyOfRoutineExercises
- ✅ RoutineDuplication (plan 03-03) › supersetGroupRemappedToClonedGroup
- ✅ RoutineDuplication (plan 03-03) › perSetOverridesCloned
- ✅ RoutineDuplication (plan 03-03) › folderIDPreserved
- ✅ RoutineDuplication (plan 03-03) › originalRoutineUntouched
- ✅ RoutineFolderDraft › emptyDraftIsInvalid
- ✅ RoutineFolderDraft › whitespaceOnlyNameIsInvalid
- ✅ RoutineFolderDraft › namedDraftIsValid
- ✅ RoutinesListCopy › verbatimCopy — Routines tab strings present in source
- ✅ SchemaV1 › container builds with versioned schema + migration plan
- ✅ SchemaV1 › schema list and SchemaV1.models agree on 12 entities
- ✅ SchemaV1 › migration plan registers SchemaV1 as historical version
- ✅ SchemaV1 › Exercise round-trips through insert + save + fetch
- ✅ SchemaV1 › Exercise default-inits and saves
- ✅ SchemaV1 › MuscleGroup default-inits and saves
- ✅ SchemaV1 › ExerciseMuscleStimulus default-inits and saves
- ✅ SchemaV1 › Routine default-inits and saves
- ✅ SchemaV1 › RoutineExercise default-inits and saves
- ✅ SchemaV1 › Session default-inits and saves
- ✅ SchemaV1 › SessionExercise default-inits and saves
- ✅ SchemaV1 › SetEntry default-inits and saves
- ✅ SchemaV1 › Block default-inits and saves
- ✅ SchemaV1 › BlockPhase default-inits and saves
- ✅ SchemaV1 › UserSettings default-inits and saves
- ✅ SchemaV1 › MuscleVolumeTarget default-inits and saves
- ✅ SchemaV2Migration › SchemaV2 models list contains every V1 entity plus 3 new types
- ✅ SchemaV2Migration › FitbodSchemaMigrationPlan registers V1 then V2, one lightweight stage per step
- ✅ SchemaV2Migration › Fresh in-memory V2 ModelContainer opens; round-trips a Routine + new entity
- ✅ SchemaV2Migration › Cascade: deleting a RoutineExercise cascades into its setOverrides
- ✅ SchemaV2Migration › Soft refs: deleting a RoutineFolder does NOT cascade into routines
- ✅ SchemaV3Migration › SchemaV3 models list equals SchemaV2.models + PlateInventory.self
- ✅ SchemaV3Migration › FitbodSchemaMigrationPlan registers V1+V2+V3 and TWO lightweight stages
- ✅ SchemaV3Migration › Fresh in-memory V3 ModelContainer opens; round-trips PlateInventory with plates
- ✅ SchemaV3Migration › Additive Phase 3 fields round-trip with correct defaults
- ✅ ExerciseLibraryImporter › Seed inserts at least 600 strength exercises (LIB-01 / FOUND-05)
- ✅ ExerciseLibraryImporter › Seed creates exactly 17 canonical MuscleGroup rows
- ✅ ExerciseLibraryImporter › Seed is idempotent — second call does not duplicate rows
- ✅ ExerciseLibraryImporter › Seed populates the UserSettings singleton with weightUnit == .lb
- ✅ ExerciseLibraryImporter › Stimulus rows: primary=1.0, secondary=0.5, at least 1 per exercise
- ✅ ExerciseLibraryImporter › primaryMuscleSlugsJoined populated as |slug| for the muscle-filter predicate
- ✅ ExerciseLibraryImporter › Cold seed completes within performance budget (target <2s, soft cap 5s)
- ✅ ExerciseLibraryImporter › Re-seed updates built-ins in place and keeps custom exercises, references and tweaks
- ✅ SessionFactoryPhase3 › prescribedWeightSetOnSessionExercise
- ✅ SessionFactoryPhase3 › warmupSetEntriesInsertedForFirstQualifyingCompound
- ✅ SessionFactoryPhase3 › workingSetsShiftAfterWarmupInsertion
- ✅ SessionFactoryPhase3 › secondQualifyingCompoundDoesNotGetWarmup
- ✅ SessionFactoryPhase3 › warmupSkippedWhenWarmupConfigDisabled
- ✅ SessionFactory › snapshotsAllPrescriptionFields — every RoutineExercise field is copied verbatim
- ✅ SessionFactory › editingRoutineAfterStartLeavesSnapshotIntact — ROUTINE-07 / PITFALLS-doc #1
- ✅ SessionFactory › sessionLinksRoutineByUUIDAndName — sourceRoutineID is the routine UUID; name survives rename
- ✅ SessionFactory › plannedSetEntriesCount — one SetEntry per targetSets; all carry isComplete = false
- ✅ SessionFactory › activeSessionInvariant — start throws when an unfinished session exists
- ✅ SessionFactory › emptyRoutineGuard — start throws when routine has no exercises
- ✅ SessionFactory › orderIndexPreservedAcrossSnapshot — RoutineExercise.orderIndex translates to SessionExercise.orderIndex
- ✅ SessionFactory › snapshotsTracksTempoAndTracksPartialReps — opt-in row toggles are snapshotted
- ✅ SessionFactory › blockReferenceCopiedFromRoutine — optional Block link survives snapshot
- ✅ SessionLoggerCopy › verbatimCopy — active-workout strings and wiring present in source
- ✅ SetRowCommit › commitFlipsIsComplete — after commit, entry.isComplete == true
- ✅ SetRowCommit › commitWritesCompletedAt — entry.completedAt is set to a recent Date
- ✅ SetRowCommit › commitStartsRestTimer — engine.start(seconds:, exerciseName:) is called
- ✅ SetRowCommit › commitGuardedByWeightAndReps — zero-weight or zero-rep entry is a no-op
- ✅ SettingsView units toggle (SET-01 integration) › Flipping weightUnit on UserSettings persists across re-fetched ModelContext (SET-01)
- ✅ SettingsView units toggle (SET-01 integration) › Flipping weightUnit kg → lb also persists across re-fetched ModelContext
- ✅ SupersetGroup (plan 03-03) › createAndAssign
- ✅ SupersetGroup (plan 03-03) › unassignSetsNil
- ✅ SupersetGroup (plan 03-03) › kindAccessor
- ✅ SupersetGroup (plan 03-03) › orphanedSupersetGroupAfterRoutineDelete — handled by RoutinesListView.handleDelete
- ✅ TuchschererTable › rpe10reps1Returns1_000
- ✅ TuchschererTable › rpe8reps5Returns0_811
- ✅ TuchschererTable › rpe6reps10Returns0_656
- ✅ TuchschererTable › clampRepsAboveTen
- ✅ TuchschererTable › nearestRPESnap
- ✅ UserSettings › default() returns lb, and the kg toggle round-trips (SET-01)
- ✅ UserSettings › defaultProgressionKind toggle round-trips
- ✅ UserSettings › default() factory ships lb units and double progression
- ✅ WarmupConfig › codableRoundTripPreservesEnabledAndSkipNextSession — encode/decode is lossless
- ✅ WarmupConfig › defaultsAreEnabledTrueSkipFalse — WarmupConfig() carries correct defaults
- ✅ WarmupConfig › routineExerciseWarmupOverrideNilByDefault — fresh RoutineExercise has nil override
- ✅ WarmupConfig › routineExerciseWarmupOverrideSetGetRoundTrip — set encodes Data; get decodes back
- ✅ WarmupRamp › barbellCompoundAtTopGenerates4Sets
- ✅ WarmupRamp › dumbbellHalvesTo2Sets
- ✅ WarmupRamp › lightWeightSkipsRamp
- ✅ WarmupRamp › bodyweightSkipsRamp
- ✅ WarmupRamp › deloadActiveSkipsRamp
- ✅ WorkoutLogic (milestone 1) › reps are always required; weight only for loaded lifts
- ✅ WorkoutLogic (milestone 1) › complete only marks valid sets, stamps the time and saves
- ✅ WorkoutLogic (milestone 1) › add set copies the last working weight; delete removes it
- ✅ WorkoutLogic (milestone 1) › a logged weight carries into later empty sets, never over typed ones or bodyweight
- ✅ WorkoutLogic (milestone 1) › previous performance comes from the last earlier workout, never the one in progress
- ✅ WorkoutLogic (milestone 1) › finish keeps only performed work and stamps the duration
- ✅ WorkoutLogic (milestone 1) › discard deletes the workout; the routine is untouched
- ✅ WorkoutLogic (milestone 1) › an unplanned exercise is appended after the planned ones
- ✅ WorkoutLogic (milestone 1) › recap delta compares best sets
- ✅ WorkoutLogic (milestone 1) › summary recap reports the gain over the previous session
- ✅ WorkoutLogic (milestone 1) › Epley estimate, capped at 12 reps
- ✅ WorkoutPersistence (milestone 1) › editing or deleting the routine never rewrites a logged workout
- ✅ WorkoutPersistence (milestone 1) › an in-progress workout reopens intact from disk, then finishes and stays in history

</details>

