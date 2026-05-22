//
//  PlateInventory.swift
//  fitbod
//
//  Per-equipment-kind plate inventory. One row per `PlateEquipmentKind`
//  case, seeded on first launch based on the user's unit system
//  (kg defaults: 25/20/15/10/5/2.5/1.25 per side; lb defaults:
//  45/35/25/10/5/2.5/1.25 per side).
//
//  Modeled after `UserSettings` (singleton-ish model with computed
//  accessors — PATTERNS.md lines 206–227).
//
//  `availablePlatesData` holds a JSON-encoded `[PlateSpec]` array.
//  The computed `availablePlates` accessor handles encode/decode,
//  mirroring `SetEntry.clusterSubReps` (PATTERNS.md lines 228–242).
//  Decode failure returns an empty array (safe default).
//
//  All properties carry literal default values (FOUND-02 / RESEARCH
//  § Schema Evolution) so adding this entity to SchemaV3 is a valid
//  lightweight-migration operation.
//

import Foundation
import SwiftData

@Model
public final class PlateInventory {
    @Attribute(.unique) public var id: UUID = UUID()
    public var equipmentKindRaw: String = "barbell"
    public var barWeight: Double = 20.0
    public var availablePlatesData: Data = Data()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init() {}
}

extension PlateInventory {
    public var equipmentKind: PlateEquipmentKind {
        get { PlateEquipmentKind(rawValue: equipmentKindRaw) ?? .barbell }
        set { equipmentKindRaw = newValue.rawValue }
    }

    public var availablePlates: [PlateSpec] {
        get { (try? JSONDecoder().decode([PlateSpec].self, from: availablePlatesData)) ?? [] }
        set { availablePlatesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
