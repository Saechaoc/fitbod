//
//  SingleActiveBlockInvariantTests.swift
//  fitbodTests
//
//  Phase 4 coverage for the transactional one-active-block invariant.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SingleActiveBlockInvariant", .serialized)
struct SingleActiveBlockInvariantTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("saving an active draft deactivates prior active blocks")
    func savingActiveDraftDeactivatesPriorActiveBlocks() throws {
        let context = try makeContext()
        let prior = Block()
        prior.name = "Prior"
        prior.isActive = true
        context.insert(prior)
        try context.save()

        let next = BlockDraft(template: BlockTemplates.hypertrophy)
        next.name = "Next"
        next.isActive = true

        try next.save(into: context)
        try context.save()

        let active = try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.isActive == true }))
        #expect(active.count == 1)
        #expect(active.first?.name == "Next")
        #expect(prior.isActive == false)
    }

    @Test("saving an inactive draft keeps the existing active block")
    func savingInactiveDraftKeepsExistingActiveBlock() throws {
        let context = try makeContext()
        let active = Block()
        active.name = "Active"
        active.isActive = true
        context.insert(active)
        try context.save()

        let inactiveDraft = BlockDraft(template: BlockTemplates.generic)
        inactiveDraft.name = "Later"
        inactiveDraft.isActive = false

        try inactiveDraft.save(into: context)
        try context.save()

        let activeBlocks = try context.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.isActive == true }))
        #expect(activeBlocks.count == 1)
        #expect(activeBlocks.first?.id == active.id)
    }

    @Test("editing the current active block preserves exactly one active row")
    func editingCurrentActiveBlockPreservesExactlyOneActiveRow() throws {
        let context = try makeContext()
        let existing = Block()
        existing.name = "Existing"
        existing.isActive = true
        context.insert(existing)
        try context.save()

        let draft = BlockDraft(block: existing)
        draft.name = "Renamed"
        draft.isActive = true

        try draft.save(into: context)
        try context.save()

        let blocks = try context.fetch(FetchDescriptor<Block>())
        let activeBlocks = blocks.filter(\.isActive)
        #expect(blocks.count == 1)
        #expect(activeBlocks.count == 1)
        #expect(activeBlocks.first?.name == "Renamed")
    }
}
