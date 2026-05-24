// BRUGrepAuditPhase6Tests.swift
// fitbodTests
//
// Phase 6.1 Plan 07 — final guardrail for the Phase 6 BRU visual rewrite
// (Progress + Settings + InSessionPRBanner + ExerciseHistoryView reskin,
// Plans 06.1-01 through 06.1-06). Mirrors the BRUGrepAuditTests +
// Phase3BRUGrepAuditTests + BRUPhase5GrepAuditTests pattern exactly.
//
// PURPOSE: Programmatically grep every Phase 6 surface file for banned
// legacy UIKit/HIG tokens. If a future bugfix accidentally re-introduces
// Color.accentColor or Image(systemName:) into a Phase 6 surface, this
// test fires — catching the regression in CI rather than via a manual
// gsd-ui-checker run.
//
// AUDITED FILES (Phase 6.1 surfaces, Plans 06.1-01 through 06.1-06):
//   fitbod/Progress/ProgressHomeView.swift
//   fitbod/Progress/ExerciseProgressView.swift
//   fitbod/Progress/SeriesToggleChipRow.swift
//   fitbod/Progress/ProgressColors.swift
//   fitbod/Progress/ProgressFilterChip.swift
//   fitbod/Progress/ExercisePRsView.swift
//   fitbod/Progress/SessionComparisonView.swift
//   fitbod/Progress/WeeklyTonnageView.swift
//   fitbod/Progress/WeeklyTonnageFilterChips.swift
//   fitbod/Progress/WeekDetailView.swift
//   fitbod/Settings/SettingsView.swift
//   fitbod/Sessions/InSessionPRBanner.swift
//   fitbod/ExerciseLibrary/ExerciseHistoryView.swift
//
// EXEMPTIONS:
//   - Comment lines (lines starting with //) are skipped.
//   - #Preview blocks are skipped (system-name images and semantic fonts
//     are acceptable in development-only previews).
//   - Image(systemName:) inside ShareLink closures is allowed — the system
//     ShareLink chrome legitimately uses SF Symbol affordances.
//
// NOTE: These tests run against the source tree, not compiled output.
// They use FileManager + #filePath path arithmetic to resolve source files
// at test run time (the pattern established by Phase 02.1-11 BRUGrepAuditTests).

import Testing
import Foundation

@Suite("BRU Phase 6 Grep Audit — Phase 6 Surface Banned Token Check")
struct BRUGrepAuditPhase6Tests {

    // MARK: - Phase 6 surface file paths

    /// Explicit list of Phase 6.1 surface file paths (relative to project root).
    /// BRU reskin covered in Plans 06.1-01 through 06.1-06.
    private static let phase6Files: [String] = [
        "fitbod/Progress/ProgressHomeView.swift",
        "fitbod/Progress/ExerciseProgressView.swift",
        "fitbod/Progress/SeriesToggleChipRow.swift",
        "fitbod/Progress/ProgressColors.swift",
        "fitbod/Progress/ProgressFilterChip.swift",
        "fitbod/Progress/ExercisePRsView.swift",
        "fitbod/Progress/SessionComparisonView.swift",
        "fitbod/Progress/WeeklyTonnageView.swift",
        "fitbod/Progress/WeeklyTonnageFilterChips.swift",
        "fitbod/Progress/WeekDetailView.swift",
        "fitbod/Settings/SettingsView.swift",
        "fitbod/Sessions/InSessionPRBanner.swift",
        "fitbod/ExerciseLibrary/ExerciseHistoryView.swift",
    ]

    // MARK: - Banned token patterns

    /// The banned-token regex patterns that must not appear in Phase 6 surfaces.
    /// Mirrors the must_haves.truths + interfaces block in 06.1-07-PLAN.md.
    private static let bannedPatterns: [String] = [
        // Accent color — replaced by explicit BRU color tokens
        #"Color\.accentColor"#,
        // Dynamic system colors — replaced by BRU palette
        #"Color\(\.system"#,
        // Apple semantic font roles — replaced by BRUFont type roles
        #"\.font\(\.(body|headline|title|title2|title3|caption|caption2|subheadline|footnote)\)"#,
        // SF Symbol image — BRU uses no system icons in Phase 6 surfaces
        #"Image\(systemName:"#,
        // Rounded rectangle with corner radius — BRU uses sharp corners
        #"RoundedRectangle\(cornerRadius:"#,
        // Capsule shape — BRU uses sharp/rectangular shapes
        #"Capsule\(\)"#,
        // Bordered button style — BRU uses BRUButton / .buttonStyle(.plain)
        #"\.buttonStyle\(\.bordered\)"#,
        // Navigation title modifier — BRU uses BRUHeaderBar instead
        #"\.navigationTitle\("#,
        // Toolbar modifier — BRU uses BRUHeaderBar instead (word-boundary: allows toolbarBackground)
        #"\.toolbar\b(?![A-Za-z])"#,
        // Inset grouped list style — replaced by ScrollView + LazyVStack
        #"InsetGroupedListStyle"#,
        // Form — replaced by ScrollView + LazyVStack
        #"\bForm\b"#,
        // Segmented picker style — replaced by BRUChip rows
        #"\.pickerStyle\(\.segmented"#,
        // Picker — BRU uses custom chip rows instead of system pickers
        #"Picker\("#,
    ]

    // MARK: - Helpers

    /// Resolves the project root from #filePath (fitbodTests/Phase6/BRU/ → up 4 levels).
    private func projectRoot(
        file: StaticString = #filePath
    ) -> URL {
        let testFilePath = String(describing: file)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        // fitbodTests/Phase6/BRU/BRUGrepAuditPhase6Tests.swift → go up 4 levels:
        //   1. BRU/
        //   2. Phase6/
        //   3. fitbodTests/
        //   4. project root
        return testFileURL
            .deletingLastPathComponent() // BRU/
            .deletingLastPathComponent() // Phase6/
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
    }

    /// Returns URLs for all 13 Phase 6 surface files, skipping any that do not exist.
    private func surfaceFileURLs(
        file: StaticString = #filePath
    ) -> [URL] {
        let root = projectRoot(file: file)
        let fm = FileManager.default
        return Self.phase6Files.compactMap { relativePath in
            let url = root.appendingPathComponent(relativePath)
            guard fm.fileExists(atPath: url.path) else { return nil }
            return url
        }
    }

    /// Returns a short, display-friendly path relative to the project root.
    private func shortPath(for url: URL) -> String {
        let path = url.path
        if let range = path.range(of: "/fitbod/") {
            return "fitbod/" + String(path[range.upperBound...])
        }
        return url.lastPathComponent
    }

    /// Checks whether `line` is inside a ShareLink closure, within `contextWindow` lines above.
    /// ShareLink legitimately uses Image(systemName:) internally — those hits are allowed.
    private func isInsideShareLinkClosure(
        lineIndex: Int,
        lines: [String],
        contextWindow: Int = 5
    ) -> Bool {
        let start = max(0, lineIndex - contextWindow)
        for i in stride(from: lineIndex, through: start, by: -1) {
            if lines[i].contains("ShareLink(item:") || lines[i].contains("ShareLink(") {
                return true
            }
        }
        return false
    }

    /// Checks `source` for a banned regex pattern.
    /// Returns violation strings in the form "filePath:lineNumber: offending line".
    ///
    /// Exemptions applied:
    ///   - Lines starting with // (comment lines) — skipped
    ///   - Lines inside #Preview blocks — skipped
    ///   - Image(systemName:) inside ShareLink closures — allowed
    private func violations(
        pattern: String,
        in source: String,
        fileURL: URL
    ) throws -> [String] {
        var found: [String] = []
        let lines = source.components(separatedBy: "\n")
        let regex = try NSRegularExpression(pattern: pattern)
        let displayPath = shortPath(for: fileURL)

        var insidePreviewBlock = false

        for (index, line) in lines.enumerated() {
            // Track #Preview block entry (single-line check — sufficient for single-line #Preview macros)
            if line.contains("#Preview") {
                insidePreviewBlock = true
            }
            // Exit preview block when we see a closing brace at column 0 after the entry line
            if insidePreviewBlock && index > 0 && line == "}" {
                insidePreviewBlock = false
                continue
            }
            if insidePreviewBlock { continue }

            // Skip pure comment lines (documenting banned patterns in comments is expected)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }

            let lineRange = NSRange(line.startIndex..., in: line)
            guard regex.firstMatch(in: line, range: lineRange) != nil else { continue }

            // Exempt Image(systemName:) inside ShareLink closures
            if pattern.contains("Image") && isInsideShareLinkClosure(lineIndex: index, lines: lines) {
                continue
            }

            found.append("\(displayPath):\(index + 1): \(trimmed)")
        }
        return found
    }

    // MARK: - @Test function

    @Test("Phase 6 BRU surfaces contain no banned tokens")
    func phase6BRUSurfacesContainNoBannedTokens() throws {
        let files = surfaceFileURLs()

        // Verify all 13 surface files were found
        let missingFiles = Self.phase6Files.filter { path in
            !files.contains(where: { $0.path.hasSuffix(path) })
        }
        if !missingFiles.isEmpty {
            Issue.record("Missing Phase 6 surface files: \(missingFiles.joined(separator: ", "))")
        }

        var allViolations: [String] = []

        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for pattern in Self.bannedPatterns {
                let hits = try violations(pattern: pattern, in: source, fileURL: fileURL)
                allViolations.append(contentsOf: hits)
            }
        }

        let violationReport = allViolations.joined(separator: "\n")
        #expect(
            allViolations.isEmpty,
            "Phase 6 BRU audit found \(allViolations.count) violation(s):\n\(violationReport)"
        )
    }
}
