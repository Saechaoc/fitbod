//
//  SessionSetActionsTests.swift
//  fitbodTests
//
//  Set complete / un-complete / delete / add, each checked after a save
//  by re-reading through a second ModelContext on the same container, so
//  "persisted" means persisted, not just mutated in memory.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionSetActions", .serialized)
struct SessionSetActionsTests {

    private func freshRead(_ ctx: ModelContext, _ id: UUID) throws -> SessionExercise? {
        let reader = ModelContext(ctx.container)
        let targetID = id
        return try reader.fetch(FetchDescriptor<SessionExercise>(predicate: #Predicate { $0.id == targetID })).first
    }

    private func makeSession(_ ctx: ModelContext) throws -> SessionExercise {
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        let session = try LoggerFixtures.session(
            exercise: ex,
            startedAt: .now,
            completedAt: nil,
            sets: [(100, 5, false), (100, 5, false), (100, 5, false)],
            in: ctx
        )
        return try #require(session.exercises?.first)
    }

    @Test("complete persists; guard rejects empty sets")
    func completePersists() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let sets = SessionSetActions.ordered(se)

        #expect(SessionSetActions.complete(sets[0], context: ctx))
        sets[1].reps = 0
        #expect(!SessionSetActions.complete(sets[1], context: ctx))

        let reread = try #require(try freshRead(ctx, se.id))
        let done = (reread.sets ?? []).filter(\.isComplete)
        #expect(done.count == 1)
        #expect(done.first?.id == sets[0].id)
    }

    @Test("uncomplete persists and keeps weight and reps")
    func uncompletePersists() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let set = SessionSetActions.ordered(se)[0]
        SessionSetActions.complete(set, context: ctx)
        SessionSetActions.uncomplete(set, context: ctx)

        let reread = try #require(try freshRead(ctx, se.id))
        let row = try #require(reread.sets?.first { $0.id == set.id })
        #expect(row.isComplete == false)
        #expect(row.weight == 100)
        #expect(row.reps == 5)
    }

    @Test("uncomplete does not touch a running rest timer")
    func uncompleteLeavesRestTimer() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let engine = RestTimerEngine(scheduler: NoopScheduler(), now: { Date(timeIntervalSince1970: 0) })
        let set = SessionSetActions.ordered(se)[0]
        SessionSetActions.complete(set, context: ctx)
        engine.start(seconds: 120, exerciseName: "Bench")
        let startedAt = engine.startedAt

        SessionSetActions.uncomplete(set, context: ctx)
        #expect(engine.isRunning)
        #expect(engine.startedAt == startedAt)
        #expect(engine.targetSeconds == 120)
    }

    @Test("delete removes the set and renumbers the rest contiguously")
    func deleteRenumbers() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let warmup = SetEntry()
        ctx.insert(warmup)
        warmup.sessionExercise = se
        warmup.isWarmup = true
        warmup.orderIndex = 3
        try ctx.save()

        let before = SessionSetActions.ordered(se)
        #expect(before.first?.isWarmup == true)
        let middleWorking = before[2]
        SessionSetActions.delete(middleWorking, context: ctx)

        let reread = try #require(try freshRead(ctx, se.id))
        let after = SessionSetActions.ordered(reread)
        #expect(after.count == 3)
        #expect(!after.contains { $0.id == middleWorking.id })
        #expect(after.map(\.orderIndex) == [0, 1, 2])
        // Working sets number S1, S2 regardless of the warm-up ahead of them.
        let working = after.filter { !$0.isWarmup }
        #expect(working.map { SessionSetActions.displayNumber(of: $0) } == [1, 2])
        #expect(SessionSetActions.displayNumber(of: after[0]) == 1)
    }

    @Test("addSet appends at the end seeded from the last working weight")
    func addSetAppends() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        SessionSetActions.ordered(se)[2].weight = 102.5
        let added = SessionSetActions.addSet(to: se, context: ctx)

        #expect(added.orderIndex == 3)
        #expect(added.weight == 102.5)
        #expect(added.isComplete == false)
        let reread = try #require(try freshRead(ctx, se.id))
        #expect((reread.sets ?? []).count == 4)
    }

    @Test("dropIntensity lightens only pending working sets, rounded to the increment")
    func dropIntensityPendingOnly() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let sets = SessionSetActions.ordered(se)
        SessionSetActions.complete(sets[0], context: ctx)
        sets[2].weight = 97.5
        SessionSetActions.dropIntensity(of: se, fraction: 0.10, increment: 2.5, context: ctx)

        #expect(sets[0].weight == 100)
        // 100 × 0.9 = 90, already on a 2.5 step.
        #expect(sets[1].weight == 90)
        // 97.5 × 0.9 = 87.75, rounded down to 87.5.
        #expect(sets[2].weight == 87.5)
    }

    private final class NoopScheduler: RestTimerNotificationScheduling {
        func schedule(in seconds: Int, exerciseName: String, identifier: String) {}
        func cancel(identifier: String) {}
    }
}
