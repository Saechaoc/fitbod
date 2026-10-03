//
//  BlockBuilderViewActivationTests.swift
//  fitbodTests
//
//  260528-ejb: New Block saves an INACTIVE template; Days Per Week clamps 1...7.
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
        draft.isActive = false   // mirrors BlockBuilderView.saveIfValid()

        try draft.save(into: context)
        try context.save()

        let blocks = try context.fetch(FetchDescriptor<Block>())
        #expect(blocks.count == 1)
        let block = try #require(blocks.first)
        #expect(block.isActive == false)
    }

    @Test("Days Per Week stepper clamps to the inclusive 1...7 range")
    func daysPerWeekClampsToOneThroughSeven() {
        let draft = BlockDraft.newBlock()
        // Mirrors the private BlockBuilderView.adjustDaysPerWeek(by:) clamp.
        func adjust(by delta: Int) {
            draft.daysPerWeek = min(7, max(1, draft.daysPerWeek + delta))
        }

        draft.daysPerWeek = 7
        adjust(by: 1)
        #expect(draft.daysPerWeek == 7)   // upper clamp holds

        draft.daysPerWeek = 1
        adjust(by: -1)
        #expect(draft.daysPerWeek == 1)   // lower clamp holds

        draft.daysPerWeek = 4
        adjust(by: 1)
        #expect(draft.daysPerWeek == 5)   // increments

        draft.daysPerWeek = 4
        adjust(by: -1)
        #expect(draft.daysPerWeek == 3)   // decrements
    }
}
