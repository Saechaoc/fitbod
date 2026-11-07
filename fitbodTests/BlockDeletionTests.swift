//
//  BlockDeletionTests.swift
//  fitbodTests
//
//  Deleting a block cascades its phases and nullifies its template and
//  session links.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockDeletion", .serialized)
struct BlockDeletionTests {
    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func makeBlock(weeks: [Int] = [4, 2, 1, 1]) -> Block {
        let block = Block()
        block.name = "Test Block"
        block.startDate = Date(timeIntervalSince1970: 1_700_000_000)
        block.phases = weeks.enumerated().map { index, weeks in
            let phase = BlockPhase()
            phase.block = block
            phase.orderIndex = index
            phase.nameRaw = BlockPhaseKind.accumulation.rawValue
            phase.weeks = weeks
            return phase
        }
        return block
    }

    @Test("deleting block cascades phases")
    func deletingBlockCascadesPhases() throws {
        let context = try makeContext()
        let block = makeBlock()
        context.insert(block)
        for phase in block.phases ?? [] {
            context.insert(phase)
        }
        try context.save()

        context.delete(block)
        try context.save()

        let phases = try context.fetch(FetchDescriptor<BlockPhase>())
        #expect(phases.isEmpty)
    }

    @Test("deleting block nullifies session template link")
    func deletingBlockNullifiesRoutineLink() throws {
        let context = try makeContext()
        let block = makeBlock()
        let routine = SessionTemplate()
        routine.name = "Linked"
        routine.block = block
        context.insert(block)
        context.insert(routine)
        try context.save()

        context.delete(block)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<SessionTemplate>()).first)
        #expect(fetched.block == nil)
    }

    @Test("deleting block nullifies session link")
    func deletingBlockNullifiesSessionLink() throws {
        let context = try makeContext()
        let block = makeBlock()
        let session = Session()
        session.routineSnapshotName = "Snapshot"
        session.block = block
        context.insert(block)
        context.insert(session)
        try context.save()

        context.delete(block)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Session>()).first)
        #expect(fetched.block == nil)
        #expect(fetched.routineSnapshotName == "Snapshot")
    }
}
