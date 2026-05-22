//
//  Calibration.swift
//  fitbod
//
//  Per-exercise e1RM calibration via weighted-mean over a Gaussian time kernel
//  (RESEARCH §3 simplified — polynomial-degree-0 LOWESS). Bandwidth: 30 days.
//
//  The targetReps / targetRPE parameters are accepted for future-upgrade
//  compatibility with full LOWESS (Phase 5 may revisit) but are unused at
//  the weighted-mean simplification.
//
//  Caller (RPEAutoregStrategy) is responsible for filtering nil-RPE history
//  before calling per RESEARCH §Pitfall 7.
//
//  No SwiftData coupling. No @MainActor. Implicitly Sendable.
//

import Foundation

/// A single historical data point for e1RM calibration.
///
/// The caller (RPEAutoregStrategy) back-calculates e1RM from each logged set via:
///   `e1RM = actualWeight / TuchschererTable.percent(reps: actualReps, rpe: actualRPE)`
/// and passes the resulting array here. Sets with nil RPE must be excluded before calling.
public struct HistoryPoint: Sendable, Equatable {
    /// The estimated one-rep max derived from a logged working set.
    public let e1RM: Double
    /// The date the set was logged — used to compute time-kernel decay weights.
    public let date: Date

    public init(e1RM: Double, date: Date) {
        self.e1RM = e1RM
        self.date = date
    }
}

/// Pure-function e1RM calibration using a Gaussian time-kernel weighted mean.
///
/// Algorithm (RESEARCH §3 simplified):
///   w_i = exp(-(daysFromNow_i / bandwidthDays)²)
///   calibratedE1RM = Σ(w_i × e1RM_i) / Σ(w_i)
///
/// This is a degenerate LOWESS at polynomial degree 0: the prediction is the
/// weighted mean of all historical e1RM values, with recent sets counting more.
/// Phase 5 may upgrade to full weighted linear regression when more data exists.
public enum Calibration {

    /// Predict the current calibrated e1RM from a history of logged sets.
    ///
    /// - Parameter history: Pre-computed e1RM values with their log dates. Must not
    ///   contain sets where RPE was not logged — the caller filters nil-RPE sets first.
    /// - Parameter targetReps: Target rep count for the upcoming set. Accepted for
    ///   future-compatibility with full LOWESS; unused at polynomial-degree-0 simplification.
    /// - Parameter targetRPE: Target RPE for the upcoming set. Same future-compatibility note.
    /// - Parameter now: Reference date for time-kernel computation. Defaults to `Date()`
    ///   in production; injectable for deterministic unit testing.
    /// - Returns: The Gaussian-weighted mean e1RM, or nil when history is empty or all
    ///   weights are numerically negligible (Σw < 1e-9).
    public static func predict(
        history: [HistoryPoint],
        targetReps: Int,
        targetRPE: Double,
        now: Date = Date()
    ) -> Double? {
        guard !history.isEmpty else { return nil }

        let bandwidthDays = 30.0
        var weightSum = 0.0
        var weightedE1RMSum = 0.0

        for point in history {
            let daysFromNow = now.timeIntervalSince(point.date) / 86400.0
            let w = exp(-pow(daysFromNow / bandwidthDays, 2.0))
            weightSum += w
            weightedE1RMSum += w * point.e1RM
        }

        guard weightSum >= 1e-9 else { return nil }

        return weightedE1RMSum / weightSum
    }
}
