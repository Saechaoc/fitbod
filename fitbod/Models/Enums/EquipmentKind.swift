//
//  EquipmentKind.swift
//  fitbod
//
//  The equipment-kind facet used by the plate inventory system (Phase 3).
//  Four cases: the four equipment types that can have a plate inventory
//  configured (barbell, dumbbell, EZ-bar, trap bar).
//
//  Persisted as `equipmentKindRaw: String` on `PlateInventory`
//  (FOUND-03 / PITFALLS #9). No `default` static property — the inventory
//  editor always renders all 4 tabs unconditionally (PATTERNS.md line 316).
//

import Foundation

public enum PlateEquipmentKind: String, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case ezBar = "ez_bar"
    case trapBar = "trap_bar"
}
