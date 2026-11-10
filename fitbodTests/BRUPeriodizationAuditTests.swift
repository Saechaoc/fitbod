// BRUPeriodizationAuditTests.swift
// fitbodTests
//
// Phase 04.1 Plan 08 — Wave 7: Final audit re-run for Phase 4 BRU visual rewrite.
//
// PURPOSE: Programmatically grep the Phase 4 surface files still in the app
// (`surfaces` below) and assert ZERO occurrences of the 25 forbidden
// Apple-HIG patterns enumerated in 04.1-PATTERNS.md lines 56-84.
//
// Run via:
//   xcodebuild test -scheme fitbod -only-testing:fitbodTests/BRUPeriodizationAuditTests

import Foundation
import Testing

// MARK: - BRUPeriodizationAuditTests

@Suite("BRUPeriodizationAudit", .serialized)
struct BRUPeriodizationAuditTests {

    // MARK: - Path Helpers

    /// Computes absolute path to a Periodization source file from #filePath ascent.
    private func sourcePath(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("fitbod")
            .appendingPathComponent("Periodization")
            .appendingPathComponent(filename)
    }

    // MARK: - Comment-Stripping Helper

    /// Returns non-comment lines from a Swift source file, preserving line indices.
    /// Strips:
    ///   - Lines whose first non-whitespace characters are "//"
    ///   - Lines inside /* ... */ block comment spans (balance-counter)
    ///
    /// Returns tuples of (originalLineIndex, lineText) so violations can cite line numbers.
    private func nonCommentLines(of source: String) -> [(lineIndex: Int, text: String)] {
        var results: [(lineIndex: Int, text: String)] = []
        var inBlockComment = false

        for (idx, line) in source.components(separatedBy: "\n").enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect entry/exit from /* */ block comment
            if !inBlockComment {
                if trimmed.hasPrefix("/*") {
                    inBlockComment = !trimmed.contains("*/")
                    continue
                }
                if trimmed.hasPrefix("//") {
                    continue
                }
                results.append((idx, line))
            } else {
                if trimmed.contains("*/") {
                    inBlockComment = false
                }
                // Skip lines inside block comment
            }
        }
        return results
    }

    // MARK: - Forbidden Patterns Table

    /// The 25 forbidden Apple-HIG patterns from 04.1-PATTERNS.md lines 56-84,
    /// each as (name, regex).
    private static let forbiddenPatterns: [(name: String, regex: String)] = [
        // 1. Form + Section (Apple inset-grouped — banned per UI-REVIEW Pillar 2 Fix 3)
        ("Form {", #"Form \{"#),
        ("Section(", #"\bSection\("#),

        // 2. RoundedRectangle with corner radius (04-UI-SPEC line 36)
        ("RoundedRectangle(cornerRadius:", #"RoundedRectangle\(cornerRadius:"#),

        // 3. clipShape with forbidden shapes
        ("clipShape(RoundedRectangle/Capsule/Circle)", #"\.clipShape\(RoundedRectangle|\.clipShape\(Capsule\(\)|\.clipShape\(Circle\(\)|\.clipShape\(\.capsule\)"#),

        // 4. Capsule() as visual element
        ("Capsule()", #"\bCapsule\(\)"#),

        // 5. Color.accentColor / Color("AccentColor")
        ("Color.accentColor", #"Color\.accentColor|Color\("AccentColor"\)|\.tint\(\.accentColor\)"#),

        // 6. Color.red / Color(.systemRed)
        ("Color.red / Color(.systemRed)", #"Color\.red\b|Color\(\.systemRed\)"#),

        // 7. Color.yellow / Color(.systemYellow)
        ("Color.yellow / Color(.systemYellow)", #"Color\.yellow\b|Color\(\.systemYellow\)"#),

        // 8. Color(.systemGray6) / Color(.secondarySystemGroupedBackground) / Color(.systemBackground)
        ("Color(.system*) background tokens", #"Color\(\.systemGray6\)|Color\(\.secondarySystemGroupedBackground\)|Color\(\.systemBackground\)"#),

        // 9. Color.white foreground on chip text
        ("Color.white", #"\bColor\.white\b"#),

        // 10. Apple semantic font styles (Pillar 4)
        (".font(.body)", #"\.font\(\.body\)"#),
        (".font(.caption)", #"\.font\(\.caption\b"#),
        (".font(.headline)", #"\.font\(\.headline\)"#),
        (".font(.title)", #"\.font\(\.title\b"#),
        (".font(.subheadline)", #"\.font\(\.subheadline\)"#),

        // 11. Image(systemName:) forbidden SF Symbols (per Pillar 6 table)
        ("Image(systemName: \"line.3.horizontal\")", #"Image\(systemName:\s*"line\.3\.horizontal"\)"#),
        ("Image(systemName: \"ellipsis.circle\")", #"Image\(systemName:\s*"ellipsis\.circle"\)"#),
        ("Image(systemName: \"exclamationmark.triangle\")", #"Image\(systemName:\s*"exclamationmark\.triangle"\)"#),
        ("Image(systemName: \"xmark\")", #"Image\(systemName:\s*"xmark"\)"#),
        ("Image(systemName: \"chevron.right\")", #"Image\(systemName:\s*"chevron\.right"\)"#),
        ("Image(systemName: \"trash\")", #"Image\(systemName:\s*"trash"\)"#),

        // 12. .buttonStyle(.borderedProminent) / .tint(.accentColor)
        (".buttonStyle(.borderedProminent)", #"\.buttonStyle\(\.borderedProminent\)|\.tint\(\.accentColor\)"#),

        // 13. .navigationTitle (replaced by BRUHeaderBar)
        (".navigationTitle", #"\.navigationTitle\s*\("#),

        // 14. Divider() (replaced by BRUDivider or Rectangle+bruHair)
        ("Divider()", #"\bDivider\(\)"#),
    ]

    // MARK: - 1. testForbiddenPatternsAcrossAllPhase4Surfaces

    @Test("testForbiddenPatternsAcrossAllPhase4Surfaces — 0 matches for all 25 forbidden patterns across the Phase 4 surfaces")
    func testForbiddenPatternsAcrossAllPhase4Surfaces() throws {
        let surfaces = [
            "MesocycleWeekPage.swift",
            // BlockBuilderView.swift retired from this audit in quick task 260528-vi2:
            // the New Block screen was redesigned to the rounded-card final-design.png
            // contract (warm cards, RoundedRectangle, chevron) which intentionally
            // supersedes the Phase 04.1 brutalist "sharp-corners / no RoundedRectangle"
            // contract this audit enforces. It is no longer one of these surfaces.
            "BlockReviewView.swift",
            "BlockOverviewScreen.swift",
        ]

        var allViolations: [String] = []

        for filename in surfaces {
            let fileURL = sourcePath(filename)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let filtered = nonCommentLines(of: source)

            for (name, regexPattern) in Self.forbiddenPatterns {
                let regex = try NSRegularExpression(pattern: regexPattern)

                for (lineIdx, lineText) in filtered {
                    let nsRange = NSRange(lineText.startIndex..., in: lineText)
                    guard regex.firstMatch(in: lineText, range: nsRange) != nil else { continue }

                    let violation = "Forbidden pattern '\(name)' in \(filename) at line \(lineIdx + 1): \(lineText.trimmingCharacters(in: .whitespaces))"
                    allViolations.append(violation)
                }
            }
        }

        #expect(
            allViolations.isEmpty,
            "BRU audit violations found — re-run the relevant Phase 04.1 plan to close the gap:\n\(allViolations.joined(separator: "\n"))"
        )
    }

    // MARK: - 2. testNetNewBlockOverviewScreenExists

    @Test("testNetNewBlockOverviewScreenExists — file exists + public struct + ≥4 BRU primitives")
    func testNetNewBlockOverviewScreenExists() throws {
        let fileURL = sourcePath("BlockOverviewScreen.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        #expect(source.contains("public struct BlockOverviewScreen"),
                "BlockOverviewScreen.swift must declare public struct BlockOverviewScreen (CONTEXT D-10)")

        let bruPrimitives = ["BRUHeaderBar", "BRUSectionHead", "BRUButton", "BRUChip"]
        let primitiveCount = bruPrimitives.filter { source.contains($0) }.count
        #expect(primitiveCount >= 4,
                "BlockOverviewScreen.swift must compose ≥4 BRU primitives (BRUHeaderBar + BRUSectionHead + BRUButton + BRUChip); found \(primitiveCount) of \(bruPrimitives)")
    }

    // MARK: - 3. testAccessibilityLabelsPopulated

    @Test("testAccessibilityLabelsPopulated — BlockOverviewScreen carries accessibilityLabel")
    func testAccessibilityLabelsPopulated() throws {
        // BlockOverviewScreen.swift: any .accessibilityLabel( call (CONTEXT D-15)
        let overviewURL = sourcePath("BlockOverviewScreen.swift")
        let overviewSource = try String(contentsOf: overviewURL, encoding: .utf8)
        #expect(overviewSource.contains(".accessibilityLabel("),
                "BlockOverviewScreen.swift must carry .accessibilityLabel( per CONTEXT D-15")
    }
}
