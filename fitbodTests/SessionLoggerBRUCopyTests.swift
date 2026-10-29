//
//  SessionLoggerBRUCopyTests.swift
//  fitbodTests
//
//  Phase 2.1 Plan 07 — BRU rewrite source-anchor tests for the 7 rewritten
//  session logger files. These use the same source-reading pattern as
//  sibling BRU copy test suites (RoutineBuilderCopyTests, etc.).
//
//  Each @Test reads the relevant source file and asserts:
//    1. Verbatim UI-SPEC copy strings are present.
//    2. Banned v1 tokens (accentColor, Capsule, SF Symbols, system colors) are absent.
//
//  Tests are intentionally named to map to UI-REVIEW Wave D items 31-36 + 48.
//

import Foundation
import Testing
@testable import fitbod

@Suite("SessionLoggerBRUCopy")
struct SessionLoggerBRUCopyTests {

    // MARK: - Helpers

    private func sessions() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions")
    }

    private func views() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Views")
    }

    private func src(_ file: String, in dir: URL) throws -> String {
        try String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8)
    }

    // MARK: - Test 1: SessionLoggerView verbatim header copy

    @Test("sessionLoggerViewIncludesVerbatimHeaderCopy")
    func sessionLoggerViewIncludesVerbatimHeaderCopy() throws {
        let source = try src("SessionLoggerView.swift", in: sessions())

        // UI-SPEC line 358-362 verbatim copy anchors:
        #expect(source.contains("\"Workout\""))                                  // header center — UI-SPEC line 360
        #expect(source.contains("\"‹\""))                                        // back glyph — UI-SPEC line 359
        #expect(source.contains("\"•••\""))                                      // menu glyph — UI-SPEC line 361

        // 3-line principal block wiring
        #expect(source.contains("routineSnapshotName"))                          // Line 2: routine name
        #expect(source.contains("elapsedLabel"))                                 // Line 2: elapsed time
        #expect(source.contains("IntentChip(intent: session.intent)"))           // Line 3: intent chip
    }

    // MARK: - Test 2: SessionLoggerView verbatim confirmation copy

    @Test("sessionLoggerViewIncludesConfirmationCopy")
    func sessionLoggerViewIncludesConfirmationCopy() throws {
        let source = try src("SessionLoggerView.swift", in: sessions())

        // UI-SPEC line 393-395 — Finish workout confirmation
        #expect(source.contains("\"Finish workout?\""))                          // UI-SPEC verbatim
        #expect(source.contains("\"Finish\""))                                   // confirm action
        #expect(source.contains("\"Keep logging\""))                             // cancel action

        // UI-SPEC line 394-395 — Discard workout confirmation
        #expect(source.contains("\"Discard workout?\""))                         // UI-SPEC verbatim
        #expect(source.contains("\"No data will be saved.\""))                   // UI-SPEC verbatim
        #expect(source.contains("\"Discard\""))                                  // destructive action
    }

    // MARK: - Test 3: SetTypeChip uses BRU mapping, not system colors

    @Test("setTypeChipUsesBRUMappingNotSystemColors")
    func setTypeChipUsesBRUMappingNotSystemColors() throws {
        let source = try src("SetTypeChip.swift", in: sessions())

        // UI-SPEC line 222 + 257: system-colored capsules deprecated
        #expect(!source.contains("systemBlue"))
        #expect(!source.contains("systemOrange"))
        #expect(!source.contains("systemRed"))
        #expect(!source.contains("systemPurple"))
        #expect(!source.contains("Capsule("))                                    // NO Capsule shape

        // UI-SPEC line 378: BRU chip label mapping
        #expect(source.contains("\"W/UP\""))                                     // warmup chip label
        #expect(source.contains("\"DROP\""))                                     // drop chip label
        #expect(source.contains("\"FAIL\""))                                     // failure chip label
        #expect(source.contains("\"RP\""))                                       // rest-pause chip label

        // BRUChip present (not system capsule)
        #expect(source.contains("BRUChip"))

        // Long-press menu labels preserved verbatim (UI-SPEC line 379)
        #expect(source.contains("\"Working\""))
        #expect(source.contains("\"Warm-up\""))
        #expect(source.contains("\"Drop Set\""))
        #expect(source.contains("\"To Failure\""))
        #expect(source.contains("\"Rest-Pause\""))
    }

    // MARK: - Test 4: IntentChip uses BRU, not accent/teal

    @Test("intentChipUsesBRUNotAccentTeal")
    func intentChipUsesBRUNotAccentTeal() throws {
        let source = try src("IntentChip.swift", in: views())

        // Banned v1 tokens
        #expect(!source.contains("Color.accentColor"))
        #expect(!source.contains("Capsule()"))

        // BRU primitive
        #expect(source.contains("BRUChip"))

        // Accessibility label format preserved verbatim (UI-SPEC line 686)
        #expect(source.contains(".accessibilityLabel(\"Intent: \\(intent.rawValue.capitalized)\")"))

        // .strength → signal fill per UI-SPEC line 268-269
        #expect(source.contains(".bruSignal"))
    }

    // MARK: - Test 5: InlineRPEChipRow exposes 5 RPE values

    @Test("inlineRPEChipRowExposesFiveValues")
    func inlineRPEChipRowExposesFiveValues() throws {
        let source = try src("InlineRPEChipRow.swift", in: sessions())

        // UI-SPEC line 375: 5 chips "6" / "7" / "8" / "9" / "10"
        #expect(source.contains("[6, 7, 8, 9, 10]"))

        // Individual value literals (ForEach produces Text("\(value)") — asserting array is sufficient)
        // BRU chip styling present
        #expect(source.contains("BRUFont.displayMedium"))                        // displayMedium 18pt per spec
        #expect(source.contains("Color.bruInk"))
        #expect(source.contains("Color.bruPaper"))

        // Long-press to decimal sheet preserved
        #expect(source.contains("onLongPressGesture(minimumDuration: 0.5)"))
        #expect(source.contains("DecimalRPEPickerSheet"))

        // No banned tokens
        #expect(!source.contains("Color.accentColor"))
        #expect(!source.contains(".buttonStyle(.bordered)"))
    }

    // MARK: - Test 6: SetRow uses SetCompletionGlyph

    @Test("setRowUsesSetCompletionGlyph")
    func setRowUsesSetCompletionGlyph() throws {
        let source = try src("SetRow.swift", in: sessions())

        // SetCompletionGlyph replaces SF Symbol checkmark
        #expect(source.contains("SetCompletionGlyph"))

        // SF Symbol checkmarks removed from non-comment code
        // (We check the literal is NOT present in the live code by looking for it without quotes+period combo)
        // The file header comment mentions these; the actual Image(systemName:) call must be gone.
        #expect(!source.contains("Image(systemName: \"checkmark.circle.fill\""))
        #expect(!source.contains("Image(systemName: \"circle\""))                // old incomplete glyph
        #expect(!source.contains("Image(systemName: \"square.and.pencil\""))     // old notes icon

        // Typographic pencil glyph used instead
        #expect(source.contains("\"✎\""))                                        // UI-SPEC line 191

        // Commit guard preserved (T-02.1-07-01)
        #expect(source.contains("SessionSetActions.canComplete(entry)"))

        // No banned tokens in functional code
        #expect(!source.contains("Color.accentColor"))
    }

    // MARK: - Test 7: No banned tokens across all 7 rewritten files

    @Test("noBannedTokensInSessionLoggerSurfaces")
    func noBannedTokensInSessionLoggerSurfaces() throws {
        let sessBase = try sessions()
        let viewBase = try views()

        let filesToCheck: [(String, URL)] = [
            ("SessionLoggerView.swift",    sessBase),
            ("SessionExerciseCard.swift",  sessBase),
            ("SetRow.swift",               sessBase),
            ("InlineRPEChipRow.swift",     sessBase),
            ("DecimalRPEPickerSheet.swift", sessBase),
            ("SetTypeChip.swift",          sessBase),
            ("IntentChip.swift",           viewBase),
        ]

        for (file, dir) in filesToCheck {
            let source = try src(file, in: dir)

            // Strip comment lines before checking to avoid false positives in doc comments
            let codeLines = source.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            let code = codeLines.joined(separator: "\n")

            #expect(!code.contains("Color.accentColor"),
                    "Color.accentColor banned in \(file) — UI-SPEC line 214")
            #expect(!code.contains("Color(.system"),
                    "Color(.system* banned in \(file) — UI-SPEC line 259")
            #expect(!code.contains("Capsule()"),
                    "Capsule() banned in \(file) — UI-SPEC line 257")
            #expect(!code.contains(".buttonStyle(.bordered"),
                    ".buttonStyle(.bordered) banned in \(file)")
            #expect(!code.contains(".font(.body)"),
                    ".font(.body) banned in \(file) — use BRUFont.*")
            #expect(!code.contains(".font(.headline)"),
                    ".font(.headline) banned in \(file) — use BRUFont.*")
            #expect(!code.contains(".font(.title2)"),
                    ".font(.title2) banned in \(file) — use BRUFont.*")
            #expect(!code.contains(".font(.caption)"),
                    ".font(.caption) banned in \(file) — use BRUFont.*")
        }
    }
}
