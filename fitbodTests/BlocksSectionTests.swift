//
//  BlocksSectionTests.swift
//  fitbodTests
//
//  Phase 4 coverage for the Routines tab Blocks section.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlocksSection", .serialized)
struct BlocksSectionTests {
    private let day: TimeInterval = 86_400

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV5.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeBlock(
        name: String = "Test Block",
        startDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date? = nil,
        isActive: Bool = false,
        weeks: [Int] = [4, 2, 1, 1]
    ) -> Block {
        let block = Block()
        block.name = name
        block.startDate = startDate
        block.endDate = endDate
        block.isActive = isActive
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

    @Test("copy anchors exist in RoutinesListView")
    func copyAnchorsExistInRoutinesListView() throws {
        let source = try routinesListSource()

        #expect(source.contains("\"Blocks\""))
        #expect(source.contains("\"+ Block\""))
        #expect(source.contains("\"No blocks yet.\""))
        #expect(source.contains("\"Define a training block to organize routines into a mesocycle.\""))
        #expect(source.contains("\"Generic Strength Meso\""))
        #expect(source.contains("\"Hypertrophy Meso\""))
        #expect(source.contains("\"Powerlifting Peak\""))
        #expect(source.contains("\"Blank Block\""))
        #expect(source.contains("\"Delete block?\""))
        #expect(source.contains("\"Linked routines stay; sessions logged under this block keep their snapshot context.\""))
    }

    @Test("caption shows Starting for future block")
    func captionShowsStartingForFutureBlock() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(startDate: now.addingTimeInterval(7 * day))

        #expect(BlockRow.captionText(for: block, now: now).hasPrefix("Starting "))
    }

    @Test("caption shows Started for active block")
    func captionShowsStartedForActiveBlock() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(
            startDate: now.addingTimeInterval(-7 * day),
            endDate: now.addingTimeInterval(14 * day),
            isActive: true
        )

        #expect(BlockRow.captionText(for: block, now: now).hasPrefix("Started "))
    }

    @Test("caption shows Ended for finished block")
    func captionShowsEndedForFinishedBlock() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(
            startDate: now.addingTimeInterval(-21 * day),
            endDate: now.addingTimeInterval(-day),
            isActive: false
        )

        #expect(BlockRow.captionText(for: block, now: now).hasPrefix("Ended "))
    }

    @Test("active week badge shows Week N of M")
    func activeWeekBadgeShowsWeekNOfM() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(
            startDate: now.addingTimeInterval(-14 * day),
            isActive: true,
            weeks: [4, 2, 1, 1]
        )

        #expect(BlockRow.weekBadgeText(for: block, now: now) == "Week 3 of 8")
    }

    @Test("inactive week badge shows total weeks")
    func inactiveWeekBadgeShowsTotalWeeks() {
        let block = makeBlock(isActive: false, weeks: [4, 2, 1, 1])

        #expect(BlockRow.weekBadgeText(for: block, now: .now) == "8 weeks")
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

    @Test("deleting block nullifies routine link")
    func deletingBlockNullifiesRoutineLink() throws {
        let context = try makeContext()
        let block = makeBlock()
        let routine = Routine()
        routine.name = "Linked"
        routine.block = block
        context.insert(block)
        context.insert(routine)
        try context.save()

        context.delete(block)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Routine>()).first)
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

    @Test("blocks display sorts active desc then start date desc")
    func blocksDisplaySortsActiveDescStartDateDesc() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let active = makeBlock(name: "Active", startDate: now.addingTimeInterval(-7 * day), isActive: true)
        let inactiveNewer = makeBlock(name: "Inactive Newer", startDate: now.addingTimeInterval(-14 * day))
        let inactiveOlder = makeBlock(name: "Inactive Older", startDate: now.addingTimeInterval(-21 * day))

        let fetched = BlockRow.sortedForDisplay([inactiveOlder, active, inactiveNewer])

        #expect(fetched.map(\.name) == ["Active", "Inactive Newer", "Inactive Older"])
    }

    private func routinesListSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Routines/RoutinesListView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
