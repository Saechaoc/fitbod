// BRUPhase5GrepAuditTests.swift
// fitbodTests
//
// Phase 5.1 Plan 08 — final regression guardrail for the Phase 5 BRU
// visual rewrite (Fatigue / Volume surface reskin, Plans 05.1-01..08).
// Mirrors the BRUGrepAuditTests + Phase3BRUGrepAuditTests pattern exactly.
//
// PURPOSE: Programmatically grep every Phase 5 surface file for banned
// legacy UIKit/HIG tokens. If a future bugfix accidentally re-introduces
// Color.accentColor or Image(systemName:) into a Phase 5 surface, this
// test fires — catching the regression in CI rather than via a manual
// gsd-ui-checker run.
//
// AUDITED FILES / DIRECTORIES:
//   fitbod/Fatigue/           — all 21 Phase 5 surface files (Plans 05.1-01..07)
//   fitbod/Settings/MuscleVolumeTargetEditor.swift  — Plan 05.1-06 reskin
//   fitbod/ExerciseLibrary/ExerciseDetailView.swift — Plateau Detection section
//                             only (line-range guardrail via MARK boundary)
//
// EXEMPTIONS (kept short — per must_haves.truths):
//   BodySilhouetteView.swift  — .font(.system(size:)) for size-anchored per-region
//                               labels (UI-SPEC §Dynamic Type — explicit point sizes
//                               are permitted for display elements)
//   WeeklyRecapSheet.swift    — .font(.system(size: 38|56|68|...)) for display numerals
//   FatigueSurfaceView.swift  — .font(.system(size: 56|32|...)) for display numerals
//
// NOTE: These tests run against the source tree, not compiled output.
// They use FileManager to walk the source directories and String regex
// matching for banned token detection.

import Testing
import Foundation

@Suite("BRU Phase 5 Grep Audit")
struct BRUPhase5GrepAuditTests {

    // MARK: - Banned token patterns

    /// The 11 banned-token regex patterns that must not appear in Phase 5 surfaces.
    /// Mirrors the must_haves.truths list in 05.1-08-PLAN.md.
    private static let bannedPatterns: [String] = [
        // Accent color — replaced by explicit BRU color tokens
        #"Color\.accentColor"#,
        // Dynamic system colors — replaced by BRU palette
        #"Color\(\.system"#,
        // Phase 5 baseline VolumeZone asset names — dropped in Plan 05.1-01
        #"Color\(\"Volume[A-Za-z]+\"\)"#,
        // Rounded rectangle with corner radius — BRU uses sharp corners
        #"RoundedRectangle\(cornerRadius:"#,
        // Capsule shape
        #"Capsule\(\)"#,
        // SF Symbol image — BRU uses no system icons in Phase 5 surfaces
        #"Image\(systemName:"#,
        // Bordered button style
        #"\.buttonStyle\(\.bordered\)"#,
        // Navigation title modifier — BRU uses BRUHeaderBar instead
        #"\.navigationTitle\("#,
        // Apple semantic font roles (all 9 banned roles)
        #"\.font\(\.(body|headline|title|title2|title3|caption|caption2|subheadline|footnote)\)"#,
        // Segmented picker — replaced by BRUChip row (deleted Front/Back Picker in Plan 05.1-04/05)
        #"\.pickerStyle\(\.segmented\)"#,
        // List inset grouped — replaced by ScrollView + LazyVStack
        #"List\(\.insetGrouped"#,
    ]

    // MARK: - Exemptions

    /// Per-file exemptions. Key: file path suffix (relative to project root).
    /// Value: array of regex patterns ALLOWED in that file despite matching a banned pattern.
    /// Applied before recording a violation — if an exemption regex matches the offending
    /// line AND the file suffix matches, the violation is skipped.
    private static let exemptions: [String: [String]] = [
        // BodySilhouetteView uses explicit-size point fonts for per-region heatmap labels
        // (UI-SPEC §Dynamic Type line 65 — size-anchored display elements).
        "fitbod/Fatigue/BodySilhouetteView.swift": [
            #"\.font\(\.system\(size:"#,
        ],
        // WeeklyRecapSheet and FatigueSurfaceView use explicit-size fonts for display numerals
        // (UI-SPEC §Display row — 38/56/68pt semibold numerals).
        "fitbod/Fatigue/WeeklyRecapSheet.swift": [
            #"\.font\(\.system\(size:"#,
        ],
        "fitbod/Fatigue/FatigueSurfaceView.swift": [
            #"\.font\(\.system\(size:"#,
        ],
    ]

    // MARK: - Source file sets

    /// Returns all .swift URLs under fitbod/Fatigue/ + MuscleVolumeTargetEditor.swift.
    private func phase5SurfaceFileURLs(
        file: StaticString = #filePath
    ) throws -> [URL] {
        let testFilePath = String(describing: file)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        // fitbodTests/BRUPhase5GrepAuditTests.swift → up 2 levels to project root
        let projectRoot = testFileURL
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root

        var results: [URL] = []
        let fm = FileManager.default

        // All files under fitbod/Fatigue/
        let fatigueDir = projectRoot.appendingPathComponent("fitbod/Fatigue")
        if let enumerator = fm.enumerator(
            at: fatigueDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "swift" else { continue }
                results.append(fileURL)
            }
        }

        // MuscleVolumeTargetEditor.swift (single file)
        let editorURL = projectRoot
            .appendingPathComponent("fitbod/Settings/MuscleVolumeTargetEditor.swift")
        if fm.fileExists(atPath: editorURL.path) {
            results.append(editorURL)
        }

        return results
    }

    /// Returns the content slice of ExerciseDetailView.swift from the
    /// `// MARK: - Plateau Detection section` marker through the closing
    /// brace of that method (i.e., the first top-level `    }` line after
    /// the marker that closes the function body).
    private func plateauDetectionSectionContent(
        file: StaticString = #filePath
    ) throws -> (content: String, fileURL: URL) {
        let testFilePath = String(describing: file)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let detailViewURL = projectRoot
            .appendingPathComponent("fitbod/ExerciseLibrary/ExerciseDetailView.swift")

        let source = try String(contentsOf: detailViewURL, encoding: .utf8)
        let lines = source.components(separatedBy: "\n")

        // Find the Plateau Detection MARK line
        guard let markIndex = lines.firstIndex(where: {
            $0.contains("MARK: - Plateau Detection section")
        }) else {
            return ("", detailViewURL)
        }

        // Collect lines from the MARK through the next top-level MARK or end-of-file
        var sectionLines: [String] = []
        for i in markIndex..<lines.count {
            let line = lines[i]
            // Stop at the next MARK (excluding the start mark)
            if i > markIndex && line.contains("// MARK:") {
                break
            }
            sectionLines.append(line)
        }

        return (sectionLines.joined(separator: "\n"), detailViewURL)
    }

    // MARK: - Violation checker

    /// Checks file content for banned regex patterns, respecting the exemptions list.
    /// Returns violation strings in the form "path:lineNumber: offending line content".
    private func violations(
        pattern: String,
        in source: String,
        fileURL: URL
    ) throws -> [String] {
        var found: [String] = []
        let lines = source.components(separatedBy: "\n")
        let regex = try NSRegularExpression(pattern: pattern)

        // Determine which exemption regexes apply to this file
        let fileSuffix = Self.exemptions.keys.first { fileURL.path.hasSuffix($0) }
        let exemptPatterns: [String] = fileSuffix.flatMap { Self.exemptions[$0] } ?? []
        let exemptRegexes: [NSRegularExpression] = try exemptPatterns.map {
            try NSRegularExpression(pattern: $0)
        }

        for (index, line) in lines.enumerated() {
            // Skip pure comment lines (contract documentation, not actual code)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }
            // Skip #Preview blocks — semantic fonts/system images are OK in previews
            guard !line.contains("#Preview") else { continue }

            let lineRange = NSRange(line.startIndex..., in: line)
            guard regex.firstMatch(in: line, range: lineRange) != nil else { continue }

            // Check exemptions: if any exemption regex also matches this line, skip it
            let isExempt = exemptRegexes.contains { exemptRegex in
                exemptRegex.firstMatch(in: line, range: lineRange) != nil
            }
            guard !isExempt else { continue }

            let shortPath = fileURL.path.components(separatedBy: "/fitbod/").last
                ?? fileURL.lastPathComponent
            found.append("fitbod/\(shortPath):\(index + 1): \(trimmed)")
        }
        return found
    }

    // MARK: - @Test functions

    @Test("No banned BRU tokens in Phase 5 Fatigue + Settings surfaces")
    func testFatigueSurfacesContainNoBannedTokens() throws {
        let files = try phase5SurfaceFileURLs()
        var allViolations: [String] = []

        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for pattern in Self.bannedPatterns {
                let hits = try violations(pattern: pattern, in: source, fileURL: fileURL)
                allViolations.append(contentsOf: hits)
            }
        }

        #expect(
            allViolations.isEmpty,
            "BRU Phase 5 violation(s) found:\n\(allViolations.joined(separator: "\n"))"
        )
    }

    @Test("No banned BRU tokens in MuscleVolumeTargetEditor.swift")
    func testMuscleVolumeTargetEditorContainsNoBannedTokens() throws {
        let testFilePath = String(describing: #filePath as StaticString)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let editorURL = projectRoot
            .appendingPathComponent("fitbod/Settings/MuscleVolumeTargetEditor.swift")

        guard FileManager.default.fileExists(atPath: editorURL.path) else {
            Issue.record("MuscleVolumeTargetEditor.swift not found at expected path")
            return
        }

        let source = try String(contentsOf: editorURL, encoding: .utf8)
        var allViolations: [String] = []

        for pattern in Self.bannedPatterns {
            let hits = try violations(pattern: pattern, in: source, fileURL: editorURL)
            allViolations.append(contentsOf: hits)
        }

        #expect(
            allViolations.isEmpty,
            "BRU violation(s) in MuscleVolumeTargetEditor.swift:\n\(allViolations.joined(separator: "\n"))"
        )
    }

    @Test("No banned BRU tokens in ExerciseDetailView Plateau Detection section")
    func testPlateauDetectionSectionContainsNoBannedTokens() throws {
        let (sectionContent, fileURL) = try plateauDetectionSectionContent()

        guard !sectionContent.isEmpty else {
            Issue.record("Could not locate '// MARK: - Plateau Detection section' in ExerciseDetailView.swift")
            return
        }

        var allViolations: [String] = []
        for pattern in Self.bannedPatterns {
            let hits = try violations(pattern: pattern, in: sectionContent, fileURL: fileURL)
            // For this single-section audit, report with a [plateau-section] prefix
            allViolations.append(contentsOf: hits.map { "[plateau-section] \($0)" })
        }

        #expect(
            allViolations.isEmpty,
            "BRU violation(s) in ExerciseDetailView Plateau Detection section:\n\(allViolations.joined(separator: "\n"))"
        )
    }
}
