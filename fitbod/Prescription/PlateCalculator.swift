//
//  PlateCalculator.swift
//  fitbod
//
//  Greedy plate-loading math. Canonical kg/lb plate sets are provably greedy-optimal
//  (coin-system equivalence per tommyodland.com / RESEARCH §4). Non-canonical sets
//  (e.g., 7 kg plates) may not produce the minimal solution but are acceptable for v1
//  since default inventories are canonical.
//
//  Uses < 0.001 epsilon comparisons throughout to dodge float drift (RESEARCH §Pitfall 4).
//  Example: 100.0 - 45.0 - 45.0 - 10.0 evaluates to ~0.0000000000000142 in IEEE 754,
//  causing a false "no solution" result without the epsilon guard.
//

import Foundation

/// A plate-loading solution: the plates to put on each side of the bar, plus the total
/// weight of the loaded bar.
public struct PlateStack: Sendable {
    /// Plates per side, sorted heaviest first. Each tuple is (plateWeight, count).
    public let platesPerSide: [(weight: Double, count: Int)]
    /// Total weight of the loaded barbell: barWeight + 2 × (sum of platesPerSide).
    public let totalWeight: Double

    public init(platesPerSide: [(weight: Double, count: Int)], totalWeight: Double) {
        self.platesPerSide = platesPerSide
        self.totalWeight = totalWeight
    }

    public static func == (lhs: PlateStack, rhs: PlateStack) -> Bool {
        guard lhs.totalWeight == rhs.totalWeight else { return false }
        guard lhs.platesPerSide.count == rhs.platesPerSide.count else { return false }
        for (l, r) in zip(lhs.platesPerSide, rhs.platesPerSide) {
            if l.weight != r.weight || l.count != r.count { return false }
        }
        return true
    }
}

extension PlateStack: Equatable {}

/// Pure-function plate-loading math. No SwiftData coupling, no @MainActor.
///
/// Both functions accept plates as `[(weight: Double, countPerSide: Int)]` tuples
/// — the structural shape that PlateSpec (the persisted entity) presents after
/// mapping. The caller (SessionFactory / WarmupRamp) bridges the two.
public enum PlateCalculator {

    /// Returns a plate stack that exactly loads `target`, or nil if the combination
    /// is impossible with the given plates.
    ///
    /// Uses greedy heaviest-plate-first order. For canonical kg and lb plate sets
    /// this is provably optimal (coin-system equivalence). For non-canonical sets
    /// greedy may not find a solution even if one exists — acceptable for v1.
    ///
    /// - Parameter target: Desired total weight including bar.
    /// - Parameter barWeight: Weight of the unloaded bar.
    /// - Parameter plates: Available plates as (weight, countPerSide) tuples. Not required
    ///   to be pre-sorted — the function sorts descending internally.
    /// - Returns: A `PlateStack` if the target is exactly achievable, nil otherwise.
    public static func solve(
        target: Double,
        barWeight: Double,
        plates: [(weight: Double, countPerSide: Int)]
    ) -> PlateStack? {
        guard target >= barWeight else { return nil }

        var remaining = ((target - barWeight) / 2.0).rounded(toPlaces: 3)
        var used: [(weight: Double, count: Int)] = []

        let sortedPlates = plates.sorted { $0.weight > $1.weight }
        for plate in sortedPlates {
            guard plate.weight > 0 else { continue }  // guard divide-by-zero
            let useCount = min(plate.countPerSide, Int(remaining / plate.weight))
            if useCount > 0 {
                used.append((plate.weight, useCount))
                remaining -= plate.weight * Double(useCount)
                remaining = remaining.rounded(toPlaces: 3)  // float drift guard
            }
        }

        // Solution found only if remaining weight is within epsilon of zero.
        guard remaining < 0.001 else { return nil }

        let usedSum = used.reduce(0.0) { $0 + $1.weight * Double($1.count) }
        return PlateStack(platesPerSide: used, totalWeight: barWeight + 2.0 * usedSum)
    }

    /// Returns the nearest plate-loadable weight at or below `target`.
    ///
    /// Unlike `solve`, this function always succeeds: it loads as much weight as
    /// possible without exceeding the target, then returns that total. This is the
    /// "round DOWN" semantic used for warm-up ramp sets — a warm-up should
    /// under-load rather than over-load if the target falls between increments.
    ///
    /// - Parameter target: Ceiling weight (the function returns ≤ this value).
    /// - Parameter barWeight: Weight of the unloaded bar.
    /// - Parameter plates: Available plates as (weight, countPerSide) tuples.
    /// - Returns: `barWeight` when `target < barWeight` (cannot load below bar).
    ///   Otherwise returns `barWeight + 2 × (plates loaded per side)`.
    public static func roundDown(
        target: Double,
        barWeight: Double,
        plates: [(weight: Double, countPerSide: Int)]
    ) -> Double {
        guard target >= barWeight else { return barWeight }

        var remaining = ((target - barWeight) / 2.0).rounded(toPlaces: 3)
        var usedPerSide: [(weight: Double, count: Int)] = []

        let sortedPlates = plates.sorted { $0.weight > $1.weight }
        for plate in sortedPlates {
            guard plate.weight > 0 else { continue }  // guard divide-by-zero
            let useCount = min(plate.countPerSide, Int(remaining / plate.weight))
            if useCount > 0 {
                usedPerSide.append((plate.weight, useCount))
                remaining -= plate.weight * Double(useCount)
                remaining = remaining.rounded(toPlaces: 3)  // float drift guard
            }
        }

        // Always return what was loaded — the remaining gap is intentional under-load.
        let totalPerSide = usedPerSide.reduce(0.0) { $0 + $1.weight * Double($1.count) }
        return barWeight + 2.0 * totalPerSide
    }
}

// MARK: - Private helpers

private extension Double {
    /// Rounds this value to a fixed number of decimal places to prevent accumulation
    /// of IEEE 754 floating-point errors in iterative plate subtraction loops.
    func rounded(toPlaces places: Int) -> Double {
        let d = pow(10.0, Double(places))
        return (self * d).rounded() / d
    }
}
