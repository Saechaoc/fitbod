//
//  Tracking.swift
//  fitbod
//
//  What a set of an exercise records. Persisted as `trackingRaw: String?` on
//  `Exercise`; `Exercise.tracking` supplies the value when it is unset.
//

import Foundation

public enum Tracking: String, CaseIterable, Sendable {
    /// Load and reps: most lifts.
    case weightReps = "weight_reps"
    /// Reps with optional added load: bodyweight moves.
    case reps
    /// Reps with assistance, stored as a negative weight.
    case assistedReps = "assisted_reps"
    /// Time, with optional load: planks, hangs, carries.
    case duration
    /// Time and distance: treadmill, rower, bike, run.
    case durationDistance = "duration_distance"
    /// Time and a machine level: stair climber, elliptical.
    case durationLevel = "duration_level"
}
