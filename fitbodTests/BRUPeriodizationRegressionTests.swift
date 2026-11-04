// BRUPeriodizationRegressionTests.swift
// fitbodTests
//
// Phase 04.1 Plan 08 — Wave 7: Body-structure regression suite for all 12 rewritten
// Phase 4 surfaces + 1 net-new BlockOverviewScreen (CONTEXT D-10).
//
// Framework choice: XCTest body-structure assertions (NOT image-diff snapshots).
// See PLAN-INDEX.md "Snapshot Test Framework" section + CONTEXT D-23.
//
// Strategy per PLAN-INDEX.md D-23:
//   1. Each @Test loads the surface's source file via #filePath ascent.
//   2. Asserts BRU primitive identifiers (BRUChip, BRUHeaderBar, Color.bruInk, etc.)
//      are present, and forbidden Apple-HIG identifiers are absent.
//   3. Matches the precedent set by Phase 6 SessionLoggerCopyTests.
//
// Revision iter 1 hooks per PLAN-INDEX.md:
//   - BlockOverviewScreen: assert @Query<Session> data wiring, no hardcoded mocks (B5)
//
// Run via:
//   xcodebuild test -scheme fitbod -only-testing:fitbodTests/BRUPeriodizationRegressionTests

import Foundation
import SwiftUI
import Testing
@testable import fitbod

// MARK: - BRUPeriodizationRegressionTests

@Suite("BRUPeriodizationRegression", .serialized)
struct BRUPeriodizationRegressionTests {

    // MARK: - Path Helper

    /// Computes the absolute path to a source file under fitbod/Periodization/ (or fitbod/Routines/)
    /// relative to this test file's compile-time location (#filePath ascent).
    ///
    /// Layout:
    ///   fitbodTests/BRUPeriodizationRegressionTests.swift   ← #filePath
    ///   fitbod/Periodization/<File>.swift                   ← default target
    ///   fitbod/Routines/<File>.swift                        ← alternate (directory: "Routines")
    ///
    /// We go up one level from fitbodTests/ to the project root, then into fitbod/<directory>/.
    private static func surfacePath(_ filename: String, in directory: String = "Periodization") -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("fitbod")
            .appendingPathComponent(directory)
            .appendingPathComponent(filename)
            .path
    }

    private func loadSource(_ filename: String, in directory: String = "Periodization") throws -> String {
        let path = Self.surfacePath(filename, in: directory)
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    /// Returns the source with single-line comment lines removed.
    /// Use this for negative assertions (patterns that MUST NOT appear in code)
    /// to avoid false positives from doc-comment references like
    /// "// replaces Image(systemName: \"line.3.horizontal\")"
    /// Mirrors the loadCodeOnly pattern from BRUPrimitivesTests.
    private func loadCodeOnly(_ filename: String, in directory: String = "Periodization") throws -> String {
        let source = try loadSource(filename, in: directory)
        let codeLines = source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("//")
            }
        return codeLines.joined(separator: "\n")
    }

    // MARK: - 1. BlockBuilderView — RETIRED (quick task 260528-vi2)
    //
    // The `blockBuilderViewBRUPrimitives()` regression test was retired when the
    // New Block screen was redesigned to the rounded-card final-design.png contract.
    // That contract intentionally abandons the Phase 04.1 brutalist vocabulary this
    // test asserted — BRUHeaderBar / BRUSectionHead / BRUButton / the 56pt `Canvas`
    // TIMELINE band were all replaced (the timeline became a Swift Charts progression
    // card in 260528-utc; the screen uses the bespoke `NewBlock*` component family with
    // its own `NewBlockScreenTokens`, not the shared BRU primitives). The screen's
    // current contract is guarded by NewBlockBuilderFidelityTests + BlockBuilderViewCopyTests
    // + BlockBuilderViewActivationTests instead. BlockBuilderView is likewise exempt from
    // `allSurfacesUseAtLeastOneBRUPrimitive` and BRUPeriodizationAuditTests below.

    // MARK: - 2. BlockReviewView

    @Test("BlockReviewView — hero band + bottom action bar + BRU primitives")
    func blockReviewViewBRUPrimitives() throws {
        let source = try loadSource("BlockReviewView.swift")
        let codeOnly = try loadCodeOnly("BlockReviewView.swift")
        #expect(source.contains("BRUHeaderBar"),
                "BlockReviewView.swift must use BRUHeaderBar")
        #expect(source.contains("BRUSectionHead"),
                "BlockReviewView.swift must use BRUSectionHead for e1RM section")
        #expect(source.contains("BRUButton"),
                "BlockReviewView.swift must use BRUButton for 'Start next ▸' CTA")
        #expect(source.contains("Color.bruInk") || source.contains(".bruInk"),
                "BlockReviewView.swift must reference bruInk for hero band background")
        #expect(source.contains("BRUFont."),
                "BlockReviewView.swift must use BRUFont type roles")
        #expect(source.contains("GeometryReader"),
                "BlockReviewView.swift must use GeometryReader for e1RM progress bars (UI-REVIEW Pillar 2 Fix 2)")
        #expect(!codeOnly.contains("Form {"),
                "BlockReviewView.swift must NOT use Form { in code (replaced by ScrollView+VStack)")
    }

    // MARK: - 5. BlockPhaseColors

    @Test("BlockPhaseColors — BRU palette tokens + rowTint")
    func blockPhaseColorsBRUPrimitives() throws {
        let source = try loadSource("BlockPhaseColors.swift")
        #expect(source.contains("Color.bruInk") || source.contains(".bruInk"),
                "BlockPhaseColors.swift must return bruInk for accumulation phase")
        #expect(source.contains("Color.bruSignal") || source.contains(".bruSignal"),
                "BlockPhaseColors.swift must return bruSignal for intensification phase")
        #expect(source.contains("rowTint"),
                "BlockPhaseColors.swift must include rowTint(for:) helper")
        #expect(source.contains("phaseLabel"),
                "BlockPhaseColors.swift must include phaseLabel(_:) helper")
    }

    // MARK: - 8. MesocycleWeekPage

    @Test("MesocycleWeekPage — BRUChip + BRUFont + no Capsule/system fonts")
    func mesocycleWeekPageBRUPrimitives() throws {
        let source = try loadSource("MesocycleWeekPage.swift")
        let codeOnly = try loadCodeOnly("MesocycleWeekPage.swift")
        #expect(source.contains("BRUChip"),
                "MesocycleWeekPage.swift must use BRUChip for phase and week chips (replaces Capsule)")
        #expect(source.contains("BRUFont."),
                "MesocycleWeekPage.swift must use BRUFont type roles")
        #expect(source.contains("Color.bruInk") || source.contains("Color.bruMuted") || source.contains(".bruMuted"),
                "MesocycleWeekPage.swift must reference BRU color tokens")
        #expect(!codeOnly.contains("Capsule()"),
                "MesocycleWeekPage.swift must NOT use Capsule() in code (replaced by BRUChip)")
    }

    // MARK: - 9. DeloadWeekBanner

    @Test("DeloadWeekBanner — bruBg2 background + bruInk top border + BRUFont + no RoundedRectangle")
    func deloadWeekBannerBRUPrimitives() throws {
        let source = try loadSource("DeloadWeekBanner.swift")
        let codeOnly = try loadCodeOnly("DeloadWeekBanner.swift")
        #expect(source.contains("Color.bruBg2") || source.contains(".bruBg2"),
                "DeloadWeekBanner.swift must use bruBg2 background")
        #expect(source.contains("Color.bruInk") || source.contains(".bruInk"),
                "DeloadWeekBanner.swift must use bruInk for top border")
        #expect(source.contains("BRUFont."),
                "DeloadWeekBanner.swift must use BRUFont type roles")
        #expect(!codeOnly.contains("RoundedRectangle(cornerRadius"),
                "DeloadWeekBanner.swift must NOT use RoundedRectangle in code (sharp corners per 04-UI-SPEC line 36)")
    }

    // MARK: - 11. StartBlockCTA

    @Test("StartBlockCTA — BRUFont + bruSignal CTA + no RoundedRectangle")
    func startBlockCTABRUPrimitives() throws {
        let source = try loadSource("StartBlockCTA.swift")
        let codeOnly = try loadCodeOnly("StartBlockCTA.swift")
        #expect(source.contains("BRUFont."),
                "StartBlockCTA.swift must use BRUFont type roles")
        #expect(source.contains("Color.bruSignal") || source.contains(".bruSignal"),
                "StartBlockCTA.swift must use bruSignal for CTA text color")
        #expect(!codeOnly.contains("RoundedRectangle(cornerRadius"),
                "StartBlockCTA.swift must NOT use RoundedRectangle in code (sharp corners per 04-UI-SPEC line 36)")
        #expect(!codeOnly.contains("Color.accentColor"),
                "StartBlockCTA.swift must NOT use Color.accentColor in code")
    }

    // MARK: - 13. BlockOverviewScreen

    @Test("BlockOverviewScreen — public struct + BRUHeaderBar + EDIT BLOCK + accessibility + real @Query<Session> data")
    func blockOverviewScreenBRUPrimitives() throws {
        let source = try loadSource("BlockOverviewScreen.swift")
        #expect(source.contains("public struct BlockOverviewScreen"),
                "BlockOverviewScreen.swift must declare public struct BlockOverviewScreen (CONTEXT D-10)")
        #expect(source.contains("BRUHeaderBar"),
                "BlockOverviewScreen.swift must use BRUHeaderBar")
        #expect(source.contains("EDIT BLOCK"),
                "BlockOverviewScreen.swift must include 'EDIT BLOCK' CTA (CONTEXT D-10)")
        #expect(source.contains("accessibilityLabel"),
                "BlockOverviewScreen.swift must carry accessibilityLabel per CONTEXT D-15")
        #expect(source.contains("BlockOverviewRoute"),
                "BlockOverviewScreen.swift must reference BlockOverviewRoute for navigation wiring (CONTEXT D-11)")
        // Revision iter 1 B5: real @Query<Session> data — no hardcoded mocks
        #expect(source.contains("@Query") || source.contains("_weekSessions = Query"),
                "BlockOverviewScreen.swift must use @Query for real session data (revision iter 1 B5)")
        #expect(source.contains("Session"),
                "BlockOverviewScreen.swift must reference Session model for real session-data wiring")
        // Additional BRU primitive coverage
        #expect(source.contains("BRUSectionHead") || source.contains("BRUButton") || source.contains("BRUChip"),
                "BlockOverviewScreen.swift must compose at least one BRU primitive beyond BRUHeaderBar")
    }

    // MARK: - 14. allSurfacesUseAtLeastOneBRUPrimitive (aggregate guardrail)

    @Test("allSurfacesUseAtLeastOneBRUPrimitive — every Phase 4 surface references at least one BRU identifier")
    func allSurfacesUseAtLeastOneBRUPrimitive() throws {
        let bruPrimitiveIdentifiers = [
            "BRUChip", "BRUHeaderBar", "BRUSectionHead", "BRUButton",
            "BRUDivider", "BRUDashedSlot", "BRUPillButton", "BRUDisplay",
            "BRUReadout", "BRUCornerBadge", "Color.bruInk", "Color.bruSignal",
            "Color.bruPaper", "Color.bruBg", "Color.bruBg2", "Color.bruMuted",
            "Color.bruHair", "Color.bruFaint", "BRUFont.",
            ".bruInk", ".bruSignal", ".bruPaper", ".bruMuted",
        ]

        let surfaces: [(filename: String, directory: String)] = [
            // BlockBuilderView.swift retired here in 260528-vi2: the rounded-card redesign
            // uses local NewBlockScreenTokens, not the shared BRU primitive identifiers.
            ("BlockReviewView.swift", "Periodization"),
            ("BlockPhaseColors.swift", "Periodization"),
            ("MesocycleWeekPage.swift", "Periodization"),
            ("DeloadWeekBanner.swift", "Periodization"),
            ("StartBlockCTA.swift", "Periodization"),
            ("BlockOverviewScreen.swift", "Periodization"),
        ]

        for (filename, directory) in surfaces {
            let source = try loadSource(filename, in: directory)
            let hasAnyPrimitive = bruPrimitiveIdentifiers.contains { source.contains($0) }
            #expect(hasAnyPrimitive,
                    "\(filename) must reference at least one BRU primitive identifier — found none. This file may have missed the BRU re-skin.")
        }
    }
}
