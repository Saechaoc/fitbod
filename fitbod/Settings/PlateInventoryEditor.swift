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
                center: "Plate Inventory",
                right: HeaderAction("•••") { showCalculatorSheet = true }
            )

            // Custom bruInk-styled tab strip (replaces Picker(.segmented))
            equipmentTabStrip

            // Content scroll area
            ScrollView {
                if let inv = activeInventory {
                    @Bindable var binv = inv
                    activeTabContent(binv: binv)
                } else {
                    emptyInventoryState
                }
            }

            // Footer — 2pt bruInk top rule + ghost "Save inventory" + primary "Done ▸"
            footerBar

            // 24pt bruBg safe-area filler
            Rectangle()
                .fill(Color.bruBg)
                .frame(height: 24)
        }
        .background(Color.bruPaper)
        // No .navigationTitle — BRUHeaderBar owns that chrome
        .navigationBarHidden(true)
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
    /// 1pt bruInk vertical separators between segments.
    /// 2pt bruInk bottom rule beneath the strip.
    private var equipmentTabStrip: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(PlateEquipmentKind.allCases, id: \.self) { kind in
                    tabButton(for: kind)

                    // 1pt vertical separator between buttons (not after last)
                    if kind != PlateEquipmentKind.allCases.last {
                        Rectangle()
                            .fill(Color.bruInk)
                            .frame(width: 1)
                    }
                }
            }
            .background(Color.bruPaper)
            // Outer 1.5pt bruInk border around the full strip (per UI-SPEC line 441)
            .overlay {
                Rectangle()
                    .stroke(Color.bruInk, lineWidth: 1.5)
            }
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
                .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
                .frame(maxWidth: .infinity)
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
        VStack(spacing: 0) {
            // Bar weight section
            barWeightSection(binv: binv)

            // Plates per side section
            platesSection(binv: binv)
        }
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
                .font(BRUFont.bodyDefault)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)

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
                    .font(.custom("SpaceGrotesk-Bold", size: 28))
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
            LazyVStack(spacing: 0) {
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
                        Button("Delete", role: .destructive) {               // UI-SPEC verbatim
                            delete(plate: plate, from: binv)
                        }
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

    /// 2pt bruInk top rule + ghost "Save inventory" (half-width) + primary "Done ▸" (half-width)
    /// T-03.2-12 note: @Bindable write-through already persists all changes; the ghost Save
    /// button is a visual continuity gesture matching plate-calc.jsx mockup, not a state mutation.
    private var footerBar: some View {
        VStack(spacing: 0) {
            // 2pt bruInk top rule
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)

            HStack(spacing: 0) {
                // Ghost "Save inventory" — visual gesture per plate-calc.jsx line 133
                BRUButton("Save inventory", kind: .ghost) {
                    // No-op: @Bindable + try? ctx.save() in stepperBinding already write-through.
                    // This button provides visual continuity with the mockup (T-03.2-12 accepted).
                }
                .frame(maxWidth: .infinity)

                // Primary "Done ▸" — dismisses the view
                BRUButton("Done ▸", kind: .primary) {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
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
                .font(.custom("SpaceGrotesk-Bold", size: 28))
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
                    .font(BRUFont.bodyDefault)

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
