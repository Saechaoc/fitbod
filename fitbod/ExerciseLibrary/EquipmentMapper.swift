//
//  EquipmentMapper.swift
//  fitbod
//
//  LIB-06 anchor: maps the dataset's 12+ raw `equipment` string values onto
//  the 9-case canonical `Equipment` enum (defined in `fitbod/Models/Enums/`).
//  Also publishes the strength-only `acceptedCategories` filter that plan 02-02
//  applies before inserting `@Model Exercise` rows.
//
//  Verified raw values (from vendored snapshot 2026-05-10, see SOURCE.md):
//  `bands, barbell, body only, cable, dumbbell, e-z curl bar, exercise ball,`
//  `foam roll, kettlebells, machine, medicine ball, other`, plus `null`.
//  Coverage tested in `fitbodTests/DTODecodingTests.equipmentMappingCovered`.
//

import Foundation

/// Canonical translation layer between `ExerciseDTO.equipment` (free-form
/// string from upstream) and `Equipment` (closed 9-case enum on `@Model Exercise`).
public enum EquipmentMapper {

    /// Maps a raw dataset `equipment` string to the canonical `Equipment` enum.
    /// Unknown / nil values collapse to `.other` so an importer never crashes
    /// on a future dataset bump that introduces a new equipment label.
    public static func map(_ raw: String?) -> Equipment {
        guard let raw, !raw.isEmpty else { return .other }
        switch raw.lowercased() {
        case "barbell":        return .barbell
        case "dumbbell":       return .dumbbell
        case "cable":          return .cable
        case "machine":        return .machine
        case "bands":          return .bands
        case "body only":      return .bodyweight
        case "kettlebells":    return .kettlebell
        case "e-z curl bar":   return .barbell    // collapse to canonical barbell
        // Soft-equipment + accessory categories that v1 doesn't model
        // explicitly — all land in `.other` (the catch-all bucket).
        case "medicine ball",
             "exercise ball",
             "foam roll",
             "other":          return .other
        default:               return .other
        }
    }

    /// Categories accepted into the v1 seed. Per CONTEXT.md Area 1 + plan 02-01,
    /// only resistance-training categories are imported; cardio / stretching /
    /// plyometrics rows are skipped.
    public static let acceptedCategories: Set<String> = [
        "strength",
        "powerlifting",
        "olympic weightlifting",
        "strongman"
    ]

    /// Convenience predicate used by the importer's strength filter.
    public static func shouldImport(category: String) -> Bool {
        acceptedCategories.contains(category.lowercased())
    }
}
