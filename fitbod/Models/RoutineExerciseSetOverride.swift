//
//  RoutineExerciseSetOverride.swift
//  fitbod
//
//  Per-set prescription override for a `RoutineExercise`. When the routine
//  builder needs to express something like "set 1: 5 reps @ RPE 9, sets
//  2-3: 8 reps @ RPE 8", each varying set lands as one row of this entity
//  keyed by `setIndex`. Sets WITHOUT an override fall back to the parent
//  `RoutineExercise` defaults (targetRepsLow / targetRepsHigh / targetRPE)
//  at session-snapshot time.
//
//  Owned by `RoutineExercise.setOverrides` (cascade) — deleting a
//  RoutineExercise cleans up all its overrides. The `routineExercise`
//  field is the inverse anchor; declared optional so SwiftData can perform
//  lightweight migration from SchemaV1 stores that never wrote it
//  (FOUND-02).
//
//  Per RESEARCH § Pitfall 8 (per-set override / targetSets desync), when
//  `targetSets` decreases on the parent RoutineExercise, the override rows
//  whose `setIndex >= newTargetSets` must be pruned. That pruning logic
//  lives in `RoutineDraft` (plan 03-02), not in this schema plan.
//

import Foundation
import SwiftData

@Model
public final class RoutineExerciseSetOverride {
    @Attribute(.unique) public var id: UUID = UUID()
    public var routineExercise: RoutineExercise? = nil
    public var setIndex: Int = 0
    public var targetRepsLow: Int? = nil
    public var targetRepsHigh: Int? = nil
    public var targetRPE: Double? = nil

    public init() {}

    public convenience init(
        setIndex: Int,
        targetRepsLow: Int? = nil,
        targetRepsHigh: Int? = nil,
        targetRPE: Double? = nil
    ) {
        self.init()
        self.setIndex = setIndex
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.targetRPE = targetRPE
    }
}
