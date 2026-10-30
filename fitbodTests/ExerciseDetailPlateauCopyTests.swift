//
//  ExerciseDetailPlateauCopyTests.swift
//  fitbodTests
//
//  Ticket T64, finding F39. The Plateau Detection section on an exercise's
//  detail screen ends with a footer that states the global plateau
//  defaults. Settings has no control for either default, so no copy may
//  send the user there.
//
//  Reads ExerciseDetailView.swift through a #filePath-relative URL, the
//  way the other copy tests read their sources, and skips comment lines.
//

import Foundation
import Testing

@Suite("ExerciseDetailView plateau footer copy")
struct ExerciseDetailPlateauCopyTests {

    /// ExerciseDetailView.swift without its comment lines.
    private func codeOnly() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // remove this file
            .deletingLastPathComponent() // remove fitbodTests/
            .appendingPathComponent("fitbod/ExerciseLibrary/ExerciseDetailView.swift")
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("No string literal sends the user to Settings")
    func noLiteralSaysSetInSettings() throws {
        let code = try codeOnly()
        #expect(!code.contains("Set in Settings"),
                "Settings has no plateau control, so ExerciseDetailView must not say \"Set in Settings\"")
    }

    @Test("The plateau footer still states the global defaults and points to no setting")
    func footerStatesGlobalDefaults() throws {
        let footer = try #require(
            codeOnly().split(separator: "\n").first { $0.contains("\"Global defaults:") },
            "The Plateau Detection footer must still start with \"Global defaults:\""
        )
        #expect(footer.contains("settings.plateauWindowSessions"), "The footer must state the global window")
        #expect(footer.contains("settings.plateauTolerance"), "The footer must state the global tolerance")
        #expect(!footer.contains("Settings"), "The footer must not point to a setting: \(footer)")
    }
}
