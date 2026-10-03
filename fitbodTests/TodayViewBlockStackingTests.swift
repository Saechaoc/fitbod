//
//  TodayViewBlockStackingTests.swift
//  fitbodTests
//
//  Source-level contract tests for the Phase 4 Today banner stack.
//
//  Phase 2.1 Plan 04 update: TodayView was extracted from RootView.swift
//  into fitbod/Views/TodayView.swift. The `todayViewSource()` helper now
//  reads from the new canonical path. All structural assertions continue
//  to hold — the Phase 4/5 composition order is preserved in the new file.
//

import Foundation
import Testing
@testable import fitbod

@Suite("TodayViewBlockStacking")
struct TodayViewBlockStackingTests {
    @Test("TodayView source contains banner stacking order")
    func todayViewSourceContainsBannerStackingOrder() throws {
        let source = try todayViewSource()

        let deload = try position(of: "DeloadWeekBanner", in: source)
        let advisory = try position(of: "DeloadAdvisoryBanner", in: source)
        let statStrip = try position(of: "TodayStatStrip", in: source)
        let resume = try position(of: "ResumeWorkoutSlab", in: source)

        #expect(deload < advisory)
        #expect(advisory < statStrip)
        #expect(statStrip < resume)
    }

    @Test("TodayView has active block query")
    func todayViewHasActiveBlockQuery() throws {
        let source = try todayViewSource()

        #expect(source.contains("$0.isActive"))
        #expect(source.contains("activeBlocks"))
    }

    @Test("TodayView conditionally renders StartBlockCTA")
    func todayViewConditionallyRendersStartBlockCTA() throws {
        let source = try todayViewSource()

        // The condition that guards the CTA sits just before it. Search the
        // text right above the CTA so an unrelated `!activeBlocks.isEmpty`
        // earlier in the file cannot satisfy the check.
        let cta = try position(of: "StartBlockCTA(", in: source)
        let start = source.index(source.startIndex, offsetBy: max(0, cta - 200))
        let end = source.index(source.startIndex, offsetBy: cta)
        let guardText = source[start..<end]

        #expect(guardText.contains("activeBlocks.isEmpty"))
        #expect(!guardText.contains("!activeBlocks.isEmpty"))
    }

    @Test("TodayView conditionally renders deload banner when phase is deload")
    func todayViewConditionallyRendersDeloadBannerWhenPhaseIsDeload() throws {
        let source = try todayViewSource()

        #expect(source.contains("DeloadWeekBanner"))
        #expect(source.contains("phase.kind == .deload"))
    }

    @Test("StartBlockCTA copy verbatim")
    func startBlockCTACopyVerbatim() throws {
        let source = try sourceFile("fitbod/Periodization/StartBlockCTA.swift")

        #expect(source.contains("\"No active block.\""))
        #expect(source.contains("\"Define a training block to see your phase, week, and deloads here.\""))
        #expect(source.contains("\"Start a block\""))
        #expect(source.contains(".textCase(.uppercase)"))
    }

    @Test("DeloadWeekBanner copy verbatim")
    func deloadBannerCopyVerbatim() throws {
        let source = try sourceFile("fitbod/Periodization/DeloadWeekBanner.swift")

        #expect(source.contains("\"Deload week — recover, don't load.\""))
        #expect(source.contains("\"Working sets cut by ~50%. Weights held to phase intensity.\""))
    }

    @Test("no workout scheduled fallback preserved")
    func noWorkoutFallbackPreserved() throws {
        let source = try todayViewSource()

        #expect(source.contains("\"No workout scheduled\""))
        #expect(source.contains("\"Build a routine or pick one from your library.\""))
        #expect(source.contains("\"+ NEW ROUTINE\""))
    }

    @Test("BlockContextBand receives block value")
    func blockContextBandReceivesBlockValue() throws {
        let source = try todayViewSource()

        #expect(source.contains("BlockContextBand(block:"))
    }

    @Test("TodayView is standalone in fitbod/Views/TodayView.swift")
    func todayViewIsStandalone() throws {
        let rootSource = try sourceFile("fitbod/App/RootView.swift")

        // The inline private struct TodayView must NOT exist in RootView.swift anymore
        #expect(!rootSource.contains("private struct TodayView: View {"))
        // The call site still mounts TodayView()
        #expect(rootSource.contains("TodayView()"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func todayViewSource() throws -> String {
        // Phase 2.1 Plan 04: TodayView is now in fitbod/Views/TodayView.swift
        try sourceFile("fitbod/Views/TodayView.swift")
    }

    private func position(of needle: String, in source: String) throws -> Int {
        let range = try #require(source.range(of: needle))
        return source.distance(from: source.startIndex, to: range.lowerBound)
    }
}
