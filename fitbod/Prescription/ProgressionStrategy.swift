//
//  ProgressionStrategy.swift
//  fitbod
//
//  Protocol-oriented prescription layer for Phase 3.
//  All conforming types are pure-function value types with no SwiftData
//  coupling (CONTEXT.md Area 1 / FOUND-07). The caller (plan 03-08
//  SessionFactory) pre-fetches history and last-session scalars and
//  passes them in — strategies never touch the ModelContext directly.
//

import Foundation

// MARK: - CalibrationStatus

/// Tracks whether an RPE-autoreg strategy has accumulated enough data to
/// leave calibrating mode. Not applicable for double-progression strategies.
public enum CalibrationStatus: Sendable, Equatable {
    /// Accumulating data. `current` sets logged; `threshold` sets required.
    case calibrating(current: Int, threshold: Int)
    /// Sufficient data accumulated — prediction uses Calibration.predict LOWESS.
    case calibrated
    /// Strategy does not use RPE calibration (e.g. DoubleProgressionStrategy).
    case notApplicable
}

// MARK: - PrescriptionExplanation

/// The "Why this weight?" data model. Carries all information needed to
/// populate the WhyThisWeightSheet (UI-SPEC § WhyThisWeightSheet).
///
/// PrescriptionExplanation is a value type — all fields are value types
/// or optional value types, so it is implicitly Sendable under Swift 6
/// strict concurrency.
public struct PrescriptionExplanation: Sendable {
    /// Summary of the most recent logged set for this exercise+intent, e.g.
    /// "100 kg × 8 @ RPE 8.5 (May 15)". Nil when no prior session exists.
    public var lastSessionLine: String?

    /// Human-readable name of the formula, e.g. "RPE autoregulation" or
    /// "Double progression".
    public let formulaName: String

    /// RPE-autoreg–specific computed line, e.g.
    /// "Target e1RM 122 kg → 88% × 8 → 107 kg". Nil for double progression.
    public var computedLine: String?

    /// The plate-rounded prescribed weight in kg.
    public let roundedWeight: Double

    /// Human-readable rounding explanation, e.g.
    /// "→ 107.5 kg (rounded down to 1.25 kg plates)".
    public let roundedLine: String

    /// Calibration state for RPE-autoreg strategies.
    public let status: CalibrationStatus

    /// True when double-progression bump was triggered (all working sets
    /// hit the top of the rep range). Always false for RPE-autoreg.
    public var bumpOccurred: Bool

    /// Non-nil during the calibrating window: the low–high plate-rounded
    /// range the user should aim for (±5% of the point estimate).
    /// Nil once calibrated or for double-progression strategies.
    public var range: ClosedRange<Double>?

    public init(
        lastSessionLine: String? = nil,
        formulaName: String,
        computedLine: String? = nil,
        roundedWeight: Double,
        roundedLine: String,
        status: CalibrationStatus,
        bumpOccurred: Bool = false,
        range: ClosedRange<Double>? = nil
    ) {
        self.lastSessionLine = lastSessionLine
        self.formulaName = formulaName
        self.computedLine = computedLine
        self.roundedWeight = roundedWeight
        self.roundedLine = roundedLine
        self.status = status
        self.bumpOccurred = bumpOccurred
        self.range = range
    }
}

// MARK: - ProgressionStrategy

/// Protocol for all progression strategies. Conforming types are pure-function
/// value types with no stored mutable state (FOUND-07). They accept pre-fetched
/// history arrays and last-session scalars from the caller (plan 03-08
/// SessionFactory).
///
/// The `lastSessionRepsArray` parameter carries the working-set rep counts from
/// the most recent session — used by DoubleProgressionStrategy to decide whether
/// to bump the weight. Defaults to nil so RPE-autoreg strategies can ignore it.
///
/// The `lastSession*` scalar parameters are pre-fetched by the caller via
/// `PreviousMatchingIntent.fetchTopWorkingSet(...)` and passed in directly.
/// Passing scalars (not a struct) keeps strategies free of nested types beyond
/// HistoryPoint.
public protocol ProgressionStrategy: Sendable {
    func prescribe(
        history: [HistoryPoint],
        targetRepsLow: Int,
        targetRepsHigh: Int,
        targetRPE: Double?,
        lastSessionRepsArray: [Int]?,
        smallestIncrement: Double,
        plates: [(weight: Double, countPerSide: Int)],
        barWeight: Double,
        minCalibrationSets: Int,
        lastSessionWeight: Double?,
        lastSessionReps: Int?,
        lastSessionRPE: Double?,
        lastSessionDate: Date?
    ) -> (weight: Double, explanation: PrescriptionExplanation)
}
