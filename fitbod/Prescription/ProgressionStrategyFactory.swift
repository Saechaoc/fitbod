//
//  ProgressionStrategyFactory.swift
//  fitbod
//
//  Routes ProgressionKind enum values to the correct ProgressionStrategy
//  implementation. The factory is the single call site that decides which
//  algorithm a SessionExercise uses — plan 03-08 (SessionFactory) calls
//  ProgressionStrategyFactory.make(for:) and passes the result to prescribe().
//
//  .block and .hybrid silently fall back to DoubleProgressionStrategy per
//  UI-SPEC § What's Explicitly Deferred: "Phase 3 sessions behave like
//  Double Progression for these kinds."
//
//  NOTE: Phase 4 will replace this fallback with BlockPeriodizedStrategy /
//  HybridStrategy once the periodization layer lands. The call site in
//  plan 03-08 SessionFactory already routes through this factory, so no
//  call-site changes will be required.
//

import Foundation

/// Routes a `ProgressionKind` to its concrete `ProgressionStrategy` implementation.
/// Namespace enum — never instantiated.
public enum ProgressionStrategyFactory {

    /// Returns the concrete strategy for the given progression kind.
    ///
    /// - `.rpe` → `RPEAutoregStrategy` (TuchschererTable prior → LOWESS calibration)
    /// - `.double` → `DoubleProgressionStrategy` (bump-on-all-hit-top)
    /// - `.block`, `.hybrid` → `DoubleProgressionStrategy` (Phase 4 fallback; see NOTE above)
    public static func make(for kind: ProgressionKind) -> any ProgressionStrategy {
        switch kind {
        case .rpe:
            return RPEAutoregStrategy()
        case .double:
            return DoubleProgressionStrategy()
        case .block, .hybrid:
            // NOTE: Phase 4 will replace this fallback with BlockPeriodizedStrategy /
            // HybridStrategy once the periodization layer lands.
            return DoubleProgressionStrategy()
        }
    }
}
