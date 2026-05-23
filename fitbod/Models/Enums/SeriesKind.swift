//
//  SeriesKind.swift
//  fitbod
//
//  Wave-3 plan 06-05 — runtime-only enum identifying which series an
//  ExerciseProgressView point belongs to: the per-session top set or
//  the per-session all-set average. CONTEXT D-07 + UI-SPEC § Chart
//  Styling Contract.
//
//  Never persisted on a @Model — pure SwiftUI/value-type state
//  consumed by SeriesBuilder + the chart `Chart(...)` body. Two
//  consumers depend on `displayLabel`: the chart legend
//  (`chartForegroundStyleScale`) and the toggle chip row
//  (`SeriesToggleChipRow`).
//

import Foundation

/// Identifies one of the two chart series rendered by
/// `ExerciseProgressView`.
public enum SeriesKind: String, CaseIterable, Sendable {
    case topSet = "top_set"
    case allSetAvg = "all_set_avg"

    /// UI-SPEC verbatim — drives the chip label, legend key, and
    /// chart foreground style scale key.
    public var displayLabel: String {
        switch self {
        case .topSet:    return "Top set"
        case .allSetAvg: return "All-set avg"
        }
    }
}
