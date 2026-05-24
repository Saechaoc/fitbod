//
//  SessionWidgetsBRUCopyTests.swift
//  fitbodTests
//
//  Phase 2.1 Plan 08 — BRU rewrite source-anchor tests for the 11 session
//  widget files rewritten / created in Plan 08. Uses the same source-reading
//  pattern as sibling BRU copy test suites.
//
//  Each @Test reads the relevant source file and asserts:
//    1. Verbatim UI-SPEC copy strings are present.
//    2. Banned v1 tokens (accentColor, Capsule, SF Symbols, system colors) are absent.
//
//  Tests map to UI-REVIEW Wave D items 37-47.
//

import Foundation
import Testing
@testable import fitbod

@Suite("SessionWidgetsBRUCopy")
struct SessionWidgetsBRUCopyTests {

    // MARK: - Helpers

    private func sessions() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions")
    }

    private func src(_ file: String) throws -> String {
        try String(contentsOf: sessions().appendingPathComponent(file), encoding: .utf8)
    }

    // MARK: - Test 1: PerSetNoteSheet verbatim copy

    @Test("perSetNoteSheetIncludesVerbatimCopy")
    func perSetNoteSheetIncludesVerbatimCopy() throws {
        let source = try src("PerSetNoteSheet.swift")

        // UI-SPEC line 380 verbatim labels
        #expect(source.contains("SET"))                                            // "SET {N} NOTE"
        #expect(source.contains("NOTE"))                                           // "SET {N} NOTE"
        #expect(source.contains("\"CANCEL\""))                                     // left action
        #expect(source.contains("\"SAVE\""))                                       // right action (signal)
        #expect(source.contains("BRUHeaderBar"))                                   // BRU chrome
    }

    // MARK: - Test 2: TempoEntryRow verbatim labels

    @Test("tempoEntryRowIncludesVerbatimLabels")
    func tempoEntryRowIncludesVerbatimLabels() throws {
        let source = try src("TempoEntryRow.swift")

        // UI-SPEC line 382 verbatim labels
        #expect(source.contains("\"TEMPO\""))                                      // section label
        #expect(source.contains("\"ECC\""))                                        // field label
        #expect(source.contains("\"BOT\""))                                        // field label
        #expect(source.contains("\"CON\""))                                        // field label
        #expect(source.contains("\"TOP\""))                                        // field label
        #expect(source.contains("BRUFont.labelSmall"))                             // BRU typography
    }

    // MARK: - Test 3: PartialRepsRow label

    @Test("partialRepsRowLabel")
    func partialRepsRowLabel() throws {
        let source = try src("PartialRepsRow.swift")

        // UI-SPEC line 383 verbatim label
        #expect(source.contains("\"PARTIAL REPS\""))                               // section label
        #expect(source.contains("BRUFont.labelSmall"))                             // BRU typography
    }

    // MARK: - Test 4: ClusterSubRepChipRow label and no Capsule

    @Test("clusterSubRepChipRowLabel")
    func clusterSubRepChipRowLabel() throws {
        let source = try src("ClusterSubRepChipRow.swift")

        // UI-SPEC line 384 verbatim label
        #expect(source.contains("\"SUB-REPS:\""))                                  // section label

        // UI-SPEC line 349: NOT a Capsule
        #expect(!source.contains("Capsule("))

        // BRU signal for trailing "+" chip per UI-SPEC line 384 + 257
        #expect(source.contains("bruSignal"))
    }

    // MARK: - Test 5: SwapExerciseSheet copy + footer verbatim

    @Test("swapExerciseSheetCopy")
    func swapExerciseSheetCopy() throws {
        let source = try src("SwapExerciseSheet.swift")

        // UI-SPEC verbatim chrome title
        #expect(source.contains("\"SWAP EXERCISE\""))                              // header center
        #expect(source.contains("\"CANCEL\""))                                     // left action
        #expect(source.contains("BRUHeaderBar"))                                   // BRU chrome

        // UI-SPEC verbatim footer note (line 391)
        #expect(source.contains("This swap applies to this session only. The routine template will not change."))
    }

    // MARK: - Test 6: AddUnplannedExerciseButton uses BRUDashedSlot

    @Test("addUnplannedExerciseButtonUsesBRUDashedSlot")
    func addUnplannedExerciseButtonUsesBRUDashedSlot() throws {
        let source = try src("AddUnplannedExerciseButton.swift")

        // BRUDashedSlot integration per UI-SPEC line 582
        #expect(source.contains("BRUDashedSlot"))
        #expect(source.contains("+ ADD EXERCISE"))                                 // UI-SPEC verbatim label
        #expect(source.contains("↘ FROM LIBRARY"))                                 // UI-SPEC verbatim hint
    }

    // MARK: - Test 7: PinnedNoteCapsule — no yellow, no pin.fill, no Capsule

    @Test("pinnedNoteCapsuleNoYellowNoPinFill")
    func pinnedNoteCapsuleNoYellowNoPinFill() throws {
        let source = try src("PinnedNoteCapsule.swift")

        // UI-SPEC line 221: explicitly bans system yellow
        #expect(!source.contains("systemYellow"))

        // pin.fill SF Symbol must be absent
        #expect(!source.contains("pin.fill"))

        // Capsule shape must be absent (UI-SPEC line 349)
        // Note: checks for ".clipShape(Capsule(" not bare "Capsule(" since struct name contains substring
        #expect(!source.contains(".clipShape(Capsule("))
        #expect(!source.contains(" Capsule()"))

        // BRU replacement: bruBg2 fill + Rectangle outline
        #expect(source.contains("Color.bruBg2"))
        #expect(source.contains("Rectangle()"))
    }

    // MARK: - Test 8: ResumeWorkoutBanner — no rounded rectangle, no accent, uses BRUPillButton

    @Test("resumeWorkoutBannerNoRoundedNoAccent")
    func resumeWorkoutBannerNoRoundedNoAccent() throws {
        let source = try src("ResumeWorkoutBanner.swift")

        // Banned v1 tokens removed per UI-SPEC line 583
        #expect(!source.contains("RoundedRectangle(cornerRadius: 12"))
        #expect(!source.contains("Color.accentColor"))
        #expect(!source.contains("arrow.uturn.backward.circle"))

        // BRU replacement
        #expect(source.contains("BRUPillButton"))
        #expect(source.contains("\"RESUME\""))                                     // UI-SPEC verbatim label
    }

    // MARK: - Test 9: No banned tokens across all 10 rewritten session widget files

    @Test("noBannedTokensInSessionWidgetSurfaces")
    func noBannedTokensInSessionWidgetSurfaces() throws {
        let filesToCheck = [
            "PerSetNoteSheet.swift",
            "WorkoutNotesSheet.swift",
            "TempoEntryRow.swift",
            "PartialRepsRow.swift",
            "ClusterSubRepChipRow.swift",
            "PreviousColumn.swift",
            "SwapExerciseSheet.swift",
            "AddUnplannedExerciseButton.swift",
            "ResumeWorkoutBanner.swift",
            "PinnedNoteCapsule.swift",
        ]

        for file in filesToCheck {
            let source = try src(file)

            // Strip comment lines before checking to avoid false positives in doc comments
            let codeLines = source.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            let code = codeLines.joined(separator: "\n")

            #expect(!code.contains("Color.accentColor"),
                    "\(file): Color.accentColor banned — UI-SPEC line 214")
            #expect(!code.contains("Color(.system"),
                    "\(file): Color(.system* banned — UI-SPEC line 259")
            #expect(!code.contains("Capsule()"),
                    "\(file): Capsule() banned — UI-SPEC line 257")
            #expect(!code.contains(".buttonStyle(.bordered"),
                    "\(file): .buttonStyle(.bordered) banned")
            #expect(!code.contains(".font(.body)"),
                    "\(file): .font(.body) banned — use BRUFont.*")
            #expect(!code.contains(".font(.headline)"),
                    "\(file): .font(.headline) banned — use BRUFont.*")
            #expect(!code.contains(".font(.caption)"),
                    "\(file): .font(.caption) banned — use BRUFont.*")
            #expect(!code.contains(".font(.title"),
                    "\(file): .font(.title*) banned — use BRUFont.*")
        }
    }
}
