//
//  DoubleProgressionStrategyTests.swift
//  fitbodTests
//
//  RED scaffold — 5 @Test stubs for the DoubleProgressionStrategy (bump
//  trigger when all working sets hit the top of the rep range). Replaced
//  by plan 03-05 with real assertions against DoubleProgressionStrategy
//  (a pure function over HistoryPoint arrays that does not exist yet).
//
//  Each body issues a single Issue.record with the verbatim expectation
//  string so downstream planners can grep "PENDING IMPL" to find their
//  work targets. Function signatures use `throws` so plan 03-05 can add
//  `try`-using assertions without changing the signature.
//

import Foundation
import Testing
@testable import fitbod

@Suite("DoubleProgressionStrategy")
struct DoubleProgressionStrategyTests {

    @Test("bumpWhenAllSetsHitTopOfRange")
    func bumpWhenAllSetsHitTopOfRange() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: history where every working set reps == targetRepsHigh triggers bump; explanation.bumpOccurred == true; prescribedWeight == lastWeight + smallestIncrement")
    }

    @Test("noBumpWhenAnySetMissesTop")
    func noBumpWhenAnySetMissesTop() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: history with any working set reps < targetRepsHigh holds weight; explanation.bumpOccurred == false; prescribedWeight == lastWeight")
    }

    @Test("noBumpWhenWarmupsExcluded")
    func noBumpWhenWarmupsExcluded() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: warmup sets (isWarmup == true) must not count toward the bump trigger")
    }

    @Test("noBumpFirstSessionUsesPriorHint")
    func noBumpFirstSessionUsesPriorHint() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: empty history returns lastSessionLine == nil; prescribedWeight comes from caller-supplied hint")
    }

    @Test("smallestIncrementHonored")
    func smallestIncrementHonored() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-05: increment of 1.25 kg used when Exercise.smallestIncrement is 1.25")
    }
}
