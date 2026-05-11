//
//  ExerciseHistoryViewCopyTests.swift
//  fitbodTests
//
//  Single test function — pins the UI-SPEC § Exercise history view
//  verbatim copy strings against the source files in
//  `fitbod/ExerciseLibrary/`.
//
//  The Phase 1 convention for copy-anchor tests (see e.g.
//  `RoutinesListCopyTests`, `RoutineBuilderCopyTests`,
//  `SessionLoggerCopyTests`, `RestTimerOverlayCopyTests`): read the
//  view's source file from disk via `#filePath` ascent and `#expect`
//  on `contains(...)`. The test never instantiates the view — it just
//  guards that someone editing the file doesn't silently drift away
//  from the UI-SPEC's normative copy.
//
//  Why anchor copy in tests at all? Because the UI-SPEC's Copywriting
//  Contract is normative — "the executor copies them verbatim from
//  this file into the SwiftUI source" — and the only mechanical way
//  to keep that contract from rotting over months of refactors is to
//  fail the build when it does.
//

import Foundation
import Testing
@testable import fitbod

@Suite("ExerciseHistoryViewCopy")
struct ExerciseHistoryViewCopyTests {

    @Test("verbatimCopy — UI-SPEC § Exercise history strings present in source")
    func verbatimCopy() throws {
        // Ascend from this test file at fitbodTests/.../*.swift to the
        // repo root, then descend into fitbod/ExerciseLibrary/.
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/ExerciseLibrary")

        let view = try String(
            contentsOf: base.appendingPathComponent("ExerciseHistoryView.swift"),
            encoding: .utf8
        )
        #expect(view.contains("\"History\""))
        #expect(view.contains("\"No logged sets yet\""))
        #expect(view.contains("\"Log this exercise in a workout to see history.\""))
        #expect(view.contains("\"No \\(intent!.rawValue.capitalized) sets\""))
        #expect(view.contains("\"Try a different intent filter.\""))
        #expect(view.contains("\"Show All\""))

        let chips = try String(
            contentsOf: base.appendingPathComponent("IntentFilterChipRow.swift"),
            encoding: .utf8
        )
        #expect(chips.contains("\"All\""))
        #expect(chips.contains("ForEach(Intent.allCases"))

        let row = try String(
            contentsOf: base.appendingPathComponent("ExerciseHistoryRow.swift"),
            encoding: .utf8
        )
        // Verifies the primary line format "{w} × {reps} @ RPE {N}" is built.
        #expect(row.contains("× \\(setEntry.reps)"))
        #expect(row.contains("@ RPE"))
    }
}
