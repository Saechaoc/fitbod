//
//  UserSettings.swift
//  fitbod
//
//  Singleton settings row — exactly one instance lives in the store after
//  first launch (bootstrapped via `UserSettings.default()` and inserted
//  by the importer in Phase 1 Wave 2). The Settings tab queries
//  `[UserSettings]` and reads `.first`.
//
//  `unitsRaw` (WeightUnit) is the SET-01 anchor: lb/kg display toggle.
//  Phase 5 will read more fields from this type (plateau window, deload
//  alert, week-start preference); locking them now keeps the schema stable
//  through Phase 4.
//
//  The `weightUnit` and `defaultProgressionKind` extension accessors are
//  `get/set` (vs the read-only `get` on most other entities) so the
//  Settings form can bind a SwiftUI Toggle directly via `@Bindable`.
//

import Foundation
import SwiftData

@Model
public final class UserSettings {
    @Attribute(.unique) public var id: UUID = UUID()
    public var unitsRaw: String = "lb"
    public var defaultProgressionKindRaw: String = "double"
    public var warmupSchemeRaw: String = "standard"
    public var customWarmupPercents: [Double]? = nil
    public var plateauWindowSessions: Int = 4
    public var plateauTolerance: Double = 0.005
    public var deloadAlertEnabled: Bool = true
    public var weekStartsMonday: Bool = true
    public var defaultIncrementKg: Double = 2.5
    public var minCalibrationSets: Int = 10

    public init() {}

    public static func `default`() -> UserSettings {
        let s = UserSettings()
        s.unitsRaw = "lb"
        return s
    }
}

extension UserSettings {
    public var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: unitsRaw) ?? .lb }
        set { unitsRaw = newValue.rawValue }
    }
    public var defaultProgressionKind: ProgressionKind {
        get { ProgressionKind(rawValue: defaultProgressionKindRaw) ?? .double }
        set { defaultProgressionKindRaw = newValue.rawValue }
    }
}
