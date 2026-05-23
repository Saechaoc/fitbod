//
//  WarmupRamp.swift
//  fitbod
//
//  Warm-up ramp generator for the first qualifying compound exercise in a
//  session. Produces 4 SetEntry rows for barbell (40%/60%/75%/90% × 5/3/2/1)
//  or 2 rows for dumbbell/unilateral (60%/90% × 3/1). All weights are rounded
//  DOWN via PlateCalculator.roundDown so warm-ups never exceed the target.
//
//  shouldGenerate guards:
//    - deloadActive == true → skip (deload flag always false until Phase 4)
//    - warmupConfig?.enabled == false → skip (user-disabled per-exercise)
//    - exercise?.mechanic != .compound → skip (machines, cables, bodyweight)
//    - equipment NOT in {.barbell, .dumbbell} → skip
//    - topWorkingWeight < 1.5 × barWeight → skip (too light, no ramp needed)
//    - barWeight == 0 → skip the 1.5× check for dumbbell (accept any weight)
//
//  Caller (plan 03-08 SessionFactory) is responsible for inserting the returned
//  SetEntry instances into the ModelContext and attaching them to a SessionExercise.
//  WarmupRamp does NOT touch SwiftData / ModelContext — it only constructs in-memory
//  SetEntry instances using the model's default init.
//
//  No SwiftData coupling in the logic layer. The `import SwiftData` is required
//  because SetEntry is @Model.
//

import Foundation
import SwiftData

/// Warm-up ramp generator. Namespace enum — never instantiated.
public enum WarmupRamp {

    // MARK: - shouldGenerate

    /// Returns true when a warm-up ramp should be generated for the given exercise.
    ///
    /// - Parameters:
    ///   - sessionExercise: The SessionExercise being prescribed (reads exercise metadata).
    ///   - deloadActive: True when the current block is in a deload week (Phase 4 signal;
    ///     always false in Phase 3 since deload wiring lands in Phase 4).
    ///   - topWorkingWeight: The top prescribed working weight for this exercise.
    ///   - barWeight: The bar weight for the equipment (0 for dumbbell pairs).
    ///   - warmupConfig: Optional per-exercise warm-up override from `RoutineExercise.warmupOverride`.
    ///     When nil, default auto-warm-up behavior is used. When non-nil with `.enabled == false`,
    ///     the ramp is skipped.
    /// - Returns: `true` if a ramp should be generated; `false` if any guard trips.
    public static func shouldGenerate(
        for sessionExercise: SessionExercise,
        deloadActive: Bool,
        topWorkingWeight: Double,
        barWeight: Double,
        warmupConfig: WarmupConfig? = nil
    ) -> Bool {
        // Guard 1: deload week → skip
        guard !deloadActive else { return false }

        // Guard 2: user explicitly disabled warm-up for this exercise → skip
        if let config = warmupConfig, !config.enabled { return false }

        // Guard 3: exercise metadata required
        guard let exercise = sessionExercise.exercise else { return false }

        // Guard 4: compound mechanics only (machines, cables, isolation → skip)
        guard exercise.mechanic == .compound else { return false }

        // Guard 5: barbell or dumbbell only (bodyweight, cable, kettlebell, etc. → skip)
        guard exercise.equipment == .barbell || exercise.equipment == .dumbbell else { return false }

        // Guard 6: light weight check — skip when top < 1.5 × bar weight.
        // For dumbbell, barWeight is typically 0 — skip the ratio check to avoid
        // division-by-zero / false negatives with dumbbell pairs.
        if barWeight > 0 {
            guard topWorkingWeight >= 1.5 * barWeight else { return false }
        }

        return true
    }

    // MARK: - generate

    /// Generates a warm-up ramp as an array of SetEntry instances.
    ///
    /// Each SetEntry is initialised with:
    ///   - `orderIndex`: 0-based position in the ramp
    ///   - `weight`: PlateCalculator.roundDown(target: pct×top, barWeight:, plates:)
    ///   - `reps`: per-step target reps (5/3/2/1 for barbell; 3/1 for dumbbell)
    ///   - `setTypeRaw`: "warmup"
    ///   - `isWarmup`: true
    ///   - `isComplete`: false
    ///
    /// The caller (plan 03-08 SessionFactory) must insert the returned instances into
    /// the ModelContext and wire `setEntry.sessionExercise = se`.
    ///
    /// - Parameters:
    ///   - top: The top working weight (100% reference point).
    ///   - bar: The bar weight used by PlateCalculator (0 for dumbbell).
    ///   - plates: Available plate inventory as (weight, countPerSide) tuples.
    ///   - isUnilateral: True for dumbbell (2-set ramp); false for barbell (4-set ramp).
    /// - Returns: Array of SetEntry instances (count 4 for barbell, 2 for dumbbell).
    public static func generate(
        top: Double,
        bar: Double,
        plates: [(weight: Double, countPerSide: Int)],
        isUnilateral: Bool
    ) -> [SetEntry] {
        let steps: [(pct: Double, reps: Int)] = isUnilateral
            ? [(0.60, 3), (0.90, 1)]
            : [(0.40, 5), (0.60, 3), (0.75, 2), (0.90, 1)]

        return steps.enumerated().map { idx, step in
            let entry = SetEntry()
            entry.orderIndex = idx
            entry.weight = PlateCalculator.roundDown(
                target: step.pct * top,
                barWeight: bar,
                plates: plates
            )
            entry.reps = step.reps
            entry.setTypeRaw = "warmup"
            entry.isWarmup = true
            entry.isComplete = false
            return entry
        }
    }
}
