//
//  BlackSlabCTALabelTests.swift
//  fitbodTests
//
//  The hero's top label: TODAY on a fixed-weekly block, the session's place
//  in the cycle on a rotation (redesign 1.2).
//

import Testing
@testable import fitbod

@MainActor
@Suite("BlackSlabCTA label")
struct BlackSlabCTALabelTests {
    @Test("a fixed-weekly block reads TODAY")
    func aFixedWeeklyBlockReadsToday() {
        #expect(BlackSlabCTA.heroLabel(mode: .fixedWeekly, position: 2, slotCount: 4) == "TODAY")
    }

    @Test("a rotation reads its place in the cycle")
    func aRotationReadsItsPlaceInTheCycle() {
        #expect(BlackSlabCTA.heroLabel(mode: .rotation, position: 1, slotCount: 3) == "NEXT UP · 2 OF 3")
    }

    @Test("a one-slot rotation reads one of one")
    func aOneSlotRotationReadsOneOfOne() {
        #expect(BlackSlabCTA.heroLabel(mode: .rotation, position: 0, slotCount: 1) == "NEXT UP · 1 OF 1")
    }
}
