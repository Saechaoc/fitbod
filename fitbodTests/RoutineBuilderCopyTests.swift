//
//  RoutineBuilderCopyTests.swift
//  fitbodTests
//
//  Verbatim-copy anchors for UI-SPEC § Routine builder + Prescription
//  editor strings. Mirrors the `RoutinesListCopyTests` pattern from
//  plan 03-01 — read the source files at runtime via `#filePath`-
//  relative URLs and grep for exact string literals so a careless
//  future edit can't silently mutate the copy contract without
//  tripping the test suite.
//
//  Strings anchored:
//    - RoutineBuilderView: "New Routine" / "Routine name" /
//      "Notes (optional)" / "Discard Changes?" / "Discard" /
//      "Keep Editing" / "Cancel" / "Save" / "Exercises" /
//      "Add an exercise to begin."
//    - InlineExerciseSearchRow: "Add an exercise"
//    - PrescriptionEditorRow: "Intent" / "Sets" / "Reps" /
//      "Target RPE" / "Progression" / "Rest" / "Track tempo" /
//      "Track partial reps" / "Auto warm-up" / "Available in Phase 3" /
//      "Per-set overrides" / "Add Override" / "Remove"
//    - Progression picker rows: "RPE Autoregulation" /
//      "Double Progression" / "Block Periodized" / "Hybrid"
//    - Intent picker rows: "Strength" / "Hypertrophy" / "Power" /
//      "Endurance" / "Technique"
//

import Foundation
import Testing
@testable import fitbod

@Suite("RoutineBuilderCopy")
struct RoutineBuilderCopyTests {

    @Test("verbatimCopy — UI-SPEC § Routine builder strings present in source")
    func verbatimCopy() throws {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Routines")

        // MARK: RoutineBuilderView
        let builder = try String(
            contentsOf: base.appendingPathComponent("RoutineBuilderView.swift"),
            encoding: .utf8
        )
        #expect(builder.contains("\"New Routine\""))
        #expect(builder.contains("\"Routine name\""))
        #expect(builder.contains("\"Notes (optional)\""))
        #expect(builder.contains("\"Discard Changes?\""))
        #expect(builder.contains("\"Discard\""))
        #expect(builder.contains("\"Keep Editing\""))
        #expect(builder.contains("\"Cancel\""))
        #expect(builder.contains("\"Save\""))
        #expect(builder.contains("\"Exercises\""))
        #expect(builder.contains("\"Add an exercise to begin.\""))

        // MARK: InlineExerciseSearchRow
        let inline = try String(
            contentsOf: base.appendingPathComponent("InlineExerciseSearchRow.swift"),
            encoding: .utf8
        )
        #expect(inline.contains("\"Add an exercise\""))

        // MARK: PrescriptionEditorRow
        let editor = try String(
            contentsOf: base.appendingPathComponent("PrescriptionEditorRow.swift"),
            encoding: .utf8
        )
        // Field labels
        #expect(editor.contains("\"Intent\""))
        #expect(editor.contains("\"Sets\""))
        #expect(editor.contains("\"Reps\""))
        #expect(editor.contains("\"Target RPE\""))
        #expect(editor.contains("\"Progression\""))
        #expect(editor.contains("\"Rest\""))
        #expect(editor.contains("\"Track tempo\""))
        #expect(editor.contains("\"Track partial reps\""))
        #expect(editor.contains("\"Auto warm-up\""))
        #expect(editor.contains("\"Available in Phase 3\""))
        #expect(editor.contains("\"Per-set overrides\""))
        #expect(editor.contains("\"Add Override\""))
        #expect(editor.contains("\"Remove\""))

        // Intent picker rows
        #expect(editor.contains("\"Strength\""))
        #expect(editor.contains("\"Hypertrophy\""))
        #expect(editor.contains("\"Power\""))
        #expect(editor.contains("\"Endurance\""))
        #expect(editor.contains("\"Technique\""))

        // Progression picker rows
        #expect(editor.contains("\"RPE Autoregulation\""))
        #expect(editor.contains("\"Double Progression\""))
        #expect(editor.contains("\"Block Periodized\""))
        #expect(editor.contains("\"Hybrid\""))
    }
}
