//
//  OptionalRowRenderingTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-02 — pins the SESS-07 / SESS-08 conditional row
//  rendering contract on `SessionExerciseCard`. The three opt-in rows
//  must NOT render unconditionally:
//
//    - `TempoEntryRow`        — only when `sessionExercise.tracksTempo`
//    - `PartialRepsRow`       — only when `sessionExercise.tracksPartialReps`
//    - `ClusterSubRepChipRow` — only when `set.setType == .restPause`
//
//  Visual rendering is not hermetic (SwiftUI's view-tree is opaque),
//  so this suite anchors the gate predicates at the source level via
//  on-disk substring matches against `SessionExerciseCard.swift`. The
//  underlying *data path* (the `tracksTempo` / `tracksPartialReps`
//  fields land on SessionExercise + are snapshotted by SessionFactory)
//  is verified by `SessionFactoryTests/snapshotsTracksTempoAndTracksPartialReps`.
//

import Foundation
import Testing
@testable import fitbod

@Suite("OptionalRowRendering")
struct OptionalRowRenderingTests {

    /// Loads `SessionExerciseCard.swift` from the source tree.
    private func loadCardSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions/SessionExerciseCard.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - SESS-07 tempo gate

    @Test("tempoRowRendersWhenSnapshottedFlag — gated on sessionExercise.tracksTempo")
    func tempoRowRendersWhenSnapshottedFlag() throws {
        let src = try loadCardSource()

        // The conditional render predicate is anchored verbatim.
        #expect(src.contains("if sessionExercise.tracksTempo"))
        // And the view it instantiates is the right one.
        #expect(src.contains("TempoEntryRow(entry: set)"))
    }

    // MARK: - SESS-08 partial reps gate

    @Test("partialsRowRendersWhenSnapshottedFlag — gated on sessionExercise.tracksPartialReps")
    func partialsRowRendersWhenSnapshottedFlag() throws {
        let src = try loadCardSource()

        #expect(src.contains("if sessionExercise.tracksPartialReps"))
        #expect(src.contains("PartialRepsRow(entry: set)"))
    }

    // MARK: - SESS-08 cluster chip gate

    @Test("clusterChipRowRendersWhenSetTypeRestPause — gated on set.setType == .restPause")
    func clusterChipRowRendersWhenSetTypeRestPause() throws {
        let src = try loadCardSource()

        #expect(src.contains("if set.setType == .restPause"))
        #expect(src.contains("ClusterSubRepChipRow(entry: set)"))
    }
}
