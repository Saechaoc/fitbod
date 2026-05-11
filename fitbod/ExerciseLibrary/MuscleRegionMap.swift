//
//  MuscleRegionMap.swift
//  fitbod
//
//  RESEARCH Open Q #3 anchor: maps the dataset's 17 muscle slugs onto the
//  3-region anatomical bucket (`MuscleRegion`: upper / lower / core).
//  Plan 02-02's importer uses this to populate `MuscleGroup.regionRaw` when
//  the 17 canonical `MuscleGroup` rows are seeded.
//
//  Bucket breakdown (locked per RESEARCH recommendation):
//   - Upper (10): chest, lats, middle back, lower back, traps,
//                 shoulders, biceps, triceps, forearms, neck
//   - Lower (6):  quadriceps, hamstrings, glutes, calves, abductors, adductors
//   - Core (1):   abdominals
//
//  Coverage tested in `fitbodTests/DTODecodingTests.regionMapCovers17`.
//

import Foundation

/// Translation layer between dataset muscle slugs and the coarse
/// anatomical `MuscleRegion` enum used by Phase 5's muscle heatmap.
public enum MuscleRegionMap {

    /// The 17 canonical muscle slugs from `yuhonas/free-exercise-db`.
    /// Use this as the source of truth when seeding `MuscleGroup` rows in
    /// plan 02-02 — iterate it, create one `MuscleGroup` per slug.
    public static let allSlugs: [String] = [
        "abdominals", "abductors", "adductors", "biceps", "calves", "chest",
        "forearms", "glutes", "hamstrings", "lats", "lower back", "middle back",
        "neck", "quadriceps", "shoulders", "traps", "triceps"
    ]

    /// Maps a muscle slug to its anatomical region. Defaults to `.upper`
    /// on unknown input so the importer never crashes on a future dataset
    /// bump that introduces a new slug; the importer logs the unknown slug.
    public static func region(for slug: String) -> MuscleRegion {
        switch slug.lowercased() {
        case "chest", "lats", "middle back", "lower back",
             "traps", "shoulders", "biceps", "triceps",
             "forearms", "neck":
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
