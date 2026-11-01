//
//  PlateCalculatorSheet.swift
//  fitbod
//
//  BRU brutalist plate calculator sheet.
//  Rewritten per 03.2-07-PLAN.md — full Form/Section/plateColor/weightToWidth/plateRect
//  architecture replaced with BRU composition per plate-calc.jsx verbatim.
//
//  Architecture (top→bottom, VStack(spacing: 0)):
//    BRUHeaderBar ← center "Plate calculator" / right "DONE"
//    targetBand   ← "TARGET" label + 96pt displayHero weight + unit + 4 BRUChip quick-adjust
//    [barExceedsTargetError] ← inline signal caption if parsedBar > parsedTarget
//    plateStackZone ← bruBg2 fill + 2pt bruInk rules top+bottom + "PER SIDE" + PlateStackViz
//    equipmentGrid  ← BRUSectionHead + 2-column grid with 1pt hair separator + 2pt ink bottom
//    platesAvailableList ← BRUSectionHead + LazyVStack PlateTallyRow rows (read-only .constant)
//
//  T19: the calculator only shows information, so it closes with the header's DONE.
//  Its "‹", "•••" and footer "Save inventory" / "Done ▸" (and the 24pt bruBg filler
//  under that footer) are gone. Its values never wrap inside a number.
//
//  T107: the EQUIPMENT heading drops "TAP TO CHANGE": the calculator only shows the
//  equipment and the inventory picked in Plate Inventory, and BAR and INVENTORY do
//  nothing when tapped. Each quick-adjust chip takes taps in a 44pt band; its drawn
//  chip keeps its size.
//
//  Input init unchanged: `public init(equipment: PlateEquipmentKind, inventory: PlateInventory)`
//  Computed math (parsedTarget, parsedBar, barWeightExceedsTarget, solvedStack) preserved verbatim.
//
//  DELETED (v1 legacy):
//    - plateColor(for:)     — bruInk for ALL plates per 03-UI-SPEC line 141
//    - weightToWidth(_:)    — PlateStackViz owns sizing per spec lines 73-74
//    - plateRect(weight:)   — PlateStackViz renders the stack
//    - ScrollView(.horizontal) HStack plate stack (lines 132-154) — replaced by PlateStackViz
//    - Color(.systemRed/.systemGray4/.systemGray*) — banned tokens
//    - Duplicated "No combination found" copy (v1 lines 96+104) — replaced by single bruSignal text
//    - RoundedRectangle(cornerRadius: 2) — BRU has no rounded shapes
//    - .font(.caption) / .font(.body) / .font(.headline) — replaced by BRUFont tokens
//    - Form/Section root structure — replaced by VStack(spacing:0) in NavigationStack
//
//  96pt hero override rationale — documented inline below.
//  Read-only .constant binding on PlateTallyRow — documented inline below.
//  Threat T-03.2-14 mitigation — documented on PlateTallyRow usage.
//

import SwiftUI
import SwiftData

public struct PlateCalculatorSheet: View {

    // MARK: - Inputs

    public let equipment: PlateEquipmentKind
    public let inventory: PlateInventory

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - State

    @State private var targetWeightText: String = "60"
    @State private var barWeightText: String = ""

    // MARK: - Init

    public init(equipment: PlateEquipmentKind, inventory: PlateInventory) {
        self.equipment = equipment
        self.inventory = inventory
    }

    // MARK: - Computed (math preserved verbatim from v1)

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

    /// Total weight from plates only (both sides), for the "BAR X + PLATES Y" label.
    private var totalPlateWeight: Double {
        guard let stack = solvedStack else { return 0 }
        // stack.totalWeight includes bar weight; subtract it to get plates-only total
        return stack.totalWeight - parsedBar
    }

    /// The lifter's unit from Settings. Plate inventories are entered in it.
    private var unitLabel: String { weightUnit.rawValue }

    /// Human-readable bar name for the Equipment grid.
    private var barName: String {
        switch equipment {
        case .barbell:
            return "Olympic · \(formatted(parsedBar)) \(unitLabel)"
        case .dumbbell:
            return "Dumbbell · \(formatted(parsedBar)) \(unitLabel)"
        case .ezBar:
            return "EZ-Bar · \(formatted(parsedBar)) \(unitLabel)"
        case .trapBar:
            return "Trap Bar · \(formatted(parsedBar)) \(unitLabel)"
        }
    }

    /// Human-readable inventory name for the Equipment grid.
    private var inventoryName: String {
        switch equipment {
        case .barbell:  return "Barbell set"
        case .dumbbell: return "Dumbbell set"
        case .ezBar:    return "EZ-Bar set"
        case .trapBar:  return "Trap Bar set"
        }
    }

    /// Format a Double, stripping unnecessary trailing zeros.
    private func formatted(_ d: Double) -> String {
        String(format: "%g", d)
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            // Hide the default navigation chrome — BRUHeaderBar is the chrome.
            VStack(spacing: 0) {
                headerBar
                ScrollView {
                    VStack(spacing: 0) {
                        targetBand
                        if barWeightExceedsTarget {
                            barExceedsTargetError
                        }
                        plateStackZone
                        equipmentGrid
                        platesAvailableList
                    }
                }
            }
            .background(Color.bruPaper)
            .navigationBarHidden(true)
        }
        .onAppear {
            if barWeightText.isEmpty {
                barWeightText = formatted(inventory.barWeight)
            }
        }
    }

    // MARK: - Header Bar

    /// BRU header bar: "Plate calculator" in the center, DONE on the right.
    /// A sheet that only shows information closes with DONE (T19).
    private var headerBar: some View {
        BRUHeaderBar(
            center: "Plate calculator",
            right: HeaderAction("Done") { dismiss() }
        )
    }

    // MARK: - Target Band

    /// Target display band: 14pt top padding, 16pt horizontal, 2pt bruInk bottom rule.
    /// Per 03-UI-SPEC lines 240-244 / plate-calc.jsx lines 24-43.
    /// No value wraps inside a number (T19). Above the default text size the chips
    /// move under the weight: beside them on the small phone, even "100" showed as
    /// "1…" at XXL. At accessibility sizes TARGET also stacks over its readout, the
    /// way TodayStatStrip stacks.
    private var targetBand: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: "TARGET" label + "BAR X + PLATES Y" right label
            targetLabelLayout {
                Text("Target")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruInk)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .fixedSize()

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }

                // Takes its room before the spacer, and wraps only between words.
                Text("Bar \(formatted(parsedBar)) + Plates \(formatted(totalPlateWeight))")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruMuted)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .layoutPriority(1)
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)

            // Hero row: 96pt weight + unit label + quick-adjust chips
            Group {
                if dynamicTypeSize > .large {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            heroWeight
                            heroUnit
                        }
                        // One row of chips when it fits, else minus over plus.
                        ViewThatFits(in: .horizontal) {
                            quickAdjustChips
                            VStack(alignment: .leading, spacing: 4) {
                                subtractChips.fixedSize()
                                addChips.fixedSize()
                            }
                        }
                    }
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        // The weight and its unit take every point the chips leave.
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            heroWeight
                            heroUnit
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        quickAdjustChips
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 14)
        }
        // At accessibility sizes nothing in the band stretches, so it fills
        // the sheet's width itself and keeps TARGET on the 16pt margin.
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            // 2pt bruInk bottom rule per plate-calc.jsx line 25
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    /// TARGET beside its readout, or over it at accessibility sizes.
    private var targetLabelLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
    }

    /// 96pt hero weight per 03-UI-SPEC line 87 / plate-calc.jsx line 34.
    /// Font.custom override — BRUFont enum supplies the typeface name
    /// (SpaceGrotesk-Bold) but the 96pt size is a load-bearing spec exception
    /// requiring Font.custom directly (BRUFont.displayHero is 56pt).
    /// It shrinks rather than wrap inside the number.
    private var heroWeight: some View {
        Text(formatted(parsedTarget))
            .font(.bru(.grotesk, size: 96, relativeTo: .largeTitle))
            .foregroundStyle(Color.bruInk)
            // Negative letterspacing per displayHero spec (-0.5)
            .tracking(-0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var heroUnit: some View {
        Text(unitLabel.uppercased())
            .font(BRUFont.displayLarge)
            .foregroundStyle(Color.bruMuted)
            .fixedSize()
    }

    /// Quick-adjust chips per 03-UI-SPEC line 244 (item 25):
    /// BRUChip ink-outline, NOT signal — plate-calc.jsx line 37 shows BruChip without color override.
    /// Each chip keeps its whole width, so "−2.5" never wraps as "−2." over "5".
    private var quickAdjustChips: some View {
        HStack(spacing: 4) {
            subtractChips
            addChips
        }
        .fixedSize()
    }

    private var subtractChips: some View {
        HStack(spacing: 4) {
            quickAdjustChip(label: "−5", delta: -5)
            quickAdjustChip(label: "−2.5", delta: -2.5)
        }
    }

    private var addChips: some View {
        HStack(spacing: 4) {
            quickAdjustChip(label: "+2.5", delta: 2.5)
            quickAdjustChip(label: "+5", delta: 5)
        }
    }

    /// Quick-adjust chip: tapping mutates `targetWeightText` by `delta`.
    /// The chip draws at its own size inside a 44pt band that takes the tap.
    private func quickAdjustChip(label: String, delta: Double) -> some View {
        Button {
            // T-03.2-13 mitigation: Double can safely represent any plausible plate
            // weight — overflow not a realistic concern up to ~10^15.
            let current = parsedTarget
            let newValue = max(0, current + delta)
            targetWeightText = formatted(newValue)
        } label: {
            // Frame and hit shape sit inside the label: a frame outside the
            // Button does not grow what it takes taps on.
            BRUChip(label)
                .frame(minHeight: BRUMetrics.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Accessibility: announce the intended action including unit per 03-UI-SPEC line 502
        .accessibilityLabel(delta > 0 ? "Add \(formatted(delta)) \(unitLabel)" : "Subtract \(formatted(abs(delta))) \(unitLabel)")
    }

    // MARK: - Bar Exceeds Target Error

    /// Inline validation caption: shown when parsedBar > parsedTarget && parsedTarget > 0.
    /// Per 03-UI-SPEC line 352 verbatim. Replaces v1 Color(.systemRed) Section footer.
    private var barExceedsTargetError: some View {
        Text("Bar weight exceeds target. Check the bar weight.")
            .font(BRUFont.labelSmall)
            .foregroundStyle(Color.bruSignal)
            .textCase(.uppercase)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    // MARK: - Plate Stack Zone

    /// PLATE STACK zone: bruBg2 fill, 2pt bruInk top + bottom rules, "PER SIDE" label, PlateStackViz.
    /// Per 03-UI-SPEC line 382 / plate-calc.jsx lines 45-83.
    private var plateStackZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            // "PER SIDE" label per 03-UI-SPEC line 245 / plate-calc.jsx lines 48-49
            Text("Per side")
                .font(BRUFont.labelSmall)
                .foregroundStyle(Color.bruInk)
                .textCase(.uppercase)
                .tracking(1.5)

            if let stack = solvedStack {
                // Full-size PlateStackViz — Wave 1 primitive (03.2-01).
                // heightScale: 1.0 per plan spec. showLegend: true per plan spec.
                PlateStackViz(
                    platesPerSide: stack.platesPerSide.map { ($0.weight, $0.count) },
                    barLabel: "\(formatted(parsedBar)) \(unitLabel)",
                    heightScale: 1.0,
                    showLegend: true
                )
                .frame(maxWidth: .infinity)
            } else if parsedTarget > 0 {
                // No-solution state per 03-UI-SPEC line 256 verbatim.
                // Replaces duplicated v1 "No combination found" copy at v1 lines 96+104.
                Text("No combination found. Adjust inventory.")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruSignal)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.bruBg2)
        .overlay(alignment: .top) {
            // 2pt bruInk top rule per plate-calc.jsx line 46
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            // 2pt bruInk bottom rule per plate-calc.jsx line 46
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - Equipment Grid

    /// Equipment 2-column grid: bar + inventory display.
    /// Per 03-UI-SPEC lines 247-251 / plate-calc.jsx lines 85-97.
    /// Both cells only show what Plate Inventory picked, so the heading
    /// offers no "TAP TO CHANGE" (T107).
    private var equipmentGrid: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Equipment")

            HStack(spacing: 0) {
                // Left column: BAR
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bar")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(barName)
                        .font(.bru(.grotesk, size: 20))
                        .foregroundStyle(Color.bruInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .overlay(alignment: .trailing) {
                    // 1pt bruHair vertical separator between columns per plate-calc.jsx line 89
                    Rectangle()
                        .fill(Color.bruHair)
                        .frame(width: 1)
                }

                // Right column: INVENTORY
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inventory")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(inventoryName)
                        .font(.bru(.grotesk, size: 20))
                        .foregroundStyle(Color.bruInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .overlay(alignment: .bottom) {
                // 2pt bruInk bottom rule per plate-calc.jsx line 88
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(height: 2)
            }
        }
    }

    // MARK: - Plates Available List

    /// Plates available list: BRUSectionHead + LazyVStack of PlateTallyRow rows.
    /// READ-ONLY: PlateCalculatorSheet displays the inventory but does NOT edit it —
    /// PlateInventoryEditor is the editor. `.constant(plate.countPerSide)` ensures no
    /// accidental mutation from this calculator context.
    /// T-03.2-14 mitigation: PlateTallyRow's accessibilityAdjustableAction fires its setter;
    /// when bound to .constant, the action is a no-op — this is intentional per the
    /// PlateInventoryEditor-is-the-editor contract.
    private var platesAvailableList: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Plates available", right: "Per side")

            LazyVStack(spacing: 0) {
                ForEach(
                    inventory.availablePlates.sorted { $0.weight > $1.weight },
                    id: \.weight
                ) { plate in
                    // Read-only display per PlateInventoryEditor-is-the-editor contract.
                    PlateTallyRow(
                        weight: plate.weight,
                        count: .constant(plate.countPerSide),
                        unitLabel: unitLabel
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("plate calculator") {
    @Previewable @State var present = true
    let container = try! ModelContainer(
        for: PlateInventory.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = ModelContext(container)
    let inv = PlateInventory()
    inv.equipmentKind = .barbell
    inv.barWeight = 45
    inv.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .lb)
    ctx.insert(inv)
    try? ctx.save()
    return Color.bruPaper.sheet(isPresented: $present) {
        PlateCalculatorSheet(equipment: .barbell, inventory: inv)
            .presentationDetents([.large])
    }
    .modelContainer(container)
}
