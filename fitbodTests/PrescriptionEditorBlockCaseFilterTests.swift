//
//  PrescriptionEditorBlockCaseFilterTests.swift
//  fitbodTests
//
//  Phase 4 routine-to-block picker behavior: which progression kinds a
//  routine can choose with and without a block.
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

import Testing
@testable import fitbod

@Suite("PrescriptionEditorBlockCaseFilter")
struct PrescriptionEditorBlockCaseFilterTests {
    @Test("RoutineDraft exposes block-aware progression cases")
    @MainActor
    func routineDraftExposesBlockAwareProgressionCases() {
        #expect(RoutineDraft.availableProgressionKinds(hasBlock: false) == [.rpe, .double])
        #expect(RoutineDraft.availableProgressionKinds(hasBlock: true) == ProgressionKind.allCases)
    }
}
