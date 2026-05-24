//
//  ProgressColors.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — series colors now reference BRU palette tokens only.
//  Supersedes the Phase 6 baseline which used Color.accentColor (#0E7C86) for
//  topSet and a #3FBFC9 literal for allSetAvg.
//
//  Design pivot (06-UI-SPEC §Design Pivot key replacement 1):
//    topSet     → Color.bruInk   (2pt solid, square markers)
//    allSetAvg  → Color.bruSignal (dashed [6,3], circle markers)
//
//  Both identifiers are kept as public statics so all existing call sites
//  in ExerciseProgressView + SeriesToggleChipRow compile without change.
//

import SwiftUI

public enum ProgressColors {
    /// Primary chart series: top-set e1RM per session.
    /// BRU token: bruInk — 2pt solid stroke + square PointMark markers.
    public static let topSetSeries: Color = .bruInk

    /// Secondary chart series: all-set-average e1RM per session.
    /// BRU token: bruSignal — 2pt dashed [6,3] stroke + circle PointMark markers.
    public static let allSetAverageSeries: Color = .bruSignal
}
