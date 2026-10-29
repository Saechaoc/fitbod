//
//  BlockDraftSnapshotTests.swift
//  fitbodTests
//
//  Review item 3: the New Block builder resists swipe-down while its draft
//  differs from the snapshot taken when the builder opened.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("BlockDraftSnapshot")
struct BlockDraftSnapshotTests {

    @Test("every edit the builder can make counts as unsaved")
    func builderEditsCountAsUnsaved() throws {
        let context = ModelContext(try FitbodModelContainer.make(inMemory: true))
        let split = Split()
        context.insert(split)
        let edits: [(String, (BlockDraft) -> Void)] = [
            ("name", { $0.name = "Peak Q4" }),
            ("days per week", { $0.daysPerWeek += 1 }),
            ("phase weeks", { $0.phases[0].weeks += 1 }),
            ("phase kind", { $0.phases[0].kind = .peak }),
            ("phase volume", { $0.phases[0].volumeMultiplier += 0.05 }),
            ("phase order", { $0.phases.swapAt(0, 1) }),
            ("added phase", { $0.phases.append(BlockPhaseDraft()) }),
            ("routine", { $0.split = split }),
            ("scheduling", { $0.schedulingMode = .fixedWeekly }),
            ("training days", { $0.trainingDays.append(2) }),
        ]
        for (field, edit) in edits {
            let draft = BlockDraft(template: BlockTemplates.generic)
            let opened = draft.snapshot()
            edit(draft)
            #expect(draft.snapshot() != opened, "Editing the \(field) must count as unsaved")
        }
    }

    @Test("undoing a phase delete leaves nothing unsaved")
    func undoneDeleteLeavesNothingUnsaved() {
        let draft = BlockDraft(template: BlockTemplates.generic)
        let opened = draft.snapshot()

        let removed = draft.phases.remove(at: 1)
        #expect(draft.snapshot() != opened)
        draft.phases.insert(removed, at: 1)

        #expect(draft.snapshot() == opened)
    }

    @Test("toggling a training day off and on again leaves nothing unsaved")
    func retoggledTrainingDayLeavesNothingUnsaved() {
        let draft = BlockDraft()
        draft.trainingDays = [2, 4]
        let opened = draft.snapshot()

        draft.trainingDays.removeAll { $0 == 2 }
        draft.trainingDays.append(2)

        #expect(draft.snapshot() == opened)
    }
}
