//
//  WorkoutStarterTests.swift
//  fitbodTests
//
//  A start credits the slot StartSlot gives it at the tap, through the real
//  starter, factory and store: in a block, with no block, for a session
//  slotted twice and after a slot is removed. A second start resumes the
//  existing workout instead of creating another.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WorkoutStarter", .serialized)
struct WorkoutStarterTests {
    private let ctx: ModelContext
    private let bench: Exercise
    private let dayOne = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        ctx = try LoggerFixtures.makeContext()
        bench = LoggerFixtures.exercise("Bench", in: ctx)
    }

    // MARK: Fixtures

    /// A routine with one slot per name, in order. A repeated name reuses its
    /// session, so that session sits in two slots. Returns each session once.
    private func routine(slots names: [String]) throws -> (routine: Split, sessions: [SessionTemplate]) {
        let split = Split()
        ctx.insert(split)
        var sessions: [SessionTemplate] = []
        for (position, name) in names.enumerated() {
            let session: SessionTemplate
            if let existing = sessions.first(where: { $0.name == name }) {
                session = existing
            } else {
                session = try LoggerFixtures.template(name, exercises: [bench], in: ctx)
                sessions.append(session)
            }
            let slot = SplitSessionSlot()
            ctx.insert(slot)
            slot.position = position
            slot.sessionTemplate = session
            slot.split = split
        }
        try ctx.save()
        return (split, sessions)
    }

    private func activeBlock(on routine: Split) throws -> Block {
        let block = Block()
        ctx.insert(block)
        block.isActive = true
        block.split = routine
        try ctx.save()
        return block
    }

    /// Starts `session` from `routine` on day `day` and returns the workout.
    private func start(_ session: SessionTemplate, in routine: Split?, day: Int = 0) throws -> Session {
        let outcome = WorkoutStarter.start(
            session, in: routine, context: ctx, now: dayOne.addingTimeInterval(Double(day) * 86_400))
        guard case .started(let workout) = outcome else {
            throw StartFailure(outcome: "\(outcome)")
        }
        return workout
    }

    private struct StartFailure: Error { let outcome: String }

    /// Finishes `workout` with one logged work set, so it counts.
    private func finish(_ workout: Session) throws {
        let set = try #require((workout.exercises ?? []).flatMap { $0.sets ?? [] }.first { !$0.isWarmup })
        set.weight = 100
        set.reps = 5
        set.isComplete = true
        workout.completedAt = workout.startedAt.addingTimeInterval(3_600)
        try ctx.save()
    }

    /// Removes `slot` the way the routine screen does: unlink, save, delete, renumber, save.
    private func remove(_ slot: SplitSessionSlot, from routine: Split) throws {
        slot.sessionTemplate = nil
        try ctx.save()
        ctx.delete(slot)
        let remaining = (routine.slots ?? []).filter { $0.id != slot.id }.sorted { $0.position < $1.position }
        for (position, kept) in remaining.enumerated() { kept.position = position }
        try ctx.save()
    }

    private func nextPosition(in block: Block) -> Int? {
        if case .session(let next) = TodayResolver.resolve(block: block, context: ctx) { return next.position }
        return nil
    }

    // MARK: In a block

    @Test("a session started from the block's routine takes its block slot, and the rotation moves on")
    func startCreditsTheBlockSlot() throws {
        let (routine, sessions) = try routine(slots: ["A", "B", "C"])
        let block = try activeBlock(on: routine)

        let workout = try start(sessions[1], in: routine)
        #expect(workout.slot?.position == 1)
        #expect(workout.block?.id == block.id)
        try finish(workout)
        #expect(nextPosition(in: block) == 2)
    }

    @Test("a session slotted twice is credited at or after NEXT, so the rotation never moves backwards")
    func startOfASessionSlottedTwice() throws {
        let (routine, sessions) = try routine(slots: ["Push", "Pull", "Legs", "Push", "Pull", "Legs"])
        let block = try activeBlock(on: routine)
        for (day, session) in sessions.enumerated() {
            try finish(try start(session, in: routine, day: day))
        }
        #expect(nextPosition(in: block) == 3)

        // NEXT is the second Push. Pull is credited to the Pull after it, not to slot 1.
        let pull = try start(sessions[1], in: routine, day: 3)
        #expect(pull.slot?.position == 4)
        try finish(pull)
        #expect(nextPosition(in: block) == 5)
    }

    @Test("while a block runs, a start from another routine or from none is unslotted but still in the block")
    func startOutsideTheBlocksRoutine() throws {
        let (routine, sessions) = try routine(slots: ["A", "B"])
        let block = try activeBlock(on: routine)
        let other = Split()
        ctx.insert(other)
        let otherSlot = SplitSessionSlot()
        ctx.insert(otherSlot)
        otherSlot.sessionTemplate = sessions[0]
        otherSlot.split = other
        try ctx.save()

        let fromOther = try start(sessions[0], in: other)
        #expect(fromOther.slot == nil && fromOther.block?.id == block.id)
        try finish(fromOther)
        let fromNone = try start(sessions[0], in: nil, day: 1)
        #expect(fromNone.slot == nil && fromNone.block?.id == block.id)
        try finish(fromNone)
        // Neither moved the rotation.
        #expect(nextPosition(in: block) == 0)
    }

    // MARK: With no block

    @Test("with no block, two starts in a row of the suggested session move through the routine")
    func startsWithNoBlockMoveThroughTheRoutine() throws {
        let (routine, sessions) = try routine(slots: ["A", "B", "C"])
        for (day, expected) in sessions.enumerated() {
            let finished = try ctx.fetch(FetchDescriptor<Session>()).filter { $0.completedAt != nil }
            let suggestion = try #require(StartSlot.suggestion(liveRoutines: [routine], sessions: sessions, finished: finished))
            #expect(suggestion.session.id == expected.id)

            let workout = try start(suggestion.session, in: suggestion.slot?.split, day: day)
            #expect(workout.slot?.position == day)
            #expect(workout.block == nil)
            try finish(workout)
        }
    }

    @Test("a slot removed after its screen opened is not credited; the session's other slot is, then none")
    func startAfterASlotIsRemoved() throws {
        let (routine, sessions) = try routine(slots: ["A", "B", "A"])
        let slots = (routine.slots ?? []).sorted { $0.position < $1.position }

        // The screen holding `routine` and A is open; A's first slot goes.
        try remove(slots[0], from: routine)
        let first = try start(sessions[0], in: routine)
        #expect(first.slot?.id == slots[2].id)
        try finish(first)

        try remove(slots[2], from: routine)
        let second = try start(sessions[0], in: routine, day: 1)
        #expect(second.slot == nil)
    }

    @Test("a second session start returns the existing workout without creating another")
    func existingWorkoutIsResumed() throws {
        let (routine, sessions) = try routine(slots: ["A", "B"])
        let first = try start(sessions[0], in: routine)
        let outcome = WorkoutStarter.start(sessions[1], in: routine, context: ctx)
        guard case .alreadyInProgress(let active) = outcome else {
            Issue.record("A second start did not find the first")
            return
        }
        #expect(active.id == first.id)
        #expect(try ctx.fetch(FetchDescriptor<Session>()).count == 1)
    }
}
