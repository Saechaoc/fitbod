//
//  EmptyWorkoutCountTests.swift
//  fitbodTests
//
//  Ticket T22. Review items 39 and 40; decision 6.
//
//  `SessionSetActions.countedWorkouts` is the count rule every session
//  count and Compare share: the finished workouts that are not empty, in
//  the order given. Compare's prior workout follows it too, so an empty
//  or unfinished workout is passed over for the logged one before it.
//  `SessionSetActions.emptyWorkoutIDs` applies the rule to a whole history
//  for the all-time counts to cache, and an updated cache agrees with a
//  full read.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("EmptyWorkoutCount")
struct EmptyWorkoutCountTests {

    /// Held by the suite so the models stay attached for the whole test.
    private let ctx: ModelContext
    private let bench: Exercise
    private let routineID = UUID()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let day: TimeInterval = 24 * 3600

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
        bench = Exercise(
            name: "Bench Press",
            canonicalName: "bench press",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(bench)
    }

    /// A strength workout of one routine's bench press, started `daysAgo`
    /// days before `now`: a done warm-up, then one work set of `weight` x 5
    /// that is logged or not.
    @discardableResult
    private func workout(
        daysAgo: Double,
        weight: Double = 100,
        logged: Bool,
        finished: Bool = true
    ) throws -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = now.addingTimeInterval(-daysAgo * day)
        session.completedAt = finished ? session.startedAt.addingTimeInterval(3_600) : nil
        session.sourceRoutineID = routineID
        session.intentRaw = Intent.strength.rawValue

        let se = SessionExercise()
        ctx.insert(se)
        se.session = session
        se.exercise = bench
        se.orderIndex = 0
        for (index, isWarmup) in [true, false].enumerated() {
            let set = SetEntry()
            ctx.insert(set)
            set.sessionExercise = se
            set.orderIndex = index
            set.isWarmup = isWarmup
            set.setTypeRaw = isWarmup ? SetType.warmup.rawValue : SetType.working.rawValue
            set.weight = isWarmup ? 60 : weight
            set.reps = 5
            set.isComplete = isWarmup || logged
            set.completedAt = session.startedAt.addingTimeInterval(Double(index) * 180)
        }
        try ctx.save()
        return session
    }

    /// Every finished workout, newest first, as the screens query them.
    private func finishedWorkouts() throws -> [Session] {
        try ctx.fetch(FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        ))
    }

    // MARK: Count rule

    @Test("Only finished workouts with logged work sets count, in the order given")
    func countRule() throws {
        let inProgress = try workout(daysAgo: 0, logged: true, finished: false)
        let newest = try workout(daysAgo: 1, logged: true)
        let empty = try workout(daysAgo: 2, logged: false)
        let inProgressEmpty = try workout(daysAgo: 3, logged: false, finished: false)
        let oldest = try workout(daysAgo: 4, logged: true)

        let counted = SessionSetActions.countedWorkouts([inProgress, newest, empty, inProgressEmpty, oldest])
        #expect(Array(counted).map(\.id) == [newest.id, oldest.id])
        #expect(SessionSetActions.countedWorkouts([empty, inProgressEmpty, inProgress]).isEmpty)
    }

    @Test("The batched read finds exactly the finished workouts with no logged work sets")
    func emptyWorkoutIDs() throws {
        try workout(daysAgo: 0, logged: false, finished: false)
        try workout(daysAgo: 1, logged: true)
        let empty = try workout(daysAgo: 2, logged: false)
        let olderEmpty = try workout(daysAgo: 3, logged: false)
        try workout(daysAgo: 4, logged: true)

        let ids = SessionSetActions.emptyWorkoutIDs(among: try finishedWorkouts(), known: nil, in: ctx)
        #expect(ids == [empty.persistentModelID, olderEmpty.persistentModelID])
    }

    @Test(
        "Cached answers plus one newly finished workout give the same counts as a full read",
        arguments: [true, false]
    )
    func cachedAnswersPlusOneNewWorkout(newWorkoutLogged: Bool) throws {
        try workout(daysAgo: 4, logged: true)
        try workout(daysAgo: 3, logged: false)
        try workout(daysAgo: 2, logged: true)
        let before = try finishedWorkouts()
        let cached = SessionSetActions.emptyWorkoutIDs(among: before, known: nil, in: ctx)

        try workout(daysAgo: 1, logged: newWorkoutLogged)
        let after = try finishedWorkouts()
        let updated = SessionSetActions.emptyWorkoutIDs(
            among: after,
            known: (finished: before.map(\.persistentModelID), empty: cached),
            in: ctx
        )
        let fullRead = SessionSetActions.emptyWorkoutIDs(among: after, known: nil, in: ctx)

        #expect(updated == fullRead)
        #expect(after.count - updated.count == after.count - fullRead.count)
        #expect(after.count - updated.count == (newWorkoutLogged ? 3 : 2))
    }

    // MARK: Compare

    @Test("Compare's prior passes over an empty workout for the logged one before it")
    func comparePassesOverEmptyWorkout() throws {
        try workout(daysAgo: 6, weight: 100, logged: true)
        try workout(daysAgo: 3, logged: false)
        let current = try workout(daysAgo: 1, weight: 105, logged: true)

        let row = try #require(SessionComparator.compare(current: current, context: ctx).first)
        let prior = try #require(row.lastWeekTopSet)
        #expect(prior.weight == 100)
        #expect(prior.sessionStartedAt == now.addingTimeInterval(-6 * day))
        #expect(row.deltaWeight == 5)
    }

    @Test("Compare's prior passes over a workout still in progress")
    func comparePassesOverUnfinishedWorkout() throws {
        try workout(daysAgo: 6, weight: 100, logged: true)
        try workout(daysAgo: 3, weight: 110, logged: true, finished: false)
        let current = try workout(daysAgo: 1, weight: 105, logged: true)

        let row = try #require(SessionComparator.compare(current: current, context: ctx).first)
        #expect(row.lastWeekTopSet?.weight == 100)
    }
}
