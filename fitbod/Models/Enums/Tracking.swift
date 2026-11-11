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
    /// Time and a machine level: elliptical, arc trainer.
    case durationLevel = "duration_level"
    /// Time and the speed number a stair machine's console shows. It is a
    /// plain number like a level, so it is stored as one and named speed.
    case durationStepSpeed = "duration_step_speed"
    /// Time, speed and incline: treadmill. Its distance shows worked out
    /// from the speed and the time.
    case durationSpeedIncline = "duration_speed_incline"

    /// Time is the main value, and reps stay zero.
    public var isTimed: Bool {
        switch self {
        case .duration, .durationDistance, .durationLevel, .durationStepSpeed, .durationSpeedIncline: true
        case .weightReps, .reps, .assistedReps: false
        }
    }

    /// What a set's level is called: a stair machine's is its speed.
    public var levelName: String {
        self == .durationStepSpeed ? "speed" : "level"
    }

    /// The progression strategies prescribe a load for it. Timed and
    /// assisted sets only carry the last workout's values forward.
    public var progressesLoad: Bool {
        self == .weightReps || self == .reps
    }

    /// What an exercise tracks when it stores no choice: a bodyweight move
    /// tracks reps with optional load, a cardio machine time and distance,
    /// and everything else weight and reps.
    public static func implied(by equipment: Equipment) -> Tracking {
        switch equipment {
        case .bodyweight, .weightedBodyweight: .reps
        case .cardioMachine: .durationDistance
        default: .weightReps
        }
    }

    /// The name a picker shows.
    public var displayName: String {
        switch self {
        case .weightReps: "Weight and reps"
        case .reps: "Reps"
        case .assistedReps: "Assisted reps"
        case .duration: "Time"
        case .durationDistance: "Time and distance"
        case .durationLevel: "Time and level"
        case .durationStepSpeed: "Time and stair speed"
        case .durationSpeedIncline: "Time, speed and incline"
        }
    }
}

/// What a timed set records beside its time. A stair machine's speed is a
/// level; a treadmill's speed is stored in km/h, and its incline in percent.
public enum TimedValue: Sendable {
    case weight, distance, level, speed, incline
}
