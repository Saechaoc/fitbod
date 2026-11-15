//
//  TimeRangeChoice.swift
//  fitbod
//
//  The single-select time-range presets of the Weekly Tonnage and exercise
//  progress filter rows (CONTEXT D-19, RM-023). Runtime SwiftUI state only,
//  never stored on a `@Model`.
//

import Foundation

/// The three time-range presets in the Weekly Tonnage and exercise progress
/// filter rows.
public enum TimeRangeChoice: String, CaseIterable, Sendable {
    case last8wk = "8wk"
    case last26wk = "26wk"
    case allTime = "all"

    /// The range in a sentence, as in "No sets in the last 8 weeks"; nil
    /// for All time, which needs no words.
    var phrase: String? {
        switch self {
        case .last8wk: "in the last 8 weeks"
        case .last26wk: "in the last 26 weeks"
        case .allTime: nil
        }
    }
}
