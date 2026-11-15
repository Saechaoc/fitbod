//
//  ChartFilterState.swift
//  fitbod
//
//  Wave-4 plan 06-06 — `@Observable` ephemeral filter state for
//  `WeeklyTonnageView` (CONTEXT D-19, PATTERNS §Pattern D outer/inner
//  @Query split). The state owns the three orthogonal filter
//  dimensions exposed at the top of the chart:
//
//    timeRange       — single-select TimeRangeChoice; default
//                      .last26wk (CONTEXT D-19).
//    blockPhases     — multi-select Set<String> of phase raw values;
//                      default empty (= every phase).
//    selectedMuscles — multi-select Set<UUID>; default empty (= one
//                      single-color bar per week, CONTEXT D-19).
//
//  This class is `@Observable` per PROJECT.md "no ObservableObject in
//  new code" rule. The Wave 2 outer view owns it as `@State`, the
//  inner chart host reads it via plain property access — SwiftUI's
//  Observation framework handles the diff-tracking.
//
//  Sendable is NOT declared — `@Observable` macro types are not
//  Sendable in Swift 6 because the storage backing the macro is
//  mutable + reference-typed. SwiftUI consumes them on the main
//  actor only, which is fine for filter state.
//
//  [CITED: PROJECT.md state management + CONTEXT D-19 + PATTERNS
//   §Pattern D]
//

import Foundation
import Observation

/// Ephemeral filter state for the Weekly Tonnage chart.
///
/// Owned by `WeeklyTonnageView` via `@State`; passed by reference
/// (no copy semantics — `@Observable` is a class macro) to the inner
/// chip rows and the @Query host.
@Observable
public final class ChartFilterState {
    /// Single-select time-range chip (Last 8 wk / Last 26 wk / All time).
    /// Default per CONTEXT D-19: `.last26wk`.
    public var timeRange: TimeRangeChoice = .last26wk

    /// Multi-select block-phase chips, by `BlockPhaseKind` raw value. Empty
    /// means every phase; otherwise the chart keeps the sets of workouts
    /// that ran in a chosen phase (RM-023).
    public var blockPhases: Set<String> = []

    /// Multi-select muscle chips by MuscleGroup.id. Empty means
    /// "single-color bars per week" (CONTEXT D-19); non-empty switches
    /// the chart to a stacked-bar view.
    public var selectedMuscles: Set<UUID> = []

    public init() {}
}
