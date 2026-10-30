//
//  StableExerciseNamesTests.swift
//  fitbodTests
//
//  The deload banner and the session comparison name their exercises
//  steadily. On a tie in RPE creep, the deload advisor's Sig-2 names the
//  exercise whose last matched workout is the newest, then the first by
//  name, whatever order its Dictionary yields the pairs in. A comparison
//  row takes the name its workout logged the exercise under, so deleting
//  or renaming the exercise later never blanks or renames the row.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("StableExerciseNames", .serialized)
struct StableExerciseNamesTests {

    private let today = Date(timeIntervalSince1970: 1_700_000_000)

    /// Fresh stores per deload check. Swift seeds every Dictionary's order
    /// and each store gives the exercises fresh ids, so a pick that follows
    /// Dictionary order changes from store to store; twelve stores would
    /// all agree by chance about once in 4,096 runs.
    private let storeCount = 12

    // MARK: - Deload advisor Sig-2

    @Test("on a tie in RPE creep, the signal names the exercise whose last workout is the newest")
    func creepTieNamesNewestLastWorkout() throws {
        var signals: [DeloadSignal] = []
        for _ in 0..<storeCount {
            let ctx = try LoggerFixtures.makeContext()
            let settings = UserSettings.default()
            ctx.insert(settings)
            let bench = LoggerFixtures.exercise("Bench", in: ctx)
            let squat = LoggerFixtures.exercise("Squat", in: ctx)
            // Each creeps from RPE 7 to 8 at one load over three workouts,
            // a creep of 1.0. The squat's last workout is two days newer.
            try workout(daysAgo: 12, logs: [(bench, [(100, 5, 7)])], in: ctx)
            try workout(daysAgo: 10, logs: [(squat, [(140, 5, 7)])], in: ctx)
            try workout(daysAgo: 8, logs: [(bench, [(100, 5, 7.5)])], in: ctx)
            try workout(daysAgo: 6, logs: [(squat, [(140, 5, 7.5)])], in: ctx)
            try workout(daysAgo: 4, logs: [(bench, [(100, 5, 8)])], in: ctx)
            try workout(daysAgo: 2, logs: [(squat, [(140, 5, 8)])], in: ctx)
            signals += creepSignals(in: ctx, settings: settings)
        }
        let squatCreep = DeloadSignal.rpeCreep(amount: 1.0, exerciseName: "Squat", intent: .strength)
        #expect(signals == Array(repeating: squatCreep, count: storeCount))
    }

    @Test("on a tie in RPE creep and last workout, the signal names the first exercise by name")
    func creepTieOnLastWorkoutNamesFirstByName() throws {
        var signals: [DeloadSignal] = []
        for _ in 0..<storeCount {
            let ctx = try LoggerFixtures.makeContext()
            let settings = UserSettings.default()
            ctx.insert(settings)
            let squat = LoggerFixtures.exercise("Squat", in: ctx)
            let bench = LoggerFixtures.exercise("Bench", in: ctx)
            // The same three workouts log both, each creeping from RPE 7
            // to 8 at one load.
            for (daysAgo, rpe) in [(12, 7.0), (8, 7.5), (4, 8.0)] {
                try workout(
                    daysAgo: daysAgo,
                    logs: [(squat, [(140, 5, rpe)]), (bench, [(100, 5, rpe)])],
                    in: ctx
                )
            }
            signals += creepSignals(in: ctx, settings: settings)
        }
        let benchCreep = DeloadSignal.rpeCreep(amount: 1.0, exerciseName: "Bench", intent: .strength)
        #expect(signals == Array(repeating: benchCreep, count: storeCount))
    }

    // MARK: - Session comparison

    @Test("a deleted custom exercise's comparison row keeps the name it was logged under")
    func comparisonRowKeepsDeletedExerciseName() throws {
        let ctx = try LoggerFixtures.makeContext()
        let press = customExercise("Landmine Press", in: ctx)
        let current = try loggedWorkout(of: press, in: ctx)

        try ExerciseDeletion.delete(press, context: ctx)

        let rows = SessionComparator.compare(current: current, context: ctx)
        #expect(rows.map(\.exerciseName) == ["Landmine Press"])
    }

    @Test("a renamed exercise's comparison row keeps the name it was logged under")
    func comparisonRowKeepsLoggedNameAfterRename() throws {
        let ctx = try LoggerFixtures.makeContext()
        let press = customExercise("Landmine Press", in: ctx)
        let current = try loggedWorkout(of: press, in: ctx)

        press.name = "Kneeling Landmine Press"
        try ctx.save()

        let rows = SessionComparator.compare(current: current, context: ctx)
        #expect(rows.map(\.exerciseName) == ["Landmine Press"])
    }

    // MARK: - Helpers

    /// One logged working set.
    private typealias LoggedSet = (weight: Double, reps: Int, rpe: Double)

    /// A finished strength workout started `daysAgo` days before `today`
    /// that holds one log per entry of `logs`, in that order, every set a
    /// completed working set.
    private func workout(
        daysAgo: Int,
        logs: [(exercise: Exercise, sets: [LoggedSet])],
        in ctx: ModelContext
    ) throws {
        let session = Session()
        ctx.insert(session)
        session.startedAt = today.addingTimeInterval(-Double(daysAgo) * 86_400)
        session.completedAt = session.startedAt.addingTimeInterval(45 * 60)
        session.intentRaw = Intent.strength.rawValue
        for (logIndex, log) in logs.enumerated() {
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            se.exercise = log.exercise
            se.exerciseNameSnapshot = log.exercise.name
            se.orderIndex = logIndex
            for (setIndex, s) in log.sets.enumerated() {
                let entry = SetEntry()
                ctx.insert(entry)
                entry.sessionExercise = se
                entry.orderIndex = setIndex
                entry.weight = s.weight
                entry.reps = s.reps
                entry.rpe = s.rpe
                entry.setTypeRaw = SetType.working.rawValue
                entry.isWarmup = false
                entry.isComplete = true
                entry.completedAt = session.startedAt
            }
        }
        try ctx.save()
    }

    /// The RPE creep signals the deload advisor fires for `ctx` today.
    private func creepSignals(in ctx: ModelContext, settings: UserSettings) -> [DeloadSignal] {
        DeloadAdvisor.signalReport(weekStart: today, in: ctx, settings: settings)
            .firedSignals
            .filter { signal in
                if case .rpeCreep = signal { return true } else { return false }
            }
    }

    private func customExercise(_ name: String, in ctx: ModelContext) -> Exercise {
        let exercise = Exercise(
            name: name,
            canonicalName: name.lowercased(),
            equipmentRaw: "barbell",
            mechanicRaw: "compound",
            isCustom: true
        )
        ctx.insert(exercise)
        return exercise
    }

    /// A finished workout of `exercise`, started from a one-exercise
    /// session template the way the app starts one, with its first working
    /// set logged at 60 x 8.
    private func loggedWorkout(of exercise: Exercise, in ctx: ModelContext) throws -> Session {
        let template = try LoggerFixtures.template("Press Day", exercises: [exercise], in: ctx)
        let session = try SessionFactory.start(template: template, on: today, context: ctx)
        let firstWorkingSet = try #require(
            (session.exercises?.first?.sets ?? [])
                .filter { !$0.isWarmup }
                .min { $0.orderIndex < $1.orderIndex }
        )
        firstWorkingSet.weight = 60
        firstWorkingSet.reps = 8
        firstWorkingSet.isComplete = true
        session.completedAt = today.addingTimeInterval(45 * 60)
        try ctx.save()
        return session
    }
}
