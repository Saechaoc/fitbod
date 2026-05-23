//
//  VolumeZoneTests.swift
//  fitbodTests
//
//  Pins the D-05 verbatim `<` boundaries of the `volumeZone(...)`
//  classifier. Pure-function math; no @MainActor, no ModelContainer.
//
//  Anchor target for tests: chest landmarks 8 / 14 / 22 (MEV / MAV /
//  MRV) — the simplest set of "round number" boundaries that exercise
//  every transition.
//
//  Strict `<` semantics:
//    currentSets < MEV          → .belowMEV
//    MEV ≤ currentSets < MAV    → .productive
//    MAV ≤ currentSets < MRV    → .nearMRV
//    MRV ≤ currentSets          → .overMRV
//

import Foundation
import Testing
@testable import fitbod

@Suite("VolumeZone")
struct VolumeZoneTests {

    // MARK: - Below MEV

    @Test("5 sets vs 8/14/22 → .belowMEV")
    func belowMEVAtFiveSets() {
        #expect(volumeZone(currentSets: 5, mev: 8, mav: 14, mrv: 22) == .belowMEV)
    }

    @Test("Zero sets vs 8/14/22 → .belowMEV (edge: empty week)")
    func belowMEVAtZeroSets() {
        #expect(volumeZone(currentSets: 0, mev: 8, mav: 14, mrv: 22) == .belowMEV)
    }

    // MARK: - Productive

    @Test("MEV boundary: 8 sets vs 8/14/22 → .productive (D-05 strict <)")
    func productiveAtMEVBoundary() {
        #expect(volumeZone(currentSets: 8, mev: 8, mav: 14, mrv: 22) == .productive)
    }

    @Test("Middle of productive: 13 sets vs 8/14/22 → .productive")
    func productiveAtThirteenSets() {
        #expect(volumeZone(currentSets: 13, mev: 8, mav: 14, mrv: 22) == .productive)
    }

    // MARK: - Near MRV

    @Test("MAV boundary: 14 sets vs 8/14/22 → .nearMRV (D-05 strict <)")
    func nearMRVAtMAVBoundary() {
        #expect(volumeZone(currentSets: 14, mev: 8, mav: 14, mrv: 22) == .nearMRV)
    }

    @Test("Just below MRV: 21 sets vs 8/14/22 → .nearMRV")
    func nearMRVAtTwentyOneSets() {
        #expect(volumeZone(currentSets: 21, mev: 8, mav: 14, mrv: 22) == .nearMRV)
    }

    // MARK: - Over MRV

    @Test("MRV boundary: 22 sets vs 8/14/22 → .overMRV (D-05 strict <)")
    func overMRVAtMRVBoundary() {
        #expect(volumeZone(currentSets: 22, mev: 8, mav: 14, mrv: 22) == .overMRV)
    }

    @Test("Well above MRV: 30 sets vs 8/14/22 → .overMRV")
    func overMRVAtThirtySets() {
        #expect(volumeZone(currentSets: 30, mev: 8, mav: 14, mrv: 22) == .overMRV)
    }

    // MARK: - All four boundaries swept

    @Test("Sweep across boundaries: strict-< semantics hold at mev/mav/mrv ± 1")
    func boundaryTransitions() {
        // chest landmarks 8 / 14 / 22 — every transition.
        #expect(volumeZone(currentSets:  7, mev: 8, mav: 14, mrv: 22) == .belowMEV)
        #expect(volumeZone(currentSets:  8, mev: 8, mav: 14, mrv: 22) == .productive)
        #expect(volumeZone(currentSets:  9, mev: 8, mav: 14, mrv: 22) == .productive)
        #expect(volumeZone(currentSets: 13, mev: 8, mav: 14, mrv: 22) == .productive)
        #expect(volumeZone(currentSets: 14, mev: 8, mav: 14, mrv: 22) == .nearMRV)
        #expect(volumeZone(currentSets: 15, mev: 8, mav: 14, mrv: 22) == .nearMRV)
        #expect(volumeZone(currentSets: 21, mev: 8, mav: 14, mrv: 22) == .nearMRV)
        #expect(volumeZone(currentSets: 22, mev: 8, mav: 14, mrv: 22) == .overMRV)
        #expect(volumeZone(currentSets: 23, mev: 8, mav: 14, mrv: 22) == .overMRV)
    }
}
