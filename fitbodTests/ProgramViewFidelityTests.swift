//
//  ProgramViewFidelityTests.swift
//  fitbodTests
//
//  Program's template rows. Its fonts load with every BRU face
//  (BRUFoundationsTests); the look itself is checked on the simulator, not
//  pinned in tests.
//

import Foundation
import Testing
@testable import fitbod

@Suite("ProgramView fidelity")
struct ProgramViewFidelityTests {

    @MainActor
    @Test("Each template row shows only its template's weeks, name and phases")
    func templateRowsComeFromTheirTemplates() {
        let rows = ProgramView.templateRows

        #expect(rows.map(\.template.name) == BlockTemplates.catalog.map(\.name))
        for row in rows {
            let weeks = row.template.phases.reduce(0) { $0 + $1.weeks }
            let phases = row.template.phases.map { "\($0.kind.shortLabel) \($0.weeks)" }
            #expect(row.weeks == "\(weeks)W")
            #expect(row.title == row.template.name)
            #expect(row.phases == phases.joined(separator: " · "))
        }
        #expect(rows.map(\.weeks) == ["8W", "8W", "8W", "4W"])
        #expect(rows.map(\.phases) == [
            "ACCUM 5 · INTNS 2 · DELOAD 1",
            "ACCUM 4 · INTNS 2 · REAL 1 · DELOAD 1",
            "ACCUM 3 · INTNS 3 · REAL 1 · DELOAD 1",
            "ACCUM 1 · INTNS 1 · REAL 1 · DELOAD 1",
        ])
    }
}
