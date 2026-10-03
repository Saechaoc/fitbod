//
//  PrescriptionEditorBlockCaseFilterTests.swift
//  fitbodTests
//
//  Source anchors for Phase 4 routine-to-block picker behavior.
//
//  ## Phase 3.1 reconciliation (2026-05-23)
//
//  Phase 3.1's PIVOT-04 stripped the per-exercise Intent + Progression
//  pickers from PrescriptionEditorRow and hoisted Progression to the
//  routine header. Phase 4's block-required filter therefore belongs
//  on RoutineBuilderView's header picker, with a RoutineDraft save-path
//  guard so direct draft mutation cannot persist .block/.hybrid without
//  a real block.
//

import Foundation
import Testing
@testable import fitbod

@Suite("PrescriptionEditorBlockCaseFilter")
struct PrescriptionEditorBlockCaseFilterTests {
    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: projectRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    @Test("RoutineDraft exposes block-aware progression cases")
    @MainActor
    func routineDraftExposesBlockAwareProgressionCases() {
        #expect(RoutineDraft.availableProgressionKinds(hasBlock: false) == [.rpe, .double])
        #expect(RoutineDraft.availableProgressionKinds(hasBlock: true) == ProgressionKind.allCases)
    }

    @Test("RoutineBuilderView filters block-required progression cases")
    func routineBuilderViewFiltersBlockRequiredProgressionCases() throws {
        let builder = try source("fitbod/Routines/RoutineBuilderView.swift")

        #expect(builder.contains("availableProgressionKinds"))
        #expect(builder.contains("RoutineDraft.availableProgressionKinds(hasBlock: draft.blockID != nil)"))
        #expect(builder.contains("ForEach(availableProgressionKinds"))
        #expect(builder.contains("guardedProgressionSelection"))
    }

    @Test("RoutineBuilderView has block-aware guard (footnote copy may be absent post-BRU reskin)")
    func routineBuilderViewFootnoteCopy() throws {
        let builder = try source("fitbod/Routines/RoutineBuilderView.swift")

        // Phase 2.1 BRU reskin removed the inline "Add routine to a block to use these."
        // footnote and replaced it with guarded selection (requiresBlock + guardedProgressionSelection).
        // The structural guard is still present; the copy footnote was dropped.
        // Test the structural contract rather than the removed copy string.
        #expect(
            builder.contains("requiresBlock") || builder.contains("blockID != nil"),
            "Block-required guard must be present in RoutineBuilderView even if footnote copy was removed"
        )
    }

    @Test("RoutineBuilderView does not have Phase 3 deferral footnote")
    func routineBuilderViewDoesNotHavePhase3DeferralFootnote() throws {
        let builder = try source("fitbod/Routines/RoutineBuilderView.swift")

        #expect(!builder.contains("Block / Hybrid models activate"))
    }

    @Test("RoutineBuilderView propagates hasBlock")
    func routineBuilderViewPropagatesHasBlock() throws {
        let builder = try source("fitbod/Routines/RoutineBuilderView.swift")

        #expect(builder.contains("draft.blockID != nil"))
        #expect(builder.contains("hasBlock:"))
    }

    @Test("BlockPickerMenu labels are verbatim")
    func blockPickerMenuLabelsVerbatim() throws {
        let menu = try source("fitbod/Periodization/BlockPickerMenu.swift")

        #expect(menu.contains("\"No Block\""))
        #expect(menu.contains("\"+ Create New Block\""))
        // The chip label interpolates the block name: "Block: \(name)".
        #expect(menu.contains("\"Block: \\("))
    }
}
