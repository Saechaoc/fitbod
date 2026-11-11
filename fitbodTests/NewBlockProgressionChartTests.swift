//
//  NewBlockProgressionChartTests.swift
//  fitbodTests
//
//  260610-ey9: the rebuilt NewBlockProgressionChart's phase label colors.
//

import Foundation
import SwiftUI
import Testing
@testable import fitbod

@Suite("NewBlockProgressionChart")
struct NewBlockProgressionChartTests {

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
}
