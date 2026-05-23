//
//  PlateStackDisclosure.swift
//  fitbod
//
//  Phase 3 plan 06 — inline plate-stack visualization that slides in below
//  a set row when the weight cell is tapped. Renders an HStack of colored
//  Rectangles (mirrored per side) with a bar segment in the center.
//
//  Plate color palette follows UI-SPEC § Asset Contract exactly.
//  Animation is gated on @Environment(\.accessibilityReduceMotion).
//
//  Three render states:
//    1. `targetWeight < barWeight` → "Target is below bar weight..." caption
//    2. `solve == nil` (no combination found) → "No plate combination found..." error
//    3. `solve != nil` → plate-stack HStack with heading
//
//  UI-SPEC § Plate-stack inline disclosure heading verbatim:
//    "{bar} bar + {plates} each side"
//  UI-SPEC § Plate-stack accessibility label verbatim:
//    "Bar: {bar} kg. Plates each side: {plate list}. Total: {total} kg."
//
//  plan 03-08 wraps this in a DisclosureGroup or conditional VStack inside
//  SetRow. This component is standalone and does NOT own its own expand/collapse
//  state — the parent manages that via its plateStackVisible binding.
//

import SwiftUI

public struct PlateStackDisclosure: View {
    public let targetWeight: Double
    public let barWeight: Double
    public let plates: [PlateSpec]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    public init(targetWeight: Double, barWeight: Double, plates: [PlateSpec]) {
        self.targetWeight = targetWeight
        self.barWeight = barWeight
        self.plates = plates
    }

    // MARK: - Computed plate stack

    private var solvedStack: PlateStack? {
        PlateCalculator.solve(
            target: targetWeight,
            barWeight: barWeight,
            plates: plates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        )
    }

    public var body: some View {
        Group {
            if targetWeight < barWeight {
                // Below-bar state — informational, .secondaryLabel per UI-SPEC verbatim
                Text("Target is below bar weight (\(String(format: "%g", barWeight)) kg). Log as bodyweight or adjust the bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            } else if let stack = solvedStack {
                // Happy path — render the plate stack visualization
                plateStackView(stack: stack)
            } else {
                // No solution found — error state per UI-SPEC verbatim (.systemRed)
                Text("No plate combination found. Adjust inventory in Settings.")
                    .font(.caption)
                    .foregroundStyle(Color(.systemRed))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: targetWeight
        )
    }

    // MARK: - Plate stack view

    @ViewBuilder
    private func plateStackView(stack: PlateStack) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Heading: UI-SPEC verbatim "{bar} bar + {plates} each side"
            Text(headingText(stack: stack))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Plate visualization: left side (mirrored) | bar | right side
            HStack(spacing: 4) {
                Spacer(minLength: 16)

                // Left side plates (reversed order — outermost plate first visually)
                ForEach(Array(stack.platesPerSide.reversed().enumerated()), id: \.offset) { _, plateGroup in
                    ForEach(0..<plateGroup.count, id: \.self) { _ in
                        plateRect(weight: plateGroup.weight)
                    }
                }

                // Bar center segment
                Rectangle()
                    .fill(Color(.systemGray4))                                   // UI-SPEC § Asset Contract
                    .frame(width: 40, height: 6)

                // Right side plates (heaviest nearest bar)
                ForEach(Array(stack.platesPerSide.enumerated()), id: \.offset) { _, plateGroup in
                    ForEach(0..<plateGroup.count, id: \.self) { _ in
                        plateRect(weight: plateGroup.weight)
                    }
                }

                Spacer(minLength: 16)
            }
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(stack: stack))
    }

    // MARK: - Single plate rectangle

    @ViewBuilder
    private func plateRect(weight: Double) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(plateColor(weight: weight))
                .frame(width: plateWidth(weight: weight), height: 24)

            Text(String(format: "%g", weight))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Private helpers

    /// UI-SPEC § Asset Contract plate color palette.
    /// Uses kg-tier thresholds (v1 default — documented limitation in plan 03-06 SUMMARY).
    private func plateColor(weight: Double) -> Color {
        if weight >= 25 {
            return Color(.systemRed).opacity(0.8)                                // ≥25 kg / ≥45 lb
        } else if weight >= 20 {
            return Color(.systemBlue).opacity(0.8)                               // 20 kg / 35 lb
        } else if weight >= 15 {
            return Color(.systemYellow).opacity(0.8)                             // 15 kg / 25 lb
        } else if weight >= 10 {
            return Color(.systemGreen).opacity(0.8)                              // 10 kg
        } else if weight >= 5 {
            return Color(.systemGray5)                                           // 5 kg / 10 lb
        } else if weight >= 2.5 {
            return Color(.systemGray3)                                           // 2.5 kg / 5 lb
        } else {
            // <2.5 kg microplates — systemGray6 with systemGray2 border (render as overlay)
            return Color(.systemGray6)
        }
    }

    /// Linear width scale: heavier plates render wider. Clamped 8…32pt.
    private func plateWidth(_ weight: Double) -> CGFloat {
        CGFloat(max(8, min(32, weight)))
    }

    /// UI-SPEC verbatim heading: "{bar} bar + 2×20 kg, 1×5 kg each side"
    private func headingText(stack: PlateStack) -> String {
        let barStr = String(format: "%g", barWeight)
        let platesStr = perSideDescription(stack: stack)
        return "\(barStr) bar + \(platesStr) each side"
    }

    /// Builds a comma-separated plate description: "2×20 kg, 1×5 kg"
    private func perSideDescription(stack: PlateStack) -> String {
        stack.platesPerSide
            .filter { $0.count > 0 }
            .map { group in
                let w = String(format: "%g", group.weight)
                return "\(group.count)×\(w) kg"
            }
            .joined(separator: ", ")
    }

    /// UI-SPEC verbatim a11y label:
    /// "Bar: {bar} kg. Plates each side: {plate list, e.g. two 20 kg, one 5 kg}. Total: {total} kg."
    private func accessibilityLabel(stack: PlateStack) -> String {
        let barStr = String(format: "%g", barWeight)
        let plateList = stack.platesPerSide
            .filter { $0.count > 0 }
            .map { group in
                let countWord = group.count == 1 ? "one" : "\(group.count)"
                let w = String(format: "%g", group.weight)
                return "\(countWord) \(w) kg"
            }
            .joined(separator: ", ")
        let totalStr = String(format: "%g", stack.totalWeight)
        return "Bar: \(barStr) kg. Plates each side: \(plateList). Total: \(totalStr) kg."
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
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
        PlateStackDisclosure(targetWeight: 100, barWeight: 20, plates: plates)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
        PlateStackDisclosure(targetWeight: 97.5, barWeight: 20, plates: plates)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding()
}

#Preview("no solution found") {
    let plates = [
        PlateSpec(weight: 20, countPerSide: 2),
    ]
    return VStack(spacing: 0) {
        Text("97.5 kg — no solution (missing 2.5 kg plates)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
        PlateStackDisclosure(targetWeight: 97.5, barWeight: 20, plates: plates)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding()
}

#Preview("below bar weight") {
    let plates = [
        PlateSpec(weight: 25, countPerSide: 2),
    ]
    return VStack(spacing: 0) {
        Text("15 kg target — below 20 kg bar")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
        PlateStackDisclosure(targetWeight: 15, barWeight: 20, plates: plates)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding()
}
