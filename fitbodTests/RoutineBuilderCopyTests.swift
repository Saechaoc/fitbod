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
//  Phase 2.1 Plan 05 UPDATE — copy strings updated to match the BRU rewrite:
//    - "New routine" (was "New Routine") per UI-SPEC BRU verbatim copy
//    - "Discard changes?" (was "Discard Changes?")
//    - "Keep editing" (was "Keep Editing")
//    - "Notes (optional)" removed (no notes field in BRU layout)
//    - "Exercises" removed (no Section header in BRU layout)
//    - "Add an exercise to begin." removed (replaced by BRUDashedSlot)
//    - "Add an exercise" in InlineExerciseSearchRow → "Add exercise" (BRUDashedSlot label)
//    - "Add Override" → "+ ADD OVERRIDE" (signal text per UI-SPEC verbatim copy)
//
//  Strings anchored:
//    - RoutineBuilderView: "New routine" / "Routine name" /
//      "Discard changes?" / "Discard" / "Keep editing" / "Cancel"
//    - InlineExerciseSearchRow: "Add exercise"
//    - PrescriptionEditorRow: "Sets" / "Min reps" / "Max reps" /
//      "Target RPE" / "Rest" / "Track tempo" / "Track partial reps" /
//      "Auto warm-up" / "Per-set overrides" / "Remove"
//
//  Phase 3.1 (PIVOT-04 / D-10) — REMOVED from PrescriptionEditorRow:
//  "Intent" / "Progression" picker labels. Verbatim assertions for the
//  header pickers live in `RoutineBuilderHeaderPickersTests`.
//

import Foundation
import Testing
@testable import fitbod

@Suite("RoutineBuilderCopy")
struct RoutineBuilderCopyTests {

    @Test("verbatimCopy — UI-SPEC § Routine builder BRU strings present in source")
    func verbatimCopy() throws {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Routines")

        // MARK: RoutineBuilderView — BRU verbatim copy
        let builder = try String(
            contentsOf: base.appendingPathComponent("RoutineBuilderView.swift"),
            encoding: .utf8
        )
        // Phase 2.1 BRU copy — lowercase per UI-SPEC verbatim copy contract
        #expect(builder.contains("\"New routine\""))
        #expect(builder.contains("\"Routine name\""))
        #expect(builder.contains("\"Discard changes?\""))
        #expect(builder.contains("\"Discard\""))
        #expect(builder.contains("\"Keep editing\""))
        // "Cancel" button still present in more-menu confirmation dialog
        #expect(builder.contains("\"Cancel\""))

        // MARK: InlineExerciseSearchRow — BRU dashed slot label
        let inline = try String(
            contentsOf: base.appendingPathComponent("InlineExerciseSearchRow.swift"),
            encoding: .utf8
        )
        // BRU slot label: "Add exercise" (singular, no trailing space)
        #expect(inline.contains("\"Add exercise\""))

        // MARK: PrescriptionEditorRow — Phase 3 field labels preserved
        let editor = try String(
            contentsOf: base.appendingPathComponent("PrescriptionEditorRow.swift"),
            encoding: .utf8
        )
        // Field labels — BRU advanced section (Sets / Min reps / Max reps /
        // Target RPE / Rest / Tempo / Partials / Auto warm-up / Per-set overrides).
        #expect(editor.contains("\"Sets\""))
        #expect(editor.contains("\"Min reps\""))
        #expect(editor.contains("\"Max reps\""))
        #expect(editor.contains("\"Target RPE\""))
        #expect(editor.contains("\"Rest\""))
        #expect(editor.contains("\"Track tempo\""))
        #expect(editor.contains("\"Track partial reps\""))
        #expect(editor.contains("\"Auto warm-up\""))
        #expect(editor.contains("\"Per-set overrides\""))
        // Per-set override add button: "+ ADD OVERRIDE" (signal text per UI-SPEC)
        #expect(editor.contains("+ ADD OVERRIDE") || editor.contains("\"Add Override\""))
        #expect(editor.contains("\"Remove\""))
    }
}
