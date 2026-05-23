//
//  ProgressionStrategyFactory.swift
//  fitbod
//
//  Routes ProgressionKind enum values to the correct ProgressionStrategy
//  implementation. The factory is the single call site that decides which
//  algorithm a SessionExercise uses — plan 03-08 (SessionFactory) calls
//  ProgressionStrategyFactory.make(for:) and passes the result to prescribe().
//
//  Phase 4 routes .block and .hybrid to BlockPeriodizedStrategy and
//  HybridStrategy respectively. Phase 3 routed both to DoubleProgression
//  as a temporary fallback.
//

import Foundation

/// Routes a `ProgressionKind` to its concrete `ProgressionStrategy` implementation.
/// Namespace enum — never instantiated.
public enum ProgressionStrategyFactory {

    /// Returns the concrete strategy for the given progression kind.
    ///
    /// - `.rpe` → `RPEAutoregStrategy` (TuchschererTable prior → LOWESS calibration)
    /// - `.double` → `DoubleProgressionStrategy` (bump-on-all-hit-top)
    /// - `.block` → `BlockPeriodizedStrategy`
    /// - `.hybrid` → `HybridStrategy`
    public static func make(for kind: ProgressionKind) -> any ProgressionStrategy {
        switch kind {
        case .rpe:
            return RPEAutoregStrategy()
        case .double:
            return DoubleProgressionStrategy()
        case .block:
            return BlockPeriodizedStrategy()
        case .hybrid:
            return HybridStrategy()
        }
    }
}
