// BRUGrepAuditTests.swift
// fitbodTests
//
// Phase 2.1 Plan 11 — final guardrail for the BRU visual rewrite.
// UI-REVIEW Wave G items 64-72 / UI-SPEC line 778.
//
// PURPOSE: Programmatically grep every Phase 2 surface file under the
// audited directories and assert ZERO occurrences of banned legacy
// UIKit/HIG tokens. If a future bugfix accidentally re-introduces
// Color.accentColor or Image(systemName:) into a BRU surface, this
// test fires — catching the regression in CI rather than via a manual
// gsd-ui-checker run.
//
// AUDITED DIRECTORIES (Phase 2 surfaces):
//   fitbod/Routines/
//   fitbod/Sessions/      (includes Sessions/RestTimer/)
//   fitbod/Views/
//   FitbodWidgets/        (4 widget files rewritten in Plan 02.1-09)
//
// EXCLUDED FILES: Out-of-scope Phase 3/5/6 surfaces whose BRU rewrite
// is deferred. If a NEW surface file falls under one of the audited
// directories but is OUT of Phase 2.1 scope, add its path (relative to
// project root) to `excludedFileSuffixes` below.
//
// NOTE: These tests run against the source tree, not compiled output.
// They use FileManager to walk the source directories and String regex
// matching for banned token detection.

import Testing
import Foundation

@Suite("BRU Grep Audit — Phase 2 Surface Banned Token Check")
struct BRUGrepAuditTests {

    // MARK: - Configuration

    /// Suffixes (relative path fragments) of files excluded from the audit.
    /// Phase 3 / Phase 5 / Phase 6 surfaces not rewritten in Phase 2.1.
    // Phase 3 surfaces audited by Phase3BRUGrepAuditTests starting Phase 03.2 / 2026-05-24;
    // their reskins removed them from this exclusion list.
    private static let excludedFileSuffixes: Set<String> = [
        // Phase 6 surfaces deferred per UI-SPEC line 721
        "fitbod/Sessions/InSessionPRBanner.swift",
        // Behavior files (not views)
        "fitbod/Sessions/SessionFactory.swift",
        "fitbod/Sessions/PreviousMatchingIntent.swift",
        "fitbod/Sessions/InSessionPRState.swift",
        // Non-view Routines files
        "fitbod/Routines/PrescriptionDefaults.swift",
        "fitbod/Routines/RoutineDraft.swift",
        "fitbod/Routines/RoutineDuplicator.swift",
        "fitbod/Routines/RoutineFolderDraft.swift",
    ]

    /// Audit directory names relative to the project root.
    private static let auditDirNames: [String] = [
        "fitbod/Routines",
        "fitbod/Sessions",
        "fitbod/Views",
        "FitbodWidgets",
    ]

    // MARK: - Helper

    /// Returns all .swift URLs under the audit directories,
    /// minus the excluded set and minus any #Preview-only files.
    ///
    /// Derives the project root from the test file's compile-time path
    /// (#filePath points into fitbodTests/, one level below the project root).
    private func surfaceFileURLs(
        file: StaticString = #filePath
    ) throws -> [URL] {
        let testFilePath = String(describing: file)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        // fitbodTests/BRUGrepAuditTests.swift → go up 2 levels to project root
        let projectRoot = testFileURL
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root

        var results: [URL] = []
        let fm = FileManager.default

        for dirName in Self.auditDirNames {
            let dirURL = projectRoot.appendingPathComponent(dirName)
            guard let enumerator = fm.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "swift" else { continue }
                // Check against excluded suffixes
                let absolutePath = fileURL.path
                let isExcluded = Self.excludedFileSuffixes.contains { suffix in
                    absolutePath.hasSuffix(suffix)
                }
                guard !isExcluded else { continue }
                results.append(fileURL)
            }
        }
        return results
    }

    /// Checks all surface files for a banned regex pattern.
    /// Returns a list of violation strings ("path/file.swift:42: offending line").
    private func violations(
        pattern: String,
        in files: [URL]
    ) throws -> [String] {
        var found: [String] = []
        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = source.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                // Skip pure comment lines — grepping for banned patterns in comments
                // is expected (they document the contract). Only flag actual code.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                // Also skip lines inside #Preview blocks — system-name images and
                // semantic fonts are acceptable in development-only previews.
                if line.contains("#Preview") { continue }
                let range = source.startIndex..<source.endIndex
                _ = range // suppress unused warning
                // Use NSRegularExpression for full regex support
                let regex = try NSRegularExpression(pattern: pattern)
                let lineRange = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: lineRange) != nil {
                    let shortPath = fileURL.path.components(separatedBy: "/fitbod/").last
                        ?? fileURL.lastPathComponent
                    found.append("fitbod/\(shortPath):\(index + 1): \(trimmed)")
                }
            }
        }
        return found
    }

    // MARK: - @Test Functions

    @Test("No Color.accentColor in Phase 2 surfaces")
    func noColorAccentColorInPhase2Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"Color\.accentColor|Color\("AccentColor"\)|\.tint\(\.accentColor\)"#, in: files)
        #expect(hits.isEmpty, "BRU violation — Color.accentColor found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Color(.system*) in Phase 2 surfaces")
    func noColorSystemPatternInPhase2Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"Color\(\.system"#, in: files)
        #expect(hits.isEmpty, "BRU violation — Color(.system*) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Image(systemName:) in Phase 2 surfaces")
    func noImageSystemNameInPhase2Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"Image\(systemName:"#, in: files)
        #expect(hits.isEmpty, "BRU violation — Image(systemName:) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Capsule clipShape in Phase 2 surfaces")
    func noCapsuleClipInPhase2Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"\.clipShape\(Capsule\(\)|\.clipShape\(\.capsule"#, in: files)
        #expect(hits.isEmpty, "BRU violation — .clipShape(Capsule()) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No RoundedRectangle(cornerRadius:) in Phase 2 surfaces")
    func noRoundedRectangleCornerRadiusInPhase2Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"RoundedRectangle\(cornerRadius:"#, in: files)
        #expect(hits.isEmpty, "BRU violation — RoundedRectangle(cornerRadius:) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Apple semantic font styles in Phase 2 surfaces")
    func noAppleSemanticFontStylesInPhase2Surfaces() throws {
        let files = try surfaceFileURLs()
        // Combined pattern for all banned .font() semantic styles
        let pattern = #"\.font\(\.(body|headline|title|title2|title3|caption|caption2|subheadline|footnote|callout|largeTitle)\)"#
        let hits = try violations(pattern: pattern, in: files)
        #expect(hits.isEmpty, "BRU violation — Apple semantic .font() style found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No .buttonStyle(.bordered) in Phase 2 surfaces")
    func noBorderedButtonStyleInPhase2Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"\.buttonStyle\(\.bordered\)|\.buttonStyle\(\.borderedProminent\)"#, in: files)
        #expect(hits.isEmpty, "BRU violation — .buttonStyle(.bordered) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No .background(.regularMaterial) in Phase 2 surfaces")
    func noRegularMaterialBackgroundInPhase2Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"\.background\(\.regularMaterial\)"#, in: files)
        #expect(hits.isEmpty, "BRU violation — .background(.regularMaterial) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("OFL license attribution files present (Wave G item 71)")
    func oflLicenseAttributionPresent() throws {
        let testFilePath = String(describing: #filePath as StaticString)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let licensesDir = projectRoot
            .appendingPathComponent("fitbod/Resources/Fonts/LICENSES")

        let spaceGrotesk = licensesDir.appendingPathComponent("SpaceGrotesk-OFL.txt")
        let jetBrainsMono = licensesDir.appendingPathComponent("JetBrainsMono-OFL.txt")

        #expect(
            FileManager.default.fileExists(atPath: spaceGrotesk.path),
            "SpaceGrotesk-OFL.txt missing from fitbod/Resources/Fonts/LICENSES/"
        )
        #expect(
            FileManager.default.fileExists(atPath: jetBrainsMono.path),
            "JetBrainsMono-OFL.txt missing from fitbod/Resources/Fonts/LICENSES/"
        )
    }
}
