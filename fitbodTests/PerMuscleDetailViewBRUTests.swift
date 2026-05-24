//
//  PerMuscleDetailViewBRUTests.swift
//  fitbodTests
//
//  Phase 5.1-06 Task 1 — BRU verbatim-copy + banned-token guard tests
//  for the reskinned PerMuscleDetailView.
//
//  Tests 1 & 2 assert verbatim copy strings are present in source.
//  Tests 3 & 4 assert data-layer declarations and banned tokens via
//  FileManager.contents (source-text assertions — fast, no simulator).
//
//  Project root is derived from #filePath at compile time (same pattern
//  as BRUGrepAuditTests).
//

import Foundation
import Testing

@Suite("PerMuscleDetailView BRU Tests")
struct PerMuscleDetailViewBRUTests {

    // MARK: - Helpers

    private func projectRoot(file: StaticString = #filePath) -> URL {
        let testFileURL = URL(fileURLWithPath: String(describing: file))
        // fitbodTests/PerMuscleDetailViewBRUTests.swift → up 2 = project root
        return testFileURL
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
    }

    private func sourceText(file: StaticString = #filePath) -> String {
        let url = projectRoot(file: file)
            .appendingPathComponent("fitbod/Fatigue/PerMuscleDetailView.swift")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func codeOnlyText(from src: String) -> String {
        src.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - Test 1: Verbatim section headers

    @Test("Section headers match UI-SPEC §Copywriting Contract verbatim")
    func sectionHeadersVerbatim() {
        let src = sourceText()
        #expect(!src.isEmpty, "Could not read PerMuscleDetailView.swift")

        // Four BRUSectionHead titles per UI-SPEC §PerMuscleDetailView table
        #expect(src.contains("\"This Week\""),
                "Missing BRUSectionHead(\"This Week\")")
        #expect(src.contains("\"Contributing Exercises\""),
                "Missing BRUSectionHead(\"Contributing Exercises\")")
        #expect(src.contains("\"Frequency This Week\""),
                "Missing BRUSectionHead(\"Frequency This Week\")")
        #expect(src.contains("\"Adjust Targets\""),
                "Missing BRUSectionHead(\"Adjust Targets\")")
    }

    // MARK: - Test 2: Verbatim empty state

    @Test("Contributing-exercises empty state copy matches UI-SPEC verbatim")
    func contributingExercisesEmptyStateCopy() {
        let src = sourceText()
        #expect(!src.isEmpty, "Could not read PerMuscleDetailView.swift")

        // UI-SPEC §PerMuscleDetailView: "No exercises contributed to {muscle.displayName} this week."
        #expect(src.contains("No exercises contributed to") &&
                src.contains("this week."),
                "Empty state copy must read 'No exercises contributed to ... this week.'")
    }

    // MARK: - Test 3: Data layer preserved

    @Test("@Query + @Environment declarations preserved in rewritten file")
    func dataLayerPreserved() {
        let src = sourceText()
        #expect(!src.isEmpty, "Could not read PerMuscleDetailView.swift")

        #expect(src.contains("@Query") && src.contains("MuscleGroup"),
                "@Query<MuscleGroup> declaration must be present")
        #expect(src.contains("MuscleVolumeTarget"),
                "@Query<MuscleVolumeTarget> declaration must be present")
        #expect(src.contains("@Environment") && src.contains("modelContext"),
                "@Environment(\\.modelContext) must be present")
    }

    // MARK: - Test 4: Zero banned tokens

    @Test("Zero banned tokens in reskinned PerMuscleDetailView.swift")
    func noBannedTokens() {
        let src = sourceText()
        #expect(!src.isEmpty, "Could not read PerMuscleDetailView.swift")

        let code = codeOnlyText(from: src)

        #expect(!code.contains("Color.accentColor"),
                "Banned: Color.accentColor")
        #expect(!code.contains("Color(.system"),
                "Banned: Color(.system*)")
        #expect(!code.contains("RoundedRectangle(cornerRadius"),
                "Banned: RoundedRectangle(cornerRadius:)")
        #expect(!code.contains("Capsule()"),
                "Banned: Capsule()")
        #expect(!code.contains(".navigationTitle("),
                "Banned: .navigationTitle(")
        #expect(!code.contains("List(.insetGrouped"),
                "Banned: List(.insetGrouped)")
        #expect(!code.contains("Image(systemName:"),
                "Banned: Image(systemName:)")
    }
}
