//
//  PlateInventoryEditor.swift
//  fitbod
//
//  Settings → Smart Progression → Plate Inventory.
//  Pushed onto the Settings NavigationStack — owns no NavigationStack itself.
//
//  BRU reskin (03.2-06): Stepper → PlateTallyRow; Form/Section → ScrollView/VStack;
//  ContentUnavailableView → custom BRU empty-state; Picker(.segmented) → custom HStack tab strip;
//  Color.accentColor → BRU tokens; .navigationTitle → BRUHeaderBar.
//  T77: ScrollView/VStack → a plain List of BRU rows, so a plate row's swipe-to-delete
//  works on iOS 26 and closes like other rows.
//  T19: the header gains ‹ BACK, since the system bar stays hidden, and the footer
//  drops "Save inventory": every edit already saves as it is made.
//  T107: the equipment tabs sit in equal cells, as many to a row as keep every label
//  on one line, so no tab breaks inside a word ("DUMBBELL" over "S" from XXXL). The
//  24pt bruBg filler under Done ▸ is gone: inside the Settings sheet it showed as a
//  gray band above the home indicator, whose safe area already shows the paper.
//  T39: the bar weight and Add Plate's weight select their number as they take focus,
//  so a typed weight replaces it, and both number pads get a DONE.
//
//  UI-SPEC §PlateInventoryEditor (verbatim copy in all labels / alerts / empty states).
//  Pattern: PATTERNS.md @Query + @Bindable write-through (SettingsView analog).
//

import SwiftUI
import SwiftData

public struct PlateInventoryEditor: View {

    // MARK: - Data

    @Query private var inventories: [PlateInventory]
    @Environment(\.modelContext) private var ctx
    @Query private var settingsList: [UserSettings]
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var activeTab: PlateEquipmentKind = .barbell
    @State private var showResetConfirm: Bool = false
    @State private var showAddPlateSheet: Bool = false
    @State private var showCalculatorSheet: Bool = false
    @FocusState private var barWeightFocused: Bool

    // MARK: - Init

    public init() {}

    // MARK: - Helpers

    private var activeInventory: PlateInventory? {
        inventories.first(where: { $0.equipmentKind == activeTab })
    }

    private var unitLabel: String {
        settingsList.first?.weightUnit == .kg ? "kg" : "lb"
    }

    private var currentUnit: WeightUnit {
        settingsList.first?.weightUnit ?? .lb
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // BRUHeaderBar — replaces .navigationTitle (03.2-06 must_have)
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
                center: "Plate Inventory",
                right: HeaderAction("•••") { showCalculatorSheet = true }
            )

            // Custom bruInk-styled tab strip (replaces Picker(.segmented))
            equipmentTabStrip

            // Content list. Swipe actions work only in a List on iOS 26, and a
            // List keeps one row's Delete open at a time and closes it on a tap
            // outside the rows or a scroll.
            List {
                Group {
                    if let inv = activeInventory {
                        @Bindable var binv = inv
                        activeTabContent(binv: binv)
                    } else {
                        emptyInventoryState
                    }
                }
                // Rows draw their own rules and padding: no inset, no system
                // separator, paper background.
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.bruPaper)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // Rows keep their own heights instead of the 44pt list minimum.
            .environment(\.defaultMinListRowHeight, 0)

            // Footer — 2pt bruInk top rule + primary "Done ▸"
            footerBar
        }
        .background(Color.bruPaper)
        // No .navigationTitle — BRUHeaderBar owns that chrome
        .navigationBarHidden(true)
        // Number pads have no return key (T39).
        .keyboardDone()
        .sheet(isPresented: $showCalculatorSheet) {
            if let inv = activeInventory {
                PlateCalculatorSheet(equipment: activeTab, inventory: inv)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showAddPlateSheet) {
            if let inv = activeInventory {
                @Bindable var binv = inv
                AddPlateSheet(binv: binv, ctx: ctx)
            }
        }
        .alert("Reset plate inventory?", isPresented: $showResetConfirm) {    // UI-SPEC verbatim
            Button("Reset", role: .destructive) {
                if let inv = activeInventory {
                    inv.availablePlates = PlateInventoryDefaults.make(
                        for: activeTab,
                        unitSystem: currentUnit
                    )
                    inv.barWeight = PlateInventoryDefaults.barWeight(
                        for: activeTab,
                        unitSystem: currentUnit
                    )
                    inv.updatedAt = .now
                    try? ctx.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            // UI-SPEC line 280 verbatim
            Text("Replaces with the default \(unitLabel) plate set for \(activeTab.displayName).")
        }
    }

    // MARK: - Equipment tab strip

    /// Custom 4-segment bruInk tab strip — replaces Picker(.segmented).
    /// Selected segment: bruInk fill + bruPaper text.
    /// Unselected: bruPaper fill + bruInk text.
    /// 1pt bruInk separators between segments: the strip's ink shows in the
    /// 1pt gaps `EquipmentTabLayout` leaves between them.
    /// 2pt bruInk bottom rule beneath the strip.
    private var equipmentTabStrip: some View {
        VStack(spacing: 0) {
            EquipmentTabLayout(spacing: 1) {
                ForEach(PlateEquipmentKind.allCases, id: \.self) { kind in
                    tabButton(for: kind)
                }
            }
            .background(Color.bruInk)
            // Outer 1.5pt bruInk border around the full strip (per UI-SPEC line 441)
            .overlay {
                Rectangle()
                    .stroke(Color.bruInk, lineWidth: 1.5)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("plateInventory.tabStrip")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 2pt bruInk bottom rule beneath the strip
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
        .background(Color.bruPaper)
    }

    @ViewBuilder
    private func tabButton(for kind: PlateEquipmentKind) -> some View {
        let isActive = activeTab == kind
        Button {
            activeTab = kind
        } label: {
            Text(kind.displayName)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
                // Keeps the label clear of the separators.
                .padding(.horizontal, 2)
                // Fills its cell, which a taller tab in its row can stretch.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? Color.bruInk : Color.bruPaper)
        }
        .buttonStyle(.plain)
        // T-03.2-11 mitigation: VoiceOver announces the active tab
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Active tab content

    @ViewBuilder
    private func activeTabContent(binv: PlateInventory) -> some View {
        // Bar weight section — one list row
        VStack(spacing: 0) {
            barWeightSection(binv: binv)
        }

        // Plates per side section — its head, then a list row per plate
        platesSection(binv: binv)
    }

    // MARK: - Bar weight section

    @ViewBuilder
    private func barWeightSection(binv: PlateInventory) -> some View {
        @Bindable var b = binv

        BRUSectionHead("Bar weight")                                           // UI-SPEC verbatim

        HStack {
            Text("BAR WEIGHT")                                                 // UI-SPEC verbatim
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)

            Spacer()

            TextField("45", value: $b.barWeight, format: .number)
                .keyboardType(.decimalPad)
                .focused($barWeightFocused)
                // A weight typed into the field replaces the one it shows
                // (T39).
                .selectsAllOnFocus(barWeightFocused)
                .font(BRUFont.bodyDefault)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .accessibilityLabel("Bar weight")
                .accessibilityIdentifier("plateInventory.barWeight")

            Text(unitLabel)
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        // 2pt bruInk bottom rule beneath bar weight row
        Rectangle()
            .fill(Color.bruInk)
            .frame(height: 2)
    }

    // MARK: - Plates per side section

    @ViewBuilder
    private func platesSection(binv: PlateInventory) -> some View {
        BRUSectionHead("Plates available", right: "Per side")                  // UI-SPEC verbatim

        if binv.availablePlates.isEmpty {
            // Empty state — UI-SPEC lines 282–284 verbatim
            VStack(spacing: 12) {
                Text("No plates configured")                                   // UI-SPEC verbatim
                    .font(.bru(.grotesk, size: 28))
                    .foregroundStyle(Color.bruInk)

                Text("Add plates to use the plate calculator.")                // UI-SPEC verbatim
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)

                // "+ ADD PLATE" signal text button per UI-SPEC line 284
                Button {
                    showAddPlateSheet = true
                } label: {
                    Text("+ ADD PLATE")                                        // UI-SPEC verbatim
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruSignal)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.top, 32)
            .padding(.horizontal, 16)

        } else {
            // Plate tally rows — PlateTallyRow replaces Stepper (03.2-06 must_have)
            ForEach(
                binv.availablePlates.sorted(by: { $0.weight > $1.weight }),
                id: \.weight
            ) { plate in
                PlateTallyRow(
                    weight: plate.weight,
                    count: stepperBinding(for: plate, on: binv),
                    unitLabel: unitLabel
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {                   // UI-SPEC verbatim
                        delete(plate: plate, from: binv)
                    }
                }
            }

            // "+ ADD PLATE" signal text button — UI-SPEC line 271 verbatim
            Button {
                showAddPlateSheet = true
            } label: {
                Text("+ ADD PLATE")                                          // UI-SPEC verbatim
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)

            // "RESET TO DEFAULTS" ghost text footer — UI-SPEC line 278 verbatim
            // bruMuted NOT signal — reset is destructive, not aspirational
            Button {
                showResetConfirm = true
            } label: {
                Text("RESET TO DEFAULTS")                                    // UI-SPEC verbatim
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    // MARK: - Footer bar

    /// 2pt bruInk top rule + full-width primary "Done ▸".
    /// No save button: @Bindable write-through and `try? ctx.save()` in the row
    /// bindings persist every change as it is made (T19 removed "Save inventory").
    private var footerBar: some View {
        VStack(spacing: 0) {
            // 2pt bruInk top rule
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)

            // Primary "Done ▸" — dismisses the view
            BRUButton("Done ▸", kind: .primary) {
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    /// Transforms PlateTallyRow count changes into mutations on the matching PlateSpec.
    /// Reused verbatim from v1 Stepper wire-through (stepperBinding helper).
    private func stepperBinding(
        for plate: PlateSpec,
        on inv: PlateInventory
    ) -> Binding<Int> {
        Binding(
            get: {
                inv.availablePlates
                    .first(where: { $0.weight == plate.weight })?
                    .countPerSide ?? plate.countPerSide
            },
            set: { newCount in
                var updated = inv.availablePlates
                if let idx = updated.firstIndex(where: { $0.weight == plate.weight }) {
                    updated[idx] = PlateSpec(
                        weight: updated[idx].weight,
                        countPerSide: newCount,
                        color: updated[idx].color
                    )
                    inv.availablePlates = updated
                    inv.updatedAt = .now
                    try? ctx.save()
                }
            }
        )
    }

    /// Removes the plate with the given weight from inventory.
    private func delete(plate: PlateSpec, from inv: PlateInventory) {
        var updated = inv.availablePlates
        updated.removeAll(where: { $0.weight == plate.weight })
        inv.availablePlates = updated
        inv.updatedAt = .now
        try? ctx.save()
    }

    // MARK: - Empty inventory (no PlateInventory row for active tab)

    @ViewBuilder
    private var emptyInventoryState: some View {
        VStack(spacing: 12) {
            Text("No plates configured")                                       // UI-SPEC verbatim
                .font(.bru(.grotesk, size: 28))
                .foregroundStyle(Color.bruInk)

            Text("Add plates to use the plate calculator.")                    // UI-SPEC verbatim
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)

            Button {
                showAddPlateSheet = true
            } label: {
                Text("+ ADD PLATE")                                            // UI-SPEC verbatim
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.top, 32)
        .padding(.horizontal, 16)
    }
}

// MARK: - AddPlateSheet

/// Private sheet — BRUHeaderBar + PLATE WEIGHT label + TextField + CANCEL/ADD buttons.
/// Per UI-SPEC lines 272–276 verbatim. No NavigationStack — bare VStack.
private struct AddPlateSheet: View {

    @Bindable var binv: PlateInventory
    let ctx: ModelContext

    @State private var newPlateWeightText: String = ""
    @FocusState private var weightFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(center: "ADD PLATE")                                   // UI-SPEC line 272 verbatim

            VStack(alignment: .leading, spacing: 8) {
                Text("PLATE WEIGHT")                                            // UI-SPEC line 273 verbatim
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)

                TextField("e.g. 25", text: $newPlateWeightText)                // UI-SPEC line 274 verbatim
                    .keyboardType(.decimalPad)
                    .focused($weightFocused)
                    // A weight typed into the field replaces the one it
                    // shows (T39).
                    .selectsAllOnFocus(weightFocused)
                    .font(BRUFont.bodyDefault)
                    .accessibilityLabel("Plate weight")
                    .accessibilityIdentifier("addPlate.weight")

                // Inline validation error per 03-UI-SPEC destructive pattern
                // (bruSignal replaces systemRed per must_have: "Color(.system*) zero")
                if !newPlateWeightText.isEmpty,
                   Double(newPlateWeightText) == nil {
                    Text("Enter a valid number.")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruSignal)                       // bruSignal replaces systemRed (was line 87)
                }

                HStack(spacing: 0) {
                    BRUButton("Cancel", kind: .ghost) {                        // UI-SPEC line 276 verbatim
                        newPlateWeightText = ""
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)

                    BRUButton("Add", kind: .signal) {                          // UI-SPEC line 275 verbatim
                        addPlate()
                    }
                    .disabled(Double(newPlateWeightText) == nil || newPlateWeightText.isEmpty)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
            }
            .padding(16)

            Spacer()
        }
        .background(Color.bruPaper)
        // Number pads have no return key (T39).
        .keyboardDone()
    }

    private func addPlate() {
        guard let w = Double(newPlateWeightText), w > 0 else { return }
        var updated = binv.availablePlates
        updated.append(PlateSpec(weight: w, countPerSide: 2))
        updated.sort(by: { $0.weight > $1.weight })
        binv.availablePlates = updated
        binv.updatedAt = .now
        try? ctx.save()
        newPlateWeightText = ""
        dismiss()
    }
}

// MARK: - EquipmentTabLayout

/// Lays the equipment tabs out in equal cells, `spacing` apart, as many to a
/// row as keep the widest tab's label on one line: all four across, else two
/// by two, else one per row (T107). Each row is as tall as its tallest tab.
private struct EquipmentTabLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let columns = columns(in: proposal.width, subviews: subviews)
        let width = proposal.width ?? CGFloat(columns) * widest(subviews) + CGFloat(columns - 1) * spacing
        let rows = rowHeights(of: subviews, columns: columns, cell: cellWidth(in: width, columns: columns))
        return CGSize(width: width, height: rows.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columns(in: bounds.width, subviews: subviews)
        let cell = cellWidth(in: bounds.width, columns: columns)
        var y = bounds.minY
        for (row, height) in rowHeights(of: subviews, columns: columns, cell: cell).enumerated() {
            for column in 0..<columns where row * columns + column < subviews.count {
                subviews[row * columns + column].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (cell + spacing), y: y),
                    proposal: ProposedViewSize(width: cell, height: height)
                )
            }
            y += height + spacing
        }
    }

    /// The most columns, of all the tabs, two or one, whose equal cells
    /// each fit the widest one-line label.
    private func columns(in width: CGFloat?, subviews: Subviews) -> Int {
        guard let width else { return subviews.count }
        let widest = widest(subviews)
        return [subviews.count, 2].first { columns in
            CGFloat(columns) * widest + CGFloat(columns - 1) * spacing <= width
        } ?? 1
    }

    /// The widest tab's one-line width.
    private func widest(_ subviews: Subviews) -> CGFloat {
        subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
    }

    private func cellWidth(in width: CGFloat, columns: Int) -> CGFloat {
        max(0, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
    }

    private func rowHeights(of subviews: Subviews, columns: Int, cell: CGFloat) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }
                .max() ?? 0
        }
    }
}

// MARK: - PlateEquipmentKind display names (file-private; UI-SPEC verbatim UPPERCASE)

fileprivate extension PlateEquipmentKind {
    /// Tab label per UI-SPEC §PlateInventoryEditor line 265 — UPPERCASE verbatim.
    var displayName: String {
        switch self {
        case .barbell:  return "BARBELL"     // UI-SPEC verbatim
        case .dumbbell: return "DUMBBELLS"   // UI-SPEC verbatim
        case .ezBar:    return "EZ-BAR"      // UI-SPEC verbatim
        case .trapBar:  return "TRAP BAR"    // UI-SPEC verbatim
        }
    }
}

// MARK: - Previews

#Preview("Plate Inventory Editor (seeded)") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    PlateInventorySeeder.seedIfNeeded(in: ctx, unitSystem: .kg)
    return NavigationStack {
        PlateInventoryEditor()
    }
    .modelContainer(container)
}

#Preview("Plate Inventory Editor (empty)") {
    NavigationStack {
        PlateInventoryEditor()
    }
    .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
