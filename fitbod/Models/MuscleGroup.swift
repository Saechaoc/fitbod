//
//  MuscleGroup.swift
//  fitbod
//
//  One of the 17 canonical muscle slugs from yuhonas/free-exercise-db,
//  normalized to lower-snake-case (`"chest"`, `"lats"`, `"triceps"`).
//  Bootstrap seed runs in Phase 1 Wave 2 (`01-PLAN-02-02`).
//
//  `slug` is unique (FOUND-04) — duplicate imports collapse cleanly.
//  Cascade rules per CONTEXT.md Area 4: deleting a `MuscleGroup` cascades
//  into both the stimulus join rows and the per-muscle volume-target rows.
//  (Practically the muscles never get deleted in v1; the cascade exists for
//  schema correctness and any future re-taxonomy migrations.)
//

import Foundation
import SwiftData

@Model
public final class MuscleGroup {
    #Unique<MuscleGroup>([\.slug])

    @Attribute(.unique) public var id: UUID = UUID()
    public var slug: String = ""
    public var displayName: String = ""
    public var regionRaw: String = "upper"

    @Relationship(deleteRule: .cascade, inverse: \ExerciseMuscleStimulus.muscle)
    public var stimuli: [ExerciseMuscleStimulus]? = []

    @Relationship(deleteRule: .cascade, inverse: \MuscleVolumeTarget.muscle)
    public var volumeTargets: [MuscleVolumeTarget]? = []

    public init() {}

    public convenience init(
        id: UUID = UUID(),
        slug: String,
        displayName: String,
        region: MuscleRegion = .upper
    ) {
        self.init()
        self.id = id
        self.slug = slug
        self.displayName = displayName
        self.regionRaw = region.rawValue
    }
}

extension MuscleGroup {
    public var region: MuscleRegion { MuscleRegion(rawValue: regionRaw) ?? .upper }
}
