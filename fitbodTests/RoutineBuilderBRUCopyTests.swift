//
//  RoutineBuilderBRUCopyTests.swift
//  fitbodTests
//
//  Phase 2.1 Plan 05 — Verbatim BRU copy + structural tests for the
//  RoutineBuilderView rewrite. Verifies that:
//
//    1. The header center renders "Edit routine" in edit mode (source-anchor).
//    2. The header center renders "New routine" in create mode (source-anchor).
//    3. BottomActionBar labels are verbatim: "Discard" + "Save routine ▸".
//    4. Dashed slot copy is verbatim: "Add exercise" + "↘ FROM LIBRARY".
//    5. Prescription chips render in spec order (source-anchor).
//    6. Drag handle is the typographic "⋮⋮" glyph (source-anchor).
//    7. Discard confirmation copy is verbatim (source-anchor).
//    8. TOP set row uses bruSignal tint (source-anchor via PerSetOverrideRow).
//
//  Tests use the source-anchor pattern from ExerciseHistoryViewCopyTests +
//  RoutineBuilderCopyTests: read source files from disk via #filePath ascent
//  and assert contains(...) on verbatim strings.
//
//  Imports: Swift Testing + @testable import fitbod.
//

import Foundation
import Testing
@testable import fitbod

@Suite("RoutineBuilderBRUCopy")
struct RoutineBuilderBRUCopyTests {

    // MARK: - Helpers

    /// Base URL for fitbod/Routines/ source files.
    private var routinesBase: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // fitbodTests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("fitbod/Routines")
    }

    private func source(_ filename: String) throws -> String {
        try String(
            contentsOf: routinesBase.appendingPathComponent(filename),
            encoding: .utf8
        )
    }

    // MARK: - 1. Header center "Edit routine" in edit mode

    @Test("headerCenterIsEditRoutineWhenEditing — source contains 'Edit routine'")
    func headerCenterIsEditRoutineWhenEditing() throws {
        let builder = try source("RoutineBuilderView.swift")
        #expect(builder.contains("\"Edit routine\""))
    }

    // MARK: - 2. Header center "New routine" in create mode

    @Test("headerCenterIsNewRoutineWhenCreating — source contains 'New routine'")
    func headerCenterIsNewRoutineWhenCreating() throws {
        let builder = try source("RoutineBuilderView.swift")
        #expect(builder.contains("\"New routine\""))
    }

    // MARK: - 3. Bottom action bar verbatim labels

    @Test("bottomActionBarLabelsVerbatim — 'Discard' and 'Save routine ▸' present")
    func bottomActionBarLabelsVerbatim() throws {
        let bar = try source("BottomActionBar.swift")
        #expect(bar.contains("\"Discard\""))
        #expect(bar.contains("\"Save routine ▸\""))
    }

    // MARK: - 4. Dashed slot copy verbatim

    @Test("dashedSlotCopyVerbatim — 'Add exercise' and '↘ FROM LIBRARY' present")
    func dashedSlotCopyVerbatim() throws {
        // Check in RoutineBuilderView (primary usage) and InlineExerciseSearchRow (secondary)
        let builder = try source("RoutineBuilderView.swift")
        let inline = try source("InlineExerciseSearchRow.swift")

        // Either source should contain the verbatim copy
        let builderHasAddExercise = builder.contains("\"Add exercise\"")
        let inlineHasAddExercise = inline.contains("\"Add exercise\"")
        #expect(builderHasAddExercise || inlineHasAddExercise)

        let builderHasHint = builder.contains("\"↘ FROM LIBRARY\"")
        let inlineHasHint = inline.contains("\"↘ FROM LIBRARY\"")
        #expect(builderHasHint || inlineHasHint)
    }

    // MARK: - 5. Prescription chips in spec order (source-anchor)

    @Test("prescriptionChipsRenderInSpecOrder — chip labels appear in PrescriptionEditorRow source")
    func prescriptionChipsRenderInSpecOrder() throws {
        let editor = try source("PrescriptionEditorRow.swift")

        // Render real per-exercise values, not static progression/plate labels.
        // Progression is selected once in the parent session builder.
        let reps = try #require(editor.range(of: "(repsChipLabel, Color.bruInk)"))
        let rpe = try #require(editor.range(of: "(rpeChipLabel, Color.bruInk)"))
        let rest = try #require(editor.range(of: "(restChipLabel, Color.bruInk)"))
        #expect(reps.lowerBound < rpe.lowerBound)
        #expect(rpe.lowerBound < rest.lowerBound)
        #expect(editor.contains("BRUFlowLayout"))
        #expect(!editor.contains("progressionChipLabel"))
        #expect(!editor.contains("plateChipLabel"))

        // Verify BRUChip is used (structural test)
        #expect(editor.contains("BRUChip"))

        // Verify SetRowsContainer is used
        #expect(editor.contains("SetRowsContainer"))
    }

    // MARK: - 6. Drag handle is typographic "⋮⋮" (NOT SF Symbol)

    @Test("dragHandleIsTypographic — RoutineExerciseCard uses '⋮⋮' text glyph not SF Symbol")
    func dragHandleIsTypographic() throws {
        let card = try source("RoutineExerciseCard.swift")
        // Typographic glyph must be present
        #expect(card.contains("\"⋮⋮\""))
        // SF Symbol drag handle must NOT be present
        #expect(!card.contains("line.3.horizontal"))
        #expect(!card.contains("arrow.up.arrow.down"))
    }

    // MARK: - 7. Discard confirmation copy verbatim

    @Test("discardConfirmationCopyVerbatim — all three strings present in RoutineBuilderView")
    func discardConfirmationCopyVerbatim() throws {
        let builder = try source("RoutineBuilderView.swift")
        #expect(builder.contains("\"Discard changes?\""))
        #expect(builder.contains("\"Your edits will not be saved.\""))
        #expect(builder.contains("\"Keep editing\""))
    }

    // MARK: - 8. TOP set row uses bruSignal tint (source-anchor)

    @Test("topSetRowUsesBruSignal — PerSetOverrideRow applies .bruSignal.opacity(0.06) for TOP")
    func topSetRowUsesBruSignal() throws {
        let row = try source("PerSetOverrideRow.swift")
        // Must contain bruSignal opacity tint for the TOP background
        #expect(row.contains("bruSignal") && row.contains("opacity"))
        // TOP label must be present
        #expect(row.contains("\"TOP\""))
        // isTop parameter must be present (structural)
        #expect(row.contains("isTop"))
    }
}
