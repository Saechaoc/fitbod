//
//  WorkingSetCount.swift
//  fitbod
//
//  The one rule for how many working sets a prescription yields in a block
//  phase. The session factory, Today's hero and its exercise rows all call it,
//  so the sets the hero counts are the sets the logger plans.
//

import Foundation

extension PeriodizationEngine {
    /// The working sets `targetSets` yields in `phase`. A deload keeps the
    /// floor of the target times the phase's volume multiplier, never below
    /// one set. Any other phase, or no phase, keeps the target.
    public static func workingSetCount(targetSets: Int, phase: BlockPhase?) -> Int {
        guard let phase, phase.kind == .deload else { return targetSets }
        return max(1, Int(floor(Double(targetSets) * phase.volumeMultiplier)))
    }
}

extension SessionExerciseTemplate {
    /// The working sets this routine row yields in `phase`: none for cardio,
    /// which the factory plans as one bout with no sets (RM-062).
    public func workingSetCount(phase: BlockPhase?) -> Int {
        exercise?.isCardio == true ? 0 : PeriodizationEngine.workingSetCount(targetSets: targetSets, phase: phase)
    }
}
