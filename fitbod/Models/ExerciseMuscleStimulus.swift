//
//  ExerciseMuscleStimulus.swift
//  fitbod
//
//  Join row carrying the stimulus *weight* for an `(Exercise, MuscleGroup)`
//  pair. This is the schema-level fix for PITFALLS #5 (stimulus weighting):
//  one working set of a barbell row counts as 1.0 toward lats and 0.5 toward
//  biceps, not "one set for everything."
//
//  Seed defaults (Phase 1 Wave 2): primary → 1.0, secondary → 0.5. The
//  top ~50 compound lifts will be hand-curated in Phase 5 (FatigueModel)
//  where the math actually depends on more nuance.
//
//  The forward relationships (`exercise`, `muscle`) are plain optionals;
//  the cascade rules are owned by the inverse side (declared on
//  `Exercise.muscleStimuli` and `MuscleGroup.stimuli`) — see CONTEXT.md
//  Area 4 and ARCHITECTURE.md entity-relationship table.
//

import Foundation
import SwiftData

@Model
public final class ExerciseMuscleStimulus {
    @Attribute(.unique) public var id: UUID = UUID()
    public var role: String = "primary"
    public var weight: Double = 1.0

    public var exercise: Exercise? = nil
    public var muscle: MuscleGroup? = nil

    public init() {}

    public convenience init(
        id: UUID = UUID(),
        exercise: Exercise,
        muscle: MuscleGroup,
        role: String,
        weight: Double
    ) {
        self.init()
        self.id = id
        self.exercise = exercise
        self.muscle = muscle
        self.role = role
        self.weight = weight
    }
}
