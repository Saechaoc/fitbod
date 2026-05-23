//
//  OneRepMax.swift
//  fitbod
//
//  Wave-1 plan 06-01 — canonical Phase 6 e1RM kernel name. Single
//  pure-function entry-point used by every Phase 6 surface that
//  compares lifters across rep ranges:
//
//    - ExerciseProgressView (chart series — top-set + all-set-avg e1RM)
//    - PRDetector (e1RM PR bucket)
//    - ExercisePRsView (per-bucket "best e1RM ever" lookup)
//    - WeeklyTonnageAggregator (does NOT use e1RM — only raw working tonnage)
//
//  CONTEXT D-04 formula table:
//
//    reps == 1       → identity (return weight)        per Pitfall 4
//    2 ≤ reps ≤ 6    → Brzycki: weight × 36 / (37 - r)
//    7 ≤ reps ≤ 10   → Epley:   weight × (1 + r / 30)
//    reps > 10       → nil (PROG-02 suppression)
//
//  Guards (RESEARCH Pitfall 5): weight ≤ 0 or reps ≤ 0 returns nil so
//  bodyweight-assist machines (where the user might enter negative
//  effective load) and zero-rep set-skips never produce nonsense
//  e1RM numbers downstream.
//
//  ## Relationship to OneRepMaxEstimator
//
//  Phase 5 (plan 05-01) shipped `OneRepMaxEstimator` in
//  `fitbod/Prescription/` — used by `PlateauDetector`, `DeloadAdvisor`,
//  and `WeeklyRecapSheet`. Phase 6 deliberately KEEPS that name as the
//  canonical implementation site and exposes `OneRepMax` here as the
//  short-name alias the Phase 6 charting code reads against. Both
//  surfaces share one implementation — there is no math drift.
//
//  Brzycki at reps == 1 collapses to weight × 36/36 == weight, so the
//  Pitfall 4 identity contract is satisfied by the existing Brzycki
//  branch (no separate identity case needed).
//
//  No SwiftData coupling. No `@MainActor`. Implicitly Sendable
//  (value-type pure function — FOUND-07).
//
//  [CITED: REQUIREMENTS.md PROG-02 + CONTEXT.md D-04 + RESEARCH Pitfall 4/5]
//

import Foundation

/// Canonical Phase 6 e1RM kernel — thin facade over `OneRepMaxEstimator`.
///
/// Every Phase 6 surface that needs `1RM ≈ f(weight, reps)` reads against
/// this name. Centralization here prevents two formulas from drifting in
/// Wave 2 chart code; the implementation lives in `OneRepMaxEstimator`.
public enum OneRepMax {

    /// Estimate the one-rep-max equivalent for a `(weight, reps)` tuple.
    ///
    /// - Parameter weight: The load lifted (any unit — caller is responsible
    ///   for unit consistency). The output is in the same unit.
    /// - Parameter reps: The number of reps completed at that load.
    /// - Returns: The estimated 1RM, or nil when reps are out of supported
    ///   range (≤ 0 or > 10) or weight is non-positive.
    @inlinable
    public static func estimate(weight: Double, reps: Int) -> Double? {
        OneRepMaxEstimator.estimate(weight: weight, reps: reps)
    }
}
