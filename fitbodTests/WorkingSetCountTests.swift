//
//  WorkingSetCountTests.swift
//  fitbodTests
//
//  The one rule for the working sets a prescription yields in a phase,
//  shared by the logger, Today's hero and its exercise rows (redesign 1.2).
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("WorkingSetCount")
struct WorkingSetCountTests {
    /// An un-inserted phase, as `PeriodizationEngineTests.makeBlock` builds them.
    private func phase(_ kind: BlockPhaseKind, volume: Double) -> BlockPhase {
        let phase = BlockPhase()
        phase.nameRaw = kind.rawValue
        phase.volumeMultiplier = volume
        return phase
    }

    @Test("a deload floors the product", arguments: [(4, 0.5, 2), (3, 0.5, 1), (5, 0.6, 3)])
    func aDeloadFloorsTheProduct(_ row: (targetSets: Int, volume: Double, expected: Int)) {
        let count = PeriodizationEngine.workingSetCount(
            targetSets: row.targetSets, phase: phase(.deload, volume: row.volume)
        )
        #expect(count == row.expected)
    }

    @Test("never below one set", arguments: [(1, 0.5), (2, 0.4)])
    func neverBelowOneSet(_ row: (targetSets: Int, volume: Double)) {
        let count = PeriodizationEngine.workingSetCount(
            targetSets: row.targetSets, phase: phase(.deload, volume: row.volume)
        )
        #expect(count == 1)
    }

    @Test("only a deload cuts")
    func onlyADeloadCuts() {
        #expect(PeriodizationEngine.workingSetCount(targetSets: 4, phase: phase(.accumulation, volume: 0.5)) == 4)
        #expect(PeriodizationEngine.workingSetCount(targetSets: 4, phase: nil) == 4)
    }

    @Test("a deload at full volume cuts nothing")
    func aDeloadAtFullVolumeCutsNothing() {
        #expect(PeriodizationEngine.workingSetCount(targetSets: 3, phase: phase(.deload, volume: 1.0)) == 3)
    }
}
