//
//  BlockBuilderViewActivationTests.swift
//  fitbodTests
//
//  260528-ejb: New Block saves an inactive block; Days Per Week clamps 1...7.
//  Every builder save (SAVE DRAFT, SAVE AS READY, SAVE CHANGES) calls
//  BlockDraft.save(into:) on the draft as it is. That save never writes
//  isActive (T65); only BlockLifecycleService starts or ends a block.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockBuilderViewActivation", .serialized)
struct BlockBuilderViewActivationTests {
    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    @Test("newBlock() produces an inactive template draft")
    func newBlockIsInactive() {
        let draft = BlockDraft.newBlock()
        #expect(draft.isActive == false)
    }

    @Test("saving a New Block draft persists an inactive block")
    func savingNewBlockPersistsInactiveBlock() throws {
        let context = try makeContext()
        let draft = BlockDraft(template: BlockTemplates.generic)
        draft.name = "Inactive Template"
        // The builder saves the draft as it is, with no activation step.

        try draft.save(into: context)
        try context.save()

        let blocks = try context.fetch(FetchDescriptor<Block>())
        #expect(blocks.count == 1)
        let block = try #require(blocks.first)
        #expect(block.isActive == false)
    }
}
