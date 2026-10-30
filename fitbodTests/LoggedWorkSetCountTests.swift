//
//  LoggedWorkSetCountTests.swift
//  fitbodTests
//
//  Ticket T02. Review items 2, 25 and 40; decisions 5 and 6.
//
//  The shared answers later tickets wire into the screens:
//    - `Session.loggedSetCount`: completed sets that are not warm-ups, so
//      skipped warm-ups never count.
//    - `SessionSetActions.isEmptyWorkout`: a finished workout with no
//      logged work sets. A workout still in progress is never empty.
//    - `BRUCountLabel.text`: "1 set", "2 sets", "1 SET LOGGED".
//  Plus the proof that muscle volume, PR detection and progression give
//  the same results when a workout's warm-ups were skipped.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

// MARK: - Workout shapes

/// One set in a test workout: a warm-up or a work set, done or not.
struct LoggedSetShape: Sendable {
    let isWarmup: Bool
    let isComplete: Bool

    static let warmup = LoggedSetShape(isWarmup: true, isComplete: false)
    /// SKIP WARM-UPS marks a warm-up complete without logging it.
    static let skippedWarmup = LoggedSetShape(isWarmup: true, isComplete: true)
    static let plannedWorkSet = LoggedSetShape(isWarmup: false, isComplete: false)
    static let loggedWorkSet = LoggedSetShape(isWarmup: false, isComplete: true)
}

/// A workout's sets, one array per exercise, with the expected answers.
struct WorkoutShape: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let exercises: [[LoggedSetShape]]
    let loggedWorkSets: Int
    let isEmptyWhenFinished: Bool

    static let all: [WorkoutShape] = [
        WorkoutShape(
            testDescription: "warm-ups only",
            exercises: [[.warmup, .warmup, .warmup, .warmup]],
            loggedWorkSets: 0,
            isEmptyWhenFinished: true
        ),
        WorkoutShape(
            testDescription: "four skipped warm-ups and no work sets",
            exercises: [[.skippedWarmup, .skippedWarmup, .skippedWarmup, .skippedWarmup]],
            loggedWorkSets: 0,
            isEmptyWhenFinished: true
        ),
        WorkoutShape(
            testDescription: "skipped warm-ups and unlogged work sets",
            exercises: [[.skippedWarmup, .skippedWarmup, .plannedWorkSet, .plannedWorkSet]],
            loggedWorkSets: 0,
            isEmptyWhenFinished: true
        ),
        WorkoutShape(
            testDescription: "warm-ups and work sets in two exercises",
            exercises: [
                [.skippedWarmup, .skippedWarmup, .loggedWorkSet, .loggedWorkSet, .plannedWorkSet],
                [.warmup, .loggedWorkSet],
            ],
            loggedWorkSets: 3,
            isEmptyWhenFinished: false
        ),
        WorkoutShape(
            testDescription: "an exercise with no sets",
            exercises: [[]],
            loggedWorkSets: 0,
            isEmptyWhenFinished: true
        ),
        WorkoutShape(
            testDescription: "no exercises",
            exercises: [],
            loggedWorkSets: 0,
            isEmptyWhenFinished: true
        ),
    ]
}

// MARK: - Skipped warm-ups fixture

/// A finished bench workout logged the way the app logs one, so the
/// training math reads the same rows it reads on a phone. Last week's
/// 3 x 8 at 100 kg makes `SessionFactory.start` prescribe 102.5 kg with
/// its four-set warm-up ramp (5, 3, 2 and 1 reps). Every work set is
/// logged at 102.5 x 8, and `skipWarmups` marks the ramp complete the way
/// SKIP WARM-UPS does.
///
/// Counted warm-ups would change every answer: they add four chest sets,
/// they open records in the 1-6 rep bucket that the 8-rep work sets never
/// reach, and their 5, 3, 2 and 1 reps would stop the double-progression
/// bump.
@MainActor
struct SkippedWarmupWorkout {
    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static let day: TimeInterval = 86_400

    let ctx: ModelContext
    let template: SessionTemplate
    let bench: Exercise
    let workout: Session

    init(skipWarmups: Bool) throws {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())

        // kg plates, so 102.5 kg and 105 kg are loadable.
        let inventory = PlateInventory()
        ctx.insert(inventory)
        inventory.equipmentKind = .barbell
        inventory.barWeight = 20
        inventory.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)

        let chest = MuscleGroup(slug: "chest", displayName: "Chest")
        ctx.insert(chest)
        let bench = LoggerFixtures.exercise("Bench Press", in: ctx)
        bench.smallestIncrement = 2.5
        let stimulus = ExerciseMuscleStimulus()
        ctx.insert(stimulus)
        stimulus.exercise = bench
        stimulus.muscle = chest
        stimulus.role = "primary"
        stimulus.weight = 1

        let template = try LoggerFixtures.template(
            "Push A", exercises: [bench], sets: 3, repsLow: 8, repsHigh: 8, in: ctx
        )
        try LoggerFixtures.session(
            exercise: bench,
            startedAt: Self.start - 7 * Self.day,
            completedAt: Self.start - 7 * Self.day + 3_600,
            sets: Array(repeating: (weight: 100, reps: 8, complete: true), count: 3),
            in: ctx
        )

        let workout = try SessionFactory.start(template: template, on: Self.start, context: ctx)
        let sets = (workout.exercises ?? []).flatMap { $0.sets ?? [] }
        let prescribed = workout.exercises?.first?.prescribedWeight ?? 0
        for set in sets where !set.isWarmup {
            set.weight = prescribed
            set.reps = 8
            SessionSetActions.complete(set, at: Self.start + Double(set.orderIndex) * 180, context: ctx)
        }
        if skipWarmups {
            for warmup in sets where warmup.isWarmup {
                warmup.isComplete = true
            }
        }
        workout.completedAt = Self.start + 3_600
        try ctx.save()

        self.ctx = ctx
        self.template = template
        self.bench = bench
        self.workout = workout
    }

    var warmups: [SetEntry] {
        (workout.exercises ?? []).flatMap { $0.sets ?? [] }.filter(\.isWarmup)
    }

    /// PR kinds per exercise on the finish summary.
    var summaryPRKinds: [[PRKind]] {
        SessionSummary.make(session: workout, context: ctx).exercises.map(\.prKinds)
    }

    /// Every record a resumed workout seeds, as "kind bucket weight x reps".
    func seededPRRecords() async -> [String] {
        let table = await SessionFactory.seedPRTable(for: workout, context: ctx)
        return PRKind.allCases.flatMap { kind in
            RepBucket.allCases.compactMap { bucket in
                table.record(exerciseID: bench.id, intent: .strength, kind: kind, bucket: bucket)
                    .map { "\(kind.rawValue) \(bucket.rawValue) \($0.weight) x \($0.reps)" }
            }
        }
    }

    /// The weight the next workout from the same template prescribes.
    func nextPrescribedWeight() throws -> Double? {
        let next = try SessionFactory.start(template: template, on: Self.start + 2 * Self.day, context: ctx)
        return next.exercises?.first?.prescribedWeight
    }
}

// MARK: - Tests

@MainActor
@Suite("LoggedWorkSetCount")
struct LoggedWorkSetCountTests {

    /// Held by the suite so the models stay attached for the whole test.
    private let ctx: ModelContext

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
    }

    private func makeWorkout(_ shape: WorkoutShape, finished: Bool) throws -> Session {
        let session = Session()
        ctx.insert(session)
        for (exerciseIndex, sets) in shape.exercises.enumerated() {
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            se.orderIndex = exerciseIndex
            for (index, kind) in sets.enumerated() {
                let set = SetEntry()
                ctx.insert(set)
                set.orderIndex = index
                set.isWarmup = kind.isWarmup
                set.setTypeRaw = kind.isWarmup ? SetType.warmup.rawValue : SetType.working.rawValue
                set.isComplete = kind.isComplete
                set.weight = 60
                set.reps = 5
                set.sessionExercise = se
            }
        }
        session.completedAt = finished ? session.startedAt.addingTimeInterval(3_600) : nil
        try ctx.save()
        return session
    }

    // MARK: Logged work sets and empty workouts

    @Test("A finished workout is empty only when it has no logged work sets", arguments: WorkoutShape.all)
    func finishedWorkout(shape: WorkoutShape) throws {
        let session = try makeWorkout(shape, finished: true)
        #expect(session.loggedSetCount == shape.loggedWorkSets)
        #expect(SessionSetActions.isEmptyWorkout(session) == shape.isEmptyWhenFinished)
    }

    @Test("A workout still in progress is never empty", arguments: WorkoutShape.all)
    func unfinishedWorkout(shape: WorkoutShape) throws {
        let session = try makeWorkout(shape, finished: false)
        #expect(session.loggedSetCount == shape.loggedWorkSets)
        #expect(!SessionSetActions.isEmptyWorkout(session))
    }

    // MARK: Count labels

    @Test("Lowercase count labels are singular only for one", arguments: [
        (0, "0 sets"), (1, "1 set"), (2, "2 sets"),
    ])
    func lowercaseCountLabel(count: Int, label: String) {
        #expect(BRUCountLabel.text(count, "set") == label)
    }

    @Test("Uppercase count labels keep an uppercase plural", arguments: [
        (0, "0 SETS LOGGED"), (1, "1 SET LOGGED"), (2, "2 SETS LOGGED"),
    ])
    func uppercaseCountLabel(count: Int, label: String) {
        #expect("\(BRUCountLabel.text(count, "SET")) LOGGED" == label)
    }

    @Test("A noun with an irregular plural takes the plural it is given")
    func irregularPlural() {
        #expect(BRUCountLabel.text(1, "match", plural: "matches") == "1 match")
        #expect(BRUCountLabel.text(3, "match", plural: "matches") == "3 matches")
        #expect(BRUCountLabel.text(2, "PR", plural: "PRs") == "2 PRs")
    }

    // MARK: Training math ignores warm-ups

    @Test("Muscle volume is the same when the warm-ups were skipped")
    func muscleVolumeIgnoresSkippedWarmups() throws {
        let plain = try SkippedWarmupWorkout(skipWarmups: false)
        let skipped = try SkippedWarmupWorkout(skipWarmups: true)
        try #require(skipped.warmups.count == 4 && skipped.warmups.allSatisfy(\.isComplete))

        let weekStart = SkippedWarmupWorkout.start - SkippedWarmupWorkout.day
        let plainVolume = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: weekStart, in: plain.ctx)
        let skippedVolume = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: weekStart, in: skipped.ctx)
        #expect(skippedVolume == plainVolume)
        #expect(skippedVolume == WeightedSetTotal(directSets: 3, indirectSets: 0))
    }

    @Test("PR detection is the same when the warm-ups were skipped")
    func prDetectionIgnoresSkippedWarmups() async throws {
        let plain = try SkippedWarmupWorkout(skipWarmups: false)
        let skipped = try SkippedWarmupWorkout(skipWarmups: true)
        try #require(skipped.warmups.count == 4 && skipped.warmups.allSatisfy(\.isComplete))

        // Finish summary: 102.5 x 8 beats last week's 100 x 8 on weight,
        // volume and e1RM, and ties it on reps.
        #expect(skipped.summaryPRKinds == plain.summaryPRKinds)
        #expect(skipped.summaryPRKinds == [[.weight, .volume, .e1RM]])

        // A resumed workout's table holds only 7-10 rep records.
        let plainRecords = await plain.seededPRRecords()
        let skippedRecords = await skipped.seededPRRecords()
        #expect(skippedRecords == plainRecords)
        #expect(skippedRecords == [
            "weight 7-10 102.5 x 8",
            "reps 7-10 100.0 x 8",
            "volume 7-10 102.5 x 8",
            "e1rm 7-10 102.5 x 8",
        ])

        // The detector never takes a warm-up, even as the first set ever logged.
        var empty = PRTable()
        for warmup in skipped.warmups {
            #expect(PRDetector.check(set: warmup, against: &empty).isEmpty)
        }
        #expect(empty.recordedSlotCount == 0)
    }

    @Test("Progression is the same when the warm-ups were skipped")
    func progressionIgnoresSkippedWarmups() throws {
        let plain = try SkippedWarmupWorkout(skipWarmups: false)
        let skipped = try SkippedWarmupWorkout(skipWarmups: true)
        try #require(skipped.warmups.count == 4 && skipped.warmups.allSatisfy(\.isComplete))

        // Every work set reached the top of 8 reps, so double progression
        // adds 2.5 kg.
        let plainNext = try plain.nextPrescribedWeight()
        let skippedNext = try skipped.nextPrescribedWeight()
        #expect(skippedNext == plainNext)
        #expect(skippedNext == 105)
    }
}
