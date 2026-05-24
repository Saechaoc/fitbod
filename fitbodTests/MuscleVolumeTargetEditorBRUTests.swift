//
//  MuscleVolumeTargetEditorBRUTests.swift
//  fitbodTests
//
//  Phase 5.1-06 Task 2 — BRU verbatim-copy + banned-token guard tests
//  for the reskinned MuscleVolumeTargetEditor.
//
//  Tests 1-3 assert verbatim copy strings present in source (source-text
//  assertions via FileManager.contents — fast, no simulator required).
//  Test 4 asserts row trailing preview format and no banned tokens.
//
//  Project root is derived from #filePath at compile time (same pattern
//  as BRUGrepAuditTests).
//

import Foundation
import Testing

@Suite("MuscleVolumeTargetEditor BRU Tests")
struct MuscleVolumeTargetEditorBRUTests {

    // MARK: - Helpers

    private func projectRoot(file: StaticString = #filePath) -> URL {
        let testFileURL = URL(fileURLWithPath: String(describing: file))
        // fitbodTests/MuscleVolumeTargetEditorBRUTests.swift → up 2 = project root
        return testFileURL
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
    }

    private func sourceText(file: StaticString = #filePath) -> String {
        let url = projectRoot(file: file)
            .appendingPathComponent("fitbod/Settings/MuscleVolumeTargetEditor.swift")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func codeOnlyText(from src: String) -> String {
        src.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - Test 1: Verbatim navigation header

    @Test("BRUHeaderBar center reads 'Volume Targets' verbatim")
    func verbatimHeaderTitle() {
        let src = sourceText()
        #expect(!src.isEmpty, "Could not read MuscleVolumeTargetEditor.swift")

        // BRUHeaderBar center: "Volume Targets"
        #expect(src.contains("\"Volume Targets\""),
                "BRUHeaderBar center must read 'Volume Targets' verbatim")
    }

    // MARK: - Test 2: Verbatim footer

    @Test("Footer Text reads verbatim per UI-SPEC §MuscleVolumeTargetEditor")
    func verbatimFooter() {
        let src = sourceText()
        #expect(!src.isEmpty, "Could not read MuscleVolumeTargetEditor.swift")

        // UI-SPEC §MuscleVolumeTargetEditor footer row:
        // "MEV / MAV / MRV — weekly working sets. Seeded from RP volume landmarks."
        #expect(src.contains("MEV / MAV / MRV — weekly working sets. Seeded from RP volume landmarks."),
                "Footer must read 'MEV / MAV / MRV — weekly working sets. Seeded from RP volume landmarks.' verbatim")
    }

    // MARK: - Test 3: Verbatim reset alert

    @Test("Reset alert title, body, buttons match UI-SPEC verbatim")
    func verbatimResetAlert() {
        let src = sourceText()
        #expect(!src.isEmpty, "Could not read MuscleVolumeTargetEditor.swift")

        #expect(src.contains("Reset all volume targets?"),
                "Alert title must read 'Reset all volume targets?' verbatim")
        #expect(src.contains("Your custom values will be replaced with RP defaults for all 17 muscles."),
                "Alert body must be verbatim")
        #expect(src.contains("\"Reset All\""),
                "Destructive button must read 'Reset All'")
        #expect(src.contains("\"Cancel\""),
                "Cancel button must read 'Cancel'")
    }

    // MARK: - Test 4: Row trailing preview format + no banned tokens

    @Test("Row trailing preview uses mev / mav / mrv format and zero banned tokens")
    func rowTrailingPreviewAndNoBannedTokens() {
        let src = sourceText()
        #expect(!src.isEmpty, "Could not read MuscleVolumeTargetEditor.swift")

        // Row trailing preview format: "{mev} / {mav} / {mrv}"
        // Source uses string interpolation: "\(t.mev) / \(t.mav) / \(t.mrv)"
        let hasMevMavMrv = src.contains(".mev) / \\(") ||
            (src.contains("mev) / ") && src.contains("mav) / ") && src.contains("mrv)"))
        #expect(hasMevMavMrv,
                "Row trailing preview must follow '{mev} / {mav} / {mrv}' format")

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
        #expect(!code.contains(".foregroundStyle(.red)"),
                "Banned: .foregroundStyle(.red) — use BRUButton(kind: .signal)")
    }
}
