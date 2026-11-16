import Foundation
import SwiftData
import Testing
@testable import fitbod

/// RM-022 slice 8: a first-time variant's starting weight, estimated from a
/// family sibling with the same equipment and loading.
@MainActor
@Suite("Sibling estimate")
struct SiblingEstimateTests {
    @Test("A first-time variant takes the top set of the newest matching workout of a sibling with its family, equipment and loading")
    func choosesTheNewestMatchingSibling() async throws {
        let ctx = try LoggerFixtures.makeContext()
        let paused = lift("Bench Press (Paused)", family: "Bench Press", in: ctx)
        let flat = lift("Bench Press (Barbell)", family: "Bench Press", in: ctx)
        try workout(flat, daysAgo: 10, sets: [100], in: ctx)
        try workout(lift("Bench Press (Incline Barbell)", family: "Bench Press", in: ctx), daysAgo: 3, sets: [85, 90], in: ctx)
        // Newer, but not comparable: other equipment, other loading, another
        // family, another intent, and a workout never finished.
        try workout(lift("Bench Press (Dumbbell)", family: "Bench Press", equipment: .dumbbell, in: ctx), daysAgo: 1, sets: [60], in: ctx)
        let plateLoaded = lift("Bench Press (Plate-Loaded)", family: "Bench Press", in: ctx)
        plateLoaded.loadingRaw = "plate"
        try workout(plateLoaded, daysAgo: 1, sets: [200], in: ctx)
        try workout(lift("Row (Barbell)", family: "Row", in: ctx), daysAgo: 1, sets: [150], in: ctx)
        try workout(flat, daysAgo: 1, sets: [130], intent: .hypertrophy, in: ctx)
        try workout(flat, daysAgo: 0.5, sets: [140], finished: false, in: ctx)

        let log = try today(with: paused, in: ctx)
        let expected = SiblingEstimate(weight: 90, siblingName: "Bench Press (Incline Barbell)")
        #expect(try estimate(for: log, in: ctx) == expected)
        // The card's read, in a context of its own off the main actor.
        let session = try #require(log.session)
        #expect(await SiblingEstimate.find(
            exerciseID: paused.id, intentRaw: session.intentRaw, excludingSessionID: session.id, in: ctx.container
        ) == expected)
    }

    @Test("Two siblings in one workout give the lighter top set")
    func sameWorkoutTakesTheLighterSibling() throws {
        let ctx = try LoggerFixtures.makeContext()
        let paused = lift("Bench Press (Paused)", family: "Bench Press", in: ctx)
        let session = try workout(lift("Bench Press (Barbell)", family: "Bench Press", in: ctx), daysAgo: 2, sets: [100], in: ctx)
        let closeGrip = lift("Bench Press (Close-Grip)", family: "Bench Press", in: ctx)
        let second = SessionExercise()
        ctx.insert(second)
        second.session = session
        second.exercise = closeGrip
        second.orderIndex = 1
        let set = SetEntry()
        ctx.insert(set)
        set.sessionExercise = second
        set.weight = 95
        set.reps = 5
        set.isComplete = true
        try ctx.save()

        let log = try today(with: paused, in: ctx)
        #expect(try estimate(for: log, in: ctx) == SiblingEstimate(weight: 95, siblingName: "Bench Press (Close-Grip)"))
    }

    @Test("With no comparable sibling the variant keeps today's prompt, and an estimate takes its place")
    func noSiblingKeepsThePrompt() throws {
        let ctx = try LoggerFixtures.makeContext()
        let paused = lift("Bench Press (Paused)", family: "Bench Press", in: ctx)
        let template = try LoggerFixtures.template("Push", exercises: [paused], in: ctx)
        let session = try SessionFactory.start(template: template, context: ctx)
        let log = try #require(session.exercises?.first)
        #expect(try estimate(for: log, in: ctx) == nil)
        #expect(guidance(log, estimate: nil) == "Target 5–8 reps · Choose a starting weight")

        // A sibling whose weights are another unit's numbers is no estimate.
        let kilos = lift("Bench Press (Barbell, kg)", family: "Bench Press", in: ctx)
        kilos.unitOverride = .kg
        try workout(kilos, daysAgo: 7, sets: [80], in: ctx)
        #expect(try estimate(for: log, in: ctx) == nil)

        try workout(lift("Bench Press (Barbell)", family: "Bench Press", in: ctx), daysAgo: 7, sets: [100], in: ctx)
        let found = try #require(try estimate(for: log, in: ctx))
        #expect(guidance(log, estimate: found) == "Target 5–8 reps · Estimated 100 lb from Bench Press (Barbell)")
    }

    @Test("A machine variant, or a variant with a workout of its own, gets no estimate")
    func noEstimateWhereLoadsDoNotCarry() throws {
        let ctx = try LoggerFixtures.makeContext()
        // Loads compare only within one machine (RM-066).
        let chest = lift("Chest Press (Machine)", family: "Chest Press", equipment: .machine, in: ctx)
        try workout(lift("Chest Press (Incline Machine)", family: "Chest Press", equipment: .machine, in: ctx), daysAgo: 2, sets: [120], in: ctx)
        let chestLog = try today(with: chest, in: ctx)
        #expect(try estimate(for: chestLog, in: ctx) == nil)

        let paused = lift("Bench Press (Paused)", family: "Bench Press", in: ctx)
        try workout(lift("Bench Press (Barbell)", family: "Bench Press", in: ctx), daysAgo: 1, sets: [100], in: ctx)
        try workout(paused, daysAgo: 5, sets: [80], in: ctx)
        let pausedLog = try today(with: paused, in: ctx)
        #expect(try estimate(for: pausedLog, in: ctx) == nil)
    }

    @Test("The estimate names its weight, its unit and the sibling")
    func label() {
        #expect(SiblingEstimate(weight: 110, siblingName: "Bench Press (Barbell)").label(unit: .lb)
            == "Estimated 110 lb from Bench Press (Barbell)")
        #expect(SiblingEstimate(weight: 52.5, siblingName: "Row (Dumbbell)").label(unit: .kg)
            == "Estimated 52.5 kg from Row (Dumbbell)")
    }

    @Test("An accepted estimate logs as an ordinary set, and only then is the variant's own history")
    func acceptedEstimateIsAnOrdinarySet() throws {
        let ctx = try LoggerFixtures.makeContext()
        let paused = lift("Bench Press (Paused)", family: "Bench Press", in: ctx)
        try workout(lift("Bench Press (Barbell)", family: "Bench Press", in: ctx), daysAgo: 7, sets: [100], in: ctx)
        let template = try LoggerFixtures.template("Push", exercises: [paused], in: ctx)
        let session = try SessionFactory.start(template: template, context: ctx)
        let log = try #require(session.exercises?.first)
        let found = try #require(try estimate(for: log, in: ctx))
        let sets = SessionSetActions.ordered(log)
        func offers() -> [UUID: WorkoutSetSuggestion] {
            WorkoutSetSuggestions(exercise: log, prior: [], estimatedWeight: found.weight).offers()
        }

        // Shown, never stored: no prescribed weight, no Last time, no set value.
        #expect(log.prescribedWeight == 0)
        #expect(PreviousMatchingIntent.fetchTopWorkingSet(exerciseID: paused.id, intentRaw: session.intentRaw, context: ctx) == nil)
        #expect(!SiblingEstimate.liftDone(in: log))
        let offer = try #require(offers()[sets[0].id])
        #expect(offer == WorkoutSetSuggestion(weight: 100, reps: 5))
        #expect(sets[0].weight == 0)

        #expect(try SessionSetActions.complete(sets[0], suggestion: offer, context: ctx))
        #expect(sets[0].weight == 100 && sets[0].reps == 5 && !sets[0].wasManualOverride)
        // Done once, the lift has a load of its own, here and in another log of it.
        #expect(SiblingEstimate.liftDone(in: log))
        AddUnplannedExerciseButton.append(exercise: paused, to: session, context: ctx)
        let again = try #require(session.exercises?.first { $0.orderIndex == 1 })
        #expect(SiblingEstimate.liftDone(in: again))
        // A set done at another weight beats the estimate for the sets after it.
        sets[1].weight = 95
        sets[1].reps = 6
        #expect(try SessionSetActions.complete(sets[1], context: ctx))
        #expect(offers()[sets[2].id] == WorkoutSetSuggestion(weight: 95, reps: 6))

        session.completedAt = .now
        try ctx.save()
        let lastTime = try #require(
            PreviousMatchingIntent.fetchTopWorkingSet(exerciseID: paused.id, intentRaw: session.intentRaw, context: ctx)
        )
        #expect(lastTime.weight == 100 && lastTime.reps == 5)
        let nextWorkout = try SessionFactory.start(template: template, context: ctx)
        let next = try #require(nextWorkout.exercises?.first)
        #expect(next.prescribedWeight == 100)
        #expect(try estimate(for: next, in: ctx) == nil)
    }

    // MARK: - Helpers

    private func lift(
        _ name: String, family: String?, equipment: Equipment = .barbell, in ctx: ModelContext
    ) -> Exercise {
        let exercise = Exercise.previewSample(name: name, equipment: equipment, mechanic: .compound)
        ctx.insert(exercise)
        exercise.familyName = family
        return exercise
    }

    /// A workout of `exercise` alone, `daysAgo` days back, with one logged
    /// working set per weight in `sets`.
    @discardableResult
    private func workout(
        _ exercise: Exercise, daysAgo: Double, sets: [Double], intent: Intent = .strength,
        finished: Bool = true, in ctx: ModelContext
    ) throws -> Session {
        let start = Date.now - daysAgo * 86_400
        let session = try LoggerFixtures.session(
            exercise: exercise, startedAt: start, completedAt: finished ? start + 3_600 : nil,
            sets: sets.map { ($0, 5, true) }, in: ctx
        )
        session.intentRaw = intent.rawValue
        try ctx.save()
        return session
    }

    /// `exercise` added to an empty strength workout in progress, as the
    /// logger's + ADD EXERCISE does.
    private func today(with exercise: Exercise, in ctx: ModelContext) throws -> SessionExercise {
        let session = Session()
        ctx.insert(session)
        session.intentRaw = Intent.strength.rawValue
        try ctx.save()
        AddUnplannedExerciseButton.append(exercise: exercise, to: session, context: ctx)
        return try #require(session.exercises?.first)
    }

    /// The estimate for `log`'s lift in its workout.
    private func estimate(for log: SessionExercise, in ctx: ModelContext) throws -> SiblingEstimate? {
        let exerciseID = try #require(log.exercise?.id)
        let session = try #require(log.session)
        return SiblingEstimate.find(
            exerciseID: exerciseID, intentRaw: session.intentRaw, excludingSessionID: session.id, context: ctx
        )
    }

    private func guidance(_ log: SessionExercise, estimate: SiblingEstimate?) -> String {
        WorkoutWeightGuidance(
            exercise: log, explanation: nil, unit: .lb, loggedWeight: nil,
            hasSetOffer: estimate != nil, estimate: estimate
        ).guidanceText(suggestion: nil)
    }
}
