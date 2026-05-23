//
//  TodayViewBlockStackingTests.swift
//  fitbodTests
//
//  Source-level contract tests for the Phase 4 Today banner stack.
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
        let consider = try position(of: "ConsiderDeloadBanner", in: source)
        let card = try position(of: "BlockCard(block:", in: source)
        let resume = try position(of: "ResumeWorkoutBanner", in: source)
        let fallback = try position(of: "No workout in progress", in: source)

        #expect(deload < consider)
        #expect(consider < card)
        #expect(card < resume)
        #expect(resume < fallback)
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

        let cta = try position(of: "StartBlockCTA", in: source)
        let empty = try position(of: "activeBlocks.isEmpty", in: source)

        #expect(abs(cta - empty) < 500)
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
        #expect(source.contains("\"Start a Block\""))
    }

    @Test("DeloadWeekBanner copy verbatim")
    func deloadBannerCopyVerbatim() throws {
        let source = try sourceFile("fitbod/Periodization/DeloadWeekBanner.swift")

        #expect(source.contains("\"Deload week — recover, don't load.\""))
        #expect(source.contains("\"Working sets cut by ~50%. Weights held to phase intensity.\""))
    }

    @Test("ConsiderDeloadBanner copy verbatim")
    func considerDeloadBannerCopyVerbatim() throws {
        let source = try sourceFile("fitbod/Periodization/ConsiderDeloadBanner.swift")

        #expect(source.contains("\"Consider a deload this week.\""))
        #expect(source.contains("\"Adjust block\""))
    }

    @Test("no workout fallback preserved")
    func noWorkoutFallbackPreserved() throws {
        let source = try todayViewSource()

        #expect(source.contains("\"No workout in progress\""))
        #expect(source.contains("\"Start a workout from your Routines tab.\""))
    }

    @Test("BlockCard receives block value")
    func blockCardReceivesBlockValue() throws {
        let source = try todayViewSource()

        #expect(source.contains("BlockCard(block:"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func todayViewSource() throws -> String {
        let root = try sourceFile("fitbod/App/RootView.swift")
        let start = try #require(root.range(of: "private struct TodayView"))
        return String(root[start.lowerBound...])
    }

    private func position(of needle: String, in source: String) throws -> Int {
        let range = try #require(source.range(of: needle))
        return source.distance(from: source.startIndex, to: range.lowerBound)
    }
}
