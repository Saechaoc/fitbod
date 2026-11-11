//
//  TrackingTests.swift
//  fitbodTests
//
//  What a set records, by its exercise's tracking type (RM-062):
//    - one rule decides whether a set can be completed;
//    - a timed set logs, carries forward and shows by its own values;
//    - tonnage, e1RM, records and load progression skip timed and assisted
//      sets, while counts and the summary include them;
//    - History corrections accept timed and assisted sets and never judge a
//      set that was left alone.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Tracking", .serialized)
struct TrackingTests {
    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSinceReferenceDate: 30 * 86_400)

    // MARK: - Fixtures

    private func exercise(
        _ name: String, tracking: Tracking, equipment: Equipment = .other, in ctx: ModelContext
    ) -> Exercise {
        let exercise = Exercise.previewSample(name: name, equipment: equipment, mechanic: .compound)
        exercise.trackingRaw = tracking.rawValue
        ctx.insert(exercise)
        return exercise
    }

    /// A finished workout of `exercise` a day before `now`, with one
    /// completed set per time given.
    private func finishedWorkout(
        of exercise: Exercise, seconds: [Int], in ctx: ModelContext
    ) throws -> (workout: Session, sets: [SetEntry]) {
        let start = now.addingTimeInterval(-day)
        let workout = try LoggerFixtures.session(
            exercise: exercise, startedAt: start, completedAt: start.addingTimeInterval(1_800),
            sets: seconds.map { _ in (0, 0, true) }, in: ctx
        )
        let sets = SessionSetActions.ordered(try #require(workout.exercises?.first))
        for (set, time) in zip(sets, seconds) { set.durationSeconds = time }
        try ctx.save()
        return (workout, sets)
    }

    private func prescription(for exercise: Exercise, in workout: Session, ctx: ModelContext) -> SessionFactory.ExercisePrescription {
        SessionFactory.prescription(
            for: exercise, targetRepsLow: 5, targetRepsHigh: 8, targetRPE: nil, in: workout,
            strategy: ProgressionStrategyFactory.make(for: workout.progressionKind),
            userSettings: nil, context: ctx
        )
    }

    // MARK: - The completion rule

    @Test("a set completes by what its exercise tracks")
    func validity() {
        let cases: [(Tracking?, Double, Int, Int?, Bool)] = [
            (.weightReps, 100, 5, nil, true),
            (.weightReps, 0, 5, nil, false),
            (.weightReps, 100, 0, nil, false),
            (.weightReps, 100, 0, 60, false),
            (.reps, 0, 10, nil, true),
            (.reps, 25, 10, nil, true),
            (.reps, -20, 10, nil, false),
            (.assistedReps, -20, 8, nil, true),
            (.assistedReps, 0, 8, nil, true),
            (.assistedReps, 20, 8, nil, false),
            (.assistedReps, -20, 0, nil, false),
            (.duration, 0, 0, 90, true),
            (.duration, 50, 0, 90, true),
            (.duration, 0, 10, nil, false),
            (.duration, -5, 0, 90, false),
            (.durationDistance, 0, 0, 1_200, true),
            (.durationLevel, 0, 0, 0, false),
            // No tracking: the exercise is gone, so reps or a time is enough.
            (nil, 0, 5, nil, true),
            (nil, 0, 0, 60, true),
            (nil, 100, 0, nil, false),
            (nil, .infinity, 5, nil, false),
        ]
        for (tracking, weight, reps, seconds, valid) in cases {
            #expect(
                SessionSetActions.isValidSet(weight: weight, reps: reps, durationSeconds: seconds, tracking: tracking) == valid,
                "\(String(describing: tracking)) \(weight) × \(reps), \(String(describing: seconds)) s"
            )
        }
    }

    @Test("Done saves a timed set's accepted offer with its time and distance")
    func completeTimedSetFromOffer() throws {
        let ctx = try LoggerFixtures.makeContext()
        let rower = exercise("Rower", tracking: .durationDistance, equipment: .cardioMachine, in: ctx)
        let workout = try LoggerFixtures.session(
            exercise: rower, startedAt: now, completedAt: nil, sets: [(0, 0, false)], in: ctx
        )
        let set = try #require(workout.exercises?.first?.sets?.first)
        let offer = WorkoutSetSuggestion(durationSeconds: 1_200, distanceMeters: 5_000)

        #expect(!SessionSetActions.canComplete(set))
        #expect(SessionSetActions.canComplete(set, suggestion: offer))
        #expect(try SessionSetActions.complete(set, at: now, suggestion: offer, context: ctx))
        #expect(set.isComplete && set.isTimed && set.hasResult)
        #expect(set.durationSeconds == 1_200 && set.distanceMeters == 5_000 && set.reps == 0)
    }

    @Test("a failed save leaves a timed set as it was typed")
    func completeRestoresTimedValues() throws {
        struct Failure: Error {}
        let ctx = try LoggerFixtures.makeContext()
        let climber = exercise("Stair Climber", tracking: .durationLevel, equipment: .cardioMachine, in: ctx)
        let workout = try LoggerFixtures.session(
            exercise: climber, startedAt: now, completedAt: nil, sets: [(0, 0, false)], in: ctx
        )
        let set = try #require(workout.exercises?.first?.sets?.first)
        set.durationSeconds = 600

        #expect(throws: Failure.self) {
            try SessionSetActions.complete(
                set, suggestion: WorkoutSetSuggestion(durationSeconds: 1_200, level: 8), context: ctx
            ) { _ in throw Failure() }
        }
        #expect(!set.isComplete && set.durationSeconds == 600 && set.level == nil)
    }

    // MARK: - Readers

    @Test("tonnage, e1RM and records skip timed and assisted sets; counts and the summary include them")
    func readersSkipOrCount() throws {
        let ctx = try LoggerFixtures.makeContext()
        let plank = exercise("Plank", tracking: .duration, equipment: .bodyweight, in: ctx)
        let pullUp = exercise("Assisted Pull-Up", tracking: .assistedReps, equipment: .machine, in: ctx)
        let (workout, holds) = try finishedWorkout(of: plank, seconds: [60, 90], in: ctx)
        let assisted = SessionExercise()
        ctx.insert(assisted)
        assisted.session = workout
        assisted.exercise = pullUp
        assisted.exerciseNameSnapshot = pullUp.name
        assisted.orderIndex = 1
        let rep = SetEntry()
        ctx.insert(rep)
        rep.sessionExercise = assisted
        rep.weight = -20
        rep.reps = 8
        rep.isComplete = true
        rep.completedAt = workout.startedAt
        try ctx.save()

        for set in holds + [rep] {
            #expect(set.countsAsWork && set.hasResult)
            #expect(set.tonnage == 0)
            #expect(OneRepMaxEstimator.estimate(weight: set.weight, reps: set.reps) == nil)
            #expect(!PRDetector.isWorkingSet(set))
        }
        #expect(SessionFactory.historyPoints(in: workout.exercises ?? [], intentRaw: workout.intentRaw).isEmpty)
        #expect(SessionHistoryFormat.tonnage(of: workout) == 0)
        // A workout of timed sets alone is a workout.
        #expect(workout.loggedSetCount == 3)
        #expect(!SessionSetActions.isEmptyWorkout(workout))

        let summary = SessionSummary.make(session: workout, context: ctx)
        #expect(summary.workingSetCount == 3)
        #expect(summary.totalVolume == 0)
        #expect(summary.prExerciseCount == 0)
        let line = try #require(summary.exercises.first)
        #expect(line.sets.map(\.durationSeconds) == [60, 90])
        #expect(line.sets.first(where: \.isBest)?.durationSeconds == 90)
    }

    @Test("a timed exercise's history shows its longest time and no e1RM; one rep set makes it a load history")
    func timedHistory() throws {
        let ctx = try LoggerFixtures.makeContext()
        let plank = exercise("Plank", tracking: .duration, equipment: .bodyweight, in: ctx)
        let (workout, _) = try finishedWorkout(of: plank, seconds: [60, 90], in: ctx)
        let log = try #require(workout.exercises?.first)

        let timed = ExerciseHistoryView.completedSets(from: [log], intent: nil)
        #expect(ExerciseHistoryView.longestTime(in: timed) == 90)
        let row = try #require(ExerciseHistoryView.rows(from: timed, prSetIDs: []).first)
        #expect(row.e1RMLabel == nil)
        #expect(row.topSetLabel == "1:30")
        #expect(row.setChips == ["1:00", "1:30"])

        let rep = SetEntry()
        ctx.insert(rep)
        rep.sessionExercise = log
        rep.orderIndex = 2
        rep.weight = 100
        rep.reps = 5
        rep.isComplete = true
        try ctx.save()
        let mixed = ExerciseHistoryView.completedSets(from: [log], intent: nil)
        #expect(ExerciseHistoryView.longestTime(in: mixed) == nil)
        #expect(ExerciseHistoryView.rows(from: mixed, prSetIDs: []).first?.e1RMLabel != nil)
        #expect(ExerciseHistoryView.longestTime(in: []) == nil)
    }

    @Test("a timed or assisted exercise gets no prescribed load and no warm-up ramp")
    func noPrescriptionOrRamp() throws {
        let ctx = try LoggerFixtures.makeContext()
        for tracking in [Tracking.duration, .durationDistance, .durationLevel, .assistedReps] {
            let lift = exercise("Lift \(tracking.rawValue)", tracking: tracking, equipment: .barbell, in: ctx)
            let workout = try LoggerFixtures.session(
                exercise: lift, startedAt: now, completedAt: nil, sets: [(0, 0, false)], in: ctx
            )
            let log = try #require(workout.exercises?.first)
            let prescribed = prescription(for: lift, in: workout, ctx: ctx)
            #expect(prescribed.weight == 0)
            #expect(prescribed.explanation.suggestedWeight == nil)
            #expect(!WarmupRamp.shouldGenerate(for: log, deloadActive: false, topWorkingWeight: 100, barWeight: 45))
        }
    }

    @Test("a pending timed set is offered the last workout's set, with only the value its row shows")
    func timedOffers() throws {
        let ctx = try LoggerFixtures.makeContext()
        let climber = exercise("Stair Climber", tracking: .durationLevel, equipment: .cardioMachine, in: ctx)
        let (_, logged) = try finishedWorkout(of: climber, seconds: [1_200], in: ctx)
        logged[0].level = 8
        // A value its row does not show, as a retag could leave behind.
        logged[0].distanceMeters = 3_000
        let today = try LoggerFixtures.session(
            exercise: climber, startedAt: now, completedAt: nil, sets: [(0, 0, false), (0, 0, false)], in: ctx
        )
        let current = try #require(today.exercises?.first)
        let pending = SessionSetActions.ordered(current)

        let hit = try #require(PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: climber.id, intentRaw: today.intentRaw, context: ctx, excludingSessionID: today.id
        ))
        #expect(hit.reps == 0 && hit.durationSeconds == 1_200 && hit.level == 8)

        let prior = prescription(for: climber, in: today, ctx: ctx).previousWorkingSets
        var offers = WorkoutSetSuggestions(exercise: current, prior: prior).offers()
        #expect(offers[pending[0].id] == WorkoutSetSuggestion(durationSeconds: 1_200, level: 8))

        // The set just done comes before the last workout's.
        try SessionSetActions.complete(
            pending[0], suggestion: WorkoutSetSuggestion(durationSeconds: 900, level: 10), context: ctx
        )
        offers = WorkoutSetSuggestions(exercise: current, prior: prior).offers()
        #expect(offers[pending[1].id] == WorkoutSetSuggestion(durationSeconds: 900, level: 10))
    }

    @Test("the next prescription reads sets in the shape the exercise tracks now; Last time shows any")
    func progressionInputShape() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let older = now.addingTimeInterval(-14 * day)
        try LoggerFixtures.session(
            exercise: bench, startedAt: older, completedAt: older.addingTimeInterval(3_600),
            sets: [(100, 5, true)], in: ctx
        )
        // A later workout that holds only a timed set, as a retag leaves.
        _ = try finishedWorkout(of: bench, seconds: [60], in: ctx)
        let today = try LoggerFixtures.session(
            exercise: bench, startedAt: now, completedAt: nil, sets: [(0, 0, false)], in: ctx
        )

        #expect(prescription(for: bench, in: today, ctx: ctx).previousWorkingSets.map(\.weight) == [100])
        #expect(prescription(for: bench, in: today, ctx: ctx).previousWorkingSets.map(\.reps) == [5])
        bench.trackingRaw = Tracking.duration.rawValue
        #expect(prescription(for: bench, in: today, ctx: ctx).previousWorkingSets.map(\.durationSeconds) == [60])
        #expect(PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: bench.id, intentRaw: today.intentRaw, context: ctx, excludingSessionID: today.id
        )?.durationSeconds == 60)
    }

    // MARK: - Text

    @Test("a time reads from the digits typed and shows with colons")
    func timeText() {
        #expect(SetText.duration(90) == "1:30")
        #expect(SetText.duration(1_200) == "20:00")
        #expect(SetText.duration(3_900) == "1:05:00")
        #expect(SetText.seconds(fromTyped: "130") == 90)
        #expect(SetText.seconds(fromTyped: "1:30") == 90)
        #expect(SetText.seconds(fromTyped: "90") == 90)
        #expect(SetText.seconds(fromTyped: "2000") == 1_200)
        #expect(SetText.seconds(fromTyped: "13000") == 5_400)
        #expect(SetText.seconds(fromTyped: "") == nil)
        #expect(SetText.seconds(fromTyped: "0") == nil)
        #expect(SetText.seconds(fromTyped: "1.5") == nil)
        #expect(SetText.seconds(fromTyped: "1234567") == nil)
        // Every time a field can show reads back as itself.
        for seconds in [1, 59, 60, 61, 599, 3_599, 3_600, 86_399, WorkoutCorrectionInput.durationLimit - 1] {
            #expect(SetText.seconds(fromTyped: SetText.duration(seconds)) == seconds)
        }
    }

    @Test("distance is stored in meters: miles with lb, kilometers with kg")
    func distanceText() {
        let us = Locale(identifier: "en_US")
        let de = Locale(identifier: "de_DE")
        #expect(SetText.meters(fromTyped: "2.5", unit: .kg, locale: us) == 2_500)
        #expect(SetText.meters(fromTyped: "1", unit: .lb, locale: us) == 1_609.344)
        #expect(SetText.meters(fromTyped: "2,5", unit: .kg, locale: de) == 2_500)
        #expect(SetText.meters(fromTyped: "2.5", unit: .kg, locale: de) == 2_500)
        // A half-typed value keeps what it has so far.
        #expect(SetText.number(fromTyped: "2.", locale: us) == 2)
        #expect(SetText.number(fromTyped: ".5", locale: us) == 0.5)
        #expect(SetText.number(fromTyped: "", locale: us) == nil)
        #expect(SetText.number(fromTyped: "abc", locale: us) == nil)
        #expect(SetText.number(fromTyped: "-1", locale: us) == nil)
        #expect(SetText.number(fromTyped: "1.2.3", locale: us) == nil)
        #expect(SetText.distance(5_000, unit: .kg) == "5")
        #expect(SetText.distance(5_000, unit: .lb) == "3.11")
        // A field shows a distance or a level as it is typed in that locale.
        #expect(SetText.entry(distance: 2_500, unit: .kg, locale: de) == "2,5")
        #expect(SetText.entry(distance: 2_500, unit: .kg, locale: us) == "2.5")
        #expect(SetText.entry(level: 7.5, locale: de) == "7,5")
        #expect(SetText.meters(fromTyped: SetText.entry(distance: 2_500, unit: .kg, locale: de), unit: .kg, locale: de) == 2_500)
    }

    @Test("a logged set reads from its own values")
    func resultText() {
        func text(
            _ weight: Double, _ reps: Int, _ seconds: Int? = nil,
            meters: Double? = nil, level: Double? = nil, unit: WeightUnit = .lb, compact: Bool = false
        ) -> String {
            SetText.result(
                weight: weight, reps: reps, durationSeconds: seconds,
                distanceMeters: meters, level: level, unit: unit, compact: compact
            )
        }
        #expect(text(100, 5) == "100 lb × 5")
        #expect(text(-20, 8) == "20 lb assist × 8")
        #expect(text(0, 0, 90) == "1:30")
        #expect(text(0, 0, 1_200, meters: 4_023.36) == "20:00 · 2.5 mi")
        #expect(text(0, 0, 1_200, level: 8) == "20:00 · level 8")
        #expect(text(50, 0, 60, unit: .kg) == "1:00 · 50 kg")
        #expect(text(100, 5, compact: true) == "100×5")
        #expect(text(-20, 8, compact: true) == "-20×8")
        #expect(text(0, 0, 1_200, meters: 5_000, unit: .kg, compact: true) == "20:00 5km")
        #expect(text(0, 0, 1_200, level: 8, compact: true) == "20:00 L8")
        // A set with reps is a rep set, whatever time it also holds.
        #expect(text(100, 5, 45) == "100 lb × 5")
    }

    // MARK: - Corrections

    @Test("a date correction keeps timed and assisted sets and moves their start")
    func dateCorrectionKeepsTimedSets() throws {
        let ctx = try LoggerFixtures.makeContext()
        let plank = exercise("Plank", tracking: .duration, equipment: .bodyweight, in: ctx)
        let (workout, sets) = try finishedWorkout(of: plank, seconds: [60], in: ctx)
        let started = workout.startedAt.addingTimeInterval(30)
        sets[0].startedAt = started
        try ctx.save()

        try SessionEditService.save(
            WorkoutEdit(startedAt: workout.startedAt.addingTimeInterval(-day)), to: workout, now: now, context: ctx
        )

        #expect(sets[0].durationSeconds == 60)
        #expect(sets[0].startedAt == started.addingTimeInterval(-day))
    }

    @Test("a correction is not refused for a set it leaves alone")
    func untouchedSetIsNotJudged() throws {
        let ctx = try LoggerFixtures.makeContext()
        // A load exercise holding a set no rule accepts now.
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let start = now.addingTimeInterval(-day)
        let workout = try LoggerFixtures.session(
            exercise: bench, startedAt: start, completedAt: start.addingTimeInterval(3_600),
            sets: [(0, 10, true), (100, 5, true)], in: ctx
        )
        let sets = SessionSetActions.ordered(try #require(workout.exercises?.first))

        var edit = WorkoutEdit(startedAt: start)
        edit.changed[sets[1].id] = .init(weight: 105, reps: 5, rpe: nil)
        try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        #expect(sets.map(\.weight) == [0, 105])

        // Changing the odd set itself is held to the rule.
        edit = WorkoutEdit(startedAt: start)
        edit.changed[sets[0].id] = .init(weight: 0, reps: 12, rpe: nil)
        #expect(throws: SessionEditError.invalidSet) {
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        }
        #expect(sets[0].reps == 10)
    }

    @Test("a timed set's time, distance and level are corrected; one without a time is refused")
    func timedSetCorrection() throws {
        let ctx = try LoggerFixtures.makeContext()
        let rower = exercise("Rower", tracking: .durationDistance, equipment: .cardioMachine, in: ctx)
        let (workout, sets) = try finishedWorkout(of: rower, seconds: [1_200], in: ctx)

        var edit = WorkoutEdit(startedAt: workout.startedAt)
        edit.changed[sets[0].id] = .init(weight: 0, reps: 0, rpe: nil, durationSeconds: 1_500, distanceMeters: 6_000)
        edit.added[try #require(workout.exercises?.first).id] = [
            .init(weight: 0, reps: 0, rpe: nil, durationSeconds: 300, distanceMeters: 1_000),
        ]
        try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        let saved = SessionSetActions.ordered(try #require(workout.exercises?.first))
        #expect(saved.map(\.durationSeconds) == [1_500, 300])
        #expect(saved.map(\.distanceMeters) == [6_000, 1_000])
        #expect(saved.allSatisfy { $0.isComplete && $0.isTimed })

        for bad in [
            WorkoutEdit.Values(weight: 0, reps: 0, rpe: nil, durationSeconds: nil),
            .init(weight: 0, reps: 0, rpe: nil, durationSeconds: WorkoutCorrectionInput.durationLimit),
            .init(weight: 0, reps: 0, rpe: nil, durationSeconds: 60, distanceMeters: -1),
        ] {
            edit = WorkoutEdit(startedAt: workout.startedAt)
            edit.changed[sets[0].id] = bad
            #expect(throws: SessionEditError.invalidSet) {
                try SessionEditService.save(edit, to: workout, now: now, context: ctx)
            }
        }
        // A rep set cannot be added to a timed exercise.
        edit = WorkoutEdit(startedAt: workout.startedAt)
        edit.added[try #require(workout.exercises?.first).id] = [.init(weight: 100, reps: 5, rpe: nil)]
        #expect(throws: SessionEditError.invalidSet) {
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        }
        #expect(sets[0].durationSeconds == 1_500)
    }

    @Test("a retagged exercise's old sets are corrected in the shape they were logged in")
    func retaggedSetsKeepTheirShape() throws {
        let ctx = try LoggerFixtures.makeContext()
        // Logged as reps before it was timed, then as a time.
        let plank = exercise("Plank", tracking: .duration, equipment: .bodyweight, in: ctx)
        let start = now.addingTimeInterval(-day)
        let workout = try LoggerFixtures.session(
            exercise: plank, startedAt: start, completedAt: start.addingTimeInterval(1_800),
            sets: [(0, 60, true), (0, 0, true)], in: ctx
        )
        let log = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(log)
        sets[1].durationSeconds = 60
        try ctx.save()

        var draft = WorkoutEditDraft(session: workout)
        #expect(draft.exercises[0].rows.map(\.isTimed) == [false, true])
        #expect(!draft.hasChanges)
        draft.exercises[0].rows[0].values.reps = 45
        // An added row takes the exercise's shape and copies its last timed set.
        draft.addSet(to: log.id)
        let added = try #require(draft.exercises[0].rows.last)
        #expect(added.isTimed && added.values.durationSeconds == 60)
        try SessionEditService.save(draft.edit, to: workout, now: now, context: ctx)

        let saved = SessionSetActions.ordered(log)
        #expect(saved.map(\.reps) == [45, 0, 0])
        #expect(saved.map(\.durationSeconds) == [nil, 60, 60])
    }

    @Test("an assisted row's weight is negative, however an old set stored it")
    func assistedSign() throws {
        let ctx = try LoggerFixtures.makeContext()
        let pullUp = exercise("Assisted Pull-Up", tracking: .assistedReps, equipment: .machine, in: ctx)
        let start = now.addingTimeInterval(-day)
        // Logged with a positive number before the exercise was assisted.
        let workout = try LoggerFixtures.session(
            exercise: pullUp, startedAt: start, completedAt: start.addingTimeInterval(1_800),
            sets: [(50, 8, true)], in: ctx
        )
        let log = try #require(workout.exercises?.first)

        var draft = WorkoutEditDraft(session: workout)
        #expect(draft.exercises[0].rows[0].isAssisted)
        #expect(!draft.hasChanges)
        draft.addSet(to: log.id)
        #expect(draft.exercises[0].rows.last?.values.weight == -50)
        try SessionEditService.save(draft.edit, to: workout, now: now, context: ctx)
        #expect(SessionSetActions.ordered(log).map(\.weight) == [50, -50])

        #expect(WorkoutEditDraft.signed(50, assisted: true) == -50)
        #expect(WorkoutEditDraft.signed(-50, assisted: false) == 50)
        #expect(WorkoutEditDraft.signed(0, assisted: true).sign == .plus)
        // With no rule for rep sets, the stored sign says what the weight is.
        #expect(WorkoutEditDraft.isAssisted(weight: -20, tracking: nil))
        #expect(WorkoutEditDraft.isAssisted(weight: -20, tracking: .duration))
        #expect(!WorkoutEditDraft.isAssisted(weight: -20, tracking: .weightReps))
        #expect(WorkoutEditDraft.isAssisted(weight: 20, tracking: .assistedReps))
    }

    // MARK: - Swap, routines and unplanned adds

    @Test("a swap keeps a completed set's time and clears the replacement's drafts")
    func swapKeepsTimedSet() throws {
        let ctx = try LoggerFixtures.makeContext()
        let plank = exercise("Plank", tracking: .duration, equipment: .bodyweight, in: ctx)
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let workout = try LoggerFixtures.session(
            exercise: plank, startedAt: now, completedAt: nil, sets: [(0, 0, true), (0, 0, false)], in: ctx
        )
        let current = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(current)
        sets[0].durationSeconds = 60
        sets[1].durationSeconds = 45
        try ctx.save()

        #expect(SwapExerciseSheet.swap(current, to: bench, context: ctx))

        #expect(sets[0].durationSeconds == 60)
        #expect(sets[0].sessionExercise?.exercise?.id == plank.id)
        #expect(sets[1].durationSeconds == nil)
        #expect(sets[1].sessionExercise?.exercise?.id == bench.id)
    }

    @Test("a timed exercise defaults to one set with no rep or effort target")
    func routineDefaults() throws {
        let ctx = try LoggerFixtures.makeContext()
        let plank = exercise("Plank", tracking: .duration, equipment: .bodyweight, in: ctx)
        let draft = RoutineExerciseDraft()
        PrescriptionDefaults.apply(to: draft, from: plank)
        #expect(draft.targetSets == 1)
        #expect(draft.targetRepsLow == 0 && draft.targetRepsHigh == 0)
        #expect(draft.targetRPE == nil)
        #expect(draft.prescribedRestSeconds == 180)

        #expect(prescriptionLine(sets: 1, repsLow: 0, repsHigh: 0, rpe: nil, restSeconds: 90, isTimed: true) == "1 set · 1:30 rest")
        #expect(prescriptionLine(sets: 3, repsLow: 8, repsHigh: 12, rpe: 8, restSeconds: 90, isTimed: true) == "3 sets · 1:30 rest")
        #expect(prescriptionLine(sets: 3, repsLow: 8, repsHigh: 12, rpe: 8, restSeconds: 90) == "3 × 8–12 · @8 · 1:30 rest")

        // Added in the middle of a workout, it gets one set too.
        let workout = try LoggerFixtures.session(
            exercise: LoggerFixtures.exercise("Bench", in: ctx), startedAt: now, completedAt: nil,
            sets: [(0, 0, false)], in: ctx
        )
        AddUnplannedExerciseButton.append(exercise: plank, to: workout, context: ctx)
        let added = try #require((workout.exercises ?? []).first { $0.exercise?.id == plank.id })
        #expect(added.targetSets == 1 && added.targetRepsHigh == 0)
        #expect(added.sets?.count == 1)
    }

    @Test("a custom copy of a timed exercise stays timed; a new custom exercise follows its equipment")
    func customCopyKeepsTracking() throws {
        let ctx = try LoggerFixtures.makeContext()
        let copy = CustomExerciseDraft()
        copy.name = "Plank (Copy)"
        copy.equipment = .bodyweight
        copy.tracking = .duration
        #expect(try copy.materialize(into: ctx, allMuscles: []).tracking == .duration)

        let fresh = CustomExerciseDraft()
        fresh.name = "Ring Dip"
        fresh.equipment = .bodyweight
        #expect(try fresh.materialize(into: ctx, allMuscles: []).tracking == .reps)
    }
}
