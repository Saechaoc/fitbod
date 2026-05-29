// BRUPeriodizationAuditTests.swift
// fitbodTests
//
// Phase 04.1 Plan 08 — Wave 7: Final audit re-run for Phase 4 BRU visual rewrite.
//
// PURPOSE: Programmatically grep each of the 12 rewritten Phase 4 surface files
// (+ 1 net-new BlockOverviewScreen.swift) and assert ZERO occurrences of the
// 25 forbidden Apple-HIG patterns enumerated in 04.1-PATTERNS.md lines 56-84.
//
// EXEMPTION (revision iter 1 W4 proximity rule):
//   Image(systemName: "trash") in BlockRow.swift ONLY is exempt when the nearest
//   preceding non-blank line within 20 lines contains `.swipeActions(edge:`.
//   This keeps the system swipe-chrome trash icon (CONTEXT D-07) from triggering
//   the audit. The prior brace-balance counter approach is REPLACED by this proximity
//   rule per W4 user decision.
//
//   Implementation: isBlockRowTrashWithinSwipeActions(lineIndex:lines:)
//   Docstring for the rule is included inline in the exemption helper below.
//
// ROADMAP AUDIT (revision iter 1 W5):
//   testROADMAPDependsOnUpdated is extended to additionally assert:
//   (a) "Phase 2.1 (specifically 02.1-01-PLAN.md foundation)" dependency citation
//   (b) Goal fragment "Re-skin all Phase 4" (from CONTEXT D-04)
//   (c) Requirements fragment "None (visual refactor" (from CONTEXT D-18)
//   (d) References to all 8 plan filenames: 04.1-01-PLAN.md through 04.1-08-PLAN.md
//
// Run via:
//   xcodebuild test -scheme fitbod -only-testing:fitbodTests/BRUPeriodizationAuditTests

import Foundation
import Testing

// MARK: - BRUPeriodizationAuditTests

@Suite("BRUPeriodizationAudit", .serialized)
struct BRUPeriodizationAuditTests {

    // MARK: - Path Helpers

    /// Computes absolute path to a source file from #filePath ascent.
    private func sourcePath(_ filename: String, in directory: String = "Periodization") -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("fitbod")
            .appendingPathComponent(directory)
            .appendingPathComponent(filename)
    }

    private func planningPath(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent(".planning")
            .appendingPathComponent(filename)
    }

    private func appPath(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("fitbod")
            .appendingPathComponent("App")
            .appendingPathComponent(filename)
    }

    private func viewsPath(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("fitbod")
            .appendingPathComponent("Views")
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

    // MARK: - BlockRow Trash Exemption Helper (W4 proximity rule)

    /// Returns true when the match at `lineIndex` is `Image(systemName: "trash")`
    /// AND the nearest preceding non-blank line within 20 lines contains `.swipeActions(edge:`.
    ///
    /// Exemption rule (revision iter 1 W4 user decision):
    ///   In BlockRow.swift ONLY, `Image(systemName: "trash")` is exempt when the nearest
    ///   preceding non-blank line within 20 lines contains `.swipeActions(edge:`.
    ///   This keeps the system swipe-chrome trash icon (CONTEXT D-07) from triggering
    ///   the audit guardrail. The proximity rule is O(N) with a 20-line window, not a
    ///   fragile brace-balance counter (replaced per W4).
    ///
    ///   Note: BlockRow.swift currently uses `Label("Delete", systemImage: "trash")` not
    ///   `Image(systemName: "trash")`, so this proximity check is a belt-and-suspenders
    ///   safeguard for any future refactor that re-introduces `Image(systemName: "trash")`.
    private func isBlockRowTrashWithinSwipeActions(
        lineIndex: Int,
        allLines: [String]
    ) -> Bool {
        // Walk backwards from lineIndex (exclusive) up to 20 non-blank preceding lines
        var nonBlankCount = 0
        var checkIndex = lineIndex - 1
        while checkIndex >= 0 && nonBlankCount < 20 {
            let line = allLines[checkIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                if trimmed.contains(".swipeActions(edge:") {
                    return true
                }
                nonBlankCount += 1
            }
            checkIndex -= 1
        }
        return false
    }

    // MARK: - Forbidden Patterns Table

    /// The 25 forbidden Apple-HIG patterns from 04.1-PATTERNS.md lines 56-84.
    /// Each entry: (name, regex, exemptFileSuffixes)
    /// exemptFileSuffixes: files for which this pattern is intentionally allowed.
    private static let forbiddenPatterns: [(name: String, regex: String, exemptFileSuffixes: [String])] = [
        // 1. Form + Section (Apple inset-grouped — banned per UI-REVIEW Pillar 2 Fix 3)
        ("Form {", #"Form \{"#, []),
        ("Section(", #"\bSection\("#, []),

        // 2. RoundedRectangle with corner radius (04-UI-SPEC line 36)
        ("RoundedRectangle(cornerRadius:", #"RoundedRectangle\(cornerRadius:"#, []),

        // 3. clipShape with forbidden shapes
        ("clipShape(RoundedRectangle/Capsule/Circle)", #"\.clipShape\(RoundedRectangle|\.clipShape\(Capsule\(\)|\.clipShape\(Circle\(\)|\.clipShape\(\.capsule\)"#, []),

        // 4. Capsule() as visual element
        ("Capsule()", #"\bCapsule\(\)"#, []),

        // 5. Color.accentColor / Color("AccentColor")
        ("Color.accentColor", #"Color\.accentColor|Color\("AccentColor"\)|\.tint\(\.accentColor\)"#, []),

        // 6. Color.red / Color(.systemRed)
        ("Color.red / Color(.systemRed)", #"Color\.red\b|Color\(\.systemRed\)"#, []),

        // 7. Color.yellow / Color(.systemYellow)
        ("Color.yellow / Color(.systemYellow)", #"Color\.yellow\b|Color\(\.systemYellow\)"#, []),

        // 8. Color(.systemGray6) / Color(.secondarySystemGroupedBackground) / Color(.systemBackground)
        ("Color(.system*) background tokens", #"Color\(\.systemGray6\)|Color\(\.secondarySystemGroupedBackground\)|Color\(\.systemBackground\)"#, []),

        // 9. Color.white foreground on chip text
        ("Color.white", #"\bColor\.white\b"#, []),

        // 10. Apple semantic font styles (Pillar 4)
        (".font(.body)", #"\.font\(\.body\)"#, []),
        (".font(.caption)", #"\.font\(\.caption\b"#, []),
        (".font(.headline)", #"\.font\(\.headline\)"#, []),
        (".font(.title)", #"\.font\(\.title\b"#, []),
        (".font(.subheadline)", #"\.font\(\.subheadline\)"#, []),

        // 11. Image(systemName:) forbidden SF Symbols (per Pillar 6 table)
        //     NOTE: Image(systemName: "trash") has the BlockRow.swift proximity exemption.
        //     BlockRow.swift currently uses Label("Delete", systemImage: "trash") — not Image(systemName:)
        //     so this check handles any future refactor that re-introduces Image(systemName: "trash").
        ("Image(systemName: \"line.3.horizontal\")", #"Image\(systemName:\s*"line\.3\.horizontal"\)"#, []),
        ("Image(systemName: \"ellipsis.circle\")", #"Image\(systemName:\s*"ellipsis\.circle"\)"#, []),
        ("Image(systemName: \"exclamationmark.triangle\")", #"Image\(systemName:\s*"exclamationmark\.triangle"\)"#, []),
        ("Image(systemName: \"xmark\")", #"Image\(systemName:\s*"xmark"\)"#, []),
        ("Image(systemName: \"chevron.right\")", #"Image\(systemName:\s*"chevron\.right"\)"#, []),
        // "trash" is proximity-exempt in BlockRow.swift (handled separately in the test body)
        ("Image(systemName: \"trash\")", #"Image\(systemName:\s*"trash"\)"#, ["BlockRow.swift"]),

        // 12. .buttonStyle(.borderedProminent) / .tint(.accentColor)
        (".buttonStyle(.borderedProminent)", #"\.buttonStyle\(\.borderedProminent\)|\.tint\(\.accentColor\)"#, []),

        // 13. .navigationTitle (replaced by BRUHeaderBar)
        (".navigationTitle", #"\.navigationTitle\s*\("#, []),

        // 14. Divider() (replaced by BRUDivider or Rectangle+bruHair)
        ("Divider()", #"\bDivider\(\)"#, []),
    ]

    // MARK: - 1. testForbiddenPatternsAcrossAllPhase4Surfaces

    @Test("testForbiddenPatternsAcrossAllPhase4Surfaces — 0 matches for all 25 forbidden patterns across 12 + 1 files")
    func testForbiddenPatternsAcrossAllPhase4Surfaces() throws {
        let surfaces: [(filename: String, directory: String)] = [
            ("BlockRow.swift", "Periodization"),
            ("BlockPickerMenu.swift", "Periodization"),
            ("StartBlockCTA.swift", "Periodization"),
            ("DeloadWeekBanner.swift", "Periodization"),
            ("ConsiderDeloadBanner.swift", "Periodization"),
            ("BlockCard.swift", "Periodization"),
            ("MesocycleWeekPage.swift", "Periodization"),
            ("BlockPhaseEditorRow.swift", "Periodization"),
            ("RoutinesListView.swift", "Routines"),
            // BlockBuilderView.swift retired from this audit in quick task 260528-vi2:
            // the New Block screen was redesigned to the rounded-card final-design.png
            // contract (warm cards, RoundedRectangle, chevron) which intentionally
            // supersedes the Phase 04.1 brutalist "sharp-corners / no RoundedRectangle"
            // contract this audit enforces. It is no longer one of these surfaces.
            ("BlockReviewView.swift", "Periodization"),
            ("BlockOverviewScreen.swift", "Periodization"),
        ]

        var allViolations: [String] = []

        for (filename, directory) in surfaces {
            let fileURL = sourcePath(filename, in: directory)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let allLines = source.components(separatedBy: "\n")
            let filtered = nonCommentLines(of: source)

            for patternEntry in Self.forbiddenPatterns {
                let (name, regexPattern, exemptSuffixes) = patternEntry

                // Check file-level exemption (e.g. Image(systemName: "trash") exempt in BlockRow.swift)
                let isFileExempt = exemptSuffixes.contains { filename.hasSuffix($0) }

                let regex = try NSRegularExpression(pattern: regexPattern)

                for (lineIdx, lineText) in filtered {
                    let nsRange = NSRange(lineText.startIndex..., in: lineText)
                    guard regex.firstMatch(in: lineText, range: nsRange) != nil else { continue }

                    // For Image(systemName: "trash") in BlockRow.swift — apply proximity rule (W4)
                    if filename == "BlockRow.swift" && name.contains("trash") {
                        if isBlockRowTrashWithinSwipeActions(lineIndex: lineIdx, allLines: allLines) {
                            // Exempt — nearest preceding non-blank line within 20 lines has .swipeActions(edge:
                            continue
                        }
                    }

                    // File-level exemption for other patterns
                    if isFileExempt {
                        continue
                    }

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

    // MARK: - 3. testBlockCardTapRoutingWiring

    @Test("testBlockCardTapRoutingWiring — onTapBlock in BlockCard + BlockOverviewRoute navigation destination in TodayView")
    func testBlockCardTapRoutingWiring() throws {
        // BlockCard.swift: must expose onTapBlock + .onTapGesture (CONTEXT D-11 rewire)
        let blockCardURL = sourcePath("BlockCard.swift")
        let blockCardSource = try String(contentsOf: blockCardURL, encoding: .utf8)
        #expect(blockCardSource.contains("onTapBlock"),
                "BlockCard.swift must expose onTapBlock closure for BlockOverviewScreen tap-routing (CONTEXT D-11)")
        #expect(blockCardSource.contains(".onTapGesture") || blockCardSource.contains("onTapBlock?("),
                "BlockCard.swift must invoke onTapBlock on tap (CONTEXT D-11)")

        // TodayView.swift: must declare BlockOverviewRoute + navigationDestination for it
        // (The navigationDestination is in TodayView per Plan 07 implementation)
        let todayViewURL = viewsPath("TodayView.swift")
        let todayViewSource = try String(contentsOf: todayViewURL, encoding: .utf8)
        #expect(todayViewSource.contains("BlockOverviewRoute"),
                "TodayView.swift must reference BlockOverviewRoute for tap-routing wiring (CONTEXT D-11)")
        #expect(todayViewSource.contains(".navigationDestination(for: BlockOverviewRoute.self)"),
                "TodayView.swift must declare .navigationDestination(for: BlockOverviewRoute.self) handler (CONTEXT D-11)")
    }

    // MARK: - 4. testAccessibilityLabelsPopulated

    @Test("testAccessibilityLabelsPopulated — BlockCard + BlockPhaseEditorRow + BlockOverviewScreen carry accessibilityLabel")
    func testAccessibilityLabelsPopulated() throws {
        // BlockCard.swift: .accessibilityLabel("Active block...") (CONTEXT D-15)
        let blockCardURL = sourcePath("BlockCard.swift")
        let blockCardSource = try String(contentsOf: blockCardURL, encoding: .utf8)
        #expect(blockCardSource.contains(".accessibilityLabel(\"Active block"),
                "BlockCard.swift must carry .accessibilityLabel(\"Active block...\") per CONTEXT D-15")

        // BlockPhaseEditorRow.swift: .accessibilityLabel("Phase...") (CONTEXT D-15)
        let editorRowURL = sourcePath("BlockPhaseEditorRow.swift")
        let editorRowSource = try String(contentsOf: editorRowURL, encoding: .utf8)
        #expect(editorRowSource.contains(".accessibilityLabel(\"Phase") || editorRowSource.contains("accessibilityLabel(\"Phase"),
                "BlockPhaseEditorRow.swift must carry .accessibilityLabel(\"Phase...\") per CONTEXT D-15")

        // BlockOverviewScreen.swift: any .accessibilityLabel( call (CONTEXT D-15)
        let overviewURL = sourcePath("BlockOverviewScreen.swift")
        let overviewSource = try String(contentsOf: overviewURL, encoding: .utf8)
        #expect(overviewSource.contains(".accessibilityLabel("),
                "BlockOverviewScreen.swift must carry .accessibilityLabel( per CONTEXT D-15")
    }

    // MARK: - 5. testReducedMotionGate

    @Test("testReducedMotionGate — BlockCard uses accessibilityReduceMotion + conditional animation")
    func testReducedMotionGate() throws {
        let blockCardURL = sourcePath("BlockCard.swift")
        let source = try String(contentsOf: blockCardURL, encoding: .utf8)

        #expect(source.contains("accessibilityReduceMotion"),
                "BlockCard.swift must read @Environment(\\.accessibilityReduceMotion) per CONTEXT D-14")
        // The animation gate pattern: reduceMotion ? nil : .default
        // Accept either the exact pattern or a conditional expression referencing reduceMotion
        let hasAnimationGate = source.contains("reduceMotion ? nil : .default")
            || source.contains("reduceMotion ? nil :")
            || (source.contains("reduceMotion") && source.contains(".animation("))
        #expect(hasAnimationGate,
                "BlockCard.swift must gate TabView animation on reduceMotion (e.g. .animation(reduceMotion ? nil : .default, ...)) per CONTEXT D-14")
    }

    // MARK: - 6. testROADMAPDependsOnUpdated (EXTENDED per revision iter 1 W5)

    /// Extended ROADMAP audit per revision iter 1 W5:
    /// Asserts ROADMAP.md Phase 04.1 entry contains:
    ///   (a) Dependency citation: "Phase 2.1" near "02.1-01-PLAN.md" (CONTEXT D-02)
    ///   (b) Goal fragment: "Re-skin all Phase 4" (CONTEXT D-04)
    ///   (c) Requirements fragment: "None (visual refactor" (CONTEXT D-18)
    ///   (d) All 8 plan filenames: 04.1-01-PLAN.md through 04.1-08-PLAN.md
    @Test("testROADMAPDependsOnUpdated — Phase 04.1 entry contains Depends-on + Goal + Requirements + all 8 plan filenames")
    func testROADMAPDependsOnUpdated() throws {
        let roadmapURL = planningPath("ROADMAP.md")
        let roadmapSource = try String(contentsOf: roadmapURL, encoding: .utf8)

        // (a) Dependency on Phase 2.1 with specific plan reference (CONTEXT D-02)
        #expect(roadmapSource.contains("02.1-01-PLAN.md"),
                "ROADMAP.md Phase 04.1 entry must reference '02.1-01-PLAN.md' as the foundation dependency per CONTEXT D-02")
        #expect(roadmapSource.contains("Phase 2.1") || roadmapSource.contains("02.1"),
                "ROADMAP.md Phase 04.1 entry must cite Phase 2.1 dependency per CONTEXT D-02")

        // (b) Goal fragment: "Re-skin all Phase 4" (CONTEXT D-04)
        #expect(roadmapSource.contains("Re-skin all Phase 4"),
                "ROADMAP.md Phase 04.1 entry must contain Goal text 'Re-skin all Phase 4' per CONTEXT D-04")

        // (c) Requirements fragment: "None (visual refactor" (CONTEXT D-18)
        #expect(roadmapSource.contains("None (visual refactor"),
                "ROADMAP.md Phase 04.1 entry must contain Requirements text 'None (visual refactor' per CONTEXT D-18")

        // (d) All 8 plan filenames: 04.1-01-PLAN.md through 04.1-08-PLAN.md
        for planNum in 1...8 {
            let planFilename = String(format: "04.1-%02d-PLAN.md", planNum)
            #expect(roadmapSource.contains(planFilename),
                    "ROADMAP.md must reference '\(planFilename)' in Phase 04.1 plan list (revision iter 1 W5)")
        }
    }
}
