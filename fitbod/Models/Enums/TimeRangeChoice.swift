//
//  TimeRangeChoice.swift
//  fitbod
//
//  The single-select time-range presets of the Weekly Tonnage filter row
//  (CONTEXT D-19). Runtime SwiftUI state only, never stored on a `@Model`.
//

import Foundation

/// The three time-range presets in the Weekly Tonnage filter row.
public enum TimeRangeChoice: String, CaseIterable, Sendable {
    case last8wk = "8wk"
    case last26wk = "26wk"
    case allTime = "all"
}
