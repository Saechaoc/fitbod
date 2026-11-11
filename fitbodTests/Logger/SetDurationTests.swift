//
//  SetDurationTests.swift
//  fitbodTests
//
//  RM-062 slice 5: a set's start and duration at Done, read from the rest
//  before it or from the set's START tap, and the exercise time built on
//  them.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SetDuration", .serialized)
struct SetDurationTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func engine(clock: @escaping () -> Date) -> RestTimerEngine {
        RestTimerEngine(scheduler: RestTimerEngineTests.StubScheduler(), now: clock)
    }

    /// One bench exercise with three pending 100 × 5 sets.
    private func bench(_ ctx: ModelContext) throws -> [SetEntry] {
        let session = try LoggerFixtures.session(
            exercise: LoggerFixtures.exercise("Bench", in: ctx), startedAt: t0, completedAt: nil,
            sets: [(100, 5, false), (100, 5, false), (100, 5, false)], in: ctx
        )
        return SessionSetActions.ordered(try #require(session.exercises?.first))
    }

    // MARK: - The start rule

    @Test("A skip during the rest starts the next set at the skip")
    func earlySkip() {
        var now = t0
        let engine = engine { now }
        engine.start(seconds: 120, exerciseName: "Bench")
        now = t0 + 30
        engine.stop()
        #expect(engine.setStart(doneAt: t0 + 75) == t0 + 30)
    }

    @Test("A set lifted in the overrun starts at the deadline, whatever the tap after it")
    func overrunThenLateTap() {
        var now = t0
        let engine = engine { now }
        engine.start(seconds: 120, exerciseName: "Bench")
        // Done while the rest still runs past zero.
        #expect(engine.setStart(doneAt: t0 + 160) == t0 + 120)
        // A cell tap after the set ends the rest late.
        now = t0 + 170
        engine.stop()
        #expect(engine.setStart(doneAt: t0 + 175) == t0 + 120)
    }

    @Test("With no rest before it a set's start is unknown, and a new rest replaces the one that ended")
    func noRest() {
        var now = t0
        let engine = engine { now }
        #expect(engine.setStart(doneAt: t0) == nil)
        engine.start(seconds: 120, exerciseName: "Bench")
        now = t0 + 30
        engine.stop()
        now = t0 + 40
        engine.start(seconds: 90, exerciseName: "Row")
        // Done inside the new rest: the set began at a moment nothing marked.
        #expect(engine.setStart(doneAt: t0 + 60) == t0 + 60)
    }

    // MARK: - Done

    @Test("Done stores the start and duration in the same save, and a failed save restores both")
    func doneStoresStartAndDuration() throws {
        enum SaveFailure: Error { case disk }
        let ctx = try LoggerFixtures.makeContext()
        let set = try bench(ctx)[0]
        #expect(throws: SaveFailure.self) {
            try SessionSetActions.complete(
                set, at: t0 + 75, startedAt: t0 + 30, context: ctx, save: { _ in throw SaveFailure.disk }
            )
        }
        #expect(!set.isComplete && set.startedAt == nil && set.durationSeconds == nil)

        #expect(try SessionSetActions.complete(set, at: t0 + 75, startedAt: t0 + 30, context: ctx))
        let id = set.id
        let stored = try #require(
            try ModelContext(ctx.container).fetch(FetchDescriptor<SetEntry>(predicate: #Predicate { $0.id == id })).first
        )
        #expect(stored.startedAt == t0 + 30 && stored.durationSeconds == 45)
    }

    @Test("A START tap wins over the rest, and a re-checked set keeps its time")
    func startTapWinsAndRecheckKeeps() throws {
        let ctx = try LoggerFixtures.makeContext()
        let set = try bench(ctx)[0]
        // START, ten seconds after a rest that ended at t0 + 120.
        set.startedAt = t0 + 130
        #expect(try SessionSetActions.complete(set, at: t0 + 170, startedAt: t0 + 120, context: ctx))
        #expect(set.durationSeconds == 40)

        SessionSetActions.uncomplete(set, context: ctx)
        #expect(try SessionSetActions.complete(set, at: t0 + 600, startedAt: t0 + 500, context: ctx))
        #expect(set.startedAt == t0 + 130 && set.durationSeconds == 40)
    }

    @Test("A start under a second or over an hour before Done leaves the time unknown")
    func implausibleStarts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let sets = try bench(ctx)
        #expect(try SessionSetActions.complete(sets[0], at: t0, startedAt: t0, context: ctx))
        #expect(try SessionSetActions.complete(sets[1], at: t0 + 3_700, startedAt: t0 + 50, context: ctx))
        // A START left from two hours ago.
        sets[2].startedAt = t0 - 7_200
        #expect(try SessionSetActions.complete(sets[2], at: t0 + 10, context: ctx))
        for set in sets {
            #expect(set.isComplete && set.startedAt == nil && set.durationSeconds == nil)
        }
    }

    @Test("A timed set keeps its typed time and takes no start from the rest")
    func timedSetKeepsTypedTime() throws {
        let ctx = try LoggerFixtures.makeContext()
        let plank = Exercise.previewSample(name: "Plank", equipment: .bodyweight, mechanic: .compound)
        plank.trackingRaw = Tracking.duration.rawValue
        ctx.insert(plank)
        let session = try LoggerFixtures.session(
            exercise: plank, startedAt: t0, completedAt: nil, sets: [(0, 0, false)], in: ctx
        )
        let set = try #require(session.exercises?.first?.sets?.first)
        set.durationSeconds = 60
        #expect(try SessionSetActions.complete(set, at: t0 + 300, startedAt: t0 + 100, context: ctx))
        #expect(set.durationSeconds == 60 && set.startedAt == nil)
    }

    // MARK: - Exercise time

    @Test("Exercise time runs from the first set's start to the last Done; a set of unknown start counts from its Done")
    func exerciseTime() throws {
        let ctx = try LoggerFixtures.makeContext()
        let sets = try bench(ctx)
        #expect(SessionSetActions.exerciseSeconds(sets) == nil)

        // The first set has no rest before it, so it spans nothing yet.
        #expect(try SessionSetActions.complete(sets[0], at: t0 + 40, context: ctx))
        #expect(SessionSetActions.exerciseSeconds(sets) == nil)

        #expect(try SessionSetActions.complete(sets[1], at: t0 + 200, startedAt: t0 + 160, context: ctx))
        #expect(SessionSetActions.exerciseSeconds(sets) == 160)

        // A warm-up does not count.
        sets[2].isWarmup = true
        sets[2].isComplete = true
        sets[2].completedAt = t0 - 600
        #expect(SessionSetActions.exerciseSeconds(sets) == 160)

        let session = try #require(sets[0].sessionExercise?.session)
        #expect(SessionSummary.make(session: session, priorSets: []).exercises.first?.exerciseSeconds == 160)
    }

    @Test("A swap keeps a completed set's time and clears a pending set's START")
    func swapKeepsDuration() throws {
        let ctx = try LoggerFixtures.makeContext()
        let sets = try bench(ctx)
        #expect(try SessionSetActions.complete(sets[0], at: t0 + 75, startedAt: t0 + 30, context: ctx))
        sets[1].startedAt = t0 + 200
        let current = try #require(sets[1].sessionExercise)

        #expect(SwapExerciseSheet.swap(current, to: LoggerFixtures.exercise("Row", in: ctx), context: ctx))
        #expect(sets[0].sessionExercise?.exerciseNameSnapshot == "Bench")
        #expect(sets[0].startedAt == t0 + 30 && sets[0].durationSeconds == 45)
        #expect(sets[1].sessionExercise?.exerciseNameSnapshot == "Row")
        #expect(sets[1].startedAt == nil)
    }
}
