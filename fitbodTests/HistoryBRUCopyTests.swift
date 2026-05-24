// HistoryBRUCopyTests.swift
// fitbodTests — Phase 2.1 Plan 10
//
// Source-anchor tests verifying UI-SPEC verbatim copy strings + zero banned tokens
// across all 8 history surface files (3 rewritten ExerciseLibrary + 4 new Sessions +
// 1 ExerciseLibrary new).
//
// Convention: read source files from disk via #filePath ascent. Never instantiates
// views — guards that editing source files doesn't silently drift from the UI-SPEC
// Copywriting Contract.
//
// References:
//   UI-SPEC v2 § Exercise history view (lines 423-439)
//   UI-SPEC v2 § Session history view (lines 441-458)
//   UI-SPEC v2 § Component Inventory — history surfaces (lines 579, 586-593, 607-614)

import Foundation
import Testing

@Suite("HistoryBRUCopy")
struct HistoryBRUCopyTests {

    // MARK: - Path helpers

    /// Resolve the ExerciseLibrary source directory from this test file.
    private var exerciseLibraryBase: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/ExerciseLibrary")
    }

    /// Resolve the Sessions source directory from this test file.
    private var sessionsBase: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions")
    }

    // MARK: - (1) ExerciseHistoryView header copy

    @Test("exerciseHistoryViewHeaderCopy — BRUHeaderBar header text present")
    func exerciseHistoryViewHeaderCopy() throws {
        let src = try String(
            contentsOf: exerciseLibraryBase.appendingPathComponent("ExerciseHistoryView.swift"),
            encoding: .utf8
        )
        #expect(src.contains("\"History\""))
        // Phase 06.1-06 BRU reskin moved intent filtering to inline IntentFilterChipRow strip;
        // the BRUHeaderBar right slot changed from "FILTER" to "PROGRESS" (deep link to chart).
        #expect(src.contains("\"PROGRESS\""))
        #expect(src.contains("\"‹\""))
    }

    // MARK: - (2) ExerciseHistoryView empty state copy

    @Test("exerciseHistoryEmptyStateCopy — verbatim empty state strings present")
    func exerciseHistoryEmptyStateCopy() throws {
        let src = try String(
            contentsOf: exerciseLibraryBase.appendingPathComponent("ExerciseHistoryView.swift"),
            encoding: .utf8
        )
        #expect(src.contains("\"No logged sets yet\""))
        #expect(src.contains("\"Log this exercise in a workout to see history.\""))
        #expect(src.contains("\"SHOW ALL\""))
    }

    // MARK: - (3) IntentFilterChipRow — labels + ink-fill selection

    @Test("intentFilterChipRowLabelsAndInkSelection — UI-SPEC line 244 ink-fill confirmed")
    func intentFilterChipRowLabelsAndInkSelection() throws {
        let src = try String(
            contentsOf: exerciseLibraryBase.appendingPathComponent("IntentFilterChipRow.swift"),
            encoding: .utf8
        )
        // Short labels (displayed as "STRENGTH · N" etc.)
        #expect(src.contains("\"ALL\""))
        #expect(src.contains("\"STRENGTH\""))
        #expect(src.contains("\"HYPER\""))
        #expect(src.contains("\"POWER\""))
        #expect(src.contains("\"ENDUR\""))
        #expect(src.contains("\"TECH\""))
        // UI-SPEC line 244: selected fill = bruInk (NOT bruSignal)
        #expect(src.contains("Color.bruInk"))
        // Must NOT use accentColor
        #expect(!src.contains("Color.accentColor"))
    }

    // MARK: - (4) PRStripFooter cell labels

    @Test("prStripFooterCellLabels — TOP WEIGHT / TOP REPS / VOL PR present")
    func prStripFooterCellLabels() throws {
        let src = try String(
            contentsOf: exerciseLibraryBase.appendingPathComponent("PRStripFooter.swift"),
            encoding: .utf8
        )
        #expect(src.contains("\"TOP WEIGHT\""))
        #expect(src.contains("\"TOP REPS\""))
        #expect(src.contains("\"VOL PR\""))
    }

    // MARK: - (5) SessionHistoryView header + section head

    @Test("sessionHistoryViewHeaderAndSection — BRUHeaderBar + Past sessions present")
    func sessionHistoryViewHeaderAndSection() throws {
        let src = try String(
            contentsOf: sessionsBase.appendingPathComponent("SessionHistoryView.swift"),
            encoding: .utf8
        )
        #expect(src.contains("\"History\""))
        #expect(src.contains("\"FILTER\""))
        #expect(src.contains("\"Past sessions\""))
    }

    // MARK: - (6) WeeklyTonnageSparkCard — label + BRUSpark

    @Test("weeklyTonnageSparkCardLabel — WEEKLY TONNAGE · 8 WK + BRUSpark present")
    func weeklyTonnageSparkCardLabel() throws {
        let src = try String(
            contentsOf: sessionsBase.appendingPathComponent("WeeklyTonnageSparkCard.swift"),
            encoding: .utf8
        )
        #expect(src.contains("\"WEEKLY TONNAGE · 8 WK\""))
        #expect(src.contains("BRUSpark"))
    }

    // MARK: - (7) SessionHistoryRow uses BRUCornerBadge

    @Test("sessionHistoryRowUsesBRUCornerBadge — PR badge primitive present")
    func sessionHistoryRowUsesBRUCornerBadge() throws {
        let src = try String(
            contentsOf: sessionsBase.appendingPathComponent("SessionHistoryRow.swift"),
            encoding: .utf8
        )
        #expect(src.contains("BRUCornerBadge"))
    }

    // MARK: - (8) Zero banned tokens across all 8 history files

    @Test("noBannedTokensInHistorySurfaces — all 8 files pass BRU contract check")
    func noBannedTokensInHistorySurfaces() throws {
        let filePaths: [URL] = [
            exerciseLibraryBase.appendingPathComponent("ExerciseHistoryView.swift"),
            exerciseLibraryBase.appendingPathComponent("ExerciseHistoryRow.swift"),
            exerciseLibraryBase.appendingPathComponent("IntentFilterChipRow.swift"),
            exerciseLibraryBase.appendingPathComponent("PRStripFooter.swift"),
            sessionsBase.appendingPathComponent("SessionHistoryView.swift"),
            sessionsBase.appendingPathComponent("SessionHistoryStatStrip.swift"),
            sessionsBase.appendingPathComponent("WeeklyTonnageSparkCard.swift"),
            sessionsBase.appendingPathComponent("SessionHistoryRow.swift"),
        ]

        let bannedPatterns = [
            "Capsule()",
            "RoundedRectangle(",
            "Color.accentColor",
            "Image(systemName:",
            "Color(.system",
        ]

        // Font banned patterns — exclude comments
        let bannedFontPatterns = [
            ".font(.body)",
            ".font(.headline)",
            ".font(.title)",
            ".font(.title2)",
            ".font(.title3)",
            ".font(.caption)",
            ".font(.caption2)",
            ".font(.subheadline)",
            ".font(.footnote)",
        ]

        for fileURL in filePaths {
            let src = try String(contentsOf: fileURL, encoding: .utf8)
            let nonCommentLines = src
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")

            let fileName = fileURL.lastPathComponent

            for banned in bannedPatterns {
                #expect(
                    !nonCommentLines.contains(banned),
                    "BANNED '\(banned)' found in \(fileName)"
                )
            }
            for banned in bannedFontPatterns {
                #expect(
                    !nonCommentLines.contains(banned),
                    "BANNED '\(banned)' found in \(fileName)"
                )
            }
        }
    }
}
