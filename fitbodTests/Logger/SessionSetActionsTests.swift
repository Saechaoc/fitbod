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

        #expect(try SessionSetActions.complete(sets[0], context: ctx))
        sets[1].reps = 0
        #expect(try !SessionSetActions.complete(sets[1], context: ctx))

        let reread = try #require(try freshRead(ctx, se.id))
        let done = (reread.sets ?? []).filter(\.isComplete)
        #expect(done.count == 1)
        #expect(done.first?.id == sets[0].id)
    }

    @Test("A failed save restores the draft and lets the same offer be retried")
    func failedCompletionRestoresDraft() throws {
        enum SaveFailure: Error, Equatable { case disk }
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let set = SessionSetActions.ordered(se)[0]
        set.reps = 0
        try ctx.save()
        let draftDate = set.completedAt
        let offer = WorkoutSetSuggestion(weight: 105, reps: 8)

        #expect(throws: SaveFailure.disk) {
            try SessionSetActions.complete(set, suggestion: offer, context: ctx, save: { _ in
                throw SaveFailure.disk
            })
        }
        #expect(!set.isComplete && set.completedAt == draftDate)
        #expect(set.weight == 100 && set.reps == 0)
        #expect(try SessionSetActions.complete(set, suggestion: offer, context: ctx))
        #expect(set.isComplete && set.weight == 100 && set.reps == 8)
    }

    @Test("A discard whose save fails keeps the workout and its sets, with nothing left for a later save")
    func failedDiscardKeepsWorkout() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbod-discard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("discard.store")

        let workoutID = try autoreleasepool {
            let ctx = ModelContext(try FitbodModelContainer.make(storeURL: url))
            return try LoggerFixtures.session(
                exercise: LoggerFixtures.exercise("Bench", in: ctx), startedAt: .now, completedAt: nil,
                sets: [(100, 5, true), (100, 5, false)], in: ctx
            ).id
        }

        // The same store opened so that every save fails, as a full disk would.
        let schema = Schema(versionedSchema: FitbodModelContainer.CurrentSchema.self)
        let ctx = ModelContext(try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false)
        ))
        let workout = try #require(try ctx.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == workoutID })).first)

        #expect(throws: (any Error).self) { try SessionSetActions.deleteWorkout(workout, context: ctx) }
        #expect(!ctx.hasChanges, "Nothing may stay pending for a later save to write")
        #expect(!workout.isDeleted)
        #expect(workout.loggedSetCount == 1)
        #expect(try ctx.fetchCount(FetchDescriptor<Session>()) == 1)
        #expect(try ctx.fetchCount(FetchDescriptor<SetEntry>()) == 2)
    }

    @Test("uncomplete persists and keeps weight and reps")
    func uncompletePersists() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let set = SessionSetActions.ordered(se)[0]
        try SessionSetActions.complete(set, context: ctx)
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
        try SessionSetActions.complete(set, context: ctx)
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

    @Test("completion leaves the next drafts blank while the logger offers the completed performance")
    func completeCarriesForward() throws {
        let ctx = try LoggerFixtures.makeContext()
        let session = try LoggerFixtures.session(
            exercise: LoggerFixtures.exercise("Bench", in: ctx), startedAt: .now, completedAt: nil,
            sets: [(0, 0, false), (0, 0, false), (0, 0, false)], in: ctx
        )
        let se = try #require(session.exercises?.first)
        let sets = SessionSetActions.ordered(se)
        sets[0].weight = 105
        sets[0].reps = 6
        sets[0].rpe = 8
        #expect(try SessionSetActions.complete(sets[0], context: ctx))

        let exercise = try #require(try freshRead(ctx, se.id))
        let reread = SessionSetActions.ordered(exercise)
        let offers = WorkoutSetSuggestions(exercise: exercise, prior: []).offers()
        #expect(offers[reread[1].id] == WorkoutSetSuggestion(weight: 105, reps: 6))
        #expect(reread[1].weight == 0)
        #expect(reread[1].reps == 0)
        #expect(reread[1].rpe == nil)
        #expect(reread[1].isComplete == false)
        #expect(reread[2].reps == 0)
    }

    @Test("a next set with its own reps or typed weight keeps them")
    func completeLeavesTouchedSetAlone() throws {
        let ctx = try LoggerFixtures.makeContext()
        let session = try LoggerFixtures.session(
            exercise: LoggerFixtures.exercise("Bench", in: ctx), startedAt: .now, completedAt: nil,
            sets: [(100, 6, false), (95, 8, false), (100, 6, false), (90, 0, false)], in: ctx
        )
        let se = try #require(session.exercises?.first)
        let sets = SessionSetActions.ordered(se)
        sets[3].wasManualOverride = true
        #expect(try SessionSetActions.complete(sets[0], context: ctx))
        #expect(try SessionSetActions.complete(sets[2], context: ctx))

        let reread = SessionSetActions.ordered(try #require(try freshRead(ctx, se.id)))
        #expect(reread[1].weight == 95)
        #expect(reread[1].reps == 8)
        #expect(reread[3].weight == 90, "A typed weight is the lifter's choice")
        #expect(reread[3].reps == 0)
    }

    @Test("addSet shows the latest completed performance as an offer")
    func addSetCopiesLoggedSet() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let last = SessionSetActions.ordered(se)[2]
        last.rpe = 9
        #expect(try SessionSetActions.complete(last, context: ctx))
        let added = SessionSetActions.addSet(to: se, context: ctx)

        let offers = WorkoutSetSuggestions(exercise: se, prior: []).offers()
        #expect(offers[added.id] == WorkoutSetSuggestion(weight: 100, reps: 5))
        #expect(added.weight == 0)
        #expect(added.reps == 0)
        #expect(added.rpe == nil)
        #expect(added.isComplete == false)
    }

    @Test("addSet appends a blank draft when no set has been logged")
    func addSetAppends() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        SessionSetActions.ordered(se)[2].weight = 102.5
        let added = SessionSetActions.addSet(to: se, context: ctx)

        #expect(added.orderIndex == 3)
        #expect(added.weight == 0)
        #expect(added.reps == 0)
        #expect(WorkoutSetSuggestions(exercise: se, prior: []).offers()[added.id] == WorkoutSetSuggestion())
        #expect(added.isComplete == false)
        let reread = try #require(try freshRead(ctx, se.id))
        #expect((reread.sets ?? []).count == 4)
    }

    @Test("dropIntensity lightens only pending working sets, rounded to the increment")
    func dropIntensityPendingOnly() throws {
        let ctx = try LoggerFixtures.makeContext()
        let se = try makeSession(ctx)
        let sets = SessionSetActions.ordered(se)
        try SessionSetActions.complete(sets[0], context: ctx)
        sets[1].weight = 0
        sets[2].weight = 97.5
        let offers = WorkoutSetSuggestions(exercise: se, prior: []).offers()
        SessionSetActions.dropIntensity(of: se, fraction: 0.10, increment: 2.5, offers: offers, context: ctx)

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
