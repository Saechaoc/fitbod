//
//  PRsAndComparisonCopyTests.swift
//  fitbodTests
//
//  Wave-4 plan 06-07 — verbatim-copy anchor. Reads
//  `ExercisePRsView.swift` + `SessionComparisonView.swift` +
//  `InSessionPRBanner.swift` from disk via `#filePath` ascent and
//  pins every UI-SPEC string into the build via
//  `#expect(source.contains(...))`.
//
//  T102 adds Compare's numbers: e1RM changes to one decimal, and set
//  weights and weight changes as logged.
//

import Foundation
import Testing
@testable import fitbod

@Suite("PRsAndComparisonCopy")
struct PRsAndComparisonCopyTests {

    @Test("verbatimCopy — UI-SPEC strings present across PR + Comparison + Banner sources")
    func verbatimCopy() throws {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let prsView = try String(
            contentsOf: base.appendingPathComponent("fitbod/Progress/ExercisePRsView.swift"),
            encoding: .utf8
        )
        let compView = try String(
            contentsOf: base.appendingPathComponent("fitbod/Progress/SessionComparisonView.swift"),
            encoding: .utf8
        )
        let banner = try String(
            contentsOf: base.appendingPathComponent("fitbod/Sessions/InSessionPRBanner.swift"),
            encoding: .utf8
        )

        // ExercisePRsView — section headers
        #expect(prsView.contains("\"Weight\""))
        #expect(prsView.contains("\"Reps\""))
        #expect(prsView.contains("\"Volume\""))
        #expect(prsView.contains("\"e1RM\""))

        // ExercisePRsView — rep-bucket sub-headers (EN-dash, NOT hyphen)
        #expect(prsView.contains("\"1–6 reps\""))
        #expect(prsView.contains("\"7–10 reps\""))
        #expect(prsView.contains("\"11+ reps\""))

        // ExercisePRsView — e1RM suppression caption (UI-SPEC verbatim)
        #expect(prsView.contains("\"Suppressed for reps above 10.\""))

        // ExercisePRsView — empty state (UI-SPEC verbatim)
        #expect(prsView.contains("\"No PRs yet\""))
        #expect(prsView.contains("\"Complete a working set to set your first record.\""))

        // ExercisePRsView — IntentFilter labels (UI-SPEC verbatim)
        #expect(prsView.contains("\"Strength\""))
        #expect(prsView.contains("\"Hypertrophy\""))
        #expect(prsView.contains("\"All\""))

        // ExercisePRsView — nav title (UI-SPEC verbatim)
        #expect(prsView.contains("\"Personal Records\""))

        // SessionComparisonView — nav title (UI-SPEC verbatim)
        #expect(compView.contains("\"This week vs last week\""))

        // SessionComparisonView — empty state (UI-SPEC verbatim)
        #expect(compView.contains("\"No comparable session\""))
        #expect(compView.contains("\"Log this routine again next week to compare.\""))

        // SessionComparisonView — no-prior-data inline label
        #expect(compView.contains("no prior data"))

        // InSessionPRBanner — PR chip labels (UI-SPEC verbatim)
        // Phase 06.1-06 BRU reskin changed PR kind labels to all-caps:
        // "Weight PR" → "WEIGHT PR", "Rep PR" → "REP PR", etc.
        #expect(banner.contains("WEIGHT PR") || banner.contains("\"Weight PR\""))
        #expect(banner.contains("REP PR") || banner.contains("\"Rep PR\""))
        #expect(banner.contains("VOLUME PR") || banner.contains("\"Volume PR\""))
        #expect(banner.contains("E1RM PR") || banner.contains("e1RM PR") || banner.contains("\"e1RM PR\""))
    }

    /// The estimate keeps every digit of its formula, which "%g" printed,
    /// such as "+3.16667 e1RM lb". A change under 0.05 reads "0", which
    /// Compare shows as no change.
    @MainActor
    @Test("Compare reads e1RM changes to one decimal and weights as logged")
    func e1RMChangesReadToOneDecimal() {
        #expect(SessionComparisonView.formatE1RMChange(3.16667) == "3.2")
        #expect(SessionComparisonView.formatE1RMChange(2.8125) == "2.8")
        #expect(SessionComparisonView.formatE1RMChange(5) == "5")
        #expect(SessionComparisonView.formatE1RMChange(0.04) == "0")
        #expect(SessionComparisonView.formatWeight(102.25) == "102.25")
    }
}
