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
//    - PrescriptionEditorRow: "Sets" / "Reps" / "Target RPE" /
//      "Rest" / "Track tempo" / "Track partial reps" /
//      "Auto warm-up" / "Available in Phase 3" /
//      "Per-set overrides" / "Add Override" / "Remove"
//
//  Phase 3.1 (PIVOT-04 / D-10) — REMOVED from PrescriptionEditorRow:
//  "Intent" / "Progression" picker labels + the 5 Intent option
//  strings + the 4 ProgressionKind option strings. These moved to
//  RoutineBuilderView's header pickers; verbatim assertions for the
//  new home live in `RoutineBuilderHeaderPickersTests` (plan 03.1-04
//  shipped that suite). Plan 03.1-08 strips the assertions from this
//  file so a passing PrescriptionEditorRow source matches the new
//  8-row contract (Plan 05's canonical strip).
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
        // Phase 3.1 (PIVOT-04 / D-10): per-exercise Intent + Progression
        // pickers stripped. The remaining 8-row field-label set is
        // anchored here. The Intent + Progression copy contract for
        // the new RoutineBuilderView header pickers lives in
        // `RoutineBuilderHeaderPickersTests` (plan 03.1-04).
        let editor = try String(
            contentsOf: base.appendingPathComponent("PrescriptionEditorRow.swift"),
            encoding: .utf8
        )
        // Field labels — remaining 8 rows (Sets / Reps / Target RPE /
        // Rest / Tempo / Partials / Auto warm-up / Per-set overrides).
        #expect(editor.contains("\"Sets\""))
        #expect(editor.contains("\"Reps\""))
        #expect(editor.contains("\"Target RPE\""))
        #expect(editor.contains("\"Rest\""))
        #expect(editor.contains("\"Track tempo\""))
        #expect(editor.contains("\"Track partial reps\""))
        #expect(editor.contains("\"Auto warm-up\""))
        #expect(editor.contains("\"Available in Phase 3\""))
        #expect(editor.contains("\"Per-set overrides\""))
        #expect(editor.contains("\"Add Override\""))
        #expect(editor.contains("\"Remove\""))
    }
}
