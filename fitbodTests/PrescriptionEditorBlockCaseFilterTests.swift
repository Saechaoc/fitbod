//
//  PrescriptionEditorBlockCaseFilterTests.swift
//  fitbodTests
//
//  Source anchors for Phase 4 routine-to-block picker behavior.
//
//  ## Phase 3.1 reconciliation (2026-05-23)
//
//  Phase 3.1's PIVOT-04 stripped the per-exercise Intent + Progression
//  pickers from PrescriptionEditorRow. Decision D-19 from Phase 4
//  CONTEXT.md ("disallow .block/.hybrid unless routine is in a block")
//  is OBSOLETE after that strip — there is no longer a per-exercise
//  progression picker to filter. The two tests that pinned the picker
//  filter (`prescriptionEditorRowHasHasBlockInit` and
//  `prescriptionEditorRowFootnoteCopy`) were removed during this
//  reconciliation; their behavior no longer exists in production code.
//
//  The remaining 3 tests pin Plan 04-05 surfaces that ARE still
//  current:
//
//    - `prescriptionEditorRowDoesNotHavePhase3DeferralFootnote` —
//      asserts the old "Block / Hybrid models activate" deferral
//      footnote is gone (replaced by Plan 04-06's real strategies).
//    - `routineBuilderViewPropagatesHasBlock` — asserts that the
//      routine builder still computes `draft.blockID != nil` and
//      passes `hasBlock:` into the exercise card. The `hasBlock`
//      plumbing is preserved (RoutineBuilderView → RoutineExerciseCard
//      → PrescriptionEditorRow) even though the editor row no longer
//      branches on it; future Phase 4+ surfaces (e.g., block-aware
//      banners inside the card) can re-use the same channel.
//    - `blockPickerMenuLabelsVerbatim` — anchors the verbatim copy
//      shipped in Plan 04-05's BlockPickerMenu.
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
