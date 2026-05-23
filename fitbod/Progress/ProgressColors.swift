//
//  ProgressColors.swift
//  fitbod
//
//  Wave-3 plan 06-05 — single source of truth for Phase 6 chart
//  series colors. UI-SPEC § Asset Contract:
//
//    topSet     → Color.accentColor       (existing project accent)
//    allSetAvg  → ProgressColors.allSetAverageSeries  (#3FBFC9 cyan)
//
//  Phase 6 reserves `Color.accentColor` for the primary chart series
//  + the active filter chip; secondary series uses the cyan accent
//  so the two visually distinct on the same axes. RGB values match
//  the UI-SPEC table exactly.
//

import SwiftUI

public enum ProgressColors {
    /// Secondary chart series color (#3FBFC9). Used by the all-set-avg
    /// LineMark + PointMark + the chart's foreground style scale.
    public static let allSetAverageSeries = Color(red: 0.247, green: 0.749, blue: 0.788)
}
