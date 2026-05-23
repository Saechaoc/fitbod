//
//  E1RMHelper.swift
//  fitbod
//
//  Minimal estimated-one-rep-max helper for Phase 4 block review math.
//

import Foundation

public enum E1RMHelper {
    /// Epley estimated 1RM formula: weight * (1 + reps / 30).
    /// Out-of-range reps return the original weight because the estimate
    /// is not useful for the simple Phase 4 review surface.
    public static func epley(weight: Double, reps: Int) -> Double {
        guard reps >= 1 && reps <= 10 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}
