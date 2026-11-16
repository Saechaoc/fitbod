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
//    [barExceedsTargetError] ← inline signal caption if the bar outweighs the target
//    plateStackZone ← bruBg2 fill + 2pt bruInk rules top+bottom + "PER SIDE" + PlateStackViz
//    equipmentGrid  ← BRUSectionHead + 2-column grid with 1pt hair separator + 2pt ink bottom
//    platesAvailableList ← BRUSectionHead + one read-only text row per plate
//
//  T19: the calculator only shows information, so it closes with the header's DONE.
//  Its "‹", "•••" and footer "Save inventory" / "Done ▸" (and the 24pt bruBg filler
//  under that footer) are gone. Its values never wrap inside a number.
//
//  T107: each quick-adjust chip takes taps in a 44pt band; its drawn chip keeps its size.
//
//  RM-025: a working set's actions open the calculator on the set's weight and its
//  exercise's equipment, bar and unit, and closing it returns to the logger at that set.
//  A tap on TARGET types a weight, read in the current locale like a set's weight.
//  BAR and INVENTORY switch the equipment in place, so "TAP TO CHANGE" is back, and
//  PLATES AVAILABLE reads as text: only Plate Inventory changes counts.
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
//

import SwiftUI
import SwiftData

public struct PlateCalculatorSheet: View {

    // MARK: - Inputs

    /// The equipment the calculator opens on.
    let startEquipment: PlateEquipmentKind
    /// The weight TARGET opens at.
    let startTarget: Double
    /// An exercise's own bar weight, used while the calculator shows the
    /// equipment it opened on.
    let barOverride: Double?
    /// An exercise's own unit, which wins over the lifter's.
    let unitOverride: WeightUnit?

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var defaultUnit
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Query private var inventories: [PlateInventory]

    // MARK: - State

    @State private var equipment: PlateEquipmentKind
    @State private var target: Double
    /// TARGET's text while it is typed in.
    @State private var targetText = ""
    @State private var editingTarget = false
    @FocusState private var targetFocused: Bool

    /// Where TARGET opens without a set's weight.
    static let defaultTarget = 60.0

    // MARK: - Init

    public init(equipment: PlateEquipmentKind, target: Double? = nil, barWeight: Double? = nil, unit: WeightUnit? = nil) {
        startEquipment = equipment
        startTarget = target ?? Self.defaultTarget
        barOverride = barWeight
        unitOverride = unit
        _equipment = State(initialValue: equipment)
        _target = State(initialValue: target ?? Self.defaultTarget)
    }

    /// The calculator for a working set: the weight its row shows, typed or
    /// offered, on its exercise's equipment, bar and unit. Nil for an
    /// exercise that loads no plates.
    static func forSet(_ entry: SetEntry, exercise: Exercise?, offeredWeight: Double?) -> PlateCalculatorSheet? {
        guard let kind = SessionFactory.plateEquipmentKind(for: exercise?.equipment ?? .other) else { return nil }
        // The weight cell shows a typed weight, else the set's offer.
        let shown = entry.weight != 0 || entry.wasManualOverride ? entry.weight : entry.isComplete ? nil : offeredWeight
        // An unloaded set, or an assisted one's negative load, has no plates to show.
        return PlateCalculatorSheet(
            equipment: kind,
            target: shown.flatMap { $0 > 0 ? $0 : nil },
            barWeight: exercise?.barWeightOverride,
            unit: exercise?.unitOverride
        )
    }

    /// A typed target, or nil for text that is not a weight of zero or more.
    static func typedTarget(_ text: String, locale: Locale) -> Double? {
        WorkoutLoadInput.value(text, locale: locale).flatMap { $0 >= 0 ? $0 : nil }
    }

    // MARK: - Computed

    /// The chosen equipment's inventory, when the store has one.
    private var inventory: PlateInventory? {
        inventories.first { $0.equipmentKind == equipment }
    }

    /// The exercise's own bar on the equipment it opened on, else the
    /// inventory's, else the default the logger's warm-ups use too.
    private var barWeight: Double {
        (equipment == startEquipment ? barOverride : nil)
            ?? inventory?.barWeight
            ?? PlateInventoryDefaults.barWeight(for: equipment, unitSystem: weightUnit)
    }

    private var plates: [PlateSpec] {
        inventory?.availablePlates ?? PlateInventoryDefaults.make(for: equipment, unitSystem: weightUnit)
    }

    private var barWeightExceedsTarget: Bool {
        target > 0 && barWeight > target
    }

    private var solvedStack: PlateStack? {
        guard target > 0 else { return nil }
        return PlateCalculator.solve(
            target: target,
            barWeight: barWeight,
            plates: plates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        )
    }

    /// Total weight from plates only (both sides), for the "BAR X + PLATES Y" label.
    private var totalPlateWeight: Double {
        guard let stack = solvedStack else { return 0 }
        // stack.totalWeight includes bar weight; subtract it to get plates-only total
        return stack.totalWeight - barWeight
    }

    /// The unit of the set the calculator opened from, else the lifter's.
    /// Plate inventories are entered in it.
    private var weightUnit: WeightUnit { unitOverride ?? defaultUnit }

    private var unitLabel: String { weightUnit.rawValue }

    /// TARGET as the lifter types weights.
    private var targetLabel: String { WorkoutLoadInput.text(target, locale: locale) }

    /// Human-readable bar name for the Equipment grid.
    private var barName: String {
        switch equipment {
        case .barbell:
            return "Olympic · \(NumberText.weight(barWeight)) \(unitLabel)"
        case .dumbbell:
            return "Dumbbell · \(NumberText.weight(barWeight)) \(unitLabel)"
        case .ezBar:
            return "EZ-Bar · \(NumberText.weight(barWeight)) \(unitLabel)"
        case .trapBar:
            return "Trap Bar · \(NumberText.weight(barWeight)) \(unitLabel)"
        }
    }

    /// Human-readable inventory name for the Equipment grid and its switch.
    private static func inventoryName(_ kind: PlateEquipmentKind) -> String {
        switch kind {
        case .barbell:  return "Barbell set"
        case .dumbbell: return "Dumbbell set"
        case .ezBar:    return "EZ-Bar set"
        case .trapBar:  return "Trap Bar set"
        }
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
            // The number pad has no return key (T39).
            .keyboardDone()
        }
        // Half height shows TARGET and the plates; the rest is a drag away.
        .presentationDetents([.medium, .large])
    }

    // MARK: - Header Bar

    /// BRU header bar: "Plate calculator" in the center, DONE on the right.
    /// A sheet that only shows information closes with DONE (T19).
    private var headerBar: some View {
        BRUHeaderBar(
            center: "Plate calculator",
            right: HeaderAction("Done") { dismiss() }
        )
        // Room under the drag handle, which the two-line title met at 390pt.
        .padding(.top, 8)
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
                Text("Bar \(NumberText.weight(barWeight)) + Plates \(NumberText.weight(totalPlateWeight))")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruMuted)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .layoutPriority(1)
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)

            // Hero row: 96pt weight + unit label + quick-adjust chips. While
            // TARGET is typed in, the chips step aside and the field has the row.
            Group {
                if dynamicTypeSize > .large {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            heroWeight
                            heroUnit
                        }
                        // One row of chips when it fits, else minus over plus.
                        if !editingTarget {
                            ViewThatFits(in: .horizontal) {
                                quickAdjustChips
                                VStack(alignment: .leading, spacing: 4) {
                                    subtractChips.fixedSize()
                                    addChips.fixedSize()
                                }
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

                        if !editingTarget {
                            quickAdjustChips
                        }
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
    /// It shrinks rather than wrap inside the number. A tap swaps it for a
    /// number field, as a set's time does in the logger, so 225 or 315 is a
    /// few keys away, not dozens of chip taps.
    @ViewBuilder
    private var heroWeight: some View {
        let font = Font.bru(.grotesk, size: 96, relativeTo: .largeTitle)
        if editingTarget {
            // A bare field fills the row, pushing the unit to the far edge,
            // and stands taller than the number. So the field takes its
            // text's size, with room for the caret.
            Text(targetText.isEmpty ? "0" : targetText)
                .font(font)
                .tracking(-0.5)
                .lineLimit(1)
                .padding(.trailing, 4)
                .hidden()
                .overlay(alignment: .leading) {
                    TextField("Target", text: $targetText)
                        .font(font)
                        .tracking(-0.5)
                        .foregroundStyle(Color.bruInk)
                        .keyboardType(.decimalPad)
                        .focused($targetFocused)
                        // A weight typed into the field replaces the one it shows (T39).
                        .selectsAllOnFocus(targetFocused)
                        .onAppear { targetFocused = true }
                        // The plates follow each keystroke; text that is not a
                        // weight keeps the last target.
                        .onChange(of: targetText) { _, text in
                            if let value = Self.typedTarget(text, locale: locale) { target = value }
                        }
                        .onChange(of: targetFocused) { _, focused in
                            if !focused { editingTarget = false }
                        }
                        .accessibilityLabel("Target")
                        .accessibilityIdentifier("plateCalculator.targetField")
                }
        } else {
            // The number shrinks to fit beside the chips, but the row keeps a
            // full line, as the field has while typing, so TARGET's rule
            // stays put when typing starts.
            ZStack(alignment: Alignment(horizontal: .leading, vertical: .lastTextBaseline)) {
                Text("0").font(font).hidden()
                Button {
                    targetText = targetLabel
                    editingTarget = true
                } label: {
                    Text(targetLabel)
                        .font(font)
                        .foregroundStyle(Color.bruInk)
                        // Negative letterspacing per displayHero spec (-0.5)
                        .tracking(-0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Target")
                .accessibilityValue("\(targetLabel) \(unitLabel)")
                .accessibilityHint("Double tap to type a weight")
                .accessibilityIdentifier("plateCalculator.target")
            }
        }
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

    /// Quick-adjust chip: tapping steps the target by `delta`.
    /// The chip draws at its own size inside a 44pt band that takes the tap.
    private func quickAdjustChip(label: String, delta: Double) -> some View {
        Button {
            // T-03.2-13 mitigation: Double can safely represent any plausible plate
            // weight — overflow not a realistic concern up to ~10^15.
            target = max(0, target + delta)
        } label: {
            // Frame and hit shape sit inside the label: a frame outside the
            // Button does not grow what it takes taps on.
            BRUChip(label)
                .frame(minHeight: BRUMetrics.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Accessibility: announce the intended action including unit per 03-UI-SPEC line 502
        .accessibilityLabel(delta > 0 ? "Add \(NumberText.weight(delta)) \(unitLabel)" : "Subtract \(NumberText.weight(abs(delta))) \(unitLabel)")
    }

    // MARK: - Bar Exceeds Target Error

    /// Inline validation caption: shown when the bar outweighs a target above zero.
    /// Per 03-UI-SPEC line 352 verbatim. Small text takes the readable signal (D-120).
    private var barExceedsTargetError: some View {
        Text("Bar weight exceeds target. Check the bar weight.")
            .font(BRUFont.labelSmall)
            .foregroundStyle(Color.bruSignalText)
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
                    barLabel: "\(NumberText.weight(barWeight)) \(unitLabel)",
                    heightScale: 1.0,
                    showLegend: true
                )
                .frame(maxWidth: .infinity)
            } else if target > 0 {
                // No-solution state per 03-UI-SPEC line 256 verbatim.
                // Replaces duplicated v1 "No combination found" copy at v1 lines 96+104.
                Text("No combination found. Adjust inventory.")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruSignalText)
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
    /// A tap on either cell switches the equipment in place (RM-025): the bar
    /// and plates follow, and TARGET stays.
    private var equipmentGrid: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Equipment", right: "Tap to change")

            Menu {
                Picker("Equipment", selection: $equipment) {
                    ForEach(PlateEquipmentKind.allCases, id: \.self) { kind in
                        Text(Self.inventoryName(kind)).tag(kind)
                    }
                }
            } label: {
                equipmentCells
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Equipment")
            .accessibilityValue("\(Self.inventoryName(equipment)), bar \(NumberText.weight(barWeight)) \(unitLabel)")
            .accessibilityHint("Double tap to change it")
            .accessibilityIdentifier("plateCalculator.equipment")
        }
    }

    /// The BAR and INVENTORY cells the equipment switch shows.
    private var equipmentCells: some View {
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

                Text(Self.inventoryName(equipment))
                    .font(.bru(.grotesk, size: 20))
                    .foregroundStyle(Color.bruInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            // 2pt bruInk bottom rule per plate-calc.jsx line 88
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - Plates Available List

    /// The chosen equipment's plates and how many there are per side.
    /// Plate Inventory is the editor, so these rows read as text, without the
    /// tally boxes that look and announce as adjustable there (D-114).
    private var platesAvailableList: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Plates available", right: "Per side")

            ForEach(plates.sorted { $0.weight > $1.weight }, id: \.weight) { plate in
                plateRow(plate)
            }
        }
    }

    /// One plate: its glyph and weight as Plate Inventory draws them, and
    /// "×4" or "NONE"; a plate the lifter has none of is muted there too.
    private func plateRow(_ plate: PlateSpec) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(width: 16, height: 28)
            Text(NumberText.weight(plate.weight))
                .font(.bru(.grotesk, size: 20))
                .foregroundStyle(Color.bruInk)
            Spacer(minLength: 8)
            Text(plate.countPerSide > 0 ? "×\(plate.countPerSide)" : "NONE")
                .font(BRUFont.bodyDefault)
                .fontWeight(.semibold)
                .foregroundStyle(plate.countPerSide > 0 ? Color.bruInk : Color.bruMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(plate.countPerSide == 0 ? 0.4 : 1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.bruHair)
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(NumberText.weight(plate.weight)) \(unitLabel) plate")
        .accessibilityValue("\(plate.countPerSide) per side")
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
        PlateCalculatorSheet(equipment: .barbell, target: 225)
    }
    .modelContainer(container)
}
