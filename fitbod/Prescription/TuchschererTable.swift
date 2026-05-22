//
//  TuchschererTable.swift
//  fitbod
//
//  Compile-time constant RPE → %1RM table per Tuchscherer (2009).
//  Rows 1–10 are verified against the RTS / Zourdos et al. (2016) source.
//  Rows 11+ are clamped to row 10 per CONTEXT.md Area 1 lock (revised 2026-05-22)
//  (high-rep ranges are better served by double progression).
//  No SwiftData coupling. Testable in isolation via TuchschererTableTests.
//

import Foundation

/// Hardcoded RPE → %1RM lookup table from Mike Tuchscherer's Reactive Training Systems (2009).
/// Source verified against fitnessvolt.com RPE calculator citing RTS + Zourdos et al. (2016):
/// https://fitnessvolt.com/rpe-training/rpe-to-percentage-calculator/
///
/// Table coverage: reps 1–10 × RPE 6.0–10.0 in 0.5 increments (90 cells total).
/// Reps > 10 are clamped to row 10 — the original Tuchscherer/RTS table does not publish
/// rows 11+, and high-rep training is better served by DoubleProgressionStrategy.
public enum TuchschererTable {

    /// Full 90-cell table keyed as `percentFor[reps][rpe]`.
    /// RPE keys: 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0 (9 values per row).
    /// Rep keys: 1 through 10 (10 rows).
    public static let percentFor: [Int: [Double: Double]] = [
        1: [10.0: 1.000, 9.5: 0.978, 9.0: 0.955, 8.5: 0.939,
            8.0: 0.922, 7.5: 0.907, 7.0: 0.892, 6.5: 0.878, 6.0: 0.863],
        2: [10.0: 0.955, 9.5: 0.939, 9.0: 0.922, 8.5: 0.907,
            8.0: 0.892, 7.5: 0.878, 7.0: 0.863, 6.5: 0.850, 6.0: 0.837],
        3: [10.0: 0.922, 9.5: 0.907, 9.0: 0.892, 8.5: 0.878,
            8.0: 0.863, 7.5: 0.850, 7.0: 0.837, 6.5: 0.824, 6.0: 0.811],
        4: [10.0: 0.892, 9.5: 0.878, 9.0: 0.863, 8.5: 0.850,
            8.0: 0.837, 7.5: 0.824, 7.0: 0.811, 6.5: 0.799, 6.0: 0.786],
        5: [10.0: 0.863, 9.5: 0.850, 9.0: 0.837, 8.5: 0.824,
            8.0: 0.811, 7.5: 0.799, 7.0: 0.786, 6.5: 0.774, 6.0: 0.762],
        6: [10.0: 0.837, 9.5: 0.824, 9.0: 0.811, 8.5: 0.799,
            8.0: 0.786, 7.5: 0.774, 7.0: 0.762, 6.5: 0.751, 6.0: 0.739],
        7: [10.0: 0.811, 9.5: 0.799, 9.0: 0.786, 8.5: 0.774,
            8.0: 0.762, 7.5: 0.751, 7.0: 0.739, 6.5: 0.728, 6.0: 0.717],
        8: [10.0: 0.786, 9.5: 0.774, 9.0: 0.762, 8.5: 0.751,
            8.0: 0.739, 7.5: 0.728, 7.0: 0.717, 6.5: 0.707, 6.0: 0.696],
        9: [10.0: 0.762, 9.5: 0.751, 9.0: 0.739, 8.5: 0.728,
            8.0: 0.717, 7.5: 0.707, 7.0: 0.696, 6.5: 0.686, 6.0: 0.676],
        10: [10.0: 0.739, 9.5: 0.728, 9.0: 0.717, 8.5: 0.707,
             8.0: 0.696, 7.5: 0.686, 7.0: 0.676, 6.5: 0.666, 6.0: 0.656],
    ]

    /// Look up the %1RM fraction for a given rep count and RPE.
    ///
    /// - Parameter reps: Target rep count. Clamped to `[1, 10]` — reps < 1 become 1,
    ///   reps > 10 become 10 (per CONTEXT.md Area 1 lock, revised 2026-05-22).
    /// - Parameter rpe: Target RPE. Snapped to the nearest 0.5 step (e.g., 8.3 → 8.5).
    ///   Returns nil if the snapped RPE falls outside the table range [6.0, 10.0].
    /// - Returns: The %1RM fraction (e.g., `0.922` for reps=1, rpe=9.0), or nil when
    ///   the snapped RPE is not in the table (e.g., rpe = 5.5 → snaps to 5.5, not in table).
    public static func percent(reps: Int, rpe: Double) -> Double? {
        let clampedReps = max(1, min(10, reps))
        let snappedRPE = (rpe * 2).rounded() / 2
        return percentFor[clampedReps]?[snappedRPE]
    }
}
