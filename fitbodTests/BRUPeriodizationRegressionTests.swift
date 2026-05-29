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
//   - BlockCard: assert TabView pager preserved (B4 user decision)
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

    // MARK: - 3. BlockCard

    @Test("BlockCard — pager preserved + reduced-motion + accessibility + tap-routing")
    func blockCardBRUPrimitives() throws {
        let source = try loadSource("BlockCard.swift")
        #expect(source.contains("BRUChip"),
                "BlockCard.swift must use BRUChip for block/phase chips")
        #expect(source.contains("TabView"),
                "BlockCard.swift must PRESERVE TabView pager (revision iter 1 B4 user decision)")
        #expect(source.contains("accessibilityReduceMotion"),
                "BlockCard.swift must gate TabView animation on accessibilityReduceMotion (CONTEXT D-14)")
        #expect(source.contains("accessibilityLabel(\"Active block"),
                "BlockCard.swift must carry .accessibilityLabel(\"Active block...\") per CONTEXT D-15")
        #expect(source.contains("onTapBlock"),
                "BlockCard.swift must expose onTapBlock for BlockOverviewScreen tap-routing (CONTEXT D-11)")
        #expect(source.contains("Color.bruInk") || source.contains(".bruInk"),
                "BlockCard.swift must reference bruInk")
        #expect(source.contains("BRUFont."),
                "BlockCard.swift must use BRUFont type roles")
    }

    // MARK: - 4. BlockPhaseEditorRow

    @Test("BlockPhaseEditorRow — typographic drag glyph + rowTint + accessibility")
    func blockPhaseEditorRowBRUPrimitives() throws {
        let source = try loadSource("BlockPhaseEditorRow.swift")
        let codeOnly = try loadCodeOnly("BlockPhaseEditorRow.swift")
        #expect(source.contains("accessibilityLabel(\"Phase"),
                "BlockPhaseEditorRow.swift must carry .accessibilityLabel(\"Phase...\") per CONTEXT D-15")
        #expect(source.contains("BlockPhaseColors.rowTint"),
                "BlockPhaseEditorRow.swift must use BlockPhaseColors.rowTint for NOW-row tint")
        #expect(source.contains("\"⋮⋮\""),
                "BlockPhaseEditorRow.swift must use typographic drag glyph \"⋮⋮\" (CONTEXT D-07 + UI-REVIEW Pillar 6)")
        #expect(!codeOnly.contains("line.3.horizontal"),
                "BlockPhaseEditorRow.swift must NOT reference line.3.horizontal SF Symbol in code (replaced by ⋮⋮)")
        #expect(source.contains("BRUFont."),
                "BlockPhaseEditorRow.swift must use BRUFont type roles")
    }

    // MARK: - 5. BlockPhaseColors

    @Test("BlockPhaseColors — BRU palette tokens + drawDeloadStripes + rowTint")
    func blockPhaseColorsBRUPrimitives() throws {
        let source = try loadSource("BlockPhaseColors.swift")
        #expect(source.contains("Color.bruInk") || source.contains(".bruInk"),
                "BlockPhaseColors.swift must return bruInk for accumulation phase")
        #expect(source.contains("Color.bruSignal") || source.contains(".bruSignal"),
                "BlockPhaseColors.swift must return bruSignal for intensification phase")
        #expect(source.contains("drawDeloadStripes"),
                "BlockPhaseColors.swift must include drawDeloadStripes Canvas helper")
        #expect(source.contains("rowTint"),
                "BlockPhaseColors.swift must include rowTint(for:) helper")
        #expect(source.contains("phaseLabel"),
                "BlockPhaseColors.swift must include phaseLabel(_:) helper")
    }

    // MARK: - 6. BlockRow

    @Test("BlockRow — BRU primitives + swipeActions trash kept + no Capsule")
    func blockRowBRUPrimitives() throws {
        let source = try loadSource("BlockRow.swift")
        let codeOnly = try loadCodeOnly("BlockRow.swift")
        #expect(source.contains("BRUChip"),
                "BlockRow.swift must use BRUChip for week badge (replaces Capsule)")
        #expect(source.contains("Color.bruSignal") || source.contains(".bruSignal"),
                "BlockRow.swift must use bruSignal for active indicator (replaces Color.accentColor)")
        #expect(source.contains("BRUFont."),
                "BlockRow.swift must use BRUFont type roles")
        #expect(source.contains("swipeActions"),
                "BlockRow.swift must preserve swipeActions for delete (system chrome, CONTEXT D-07)")
        #expect(!codeOnly.contains("Color.accentColor"),
                "BlockRow.swift must NOT use Color.accentColor in code")
    }

    // MARK: - 7. BlockPickerMenu

    @Test("BlockPickerMenu — BRUChip + bruSignal + no accentColor")
    func blockPickerMenuBRUPrimitives() throws {
        let source = try loadSource("BlockPickerMenu.swift")
        let codeOnly = try loadCodeOnly("BlockPickerMenu.swift")
        #expect(source.contains("BRUChip"),
                "BlockPickerMenu.swift must use BRUChip for the block link chip")
        #expect(source.contains("Color.bruSignal") || source.contains(".bruSignal"),
                "BlockPickerMenu.swift must use bruSignal for linked-block accent")
        #expect(source.contains("BRUFont.") || source.contains("BRUFont"),
                "BlockPickerMenu.swift must reference BRU fonts")
        #expect(!codeOnly.contains("Color.accentColor"),
                "BlockPickerMenu.swift must NOT use Color.accentColor in code")
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

    // MARK: - 10. ConsiderDeloadBanner

    @Test("ConsiderDeloadBanner — FATIGUE ADVISORY + BRUChip DISMISS + no Adjust block + no exclamationmark.triangle")
    func considerDeloadBannerBRUPrimitives() throws {
        let source = try loadSource("ConsiderDeloadBanner.swift")
        let codeOnly = try loadCodeOnly("ConsiderDeloadBanner.swift")
        #expect(source.contains("FATIGUE ADVISORY"),
                "ConsiderDeloadBanner.swift must display 'FATIGUE ADVISORY' header (CONTEXT D-09)")
        #expect(source.contains("BRUChip(\"DISMISS\")"),
                "ConsiderDeloadBanner.swift must use BRUChip(\"DISMISS\") for dismiss (CONTEXT D-17)")
        #expect(!codeOnly.contains("Adjust block"),
                "ConsiderDeloadBanner.swift must NOT contain 'Adjust block' button in code (CONTEXT D-16)")
        #expect(!codeOnly.contains("exclamationmark.triangle"),
                "ConsiderDeloadBanner.swift must NOT contain exclamationmark.triangle SF Symbol in code (CONTEXT D-07)")
        #expect(source.contains("BRUFont."),
                "ConsiderDeloadBanner.swift must use BRUFont type roles")
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

    // MARK: - 12. RoutinesListView (blocksSection copy fix)

    @Test("RoutinesListView.blocksSection — D-09 copy fix: 'No blocks defined.' + '+ NEW BLOCK'")
    func routinesListViewBlocksSectionBRUPrimitives() throws {
        let source = try loadSource("RoutinesListView.swift", in: "Routines")
        let codeOnly = try loadCodeOnly("RoutinesListView.swift", in: "Routines")
        #expect(source.contains("No blocks defined."),
                "RoutinesListView.swift must contain 'No blocks defined.' (D-09 copy fix)")
        #expect(source.contains("Create a training block to track mesocycles, phases, and scheduled deloads."),
                "RoutinesListView.swift must contain updated body copy (D-09 copy fix)")
        #expect(source.contains("+ NEW BLOCK"),
                "RoutinesListView.swift must contain '+ NEW BLOCK' signal-text CTA (D-09)")
        #expect(!codeOnly.contains("No blocks yet."),
                "RoutinesListView.swift must NOT contain old 'No blocks yet.' copy in code (D-09)")
        #expect(!codeOnly.contains("Define a training block to organize routines into a mesocycle."),
                "RoutinesListView.swift must NOT contain old body copy in code (D-09)")
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
            ("BlockCard.swift", "Periodization"),
            ("BlockPhaseEditorRow.swift", "Periodization"),
            ("BlockPhaseColors.swift", "Periodization"),
            ("BlockRow.swift", "Periodization"),
            ("BlockPickerMenu.swift", "Periodization"),
            ("MesocycleWeekPage.swift", "Periodization"),
            ("DeloadWeekBanner.swift", "Periodization"),
            ("ConsiderDeloadBanner.swift", "Periodization"),
            ("StartBlockCTA.swift", "Periodization"),
            ("RoutinesListView.swift", "Routines"),
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
