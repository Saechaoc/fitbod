//
//  TonnageSliceMode.swift
//  fitbod
//
//  Wave-1 plan 06-03 — runtime-only enums for the Weekly Tonnage chart
//  filter UI (CONTEXT D-19). NEITHER enum is persisted on a `@Model`
//  type; both are pure SwiftUI state types consumed by the Wave 2
//  WeeklyTonnageView and the aggregator that backs it.
//
//  TonnageSliceMode names the THREE independent filter chip rows at
//  the top of WeeklyTonnageView:
//
//    .timeRange   → Last 8 wk / Last 26 wk / All time (single-select)
//    .blockPhase  → BlockPhaseKind chips (multi-select; default all on)
//    .muscle      → top-10 trained muscles (multi-select; default none)
//
//  TimeRangeChoice locks the three single-select time-range options
//  with stable string rawValues for round-tripping through
//  @SceneStorage if Phase 6 polish chooses to persist the user's last
//  filter pick across launches. The rawValues are NEVER written into
//  a @Model — they are local SwiftUI state only.
//

import Foundation

/// The three independent filter dimensions of the Weekly Tonnage chart.
public enum TonnageSliceMode: String, CaseIterable, Sendable {
    case timeRange
    case blockPhase
    case muscle
}

/// The three time-range presets in the Weekly Tonnage filter row.
public enum TimeRangeChoice: String, CaseIterable, Sendable {
    case last8wk = "8wk"
    case last26wk = "26wk"
    case allTime = "all"
}
