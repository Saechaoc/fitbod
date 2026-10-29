// WeightUnitEnvironment.swift
// fitbod
//
// The lifter's display unit for weights, published by RootView from
// UserSettings so every screen labels its numbers the same way.

import SwiftUI

extension EnvironmentValues {
    /// The display unit for weights. `RootView` sets it from
    /// `UserSettings.weightUnit`. Weights are stored as entered, so this is
    /// a label, not a conversion. An exercise's `unitOverride` wins over it
    /// for that exercise's own numbers.
    @Entry var weightUnit: WeightUnit = .default
}

extension WeightUnit {
    /// The unit an exercise's weights are entered in: its own override,
    /// else the lifter's setting.
    static func effective(for exercise: Exercise?, default unit: WeightUnit) -> WeightUnit {
        exercise?.unitOverride ?? unit
    }
}
