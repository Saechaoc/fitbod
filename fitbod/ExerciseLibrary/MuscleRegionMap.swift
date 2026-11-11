//
//  MuscleRegionMap.swift
//  fitbod
//
//  RESEARCH Open Q #3 anchor: maps the app's 19 muscle slugs onto the
//  3-region anatomical bucket (`MuscleRegion`: upper / lower / core).
//  Plan 02-02's importer uses this to populate `MuscleGroup.regionRaw` when
//  the canonical `MuscleGroup` rows are seeded.
//
//  Bucket breakdown (locked per RESEARCH recommendation):
//   - Upper (12): chest, lats, middle back, lower back, traps, front delts,
//                 side delts, rear delts, biceps, triceps, forearms, neck
//   - Lower (6):  quadriceps, hamstrings, glutes, calves, abductors, adductors
//   - Core (1):   abdominals
//
//  Coverage tested in `fitbodTests/DTODecodingTests.regionMapCoversEveryMuscle`.
//

import Foundation

/// Translation layer between muscle slugs and the coarse anatomical
/// `MuscleRegion` enum used by Phase 5's muscle heatmap.
public enum MuscleRegionMap {

    /// The muscles the app tracks: the 17 slugs of `yuhonas/free-exercise-db`
    /// with its one "shoulders" muscle split into front, side and rear delts,
    /// as the RP volume landmarks list them (RM-065). The importer creates
    /// one `MuscleGroup` per slug.
    public static let allSlugs: [String] = [
        "abdominals", "abductors", "adductors", "biceps", "calves", "chest",
        "forearms", "front delts", "glutes", "hamstrings", "lats", "lower back",
        "middle back", "neck", "quadriceps", "rear delts", "side delts", "traps", "triceps"
    ]

    /// The slug upstream and earlier stores use for all three delts. The
    /// importer moves its credits to the delts and removes it (RM-065).
    public static let retiredShouldersSlug = "shoulders"

    /// Maps a muscle slug to its anatomical region. Defaults to `.upper`
    /// on unknown input so the importer never crashes on a future dataset
    /// bump that introduces a new slug; the importer logs the unknown slug.
    public static func region(for slug: String) -> MuscleRegion {
        switch slug.lowercased() {
        case "chest", "lats", "middle back", "lower back",
             "traps", "front delts", "side delts", "rear delts",
             "biceps", "triceps", "forearms", "neck":
            return .upper
        case "quadriceps", "hamstrings", "glutes", "calves",
             "abductors", "adductors":
            return .lower
        case "abdominals":
            return .core
        default:
            return .upper
        }
    }

    /// Canonical display-name for a slug. The dataset stores lowercased slugs;
    /// the UI presents title-cased. Two-word slugs ("lower back", "middle back")
    /// keep both words capitalized.
    public static func displayName(for slug: String) -> String {
        switch slug.lowercased() {
        case "lats":         return "Lats"
        case "lower back":   return "Lower Back"
        case "middle back":  return "Middle Back"
        default:             return slug.capitalized
        }
    }
}
