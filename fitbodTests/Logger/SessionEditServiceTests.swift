//
//  SessionEditServiceTests.swift
//  fitbodTests
//
//  History corrections: a moved workout moves whole and joins the block
//  running at its new start, one save applies all its set changes, and a
//  refused edit changes nothing.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionEditService", .serialized)
struct SessionEditServiceTests {
    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSinceReferenceDate: 30 * 86_400)

    private func finishedWorkout(on start: Date, in ctx: ModelContext) throws -> Session {
        try LoggerFixtures.session(
            exercise: LoggerFixtures.exercise("Bench", in: ctx),
            startedAt: start,
            completedAt: start.addingTimeInterval(3_600),
            sets: [(100, 5, true), (100, 5, true), (100, 5, true)],
            in: ctx
        )
    }

    private func block(from start: Date, to end: Date?, in ctx: ModelContext) -> Block {
        let block = Block()
        ctx.insert(block)
        block.startDate = start
        block.endDate = end
        block.isActive = end == nil
        return block
    }

    @Test("a moved workout moves whole and joins the block running at its new start")
    func moveShiftsWorkoutAndReassignsBlock() throws {
        let ctx = try LoggerFixtures.makeContext()
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let ended = block(from: base, to: base.addingTimeInterval(10 * day), in: ctx)
        let running = block(from: base.addingTimeInterval(10 * day), to: nil, in: ctx)
        // Saved as ready and never started: every block has a start date,
        // but one that never ran holds no workouts.
        let ready = block(from: base.addingTimeInterval(3 * day), to: nil, in: ctx)
        ready.isActive = false
        let workout = try finishedWorkout(on: base.addingTimeInterval(12 * day), in: ctx)
        workout.block = running
        let exercise = try #require(workout.exercises?.first)
        exercise.prescribedWeight = 100
        try ctx.save()
        let setTimes = SessionSetActions.ordered(exercise).map(\.completedAt)

        try SessionEditService.save(WorkoutEdit(startedAt: base.addingTimeInterval(5 * day)), to: workout, now: now, context: ctx)

        #expect(workout.startedAt == base.addingTimeInterval(5 * day))
        #expect(workout.completedAt == base.addingTimeInterval(5 * day + 3_600))
        #expect(SessionSetActions.ordered(exercise).map(\.completedAt) == setTimes.map { $0.addingTimeInterval(-7 * day) })
        #expect(workout.block?.id == ended.id)
        #expect(exercise.prescribedWeight == 100)
    }

    @Test("a move that would end after now throws and changes nothing")
    func moveIntoFutureThrows() throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-2 * day)
        let workout = try finishedWorkout(on: start, in: ctx)

        #expect(throws: SessionEditError.endsInFuture) {
            try SessionEditService.save(WorkoutEdit(startedAt: now.addingTimeInterval(-60)), to: workout, now: now, context: ctx)
        }
        #expect(workout.startedAt == start)
    }

    @Test("set changes, additions and deletions save together, in order")
    func setChangesApplyTogether() throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        let exercise = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(exercise)
        let lastLogged = sets[2].completedAt

        var edit = WorkoutEdit(startedAt: start)
        edit.changed[sets[0].id] = .init(weight: 102.5, reps: 5, rpe: 8)
        // A deleted set's leftover change is not checked: it is going away.
        edit.changed[sets[1].id] = .init(weight: 100, reps: 0, rpe: nil)
        edit.deleted = [sets[1].id]
        edit.added[exercise.id] = [.init(weight: 100, reps: 4, rpe: 9)]
        try SessionEditService.save(edit, to: workout, now: now, context: ctx)

        let saved = SessionSetActions.ordered(exercise)
        #expect(saved.map(\.weight) == [102.5, 100, 100])
        #expect(saved.map(\.reps) == [5, 5, 4])
        #expect(saved.map(\.orderIndex) == [0, 1, 2])
        let added = try #require(saved.last)
        let finishedAt = try #require(workout.completedAt)
        #expect(added.isComplete && added.rpe == 9)
        #expect(added.completedAt > lastLogged && added.completedAt <= finishedAt)
    }

    @Test("an invalid set throws and saves none of the edit")
    func invalidSetChangesNothing() throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        let sets = SessionSetActions.ordered(try #require(workout.exercises?.first))

        var edit = WorkoutEdit(startedAt: start.addingTimeInterval(-day))
        edit.changed[sets[0].id] = .init(weight: 110, reps: 5, rpe: nil)
        edit.changed[sets[1].id] = .init(weight: 100, reps: 0, rpe: nil)

        #expect(throws: SessionEditError.invalidSet) {
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        }
        #expect(workout.startedAt == start)
        #expect(sets[0].weight == 100)
    }

    @Test("a correction survives closing and reopening the store")
    func correctionSurvivesReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbod-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("edit.store")
        let start = now.addingTimeInterval(-3 * day)

        let (workoutID, setID) = try autoreleasepool {
            let ctx = ModelContext(try FitbodModelContainer.make(storeURL: url))
            ctx.autosaveEnabled = false
            let workout = try finishedWorkout(on: start, in: ctx)
            let exercise = try #require(workout.exercises?.first)
            let first = try #require(SessionSetActions.ordered(exercise).first)
            var edit = WorkoutEdit(startedAt: start.addingTimeInterval(-day))
            edit.changed[first.id] = .init(weight: 105, reps: 6, rpe: 8.5)
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
            return (workout.id, first.id)
        }

        try autoreleasepool {
            let ctx = ModelContext(try FitbodModelContainer.make(storeURL: url))
            let workout = try #require(try ctx.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == workoutID })).first)
            let set = try #require(try ctx.fetch(FetchDescriptor<SetEntry>(predicate: #Predicate { $0.id == setID })).first)
            #expect(workout.startedAt == start.addingTimeInterval(-day))
            #expect(set.weight == 105 && set.reps == 6 && set.rpe == 8.5)
        }
    }
}
