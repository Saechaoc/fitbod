//
//  PlateInventoryEditor.swift
//  fitbod
//
//  Settings → Smart Progression → Plate Inventory.
//  Tabbed Form editor for all four PlateEquipmentKind rows in the store.
//  Pushed onto the Settings NavigationStack — owns no NavigationStack itself.
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

    // MARK: - State

    @State private var activeTab: PlateEquipmentKind = .barbell
    @State private var showResetConfirm: Bool = false
    @State private var showAddPlateSheet: Bool = false
    @State private var showCalculatorSheet: Bool = false
    @State private var newPlateWeightText: String = ""

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
            // Segmented picker — top of the pushed view, above the Form.
            // Explicit .tag() on each case so the Picker's selection binding
            // resolves correctly for each PlateEquipmentKind.
            Picker("Equipment", selection: $activeTab) {
                Text(PlateEquipmentKind.barbell.displayName).tag(PlateEquipmentKind.barbell)
                Text(PlateEquipmentKind.dumbbell.displayName).tag(PlateEquipmentKind.dumbbell)
                Text(PlateEquipmentKind.ezBar.displayName).tag(PlateEquipmentKind.ezBar)
                Text(PlateEquipmentKind.trapBar.displayName).tag(PlateEquipmentKind.trapBar)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if let inv = activeInventory {
                @Bindable var binv = inv
                inventoryForm(binv: binv)
            } else {
                emptyInventoryState
            }
        }
        .navigationTitle("Plate Inventory")                                     // UI-SPEC verbatim
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Calculator") { showCalculatorSheet = true }
            }
        }
        .sheet(isPresented: $showCalculatorSheet) {
            if let inv = activeInventory {
                PlateCalculatorSheet(equipment: activeTab, inventory: inv)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showAddPlateSheet) {
            if let inv = activeInventory {
                @Bindable var binv = inv
                addPlateSheet(binv: binv)
            }
        }
        .alert("Reset plate inventory?", isPresented: $showResetConfirm) {   // UI-SPEC verbatim
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
            // UI-SPEC verbatim: "Replaces with the default {unit system} plate set for {equipment kind}."
            Text("Replaces with the default \(unitLabel) plate set for \(activeTab.displayName).")
        }
    }

    // MARK: - Inventory Form

    @ViewBuilder
    private func inventoryForm(binv: PlateInventory) -> some View {
        let plates = binv.availablePlates

        Form {
            // Section 1: Bar weight
            barWeightSection(binv: binv)

            // Section 2: Plates per side
            platesSection(binv: binv, plates: plates)

            // Section 3: Reset to Defaults
            resetSection
        }
    }

    // MARK: - Bar weight section

    @ViewBuilder
    private func barWeightSection(binv: PlateInventory) -> some View {
        @Bindable var b = binv
        Section {
            HStack {
                TextField("Bar weight", value: $b.barWeight, format: .number)   // UI-SPEC verbatim label
                    .keyboardType(.decimalPad)
                Text(unitLabel)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Bar weight")                                                  // UI-SPEC verbatim header
        }
    }

    // MARK: - Plates per side section

    @ViewBuilder
    private func platesSection(binv: PlateInventory, plates: [PlateSpec]) -> some View {
        Section {
            if plates.isEmpty {
                // Empty state — UI-SPEC verbatim
                ContentUnavailableView {
                    Label("No plates configured", systemImage: "scalemass")    // UI-SPEC verbatim heading
                } description: {
                    Text("Add plates to use the plate calculator.")             // UI-SPEC verbatim body
                } actions: {
                    Button("Add Plate") { showAddPlateSheet = true }           // UI-SPEC verbatim action
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                ForEach(plates.sorted(by: { $0.weight > $1.weight }), id: \.weight) { plate in
                    plateRow(plate: plate, binv: binv)
                }
                Button("Add Plate") { showAddPlateSheet = true }               // UI-SPEC verbatim
            }
        } header: {
            Text("Plates per side")                                             // UI-SPEC verbatim header
        }
    }

    @ViewBuilder
    private func plateRow(plate: PlateSpec, binv: PlateInventory) -> some View {
        HStack {
            // UI-SPEC plate row format: "{weight} kg" leading
            Text("\(plate.weight, specifier: "%g") \(unitLabel)")
            Spacer()
            Stepper(
                "× \(plate.countPerSide)",
                value: stepperBinding(for: plate, on: binv),
                in: 0...10
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) {                             // UI-SPEC verbatim
                delete(plate: plate, from: binv)
            }
        }
    }

    // MARK: - Reset section

    @ViewBuilder
    private var resetSection: some View {
        Section {
            Button("Reset to Defaults") {                                       // UI-SPEC verbatim
                showResetConfirm = true
            }
            .foregroundStyle(Color.accentColor)                                 // UI-SPEC accent item 21
        }
    }

    // MARK: - Add plate sheet

    @ViewBuilder
    private func addPlateSheet(binv: PlateInventory) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 25", text: $newPlateWeightText)             // UI-SPEC verbatim placeholder
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Plate weight")                                         // UI-SPEC verbatim
                }
            }
            .navigationTitle("Add Plate")                                       // UI-SPEC verbatim
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        newPlateWeightText = ""
                        showAddPlateSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {                                             // UI-SPEC verbatim
                        if let w = Double(newPlateWeightText), w > 0 {
                            var updated = binv.availablePlates
                            updated.append(PlateSpec(weight: w, countPerSide: 2))
                            updated.sort(by: { $0.weight > $1.weight })
                            binv.availablePlates = updated
                            binv.updatedAt = .now
                            try? ctx.save()
                            newPlateWeightText = ""
                            showAddPlateSheet = false
                        }
                    }
                    .disabled(Double(newPlateWeightText) == nil || newPlateWeightText.isEmpty)
                }
            }
        }
    }

    // MARK: - Empty inventory (no PlateInventory row for the active tab)

    @ViewBuilder
    private var emptyInventoryState: some View {
        ContentUnavailableView {
            Label("No plates configured", systemImage: "scalemass")            // UI-SPEC verbatim
        } description: {
            Text("Add plates to use the plate calculator.")                     // UI-SPEC verbatim
        } actions: {
            Button("Add Plate") { showAddPlateSheet = true }                   // UI-SPEC verbatim
                .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Helpers

    /// Transforms Stepper value changes into mutations on the matching PlateSpec.
    private func stepperBinding(
        for plate: PlateSpec,
        on inv: PlateInventory
    ) -> Binding<Int> {
        Binding(
            get: {
                inv.availablePlates.first(where: { $0.weight == plate.weight })?.countPerSide ?? plate.countPerSide
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
}

// MARK: - PlateEquipmentKind display names (file-private; UI-SPEC verbatim)

fileprivate extension PlateEquipmentKind {
    /// Tab label per UI-SPEC § PlateInventoryEditor.
    var displayName: String {
        switch self {
        case .barbell:  return "Barbell"     // UI-SPEC verbatim
        case .dumbbell: return "Dumbbells"   // UI-SPEC verbatim
        case .ezBar:    return "EZ-Bar"      // UI-SPEC verbatim
        case .trapBar:  return "Trap Bar"    // UI-SPEC verbatim
        }
    }
}

// MARK: - Previews

#Preview("Plate Inventory Editor (seeded)") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    // Pre-seed inventory for the preview.
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
