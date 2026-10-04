//
//  RoutineBuilderCopyTests.swift
//  fitbodTests
//
//  Copy anchors for the routine builder + prescription editor (milestone 1,
//  Chalkline redesign — docs/design/screens.md § Routine builder). Reads
//  the sources by repository-relative path and checks the exact literals
//  the spec fixes, so a careless edit can't silently change them.
//
//  Supersedes the plan 03-02 anchors: the inline search row was replaced by
//  the multi-select exercise picker ("Add exercises"), validation moved
//  from a disabled Save to inline errors + a summary, and the
//  "Available in Phase 3" placeholder is gone (warm-ups ship).
//

import Foundation
import Testing
@testable import fitbod

@Suite("RoutineBuilderCopy")
struct RoutineBuilderCopyTests {

    @Test("verbatimCopy — routine builder strings present in source")
    func verbatimCopy() throws {
        let builder = try SourceFile.read("fitbod/Routines/RoutineBuilderView.swift")
        let builderStrings = [
            "\"NEW ROUTINE\"",
            "\"EDIT ROUTINE\"",
            "\"Routine name\"",
            "\"e.g. Push Day A\"",
            "\"Notes (optional)\"",
            "\"Add exercises\"",
            "\"Add exercises in the order you'll do them. You can reorder later.\"",
            "\"Reorder\"",
            "\"Discard changes?\"",
            "\"Discard\"",
            "\"Keep editing\"",
            "\"Cancel\"",
            "\"Save\"",
            "\"Save routine first\"",
        ]
        for string in builderStrings {
            #expect(builder.contains(string), "RoutineBuilderView.swift should contain \(string)")
        }

        // Validation copy lives with the draft so it is unit-testable.
        let draft = try SourceFile.read("fitbod/Routines/RoutineDraft.swift")
        #expect(draft.contains("\"Give this routine a name.\""))
        #expect(draft.contains("\"Add at least one exercise.\""))

        let editor = try SourceFile.read("fitbod/Routines/PrescriptionEditorRow.swift")
        let editorStrings = [
            // Field labels
            "\"Sets\"", "\"Reps\"", "\"Target RPE\"", "\"Off\"", "\"Rest\"",
            "\"Intent\"", "\"Progression\"", "\"Advanced\"",
            "\"Track tempo\"", "\"Track partial reps\"", "\"Auto warm-up\"",
            "\"Warm-up settings…\"", "\"Per-set overrides\"", "\"Add override\"",
            // Progression picker rows
            "\"Double progression\"", "\"RPE autoregulation\"", "\"Block periodized\"", "\"Hybrid\"",
        ]
        for string in editorStrings {
            #expect(editor.contains(string), "PrescriptionEditorRow.swift should contain \(string)")
        }
        // Intent picker rows are the enum's raw values, capitalized.
        #expect(editor.contains("intent.rawValue.capitalized"))
        #expect(Intent.allCases.map { $0.rawValue.capitalized } == ["Strength", "Hypertrophy", "Power", "Endurance", "Technique"])

        let card = try SourceFile.read("fitbod/Routines/RoutineExerciseCard.swift")
        for string in ["\"Move up\"", "\"Move down\"", "\"Duplicate\"", "\"Add to superset…\"", "\"Remove from superset\"", "\"Remove\""] {
            #expect(card.contains(string), "RoutineExerciseCard.swift should contain \(string)")
        }
    }

    @Test("RoutineDraft issues — name and exercises, in display order")
    @MainActor
    func draftIssues() {
        let draft = RoutineDraft()
        draft.name = "   "
        #expect(draft.issues == [.missingName, .noExercises])
        #expect(draft.issueSummary == "Fix 2 things to save: name the routine and add at least one exercise.")

        draft.name = "Upper A"
        #expect(draft.issues == [.noExercises])
        #expect(draft.issueSummary == "Fix this to save: add at least one exercise.")
    }
}
