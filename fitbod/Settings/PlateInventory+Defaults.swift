//
//  PlateInventory+Defaults.swift
//  fitbod
//
//  Pure factory: returns the canonical default plate list (and bar weight)
//  for each `PlateEquipmentKind` × `WeightUnit` combination.
//
//  kg barbell (per 03-CONTEXT.md Area 4, verbatim):
//    25×4, 20×2, 15×2, 10×2, 5×2, 2.5×2, 1.25×2
//
//  lb barbell (per 03-CONTEXT.md Area 4, verbatim):
//    45×4, 35×2, 25×2, 10×2, 5×2, 2.5×2, 1.25×2
//
//  Dumbbell / EZ-Bar / Trap-Bar: planner-discretion defaults (see
//  03-CONTEXT.md Area 4 note "planner discretion") — dumbbell uses a
//  shorter plate list (handle weight is already in the plate math); EZ-Bar
//  and Trap-Bar mirror the barbell list with their respective bar weights.
//
//  No SwiftData coupling. Testable in isolation. Analog:
//  `fitbod/Routines/PrescriptionDefaults.swift` (PATTERNS.md line 641).
//

import Foundation

/// Pure factory returning canonical default plate specs and bar weights
/// per equipment kind and unit system.
public enum PlateInventoryDefaults {

    // MARK: - Public factory functions

    /// Returns the canonical default plate list for the given equipment kind
    /// and unit system. Plate counts are per-side of the bar.
    public static func make(
        for kind: PlateEquipmentKind,
        unitSystem: WeightUnit
    ) -> [PlateSpec] {
        switch (kind, unitSystem) {
        case (.barbell, .kg):
            return kgBarbellPlates
        case (.barbell, .lb):
            return lbBarbellPlates
        case (.dumbbell, .kg):
            return kgDumbbellPlates
        case (.dumbbell, .lb):
            return lbDumbbellPlates
        case (.ezBar, .kg):
            return kgBarbellPlates          // same plate set as barbell-kg; bar weight differs
        case (.ezBar, .lb):
            return lbBarbellPlates          // same plate set as barbell-lb; bar weight differs
        case (.trapBar, .kg):
            return kgBarbellPlates          // same plate set as barbell-kg; bar weight differs
        case (.trapBar, .lb):
            return lbBarbellPlates          // same plate set as barbell-lb; bar weight differs
        }
    }

    /// Returns the canonical default bar weight for the given equipment kind
    /// and unit system.
    public static func barWeight(
        for kind: PlateEquipmentKind,
        unitSystem: WeightUnit
    ) -> Double {
        switch (kind, unitSystem) {
        case (.barbell, .kg):   return 20.0   // standard Olympic men's bar
        case (.barbell, .lb):   return 45.0   // standard Olympic men's bar in lb
        case (.dumbbell, .kg):  return 0.0    // handle weight included in plate calc
        case (.dumbbell, .lb):  return 0.0    // handle weight included in plate calc
        case (.ezBar, .kg):     return 7.0    // standard EZ-curl bar
        case (.ezBar, .lb):     return 15.0   // standard EZ-curl bar in lb
        case (.trapBar, .kg):   return 22.0   // standard hex/trap bar
        case (.trapBar, .lb):   return 50.0   // standard hex/trap bar in lb
        }
    }

    // MARK: - Private plate lists

    /// kg barbell defaults — verbatim from 03-CONTEXT.md Area 4.
    private static let kgBarbellPlates: [PlateSpec] = [
        PlateSpec(weight: 25,   countPerSide: 4),
        PlateSpec(weight: 20,   countPerSide: 2),
        PlateSpec(weight: 15,   countPerSide: 2),
        PlateSpec(weight: 10,   countPerSide: 2),
        PlateSpec(weight: 5,    countPerSide: 2),
        PlateSpec(weight: 2.5,  countPerSide: 2),
        PlateSpec(weight: 1.25, countPerSide: 2),
    ]

    /// lb barbell defaults — verbatim from 03-CONTEXT.md Area 4.
    private static let lbBarbellPlates: [PlateSpec] = [
        PlateSpec(weight: 45,   countPerSide: 4),
        PlateSpec(weight: 35,   countPerSide: 2),
        PlateSpec(weight: 25,   countPerSide: 2),
        PlateSpec(weight: 10,   countPerSide: 2),
        PlateSpec(weight: 5,    countPerSide: 2),
        PlateSpec(weight: 2.5,  countPerSide: 2),
        PlateSpec(weight: 1.25, countPerSide: 2),
    ]

    /// kg dumbbell defaults — shorter list; handle weight is bundled into the
    /// plate-calc math (barWeight = 0.0 for dumbbells).
    private static let kgDumbbellPlates: [PlateSpec] = [
        PlateSpec(weight: 10,   countPerSide: 2),
        PlateSpec(weight: 5,    countPerSide: 2),
        PlateSpec(weight: 2.5,  countPerSide: 2),
        PlateSpec(weight: 1.25, countPerSide: 2),
    ]

    /// lb dumbbell defaults — handle weight is bundled into the plate-calc math
    /// (barWeight = 0.0 for dumbbells).
    private static let lbDumbbellPlates: [PlateSpec] = [
        PlateSpec(weight: 10,   countPerSide: 2),
        PlateSpec(weight: 5,    countPerSide: 2),
        PlateSpec(weight: 2.5,  countPerSide: 2),
        PlateSpec(weight: 1.25, countPerSide: 2),
    ]
}
