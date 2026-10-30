//
//  ExerciseProgressViewCopyTests.swift
//  fitbodTests
//
//  Wave-3 plan 06-05 — UI-SPEC verbatim copy anchor. Pins the
//  copywriting contract on the chart surface by greping the
//  source files of ExerciseProgressView + SeriesToggleChipRow
//  for the literal strings the UI-SPEC requires.
//
//  Single @Test that ascends via #filePath, reads the two source
//  files, and #expects each required string is present. Pattern
//  mirrors existing ExerciseHistoryViewCopyTests.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("ExerciseProgressView UI-SPEC verbatim copy")
struct ExerciseProgressViewCopyTests {

    @Test("verbatimCopy — every UI-SPEC string appears in the source")
    func verbatimCopy() throws {
        // Ascend from this file: Phase6 → fitbodTests → repo-root.
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent() // remove this file
            .deletingLastPathComponent() // remove Phase6/
            .deletingLastPathComponent() // remove fitbodTests/
        let progressViewURL = repoRoot
            .appendingPathComponent("fitbod/Progress/ExerciseProgressView.swift")
        let chipRowURL = repoRoot
            .appendingPathComponent("fitbod/Progress/SeriesToggleChipRow.swift")
        let seriesKindURL = repoRoot
            .appendingPathComponent("fitbod/Models/Enums/SeriesKind.swift")

        let progressViewSource = (try? String(contentsOf: progressViewURL, encoding: .utf8)) ?? ""
        let chipRowSource = (try? String(contentsOf: chipRowURL, encoding: .utf8)) ?? ""
        let seriesKindSource = (try? String(contentsOf: seriesKindURL, encoding: .utf8)) ?? ""
        let combined = progressViewSource + chipRowSource + seriesKindSource

        // Skip when host source unreachable (defensive against
        // sandbox surprises — the schema-names canary in 06-02
        // already covers this case).
        guard !combined.isEmpty else { return }

        // UI-SPEC verbatim strings.
        // Note: Phase 06.1-02 BRU reskin replaced the pre-BRU legend ("Solid: Strength",
        // "Top set series", "All-set average series") with BRU uppercase legends
        // ("HYPERTROPHY · N SESSIONS", "STRENGTH · N SESSIONS"). The 4-segment toggle
        // labels (e1RM, TOP SET, VOLUME, AVG RPE) replaced the prior chip row labels.
        // SeriesKind.displayLabel ("Top set", "All-set avg") continues to exist in
        // SeriesKind.swift as the chart foreground style scale keys.
        // T13 made the chips single-select, so one series always shows and the
        // empty-selection copy "Select a series to display." is gone.
        let required: [String] = [
            "Top set",        // SeriesKind.displayLabel — chart scale key
            "All-set avg",    // SeriesKind.displayLabel — chart scale key
            "Not enough data",
            "Log 2 sessions to see your trend.",
            "Sets above 10 reps aren't shown in e1RM.",
            "HYPERTROPHY",    // BRU legend row (replaced "Solid: Strength" pre-BRU)
            "STRENGTH",       // BRU legend row (replaced "Dashed: Hypertrophy" pre-BRU)
        ]

        var missing: [String] = []
        for str in required {
            if !combined.contains(str) {
                missing.append(str)
            }
        }
        let joined = missing.joined(separator: " | ")
        #expect(missing.isEmpty, "Missing UI-SPEC verbatim strings: \(joined)")
    }
}
