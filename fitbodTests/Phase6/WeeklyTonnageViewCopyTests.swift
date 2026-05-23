//
//  WeeklyTonnageViewCopyTests.swift
//  fitbodTests
//
//  Wave-4 plan 06-06 — verbatim-copy anchor. Reads
//  `WeeklyTonnageView.swift` + `WeeklyTonnageFilterChips.swift` +
//  `WeekDetailView.swift` from disk via `#filePath` ascent and pins
//  every UI-SPEC § "WeeklyTonnageView copy table" string into the
//  build via `#expect(source.contains(...))`.
//
//  The Phase 1 convention for copy-anchor tests (see e.g.
//  `ExerciseHistoryViewCopyTests`): the test never instantiates a
//  view — it just guards that someone editing the file doesn't
//  silently drift away from the UI-SPEC's normative copy.
//

import Foundation
import Testing
@testable import fitbod

@Suite("WeeklyTonnageViewCopy")
struct WeeklyTonnageViewCopyTests {

    @Test("verbatimCopy — UI-SPEC strings present across WeeklyTonnageView surfaces")
    func verbatimCopy() throws {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Progress")

        let view = try String(
            contentsOf: base.appendingPathComponent("WeeklyTonnageView.swift"),
            encoding: .utf8
        )
        let chips = try String(
            contentsOf: base.appendingPathComponent("WeeklyTonnageFilterChips.swift"),
            encoding: .utf8
        )
        let detail = try String(
            contentsOf: base.appendingPathComponent("WeekDetailView.swift"),
            encoding: .utf8
        )

        // Time-range chip labels
        #expect(chips.contains("\"Last 8 wk\""))
        #expect(chips.contains("\"Last 26 wk\""))
        #expect(chips.contains("\"All time\""))

        // Block-phase chips + disabled-footer copy
        #expect(chips.contains("\"Accumulation\""))
        #expect(chips.contains("\"Intensification\""))
        #expect(chips.contains("\"Realization\""))
        #expect(chips.contains("\"Deload\""))
        #expect(chips.contains("\"No block data yet — define a block in Routines.\""))

        // Muscle-chip footer
        #expect(chips.contains("\"Tap a muscle to break the bar by stimulus.\""))

        // Chart-host strings
        #expect(view.contains("\"Previous best\""))
        #expect(view.contains("\"Not enough data\""))
        #expect(view.contains("\"Log one week of training to see tonnage.\""))
        #expect(view.contains("\"Weekly Tonnage\""))
        #expect(view.contains("kg over"))

        // Week-detail nav title + empty state copy
        #expect(detail.contains("\"Week of"))
    }
}
