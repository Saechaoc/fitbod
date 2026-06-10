//
//  SchedulingModeTests.swift
//  fitbodTests
//
//  RED scaffold: verifies SchedulingMode enum behaviour before the type
//  is created. These tests will fail until SchedulingMode.swift exists.
//
//  Phase 7 Plan 01 (07-01) — Task 1 TDD RED.
//

import Foundation
import Testing
@testable import fitbod

@Suite("SchedulingMode")
struct SchedulingModeTests {

    @Test("rawValue rotation parses to .rotation")
    func rawValueRotation() {
        #expect(SchedulingMode(rawValue: "rotation") == .rotation)
    }

    @Test("rawValue fixedWeekly parses to .fixedWeekly")
    func rawValueFixedWeekly() {
        #expect(SchedulingMode(rawValue: "fixedWeekly") == .fixedWeekly)
    }

    @Test("default is .rotation")
    func defaultIsRotation() {
        #expect(SchedulingMode.default == .rotation)
    }

    @Test("allCases has exactly 2 cases")
    func allCasesCountIsTwo() {
        #expect(SchedulingMode.allCases.count == 2)
    }
}
