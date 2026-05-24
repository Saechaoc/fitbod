//
//  PlateStackDisclosure.swift
//  fitbod
//
//  Phase 3.2-04 BRU rewrite — inline plate-stack disclosure panel.
//
//  BRU conformance (03-UI-SPEC lines 376, 416–421):
//    - bruBg2 background fill, 2pt bruInk bottom rule
//    - Delegates ALL plate rendering to PlateStackViz (Design/PlateStackViz.swift)
//    - No local plateColor / plateWidth / plateRect helpers (deleted)
//    - No Color(.system*), no RoundedRectangle, no Capsule, no SF Symbols
//    - No Font.body / Font.caption / Font.headline — BRUFont only
//
//  Three render branches:
//    1. targetWeight < barWeight → informational copy (BRUFont.bodyDefault bruMuted)
//    2. PlateCalculator.solve returns a stack → PlateStackViz at heightScale 0.6
//    3. No solution → "NO COMBINATION FOUND. ADJUST INVENTORY." (BRUFont.labelSmall bruSignal)
//
//  Slide-in animation is the PARENT SetRow's responsibility per 03-UI-SPEC line 418.
//  This primitive renders synchronously (no .animation modifier).
//

import SwiftUI

public struct PlateStackDisclosure: View {
    public let targetWeight: Double
    public let barWeight: Double
    public let plates: [PlateSpec]
    /// Unit label for copy strings. Defaults to "kg".
    public let unitLabel: String

    public init(
        targetWeight: Double,
        barWeight: Double,
        plates: [PlateSpec],
        unitLabel: String = "kg"
    ) {
        self.targetWeight = targetWeight
        self.barWeight = barWeight
        self.plates = plates
        self.unitLabel = unitLabel
    }

    // MARK: - Computed plate stack

    private var solvedStack: PlateStack? {
        PlateCalculator.solve(
            target: targetWeight,
            barWeight: barWeight,
            plates: plates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        )
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            if targetWeight < barWeight {
                // Below-bar state: informational copy per 03-UI-SPEC line 418
                Text(
                    "Target is below bar weight (\(String(format: "%g", barWeight)) \(unitLabel)). Log as bodyweight or adjust the bar."
                )
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            } else if let stack = solvedStack {
                // Solved: delegate to PlateStackViz — no local plate rect helpers
                PlateStackViz(
                    platesPerSide: stack.platesPerSide.map { ($0.weight, $0.count) },
                    barLabel: "\(String(format: "%g", barWeight)) \(unitLabel)",
                    heightScale: 0.6,
                    showLegend: true
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            } else {
                // No solution: error state per 03-UI-SPEC line 421 verbatim
                Text("NO COMBINATION FOUND. ADJUST INVENTORY.")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruSignal)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bruBg2)
        .overlay(alignment: .bottom) {
            // 2pt bruInk bottom rule per 03-UI-SPEC line 376
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
        // PlateStackViz owns the combined accessibility label internally.
        // No additional a11y modifier on this primitive per plan 03.2-04 behavior contract.
    }
}

// MARK: - Previews

#Preview("100 kg standard") {
    let plates = [
        PlateSpec(weight: 25, countPerSide: 2),
        PlateSpec(weight: 20, countPerSide: 2),
        PlateSpec(weight: 10, countPerSide: 2),
        PlateSpec(weight: 5, countPerSide: 2),
        PlateSpec(weight: 2.5, countPerSide: 2),
    ]
    return VStack(spacing: 0) {
        Text("100 kg — standard barbell")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .padding(.bottom, 4)
        PlateStackDisclosure(targetWeight: 100, barWeight: 20, plates: plates)
    }
    .padding()
    .background(Color.bruPaper)
    .overlay { Rectangle().stroke(Color.bruInk, lineWidth: 1) }
    .padding()
}

#Preview("97.5 kg with microplates") {
    let plates = [
        PlateSpec(weight: 25, countPerSide: 2),
        PlateSpec(weight: 20, countPerSide: 2),
        PlateSpec(weight: 10, countPerSide: 2),
        PlateSpec(weight: 5, countPerSide: 2),
        PlateSpec(weight: 2.5, countPerSide: 4),
        PlateSpec(weight: 1.25, countPerSide: 4),
    ]
    return VStack(spacing: 0) {
        Text("97.5 kg — with fractional plates")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .padding(.bottom, 4)
        PlateStackDisclosure(targetWeight: 97.5, barWeight: 20, plates: plates)
    }
    .padding()
    .background(Color.bruPaper)
    .overlay { Rectangle().stroke(Color.bruInk, lineWidth: 1) }
    .padding()
}

#Preview("no solution found") {
    let plates = [
        PlateSpec(weight: 20, countPerSide: 2),
    ]
    return VStack(spacing: 0) {
        Text("97.5 kg — no solution (missing 2.5 kg plates)")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .padding(.bottom, 4)
        PlateStackDisclosure(targetWeight: 97.5, barWeight: 20, plates: plates)
    }
    .padding()
    .background(Color.bruPaper)
    .overlay { Rectangle().stroke(Color.bruInk, lineWidth: 1) }
    .padding()
}

#Preview("below bar weight") {
    let plates = [
        PlateSpec(weight: 25, countPerSide: 2),
    ]
    return VStack(spacing: 0) {
        Text("15 kg target — below 20 kg bar")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .padding(.bottom, 4)
        PlateStackDisclosure(targetWeight: 15, barWeight: 20, plates: plates)
    }
    .padding()
    .background(Color.bruPaper)
    .overlay { Rectangle().stroke(Color.bruInk, lineWidth: 1) }
    .padding()
}
