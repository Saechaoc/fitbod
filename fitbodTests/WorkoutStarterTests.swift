//
//  WorkoutStarterTests.swift
//  fitbodTests
//
//  Starting a session from anywhere counts as that day of the active
//  block, and an empty workout starts with nothing in it.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WorkoutStarter", .serialized)
struct WorkoutStarterTests {

    /// An active rotation block whose routine holds sessions A, B and C.
    private func rotationBlock(in ctx: ModelContext) throws -> (block: Block, templates: [SessionTemplate]) {
        let exercise = LoggerFixtures.exercise("Bench", in: ctx)
        let templates = try ["A", "B", "C"].map { try LoggerFixtures.template($0, exercises: [exercise], in: ctx) }
        let split = Split()
        ctx.insert(split)
        for (position, template) in templates.enumerated() {
            let slot = SplitSessionSlot()
            ctx.insert(slot)
            slot.position = position
            slot.sessionTemplate = template
            slot.split = split
        }
        let block = Block()
        ctx.insert(block)
        block.isActive = true
        block.split = split
        try ctx.save()
        return (block, templates)
    }

    @Test("a session started without a slot takes its block slot, and the rotation moves on")
    func startCreditsTheBlockSlot() throws {
        let ctx = try LoggerFixtures.makeContext()
        let (block, templates) = try rotationBlock(in: ctx)

        guard case .started(let session) = WorkoutStarter.start(templates[1], context: ctx) else {
            Issue.record("B did not start")
            return
        }
        #expect(session.slot?.position == 1)
        #expect(session.block?.id == block.id)
        session.completedAt = session.startedAt.addingTimeInterval(3_600)
        try ctx.save()

        guard case .session(let next) = TodayResolver.resolve(block: block, context: ctx) else {
            Issue.record("No session scheduled after B")
            return
        }
        #expect(next.position == 2)
    }

    @Test("an empty workout starts in the active block with nothing in it, once")
    func emptyWorkoutStarts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let (block, _) = try rotationBlock(in: ctx)

        guard case .started(let session) = WorkoutStarter.startEmpty(context: ctx) else {
            Issue.record("The empty workout did not start")
            return
        }
        #expect(session.completedAt == nil)
        #expect((session.exercises ?? []).isEmpty)
        #expect(session.block?.id == block.id && session.slot == nil)
        #expect(session.displayName == "Workout")

        guard case .alreadyInProgress(let active) = WorkoutStarter.startEmpty(context: ctx) else {
            Issue.record("A second start did not find the first")
            return
        }
        #expect(active.id == session.id)
    }
}
