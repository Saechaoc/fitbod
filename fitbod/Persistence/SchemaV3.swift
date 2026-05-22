//
//  SchemaV3.swift
//  fitbod
//
//  The Phase 3 schema wrapper. Aggregates the 15 entities inherited
//  unchanged from SchemaV2 plus the 1 new entity introduced by
//  plan 03-01 (`PlateInventory`).
//
//  Every delta against SchemaV2 is *additive*:
//    - New entity type (PlateInventory)
//    - New default-valued properties on existing entities
//      (Exercise.smallestIncrement / barWeightOverride / unitOverrideRaw,
//       RoutineExercise.warmupOverrideData,
//       SetEntry.wasManualOverride,
//       UserSettings.defaultIncrementKg / minCalibrationSets)
//
//  Per RESEARCH § Pattern 4 + Apple's docs, additive-only deltas are
//  explicitly eligible for `MigrationStage.lightweight(fromVersion:
//  toVersion:)`. The migration stage itself is registered in
//  `FitbodSchemaMigrationPlan`; this file is just the entity catalog.
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
//
//  Version identifier matches semantic-version intent:
//    3.0.0 = Phase 3 schema delta (1 new entity + 7 additive fields).
//
//  Ordering: SchemaV2.models is included verbatim (via composition)
//  so only the appended type highlights the diff against SchemaV2.swift.
//

import SwiftData

public enum SchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        SchemaV2.models + [PlateInventory.self]
    }
}
