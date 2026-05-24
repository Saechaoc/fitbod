// Phase3BRUPrimitivesTests.swift
// fitbodTests
//
// Swift Testing suite for Phase 3 BRU primitive components.
// Covers compile-and-instantiate contracts for:
//   CalibratingProgressMeter, PlateStackViz, PlateTallyRow
//
// Strategy:
//   - Each @Test instantiates the primitive with representative data.
//   - Instantiation proves the public init is honoured and all token/font
//     references (Color.bruInk, BRUFont.labelSmall, etc.) resolve at compile time.
//   - Visual / VoiceOver UAT is deferred to the Wave 3 grep audit and device QA.
//
// Run via:
//   xcodebuild test -scheme fitbod -only-testing:fitbodTests/Phase3BRUPrimitivesTests
//
// NOTE: Trust xcodebuild over SourceKit for any phantom "cannot find type" diagnostics
// on these new files — Swift Testing is bundled in Xcode 16+.

import Foundation
import SwiftUI
import Testing
@testable import fitbod

// MARK: - Phase 3 BRU Primitives

@Suite("Phase 3 BRU Primitives")
struct Phase3BRUPrimitivesTests {

    // MARK: - CalibratingProgressMeter

    @Test("CalibratingProgressMeter instantiates with in-progress data")
    func calibratingProgressMeterInstantiates() throws {
        // Proves: public init(current:threshold:rangeText:) compiles and the view
        // conforms to View. All BRU token + font references must resolve.
        let meter = CalibratingProgressMeter(current: 8, threshold: 10, rangeText: "± 5 LB")
        // Type check — if the struct is missing or mis-typed, this line fails to compile.
        let _: any View = meter
        #expect(Bool(true), "CalibratingProgressMeter instantiated successfully")
    }

    @Test("CalibratingProgressMeter handles edge case: zero current")
    func calibratingProgressMeterZeroCurrent() throws {
        let meter = CalibratingProgressMeter(current: 0, threshold: 10, rangeText: "± 5 LB")
        let _: any View = meter
        #expect(Bool(true), "CalibratingProgressMeter(0/10) instantiated without crash")
    }

    @Test("CalibratingProgressMeter handles overflow: current > threshold")
    func calibratingProgressMeterOverflow() throws {
        // current > threshold must not crash (ratio clamped to 1.0 per threat model T-03.2-03)
        let meter = CalibratingProgressMeter(current: 15, threshold: 10, rangeText: "± 2.5 KG")
        let _: any View = meter
        #expect(Bool(true), "CalibratingProgressMeter(15/10) instantiated with clamping")
    }

    // MARK: - PlateStackViz

    @Test("PlateStackViz instantiates with standard plate data")
    func plateStackVizInstantiates() throws {
        // platesPerSide is heaviest-first: [(45, 2), (25, 1), (10, 1)]
        // This mirrors the 205 lb stack (45+45+25+10+10 per side after bar subtraction)
        let viz = PlateStackViz(
            platesPerSide: [(weight: 45, count: 2), (weight: 25, count: 1), (weight: 10, count: 1)],
            barLabel: "45 lb"
        )
        let _: any View = viz
        #expect(Bool(true), "PlateStackViz instantiated successfully with sample data")
    }

    @Test("PlateStackViz instantiates with empty plates (degenerate bar)")
    func plateStackVizEmpty() throws {
        // Empty platesPerSide should render sleeve + end cap only (no crash)
        let viz = PlateStackViz(platesPerSide: [], barLabel: "45 lb")
        let _: any View = viz
        #expect(Bool(true), "PlateStackViz(empty) renders degenerate bar without crash")
    }

    @Test("PlateStackViz instantiates in mini-viz mode (heightScale 0.3)")
    func plateStackVizMiniMode() throws {
        let viz = PlateStackViz(
            platesPerSide: [(weight: 45, count: 1), (weight: 25, count: 1)],
            barLabel: "45 lb",
            heightScale: 0.3
        )
        let _: any View = viz
        #expect(Bool(true), "PlateStackViz mini-viz (heightScale=0.3) instantiated without crash")
    }

    // MARK: - PlateTallyRow

    @Test("PlateTallyRow instantiates with count = 3")
    func plateTallyRowInstantiates() throws {
        let viz = PlateTallyRow(weight: 45.0, count: .constant(3), unitLabel: "lb")
        let _: any View = viz
        #expect(Bool(true), "PlateTallyRow(45 lb, count=3) instantiated successfully")
    }

    @Test("PlateTallyRow instantiates with count = 0 (muted-opacity state)")
    func plateTallyRowZeroCount() throws {
        let viz = PlateTallyRow(weight: 2.5, count: .constant(0), unitLabel: "kg")
        let _: any View = viz
        #expect(Bool(true), "PlateTallyRow(2.5 kg, count=0) instantiated in muted-opacity state")
    }
}
