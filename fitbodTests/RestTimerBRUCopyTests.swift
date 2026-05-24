// RestTimerBRUCopyTests.swift
// fitbodTests
//
// Source-anchor tests verifying BRU brutalist contracts for the rest timer
// surface — Phase 2.1 Plan 02.1-09 (UI-REVIEW Wave E items 49-54).
//
// Seven @Test functions:
//   1. notificationCopyPreservedFromV1          — "Rest complete" + body copy verbatim
//   2. restTimerOverlayUsesBRUHeaderBar         — BRUHeaderBar present, banned tokens absent
//   3. restTimerOverlayCopyVerbatim             — "SKIP" / "−15s" / "+15s" / "PRESCRIBED"
//   4. restTimerProgressArcUsesSignalStroke     — bruSignal + bruFaint + addArc; no accentColor
//   5. restTimerLiveActivityHasNoSFTimer        — no Image(systemName:"timer"), no accentColor,
//                                                @preconcurrency + bruSignal present
//   6. dynamicIslandViewFilesExist              — both new view files on disk
//   7. noBannedTokensInRestTimerSurfaces        — zero banned tokens across all 6 files
//
// These tests read on-disk source files at runtime — they are source-anchor
// tests, not behavioral tests. They fail fast if a careless edit silently
// breaks a UI-SPEC contract.
//

import Foundation
import Testing

@Suite("RestTimerBRUCopy")
struct RestTimerBRUCopyTests {

    // MARK: - Path helpers

    /// Resolves a path relative to the project root (two directories above fitbodTests/).
    private func projectPath(_ components: String...) -> URL {
        var url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // fitbodTests/
            .deletingLastPathComponent()   // fitbod/ (project root)
        for c in components { url = url.appendingPathComponent(c) }
        return url
    }

    private func read(_ components: String...) throws -> String {
        let url = projectPath(components[0], components.dropFirst().joined(separator: "/"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Test 1: Notification copy preserved from v1

    @Test("notificationCopyPreservedFromV1 — UI-SPEC lines 409-410 verbatim strings in NotificationScheduler")
    func notificationCopyPreservedFromV1() throws {
        let src = try read("fitbod", "Sessions/RestTimer/RestTimerNotificationScheduler.swift")
        // UI-SPEC verbatim (must never change — notification seen by user on lock screen):
        #expect(src.contains("\"Rest complete\""),
                "Notification title must be exactly \"Rest complete\" (UI-SPEC line 409)")
        #expect(src.contains("— next set ready."),
                "Notification body must contain \"— next set ready.\" (UI-SPEC line 410)")
    }

    // MARK: - Test 2: RestTimerOverlay uses BRUHeaderBar, not system chrome

    @Test("restTimerOverlayUsesBRUHeaderBarNotNavigationTitle — BRUHeaderBar present, banned tokens absent")
    func restTimerOverlayUsesBRUHeaderBarNotNavigationTitle() throws {
        let src = try read("fitbod", "Sessions/RestTimer/RestTimerOverlay.swift")
        // Must use BRU primitive header
        #expect(src.contains("BRUHeaderBar"),
                "Expanded sheet must use BRUHeaderBar (UI-SPEC line 402)")
        #expect(src.contains("\"REST TIMER\""),
                "BRUHeaderBar center must be \"REST TIMER\" (UI-SPEC line 402)")
        // Must NOT use system navigation
        #expect(!src.contains("navigationTitle"),
                "RestTimerOverlay must not use .navigationTitle (banned — use BRUHeaderBar)")
        #expect(!src.contains(".background(.regularMaterial)"),
                "Collapsed slab must not use .background(.regularMaterial) (banned)")
        #expect(!src.contains(".clipShape(.capsule)") && !src.contains(".clipShape(Capsule())"),
                "RestTimerOverlay must not clip to capsule shape (banned)")
        // Must use full-bleed slab background
        #expect(src.contains("Color.bruBg2"),
                "Collapsed slab background must be Color.bruBg2 (UI-SPEC line 401)")
    }

    // MARK: - Test 3: RestTimerOverlay verbatim BRU copy

    @Test("restTimerOverlayCopyVerbatim — SKIP / −15s / +15s / PRESCRIBED labels present")
    func restTimerOverlayCopyVerbatim() throws {
        let src = try read("fitbod", "Sessions/RestTimer/RestTimerOverlay.swift")
        #expect(src.contains("\"SKIP\""),
                "Skip button label must be \"SKIP\" (UI-SPEC line 407)")
        #expect(src.contains("\"−15s\""),
                "Minus button label must be \"−15s\" (UI-SPEC line 405)")
        #expect(src.contains("\"+15s\""),
                "Plus button label must be \"+15s\" (UI-SPEC line 406)")
        #expect(src.contains("\"PRESCRIBED · "),
                "Footer must contain \"PRESCRIBED · \" (UI-SPEC line 408)")
        // Accessibility verbatim (preserved from v1)
        #expect(src.contains("\"Subtract 15 seconds\""),
                "Minus button VoiceOver label must be verbatim (UI-SPEC accessibility)")
        #expect(src.contains("\"Add 15 seconds\""),
                "Plus button VoiceOver label must be verbatim (UI-SPEC accessibility)")
    }

    // MARK: - Test 4: RestTimerProgressArc uses bruSignal stroke

    @Test("restTimerProgressArcUsesSignalStroke — bruSignal + bruFaint + addArc; no accentColor")
    func restTimerProgressArcUsesSignalStroke() throws {
        let src = try read("fitbod", "Sessions/RestTimer/RestTimerProgressArc.swift")
        #expect(src.contains("Color.bruSignal"),
                "Progress arc must stroke in Color.bruSignal (UI-SPEC line 525)")
        #expect(src.contains("Color.bruFaint"),
                "Progress arc track must use Color.bruFaint (UI-SPEC line 525)")
        #expect(src.contains("addArc"),
                "Progress arc must be drawn with Path.addArc (UI-SPEC line 525)")
        #expect(!src.contains("Color.accentColor"),
                "Progress arc must NOT use Color.accentColor (banned for Phase 2+ surfaces)")
        // Reduce-motion contract (UI-SPEC line 696)
        #expect(src.contains("accessibilityReduceMotion"),
                "Progress arc must read @Environment(\\.accessibilityReduceMotion)")
    }

    // MARK: - Test 5: RestTimerLiveActivity has no SF timer symbol

    @Test("restTimerLiveActivityHasNoSFTimer — no Image(systemName:\"timer\"), no accentColor, @preconcurrency + bruSignal")
    func restTimerLiveActivityHasNoSFTimer() throws {
        let src = try read("FitbodWidgets", "RestTimerLiveActivity.swift")
        // Banned SF Symbol (UI-SPEC line 43 — no SF Symbols in BRU)
        // Check non-comment lines only by stripping // lines
        let codeLines = src.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!codeLines.contains("Image(systemName: \"timer\""),
                "Live Activity must NOT use Image(systemName: \"timer\") (banned by UI-SPEC line 43)")
        #expect(!codeLines.contains("Color.accentColor"),
                "Live Activity must NOT use Color.accentColor (deprecated for Phase 2+ surfaces)")
        // Required patterns
        #expect(src.contains("@preconcurrency import ActivityKit"),
                "Live Activity must use @preconcurrency import ActivityKit (project memory Swift 6 pattern)")
        #expect(src.contains("Color.bruSignal"),
                "Live Activity must use Color.bruSignal for accent (UI-SPEC line 415)")
    }

    // MARK: - Test 6: Dynamic Island view files exist on disk

    @Test("dynamicIslandViewFilesExist — both new view files present")
    func dynamicIslandViewFilesExist() {
        let compact = projectPath("FitbodWidgets", "RestTimerDynamicIslandCompactView.swift")
        let expanded = projectPath("FitbodWidgets", "RestTimerDynamicIslandExpandedView.swift")
        #expect(
            FileManager.default.fileExists(atPath: compact.path),
            "RestTimerDynamicIslandCompactView.swift must exist in FitbodWidgets/"
        )
        #expect(
            FileManager.default.fileExists(atPath: expanded.path),
            "RestTimerDynamicIslandExpandedView.swift must exist in FitbodWidgets/"
        )
    }

    // MARK: - Test 7: No banned tokens across all 6 rewritten/new files

    @Test("noBannedTokensInRestTimerSurfaces — zero banned tokens in all 6 files")
    func noBannedTokensInRestTimerSurfaces() throws {
        let filePaths: [(String, String)] = [
            ("fitbod", "Sessions/RestTimer/RestTimerOverlay.swift"),
            ("fitbod", "Sessions/RestTimer/RestTimerProgressArc.swift"),
            ("FitbodWidgets", "RestTimerLockScreenView.swift"),
            ("FitbodWidgets", "RestTimerLiveActivity.swift"),
            ("FitbodWidgets", "RestTimerDynamicIslandCompactView.swift"),
            ("FitbodWidgets", "RestTimerDynamicIslandExpandedView.swift"),
        ]

        // Banned patterns (checked in non-comment lines only)
        let bannedPatterns: [(pattern: String, description: String)] = [
            ("Capsule()", "Capsule() shape (banned — use Rectangle)"),
            ("RoundedRectangle(", "RoundedRectangle (banned — use Rectangle)"),
            ("Color.accentColor", "Color.accentColor (deprecated for Phase 2+)"),
            ("Image(systemName:", "Image(systemName:) (SF Symbols banned in BRU)"),
            ("Color(.system", "Color(.system*) (system colors banned)"),
            (".buttonStyle(.bordered)", ".buttonStyle(.bordered) (banned — use .plain)"),
            (".background(.regularMaterial)", ".background(.regularMaterial) (banned)"),
        ]

        // Font banned patterns — checked separately since they need regex-style matching
        let bannedFontSubstrings: [String] = [
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

        for (dir, path) in filePaths {
            let src = try read(dir, path)
            let codeLines = src.split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")

            for banned in bannedPatterns {
                #expect(
                    !codeLines.contains(banned.pattern),
                    "\(path): must not contain \(banned.description)"
                )
            }
            for font in bannedFontSubstrings {
                #expect(
                    !codeLines.contains(font),
                    "\(path): must not use system font style \(font) (use BRUFont roles)"
                )
            }
        }
    }
}
