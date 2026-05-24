//
//  RoutinesListBRUCopyTests.swift
//  fitbodTests
//
//  Phase 2.1 Plan 06 — BRU composition + verbatim-copy assertions for the
//  rewritten Routines tab surfaces (RoutinesListView, RoutineRow,
//  NewFolderSheet, MoveRoutineSheet).
//
//  Pattern: parse the Swift source files at test runtime via #filePath-
//  relative URLs (same approach as RoutineBuilderCopyTests and
//  RoutinesListCopyTests). SwiftUI views aren't snapshot-tested at the
//  pixel level here — these are source-level invariants that catch careless
//  copy mutations and BRU-contract regressions before they ship.
//
//  Tests:
//  (1) routinesListViewIncludesVerbatimHeaderCopy — BRUHeaderBar strings
//  (2) routinesListViewIncludesEmptyStateCopy — empty state strings
//  (3) newFolderSheetIncludesVerbatimCopy — sheet copy
//  (4) moveRoutineSheetIncludesVerbatimCopy — sheet copy + ✓ glyph
//  (5) noBannedTokensInRoutinesListSurfaces — zero-banned-token assertion
//

import Foundation
import Testing
@testable import fitbod

@Suite("RoutinesListBRUCopy")
struct RoutinesListBRUCopyTests {

    // MARK: - Helpers

    /// Base URL for fitbod/Routines/ source files, derived from #filePath.
    private var routinesBase: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // fitbodTests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("fitbod/Routines")
    }

    /// Read a source file at the given filename under fitbod/Routines/.
    private func routineSource(_ filename: String) throws -> String {
        try String(
            contentsOf: routinesBase.appendingPathComponent(filename),
            encoding: .utf8
        )
    }

    // MARK: - (1) Header copy

    @Test("routinesListViewIncludesVerbatimHeaderCopy — BRUHeaderBar + search prompt + UNFILED")
    func routinesListViewIncludesVerbatimHeaderCopy() throws {
        let list = try routineSource("RoutinesListView.swift")

        // BRUHeaderBar center title per UI-SPEC line 305
        #expect(list.contains("\"Routines\""))

        // BRUHeaderBar right action per UI-SPEC line 306
        #expect(list.contains("\"+ NEW\""))

        // Search field placeholder per UI-SPEC line 307
        #expect(list.contains("\"Search routines\""))

        // Section head for routines with no folder per UI-SPEC line 308
        #expect(list.contains("\"UNFILED\""))
    }

    // MARK: - (2) Empty state copy

    @Test("routinesListViewIncludesEmptyStateCopy — no-routines empty state strings")
    func routinesListViewIncludesEmptyStateCopy() throws {
        let list = try routineSource("RoutinesListView.swift")

        // Heading per UI-SPEC line 322
        #expect(list.contains("\"No routines yet\""))

        // Body per UI-SPEC line 322
        #expect(list.contains("\"Build a routine to start logging workouts.\""))

        // Action button per UI-SPEC line 322
        #expect(list.contains("\"+ NEW ROUTINE\""))
    }

    // MARK: - (3) NewFolderSheet copy

    @Test("newFolderSheetIncludesVerbatimCopy — BRU sheet header + field + actions")
    func newFolderSheetIncludesVerbatimCopy() throws {
        let folder = try routineSource("NewFolderSheet.swift")

        // BRUHeaderBar center per UI-SPEC line 313
        #expect(folder.contains("\"NEW FOLDER\""))

        // TextField placeholder per UI-SPEC line 314
        #expect(folder.contains("\"Folder name\""))

        // BRUHeaderBar right (SAVE) per UI-SPEC line 315
        #expect(folder.contains("\"SAVE\""))

        // BRUHeaderBar left (CANCEL) per UI-SPEC line 316
        #expect(folder.contains("\"CANCEL\""))
    }

    // MARK: - (4) MoveRoutineSheet copy

    @Test("moveRoutineSheetIncludesVerbatimCopy — BRU sheet header + ✓ glyph + Unfiled")
    func moveRoutineSheetIncludesVerbatimCopy() throws {
        let move = try routineSource("MoveRoutineSheet.swift")

        // BRUHeaderBar center per UI-SPEC line 321
        #expect(move.contains("\"MOVE ROUTINE\""))

        // ✓ text glyph (NOT Image(systemName: "checkmark")) per plan must_haves
        #expect(move.contains("\"✓\""))

        // Cancel action
        #expect(move.contains("\"CANCEL\""))
    }

    // MARK: - (5) Zero-banned-token assertion

    @Test("noBannedTokensInRoutinesListSurfaces — BRU contract enforcement across 4 files")
    func noBannedTokensInRoutinesListSurfaces() throws {
        let filenames = [
            "RoutinesListView.swift",
            "RoutineRow.swift",
            "NewFolderSheet.swift",
            "MoveRoutineSheet.swift",
        ]

        // Tokens that must not appear in non-comment source lines.
        // Comment lines (// ...) are excluded from the scan to allow
        // prohibition notices in file headers.
        let bannedTokens = [
            "Color.accentColor",
            "Capsule()",
            "RoundedRectangle(cornerRadius:",
            ".font(.body)",
            ".font(.headline)",
            ".font(.title2)",
            ".font(.title)",
            ".font(.caption)",
            ".font(.subheadline)",
            ".font(.footnote)",
        ]

        for filename in filenames {
            let source = try routineSource(filename)
            let nonCommentLines = source
                .components(separatedBy: .newlines)
                .filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("#")
                }
                .joined(separator: "\n")

            for token in bannedTokens {
                #expect(
                    !nonCommentLines.contains(token),
                    "Banned token '\(token)' found in \(filename)"
                )
            }

            // Image(systemName:) must not appear in non-comment lines
            // (Apple SF Symbols are forbidden in BRU body views;
            //  system Labels in swipe actions use systemImage: on Label,
            //  which is a different argument label — not matched here).
            // Note: "Image(systemName:" is the explicit banned form.
            #expect(
                !nonCommentLines.contains("Image(systemName:"),
                "Banned Image(systemName:) found in \(filename)"
            )
        }
    }
}
