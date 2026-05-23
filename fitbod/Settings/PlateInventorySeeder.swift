//
//  PlateInventorySeeder.swift
//  fitbod
//
//  First-launch idempotent seeder for `PlateInventory` rows.
//  Creates exactly one `PlateInventory` row per `PlateEquipmentKind`
//  (barbell, dumbbell, ezBar, trapBar) using the canonical defaults
//  from `PlateInventoryDefaults.make(for:unitSystem:)`.
//
//  Idempotency is doubly-guarded:
//    1. `UserDefaults["plateInventorySeeded"]` flag — fast path, O(1).
//    2. Fetch-count check — if 4+ rows exist (e.g. after a UserDefaults
//       wipe), set the flag and return without re-seeding.
//
//  The seeder is gated by `@MainActor` because it writes to
//  `ModelContext.mainContext` which is bound to the main thread.
//  Called from `RootView.runSeed()` alongside `ExerciseLibraryImporter`.
//

import Foundation
import SwiftData

/// One-time seeder for the `PlateInventory` entities.
///
/// On first launch (or after a `UserDefaults` wipe on a device that already
/// has inventory rows), this seeder creates 4 `PlateInventory` rows — one per
/// `PlateEquipmentKind` — using the defaults from `PlateInventoryDefaults`.
@MainActor
public enum PlateInventorySeeder {

    /// UserDefaults key that tracks whether the initial seed has already run.
    public static let seededKey = "plateInventorySeeded"

    /// Seeds 4 `PlateInventory` rows if they don't already exist.
    ///
    /// Idempotent: returns immediately if the UserDefaults flag is set OR
    /// if 4+ rows are already present in the store (double-idempotency guard
    /// against UserDefaults wipes — cheap insurance).
    ///
    /// - Parameters:
    ///   - context: The main `ModelContext` (must be called on the main actor).
    ///   - unitSystem: The unit system to use for default plate weights and bar weights.
    ///     Pass `.lb` as a safe fallback when `UserSettings` may not yet be seeded.
    public static func seedIfNeeded(
        in context: ModelContext,
        unitSystem: WeightUnit
    ) {
        // Fast path: UserDefaults flag already set.
        if UserDefaults.standard.bool(forKey: seededKey) {
            return
        }

        // Double-idempotency: count existing inventory rows.
        // If 4+ rows exist the store is already populated (e.g. after a
        // UserDefaults wipe on a device that had plates configured), so just
        // set the flag and return without inserting duplicates.
        let descriptor = FetchDescriptor<PlateInventory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        if existingCount >= PlateEquipmentKind.allCases.count {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        // Seed one PlateInventory row per equipment kind.
        for kind in PlateEquipmentKind.allCases {
            let inv = PlateInventory()
            inv.equipmentKind = kind
            inv.barWeight = PlateInventoryDefaults.barWeight(for: kind, unitSystem: unitSystem)
            inv.availablePlates = PlateInventoryDefaults.make(for: kind, unitSystem: unitSystem)
            context.insert(inv)
        }

        try? context.save()

        // Stamp the UserDefaults flag so subsequent launches short-circuit.
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}
