//
//  BlockDraftSaveTests.swift
//  fitbodTests
//
//  Phase 4 coverage for the block-builder draft save path.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockDraftSave", .serialized)
struct BlockDraftSaveTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV4.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("blank draft is invalid")
    func blankDraftIsInvalid() {
        let draft = BlockDraft()

        #expect(draft.isValid == false)
    }

    @Test("template draft seeds phases and total weeks")
    func templateDraftSeedsPhasesAndTotalWeeks() throws {
        let draft = BlockDraft(template: BlockTemplates.generic)

        #expect(draft.name == "Generic Strength Meso")
        #expect(draft.phases.map(\.kind) == [.accumulation, .intensification, .realization, .deload])
        #expect(draft.totalWeeks == 8)
        #expect(draft.isValid == true)

        let first = try #require(draft.phases.first)
        #expect(first.weeks == 4)
        #expect(first.volumeMultiplier == 1.0)
        #expect(first.intensityMultiplier == 0.75)
    }

    @Test("changing phase kind applies default multipliers")
    func changingPhaseKindAppliesDefaultMultipliers() {
        let phase = BlockPhaseDraft(kind: .accumulation, weeks: 4, volumeMultiplier: 1.0, intensityMultiplier: 0.75)

        phase.kind = .realization

        #expect(phase.volumeMultiplier == 0.6)
        #expect(phase.intensityMultiplier == 0.97)
    }

    @Test("saving draft persists block and ordered phases")
    func savingDraftPersistsBlockAndOrderedPhases() throws {
        let context = try makeContext()
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let draft = BlockDraft(template: BlockTemplates.generic)
        draft.name = "  Powerlifting Peak Q3  "
        draft.startDate = startDate
        draft.isActive = true

        try draft.save(into: context)
        try context.save()

        let blocks = try context.fetch(FetchDescriptor<Block>())
        #expect(blocks.count == 1)
        let block = try #require(blocks.first)
        #expect(block.name == "Powerlifting Peak Q3")
        #expect(block.startDate == startDate)
        #expect(block.isActive == true)
        #expect(block.endDate == startDate.addingTimeInterval(Double(8 * 7) * 86_400))
        #expect(draft.id == block.id)

        let phases = (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(phases.count == 4)
        #expect(phases.map(\.orderIndex) == [0, 1, 2, 3])
        #expect(phases.map(\.kind) == [.accumulation, .intensification, .realization, .deload])
        #expect(phases.map(\.weeks) == [4, 2, 1, 1])
    }

    @Test("draft init from block sorts phases by order index")
    func draftInitFromBlockSortsPhasesByOrderIndex() throws {
        let block = Block()
        block.name = "Existing"
        block.startDate = Date(timeIntervalSince1970: 1_700_000_000)
        block.isActive = true

        let late = BlockPhase()
        late.orderIndex = 1
        late.nameRaw = BlockPhaseKind.deload.rawValue
        late.weeks = 1

        let early = BlockPhase()
        early.orderIndex = 0
        early.nameRaw = BlockPhaseKind.accumulation.rawValue
        early.weeks = 4

        block.phases = [late, early]

        let draft = BlockDraft(block: block)

        #expect(draft.name == "Existing")
        #expect(draft.isActive == true)
        #expect(draft.phases.map(\.kind) == [.accumulation, .deload])
        #expect(draft.totalWeeks == 5)
    }
}
