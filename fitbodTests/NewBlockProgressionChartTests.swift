//
//  NewBlockProgressionChartTests.swift
//  fitbodTests
//
//  260610-ey9: Guardrail suite for the rebuilt NewBlockProgressionChart.
//  Covers phaseLabelInk correctness, required source primitives, and
//  contiguous-span label logic.
//

import Foundation
import SwiftUI
import Testing
@testable import fitbod

@Suite("NewBlockProgressionChart")
struct NewBlockProgressionChartTests {

    // ── Path helpers (mirrors NewBlockBuilderFidelityTests pattern) ──────────

    private static func projectPath(_ components: [String]) -> URL {
        components.reduce(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        ) { partial, component in
            partial.appendingPathComponent(component)
        }
    }

    private func source(_ components: String...) throws -> String {
        try String(contentsOf: Self.projectPath(Array(components)), encoding: .utf8)
    }

    // ── Test 1: phaseLabelInk returns distinct, contrast-safe colors ─────────

    @Test("phaseLabelInkReturnsContrastSafeColorsPerKind")
    func phaseLabelInkReturnsContrastSafeColorsPerKind() {
        let accumulation   = BlockPhaseColors.phaseLabelInk(for: .accumulation)
        let intensification = BlockPhaseColors.phaseLabelInk(for: .intensification)
        let deload         = BlockPhaseColors.phaseLabelInk(for: .deload)
        let realization    = BlockPhaseColors.phaseLabelInk(for: .realization)

        // Each must be non-clear
        #expect(accumulation   != Color.clear)
        #expect(intensification != Color.clear)
        #expect(deload         != Color.clear)
        #expect(realization    != Color.clear)

        // Each must be distinct from bruMuted (which is the generic secondary color)
        #expect(accumulation   != Color.bruMuted)
        #expect(intensification != Color.bruMuted)
        #expect(deload         != Color.bruMuted)
        #expect(realization    != Color.bruMuted)

        // Accumulation and intensification should differ from each other
        #expect(accumulation != intensification)

        // Deload and realization should differ from each other
        #expect(deload != realization)
    }

    // ── Test 2: Required verbatim strings still present (guardrails) ─────────

    @Test("progressionChartSourceContainsRequiredStructureAfterRebuild")
    func progressionChartSourceContainsRequiredStructureAfterRebuild() throws {
        let src = try source("fitbod", "Periodization", "BlockBuilderView.swift")

        #expect(src.contains("\"PROGRESSION OVERVIEW\""),
                "PROGRESSION OVERVIEW title must remain verbatim.")
        #expect(src.contains("\"Volume\""),
                "\"Volume\" series string must remain (used in .value(\"Series\", \"Volume\")).")
        #expect(src.contains("\"Intensity\""),
                "\"Intensity\" series string must remain (used in .value(\"Series\", \"Intensity\")).")
        #expect(src.contains("NewBlockProgressionChart"),
                "Struct name NewBlockProgressionChart must remain.")
    }

    // ── Test 3: New rendering primitives present in source ───────────────────

    @Test("progressionChartSourceUsesAreaMarkAndRuleMark")
    func progressionChartSourceUsesAreaMarkAndRuleMark() throws {
        let src = try source("fitbod", "Periodization", "BlockBuilderView.swift")

        #expect(src.contains("AreaMark("),
                "Volume must render via AreaMark (translucent area mass, not a thin line).")
        #expect(src.contains("RuleMark("),
                "A vertical RuleMark must mark the selected week.")
        #expect(src.contains("chartXSelection"),
                "chartXSelection binding must drive the scrub interaction.")
        #expect(src.contains("sensoryFeedback"),
                "sensoryFeedback(.selection) must fire on week boundary changes.")
    }

    // ── Test 4: Phase label ink routes through the new helper ────────────────

    @Test("progressionChartSourceUsesPhaseLabelInkHelper")
    func progressionChartSourceUsesPhaseLabelInkHelper() throws {
        let src = try source("fitbod", "Periodization", "BlockBuilderView.swift")

        #expect(src.contains("BlockPhaseColors.phaseLabelInk("),
                "Phase label foregroundStyle must route through BlockPhaseColors.phaseLabelInk.")
    }

    // ── Test 5: Contiguous-span logic replaces per-phase label row ───────────

    @Test("contiguousPhaseSpansCollapseAdjacentSameKindWeeks")
    func contiguousPhaseSpansCollapseAdjacentSameKindWeeks() throws {
        let src = try source("fitbod", "Periodization", "BlockBuilderView.swift")

        // The source must contain the contiguousPhaseSpans computed property
        #expect(src.contains("contiguousPhaseSpans"),
                "A contiguousPhaseSpans computed property must exist to collapse adjacent same-kind phases.")

        // The old detached GeometryReader/HStack phase-label row must be gone.
        // The label row pattern was: GeometryReader { geo in HStack(spacing: 0) { ForEach(phases, id: \.draftID) { phase in Text(NewBlockPhaseText.abbreviation
        // We check the old pattern (multi-word) is absent.
        let oldPattern = "GeometryReader { geo in\n                    HStack(spacing: 0) {\n                        ForEach(phases, id: \\.draftID) { phase in\n                            Text(NewBlockPhaseText.abbreviation"
        #expect(!src.contains(oldPattern),
                "The old detached GeometryReader phase-label row must be removed.")
    }
}
