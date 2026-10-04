//
//  SettingsView.swift
//  fitbod
//
//  Settings tab (Chalkline styling). Units (SET-01), smart-progression
//  defaults and plate inventory (plan 03-04), and — for the design system
//  — the in-app Component Gallery.
//
//  Writes are direct `@Bindable` mutations of the `UserSettings`
//  singleton; SwiftData persists them.
//

import SwiftUI
import SwiftData

public struct SettingsView: View {
    @Query private var settingsList: [UserSettings]

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if let settings = settingsList.first {
                    unitsSection(settings: settings)
                    smartProgressionSection(settings: settings)
                } else {
                    Section {
                        Text("Settings unavailable — library seed not yet complete.")
                            .font(.chalkCallout)
                            .foregroundStyle(.chalkInk2)
                    }
                }
                Section {
                    NavigationLink {
                        ComponentGalleryView()
                    } label: {
                        Label("Component gallery", systemImage: "square.grid.2x2")
                            .font(.chalkBody)
                            .foregroundStyle(.chalkInk)
                    }
                    .accessibilityIdentifier("settings.gallery")
                } header: {
                    Text("Design system").chalkLabelStyle()
                } footer: {
                    Text("Chalkline tokens and components as implemented in SwiftUI.")
                        .font(.chalkFootnote)
                        .foregroundStyle(.chalkInk2)
                }
                .listRowBackground(Color.chalkSurface)
            }
            .listStyle(.insetGrouped)
            .chalkCanvasBackground()
            .navigationTitle("SETTINGS")
        }
    }

    @ViewBuilder
    private func unitsSection(settings: UserSettings) -> some View {
        @Bindable var s = settings
        Section {
            Picker("Weight unit", selection: $s.weightUnit) {
                Text("lb").tag(WeightUnit.lb)
                Text("kg").tag(WeightUnit.kg)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.unit")
            Toggle("Weeks start on Monday", isOn: $s.weekStartsMonday)
                .font(.chalkBody)
                .tint(Color.chalkInk)
        } header: {
            Text("Units").chalkLabelStyle()
        } footer: {
            Text("Weights are logged as entered; the unit labels inputs, totals and history.")
                .font(.chalkFootnote)
                .foregroundStyle(.chalkInk2)
        }
        .listRowBackground(Color.chalkSurface)
    }

    @ViewBuilder
    private func smartProgressionSection(settings: UserSettings) -> some View {
        @Bindable var s = settings
        let unitLabel = s.weightUnit.rawValue
        Section {
            NavigationLink {
                PlateInventoryEditor()
            } label: {
                Text("Plate inventory").font(.chalkBody)
            }
            Stepper(value: $s.defaultIncrementKg, in: 0.25...10.0, step: 0.25) {
                LabeledContent("Default weight increment") {
                    Text("\(ChalkFormat.weight(s.defaultIncrementKg)) \(unitLabel)")
                        .font(.chalkMetric)
                        .foregroundStyle(.chalkInk)
                }
                .font(.chalkBody)
            }
            Stepper(value: $s.minCalibrationSets, in: 5...30, step: 1) {
                LabeledContent("Sets before calibrating") {
                    Text("\(s.minCalibrationSets)")
                        .font(.chalkMetric)
                        .foregroundStyle(.chalkInk)
                }
                .font(.chalkBody)
            }
        } header: {
            Text("Smart progression").chalkLabelStyle()
        } footer: {
            Text("The increment is used when an exercise has none of its own. RPE autoregulation uses the Tuchscherer table until this many working sets are logged per exercise.")
                .font(.chalkFootnote)
                .foregroundStyle(.chalkInk2)
        }
        .listRowBackground(Color.chalkSurface)
    }
}

#Preview("Settings (seeded)") {
    SettingsView()
        .modelContainer(PreviewModelContainer.make())
}
