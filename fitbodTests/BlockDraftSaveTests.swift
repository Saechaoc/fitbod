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
        let schema = Schema(SchemaV7.models)   // V7 required — Split, SplitSessionSlot, SessionTemplate
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
        // endDate is NOT written by the builder (spec §3/§4 — freeze marker set only by
        // BlockLifecycleService.end). A builder-saved block must have endDate == nil.
        #expect(block.endDate == nil)
        #expect(draft.id == block.id)

        let phases = (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(phases.count == 4)
        #expect(phases.map(\.orderIndex) == [0, 1, 2, 3])
        #expect(phases.map(\.kind) == [.accumulation, .intensification, .realization, .deload])
        #expect(phases.map(\.weeks) == [4, 2, 1, 1])
    }

    // MARK: - T-09-13 / T-09-14 behavior tests (spec §3/§4)

    @Test("saved draft without split has derivedStatus == .draft and endDate == nil")
    func savedDraftWithoutSplitIsDraftAndHasNoEndDate() throws {
        let context = try makeContext()
        let draft = BlockDraft(template: BlockTemplates.generic)
        draft.name = "No Split Draft"
        // split is nil by default — no routine attached

        try draft.save(into: context)
        try context.save()

        let block = try #require(try context.fetch(FetchDescriptor<Block>()).first)
        #expect(block.endDate == nil, "Builder must not write endDate (T-09-13)")
        #expect(block.derivedStatus == .draft, "A builder-saved block without a split must be .draft, not .completed")
        #expect(block.split == nil)
    }

    @Test("saved draft with split and matching rotation mode has derivedStatus == .ready")
    func savedDraftWithSplitAndRotationIsReady() throws {
        let context = try makeContext()

        // Build a split with one slot so slotCount >= 1
        let split = Split()
        split.name = "Upper / Lower"
        context.insert(split)
        let slot = SplitSessionSlot()
        slot.split = split
        slot.position = 0
        context.insert(slot)
        split.slots = [slot]

        let draft = BlockDraft(template: BlockTemplates.generic)
        draft.name = "Ready Block"
        draft.split = split
        draft.schedulingMode = .rotation
        // rotation mode: trainingDays count need not match — ready as long as split != nil + slotCount >= 1

        try draft.save(into: context)
        try context.save()

        let block = try #require(try context.fetch(FetchDescriptor<Block>()).first)
        #expect(block.endDate == nil, "Builder must not write endDate (T-09-13)")
        #expect(block.derivedStatus == .ready, "A builder-saved block with a matching split must be .ready, not .completed")
        #expect(block.split?.name == "Upper / Lower")
    }

    @Test("trainingDays are persisted sorted via TrainingDaysWriter.sort (T-09-14)")
    func trainingDaysArePersistedSorted() throws {
        let context = try makeContext()
        let draft = BlockDraft(template: BlockTemplates.generic)
        draft.name = "Fixed Weekly"
        draft.schedulingMode = .fixedWeekly
        // Pass unsorted weekdays — writer must sort them
        draft.trainingDays = [6, 2, 4] // Fri, Mon, Wed (unsorted)

        try draft.save(into: context)
        try context.save()

        let block = try #require(try context.fetch(FetchDescriptor<Block>()).first)
        let sorted = TrainingDaysWriter.sort(weekdays: [6, 2, 4])
        #expect(block.trainingDays == sorted, "trainingDays must be sorted via TrainingDaysWriter.sort at save time (T-09-14)")
    }

    @Test("init(block:) round-trips split, schedulingMode, and trainingDays")
    func initFromBlockRoundTripsSchedulingFields() throws {
        let context = try makeContext()

        let split = Split()
        split.name = "PPL"
        context.insert(split)

        let block = Block()
        block.name = "Existing"
        block.split = split
        block.schedulingMode = .fixedWeekly
        block.trainingDays = [2, 4, 6]
        context.insert(block)
        try context.save()

        let draft = BlockDraft(block: block)
        #expect(draft.split?.name == "PPL")
        #expect(draft.schedulingMode == .fixedWeekly)
        #expect(draft.trainingDays == [2, 4, 6])
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
