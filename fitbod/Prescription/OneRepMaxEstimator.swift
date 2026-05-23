//
//  OneRepMaxEstimator.swift
//  fitbod
//
//  Pure-function e1RM estimator with rep-range-aware partitioning per
//  REQUIREMENTS PROG-02:
//
//    Brzycki    (reps ≤ 6):   e1RM = weight × (36 / (37 - reps))
//    Epley      (reps 7–10):  e1RM = weight × (1 + reps / 30)
//    Suppressed (reps > 10):  returns nil
//
//  Used by Phase 5's PlateauDetector (top-set e1RM per intent-matched
//  session) and by Phase 6 charts. RPEAutoregStrategy itself does NOT
//  use this estimator — RPE-based progression back-calculates e1RM via
//  TuchschererTable percent lookup, not Brzycki/Epley.
//
//  Defensive guards: reps ≤ 0 → nil (avoids divide-by-zero / negative-
//  weight outputs). Suppression at reps > 10 matches PROG-02 because
//  high-rep extrapolations are unreliable predictors of true 1RM.
//
//  No SwiftData coupling. No @MainActor. Implicitly Sendable (value-type
//  pure function — FOUND-07).
//

import Foundation

/// Pure-function e1RM estimator with rep-range-aware formula partitioning.
public enum OneRepMaxEstimator {

    /// Estimate the one-rep-max equivalent for a given weight × reps tuple.
    ///
    /// - Parameter weight: The load lifted (any unit — caller is responsible
    ///   for unit consistency). The output is in the same unit.
    /// - Parameter reps: The number of reps completed at that load.
    /// - Returns: The estimated 1RM, or nil when reps are out of supported
    ///   range (≤ 0 or > 10).
    public static func estimate(weight: Double, reps: Int) -> Double? {
        guard reps > 0 else { return nil }
        if reps <= 6 {
            // Brzycki — best fit for low-rep maximal effort.
            return weight * (36.0 / Double(37 - reps))
        }
        if reps <= 10 {
            // Epley — linear, conservative in the 7–10 range.
            return weight * (1.0 + Double(reps) / 30.0)
        }
        // PROG-02: high-rep extrapolations are suppressed.
        return nil
    }
}
