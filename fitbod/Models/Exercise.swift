//
//  Exercise.swift
//  fitbod
//
//  Library entry — either built-in (seeded from yuhonas/free-exercise-db
//  in Phase 1 Wave 2) or user-authored (`isCustom = true`, created via the
//  custom exercise editor in Phase 1 Wave 3).
//
//  Every property is optional or default-valued (FOUND-02) so the schema
//  stays iCloud-shape-ready even though sync is deferred to v2. Every
//  domain enum is persisted as `*Raw: String` with a sibling computed
//  accessor in the extension below (FOUND-03 / PITFALLS #9).
//
//  Hot query paths are indexed (FOUND-04 / PITFALLS #7):
//    - canonicalName: search-as-you-type
//    - equipmentRaw, mechanicRaw: filter chips
//    - isCustom: "show only my custom exercises"
//    - primaryMuscleSlugsJoined: denormalized muscle filter
//      (PITFALLS #3 — predicates can't traverse the many-to-many
//      ExerciseMuscleStimulus join cleanly; seed-time-populated
//      "|chest|triceps|" string with .contains(slug) is the index-friendly
//      workaround verified in RESEARCH § Pattern 4 / Pitfall 3)
//
//  externalID is unique to prevent duplicate seed imports across reruns;
//  it is nil for custom exercises (LIB-04).
//

import Foundation
import SwiftData

@Model
public final class Exercise {
    #Index<Exercise>(
        [\.canonicalName],
        [\.equipmentRaw],
        [\.mechanicRaw],
        [\.isCustom],
        [\.primaryMuscleSlugsJoined]
    )
    #Unique<Exercise>([\.externalID])

    @Attribute(.unique) public var id: UUID = UUID()
    public var externalID: String? = nil
    public var name: String = ""
    public var canonicalName: String = ""
    public var equipmentRaw: String = "other"
    public var mechanicRaw: String = "compound"
    public var forceRaw: String? = nil
    public var levelRaw: String? = nil
    public var patternRaw: String? = nil
    public var category: String = "strength"

    /// A cardio exercise: it maps no muscle unless the lifter adds one, and
    /// has no compound or isolation mechanic to show.
    public var isCardio: Bool { category == "cardio" }
    public var instructions: [String] = []
    public var imagePaths: [String] = []
    @Attribute(.externalStorage) public var imageData: Data? = nil
    public var isCustom: Bool = false
    public var primaryMuscleSlugsJoined: String = ""
    public var createdAt: Date = Date.now
    public var smallestIncrement: Double? = nil
    public var barWeightOverride: Double? = nil
    public var unitOverrideRaw: String? = nil

    // Phase 5 — SET-06 per-exercise plateau threshold overrides; nil → fall back
    // to UserSettings.plateauWindowSessions / plateauTolerance defaults.
    public var plateauWindowOverride: Int? = nil
    public var plateauToleranceOverride: Double? = nil

    // RM-022 / RM-062 catalog fields, all additive. The seed's curation
    // overlay writes them for seeded rows; the custom editor writes them for
    // custom rows. `aliasesJoined` is "skull crusher|french press".
    public var familyName: String? = nil
    public var variantLabel: String? = nil
    public var aliasesJoined: String = ""
    public var trackingRaw: String? = nil
    public var brand: String? = nil
    public var loadingRaw: String? = nil
    public var isHidden: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ExerciseMuscleStimulus.exercise)
    public var muscleStimuli: [ExerciseMuscleStimulus]? = []

    public init() {}

    public convenience init(
        id: UUID = UUID(),
        externalID: String? = nil,
        name: String,
        canonicalName: String,
        equipmentRaw: String,
        mechanicRaw: String,
        forceRaw: String? = nil,
        levelRaw: String? = nil,
        patternRaw: String? = nil,
        category: String = "strength",
        instructions: [String] = [],
        imagePaths: [String] = [],
        isCustom: Bool = false,
        primaryMuscleSlugsJoined: String = "",
        createdAt: Date = .now
    ) {
        self.init()
        self.id = id
        self.externalID = externalID
        self.name = name
        self.canonicalName = canonicalName
        self.equipmentRaw = equipmentRaw
        self.mechanicRaw = mechanicRaw
        self.forceRaw = forceRaw
        self.levelRaw = levelRaw
        self.patternRaw = patternRaw
        self.category = category
        self.instructions = instructions
        self.imagePaths = imagePaths
        self.isCustom = isCustom
        self.primaryMuscleSlugsJoined = primaryMuscleSlugsJoined
        self.createdAt = createdAt
    }
}

extension Exercise {
    public var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .other }
    public var mechanic: Mechanic { Mechanic(rawValue: mechanicRaw) ?? .compound }
    public var force: Force? { forceRaw.flatMap(Force.init) }
    public var level: Level? { levelRaw.flatMap(Level.init) }
    public var pattern: Pattern? { patternRaw.flatMap(Pattern.init) }
    /// What a set of this exercise records. Unset, bodyweight equipment
    /// tracks reps with optional load and everything else tracks weight and
    /// reps, so custom exercises and rows curation does not list need no
    /// stored value.
    public var tracking: Tracking {
        trackingRaw.flatMap(Tracking.init) ?? .implied(by: equipment)
    }

    /// What a timed set of this exercise records beside its time: an
    /// optional load for a hold or carry (a bodyweight one has none), a
    /// distance, or a machine level. Nil for a rep-tracked exercise.
    public var timedValue: TimedValue? {
        switch tracking {
        case .duration: equipment == .bodyweight ? nil : .weight
        case .durationDistance: .distance
        case .durationLevel: .level
        case .weightReps, .reps, .assistedReps: nil
        }
    }
    public var unitOverride: WeightUnit? {
        get { unitOverrideRaw.flatMap(WeightUnit.init(rawValue:)) }
        set { unitOverrideRaw = newValue?.rawValue }
    }
}
