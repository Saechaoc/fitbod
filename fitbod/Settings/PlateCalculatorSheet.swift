//
//  PlateCalculatorSheet.swift
//  fitbod
//
//  "Try it" plate calculator sheet reachable from PlateInventoryEditor's
//  toolbar trailing "Calculator" button. Rendered at .medium detent.
//
//  Inputs: editable target weight + editable bar weight.
//  Output: live plate-stack visualization using PlateCalculator.solve(...)
//  from the active PlateInventory.
//
//  Pattern: DecimalRPEPickerSheet analog (PATTERNS.md Sheet presentation
//  + dismiss pattern, lines 907–933). NavigationStack + .navigationTitle +
//  .navigationBarTitleDisplayMode(.inline) + ToolbarItem "Done" dismiss.
//
//  Plate-stack visualization: horizontal HStack of Rectangle shapes per
//  plate per side (left mirrored), bar segment in center. Colors per
//  UI-SPEC § Asset Contract color palette.
//

import SwiftUI
import SwiftData

public struct PlateCalculatorSheet: View {

    // MARK: - Inputs

    public let equipment: PlateEquipmentKind
    public let inventory: PlateInventory

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var targetWeightText: String = "60"
    @State private var barWeightText: String = ""

    // MARK: - Init

    public init(equipment: PlateEquipmentKind, inventory: PlateInventory) {
        self.equipment = equipment
        self.inventory = inventory
    }

    // MARK: - Computed

    private var parsedTarget: Double { Double(targetWeightText) ?? 0 }
    private var parsedBar: Double { Double(barWeightText) ?? inventory.barWeight }

    private var barWeightExceedsTarget: Bool {
        parsedTarget > 0 && parsedBar > parsedTarget
    }

    private var solvedStack: PlateStack? {
        guard parsedTarget > 0 else { return nil }
        return PlateCalculator.solve(
            target: parsedTarget,
            barWeight: parsedBar,
            plates: inventory.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        )
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                // Target weight input
                Section {
                    TextField("Target weight", text: $targetWeightText)
                        .keyboardType(.decimalPad)
                }

                // Bar weight input with validation footer
                Section {
                    TextField("Bar weight", text: $barWeightText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Bar weight")
                } footer: {
                    if barWeightExceedsTarget {
                        // UI-SPEC § Error states verbatim
                        Text("Bar weight exceeds target. Check the bar weight.")
                            .font(.caption)
                            .foregroundStyle(Color(.systemRed))
                    }
                }

                // Plate stack visualization
                Section {
                    if let stack = solvedStack {
                        plateStackView(stack: stack)
                    } else if parsedTarget > 0 {
                        Text("No combination found")                            // UI-SPEC verbatim
                            .foregroundStyle(.secondary)
                            .font(.body)
                    }
                } header: {
                    Text("Plate stack")
                } footer: {
                    if parsedTarget > 0, solvedStack == nil {
                        Text("No combination found")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Plate Calculator")                                // UI-SPEC verbatim
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                // Initialize bar weight text from inventory on first appear.
                if barWeightText.isEmpty {
                    barWeightText = String(format: "%g", inventory.barWeight)
                }
            }
        }
    }

    // MARK: - Plate Stack Visualization

    @ViewBuilder
    private func plateStackView(stack: PlateStack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Horizontal plate stack: left side (mirrored) | bar | right side
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Left side plates (mirrored — same as right side, reversed)
                    ForEach(Array(stack.platesPerSide.reversed().enumerated()), id: \.offset) { _, entry in
                        ForEach(0..<entry.count, id: \.self) { _ in
                            plateRect(weight: entry.weight)
                        }
                    }

                    // Bar center segment
                    Rectangle()
                        .fill(Color(.systemGray4))                              // UI-SPEC § Asset Contract bar segment
                        .frame(width: 60, height: 6)

                    // Right side plates
                    ForEach(Array(stack.platesPerSide.enumerated()), id: \.offset) { _, entry in
                        ForEach(0..<entry.count, id: \.self) { _ in
                            plateRect(weight: entry.weight)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // Total weight readout
            HStack {
                Text("Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%g", stack.totalWeight))
                    .font(.body)
            }

            // Per-plate breakdown (text summary for accessibility + clarity)
            if !stack.platesPerSide.isEmpty {
                let summary = stack.platesPerSide
                    .map { "\($0.count)×\(String(format: "%g", $0.weight))" }
                    .joined(separator: ", ")
                Text("Each side: \(summary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A single colored plate rectangle per UI-SPEC § Asset Contract.
    @ViewBuilder
    private func plateRect(weight: Double) -> some View {
        let color = plateColor(for: weight)
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: weightToWidth(weight), height: 24)               // UI-SPEC 24pt plate height
            Text(String(format: "%g", weight))
                .font(.caption)                                                 // UI-SPEC caption for plate labels
                .foregroundStyle(.secondary)
        }
    }

    /// Maps a plate weight to a display width proportional to its weight.
    private func weightToWidth(_ weight: Double) -> CGFloat {
        // Scale: heaviest standard plate (45/25 kg) → 20pt; lightest → 6pt.
        // Clamp to [6, 20] so microplates remain visible.
        let scaled = max(6, min(20, CGFloat(weight) * 0.8))
        return scaled
    }

    /// Returns the semantic system color for a plate weight per UI-SPEC § Asset Contract.
    private func plateColor(for weight: Double) -> Color {
        switch weight {
        case let w where w >= 25:                                               // UI-SPEC: Red for ≥25 kg / ≥45 lb
            return Color(.systemRed).opacity(0.8)
        case let w where w >= 20:                                               // UI-SPEC: Blue for 20 kg / 35 lb
            return Color(.systemBlue).opacity(0.8)
        case let w where w >= 15:                                               // UI-SPEC: Yellow for 15 kg / 25 lb
            return Color(.systemYellow).opacity(0.8)
        case let w where w >= 10:                                               // UI-SPEC: Green for 10 kg
            return Color(.systemGreen).opacity(0.8)
        case let w where w >= 5:                                                // UI-SPEC: Light gray for 5 kg
            return Color(.systemGray5)
        case let w where w >= 2.5:                                              // UI-SPEC: Gray for 2.5 kg
            return Color(.systemGray3)
        default:                                                                // UI-SPEC: Silver/border for microplates
            return Color(.systemGray6)
        }
    }
}

// MARK: - Preview

#Preview("plate calculator") {
    @Previewable @State var present = true
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let inv = PlateInventory()
    inv.equipmentKind = .barbell
    inv.barWeight = 20
    inv.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)
    ctx.insert(inv)
    try? ctx.save()
    return Color.clear.sheet(isPresented: $present) {
        PlateCalculatorSheet(equipment: .barbell, inventory: inv)
            .presentationDetents([.medium])
    }
    .modelContainer(container)
}
