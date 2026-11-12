import Foundation
import SwiftData
import Testing
@testable import fitbod

/// Each Program seed must land on the state it is named for: the 390pt
/// captures open Program through these seeds (RM-011).
@MainActor
@Suite("ProgramStatesSeed")
struct ProgramStatesSeedTests {

    /// Seeds `state` into an empty store, then orders its blocks as Program does.
    private func seeded(_ state: ProgramStatesSeed.State) throws -> (blocks: ProgramBlocks, routines: [Split]) {
        let ctx = ModelContext(try InMemoryContainer.makeCurrent())
        for id in TodayStatesSeed.catalogIDs {
            ctx.insert(Exercise(externalID: id, name: id, canonicalName: id.lowercased(), equipmentRaw: "barbell", mechanicRaw: "compound"))
        }
        ProgramStatesSeed.seed(state, in: ctx, now: .now)
        return (ProgramBlocks(try ctx.fetch(FetchDescriptor<Block>())), try ctx.fetch(FetchDescriptor<Split>()))
    }

    @Test("Drafts: three drafts, the newest created first, and nothing to start")
    func draftsSeed() throws {
        let blocks = try seeded(.drafts).blocks
        #expect(blocks.active == nil && blocks.ready.isEmpty && blocks.past.isEmpty)
        #expect(blocks.drafts.map(\.programName) == ["Hypertrophy Block", "Strength Block", "Untitled Block"])
    }

    @Test("Past: three finished blocks, newest ended first, with their counted workouts and seen reviews")
    func pastSeed() throws {
        let blocks = try seeded(.past).blocks
        #expect(blocks.lead == nil)
        #expect(blocks.past.map(\.name) == ["Summer Block", "Winter Block", "Winter Block"])
        #expect(blocks.past.map { SessionSetActions.countedWorkouts($0.sessions ?? []).count } == [3, 4, 2])
        #expect(blocks.past.allSatisfy { $0.reviewedAt != nil })
    }

    @Test("Long names: the active block leads, a ready block and a draft are planned, and one block is past")
    func longNamesSeed() throws {
        let blocks = try seeded(.longNames).blocks
        #expect(blocks.active?.name == "Twelve Week Strength and Hypertrophy Block")
        #expect(blocks.planned.map(\.derivedStatus) == [.ready, .draft])
        #expect(blocks.past.count == 1)
    }

    @Test("Archived: one archived routine and no block")
    func archivedSeed() throws {
        let (blocks, routines) = try seeded(.archived)
        #expect(blocks.lead == nil && blocks.past.isEmpty)
        #expect(routines.map(\.isArchived) == [true])
    }
}
