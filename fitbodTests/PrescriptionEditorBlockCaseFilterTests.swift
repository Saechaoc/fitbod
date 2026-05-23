//
//  PrescriptionEditorBlockCaseFilterTests.swift
//  fitbodTests
//
//  Source anchors for Phase 4 routine-to-block picker behavior.
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

    @Test("PrescriptionEditorRow has hasBlock init and conditional cases")
    func prescriptionEditorRowHasHasBlockInit() throws {
        let editor = try source("fitbod/Routines/PrescriptionEditorRow.swift")

        #expect(editor.contains("hasBlock: Bool"))
        #expect(editor.contains("if hasBlock {"))
        #expect(editor.contains("ProgressionKind.block"))
        #expect(editor.contains("ProgressionKind.hybrid"))
    }

    @Test("PrescriptionEditorRow has block-required help copy")
    func prescriptionEditorRowFootnoteCopy() throws {
        let editor = try source("fitbod/Routines/PrescriptionEditorRow.swift")

        #expect(editor.contains("\"Add routine to a block to use these.\""))
    }

    @Test("PrescriptionEditorRow does not have Phase 3 deferral footnote")
    func prescriptionEditorRowDoesNotHavePhase3DeferralFootnote() throws {
        let editor = try source("fitbod/Routines/PrescriptionEditorRow.swift")

        #expect(!editor.contains("Block / Hybrid models activate"))
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
        #expect(menu.contains("\"Block:\""))
    }
}
