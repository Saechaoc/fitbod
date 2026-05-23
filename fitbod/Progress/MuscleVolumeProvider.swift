//
//  MuscleVolumeProvider.swift
//  fitbod
//
//  Wave-1 plan 06-03 — Phase 5/6 protocol seam (CONTEXT D-20 + RESEARCH
//  Open Question 3). The Weekly Tonnage chart needs per-muscle volume
//  attribution when the user selects muscle filter chips. Two
//  implementations cleanly coexist:
//
//    UnweightedMuscleVolumeProvider     — Phase 6 fallback.
//      Each primary-role ExerciseMuscleStimulus contributes the full
//      `weight × reps` tonnage of the source set. Secondary muscles
//      contribute zero (matching CONTEXT D-20 fallback semantics).
//
//    StimulusWeightedMuscleVolumeProvider — Phase 5 has shipped the
//      stimulus-weight table; a future polish plan can conform a real
//      implementation that multiplies tonnage by ExerciseMuscleStimulus
//      .weight per muscle. The Phase 6 aggregator + view do not change
//      when the swap happens — that is the entire point of this
//      protocol seam.
//
//  Sendable + protocol-typed parameter on the aggregator means the
//  Wave 2 WeeklyTonnageView passes whichever provider is wired today;
//  changing the wiring is a one-line edit at the call site.
//
//  No @MainActor — providers are pure-function value types. Conformers
//  must remain Sendable so Swift 6 strict concurrency is happy when
//  WeeklyTonnageView spawns the aggregator off the main actor.
//
//  [CITED: CONTEXT D-20 + RESEARCH §"Architectural Responsibility Map"
//   Muscle-stack row + Open Question 3]
//

import Foundation
import SwiftData

/// Per-set, per-muscle tonnage attribution.
///
/// Implementations decide how a single working set's `weight × reps`
/// flows into one or more muscle contributions. The aggregator does
/// not know about role weighting; it asks the provider and trusts the
/// answer.
public protocol MuscleVolumeProvider: Sendable {

    /// Compute the per-muscle tonnage contributions of a single working set.
    ///
    /// - Parameter set: The `SetEntry` whose `weight × reps` is being
    ///   attributed. The aggregator pre-filters to working-only sets
    ///   so providers can assume the input is a valid working set.
    /// - Parameter exercise: The `Exercise` the set belongs to —
    ///   carries the `muscleStimuli` relationship used for attribution.
    /// - Returns: Zero or more `(muscleID, muscleName, tonnage)` tuples.
    ///   Returning an empty array means the exercise has no usable
    ///   muscle attribution (e.g. custom exercise without stimuli).
    func contributions(
        for set: SetEntry,
        exercise: Exercise
    ) -> [(muscleID: UUID, muscleName: String, tonnage: Double)]
}

/// Phase 6 fallback `MuscleVolumeProvider`: each primary-role stimulus
/// receives the FULL set tonnage; secondary muscles get zero.
///
/// This matches the CONTEXT D-20 "graceful fallback" semantics — every
/// chart bar reads correctly even before Phase 5's stimulus-weighted
/// implementation is wired in.
public struct UnweightedMuscleVolumeProvider: MuscleVolumeProvider {

    public init() {}

    public func contributions(
        for set: SetEntry,
        exercise: Exercise
    ) -> [(muscleID: UUID, muscleName: String, tonnage: Double)] {
        guard let stimuli = exercise.muscleStimuli, !stimuli.isEmpty else { return [] }
        let tonnage = set.weight * Double(set.reps)
        var out: [(muscleID: UUID, muscleName: String, tonnage: Double)] = []
        for stimulus in stimuli {
            // Phase 5 FatigueModel slices on the same string-valued role field.
            guard stimulus.role == "primary" else { continue }
            guard let muscle = stimulus.muscle else { continue }
            out.append((muscleID: muscle.id, muscleName: muscle.displayName, tonnage: tonnage))
        }
        return out
    }
}
