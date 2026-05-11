//
//  SettingsView.swift
//  fitbod
//
//  Wave-4 plan 04-01 — the Settings tab body. Replaces the interim
//  `SettingsTabHost` placeholder from plan 03-01 ("Settings — coming in
//  04-01"). Closes SET-01 (global lb/kg toggle) and verifies FOUND-06
//  (`@Bindable` write-through to a `@Model` row — no parallel
//  ViewModel layer).
//
//  ## Structure (UI-SPEC § Settings screen)
//
//    - Navigation title: "Settings"
//    - Section "Units":
//        Toggle "Weight Unit" — right-aligned trailing "lb" / "kg"
//        Footer help: "Affects display only. Logged session history is
//        stored in a single canonical unit and re-rendered on the fly."
//    - Section "About": placeholder header, no rows in Phase 1
//      (UI-SPEC permits the placeholder; About rows deferred to a
//      later polish pass).
//
//  ## Binding shape (FOUND-06 / SET-01 anchor)
//
//  The `Toggle` is bound to a `Binding<Bool>` projection of the
//  `UserSettings.weightUnit` computed property — `get { weightUnit ==
//  .kg }` / `set { weightUnit = newValue ? .kg : .lb }`. The setter
//  writes to `unitsRaw: String` under the hood (see
//  `UserSettings+WeightUnit` extension). SwiftData persists the
//  `unitsRaw` change on the next implicit save; the value survives
//  app relaunch because the singleton `UserSettings` row was seeded by
//  `ExerciseLibraryImporter` (plan 02-02) and lives in the on-disk
//  SQLite store.
//
//  `@Bindable var s = settings` is the iOS 17+ Observation pattern —
//  produces a `Bindable<UserSettings>` projection so mutations to
//  `s.weightUnit` go through the `@Model`'s observation tracking.
//
//  ## Empty / not-yet-seeded state
//
//  On the very first launch BEFORE the seed has run, the
//  `@Query<UserSettings>` returns zero rows. The Settings view shows
//  a single secondary-label message: "Settings unavailable — library
//  seed not yet complete." In practice this state lasts <2s (FOUND-05
//  cold-launch target) and `RootView` blocks tab presentation with
//  the "Preparing library…" splash anyway — but defensive UI here
//  prevents a crash if the user somehow reaches the Settings tab
//  before the seed completes.
//

import SwiftUI
import SwiftData

/// Settings tab body — Phase 1 contract is the lb/kg toggle (SET-01).
/// Phase 3 will add per-equipment plate inventory / smallest-increment
/// / per-exercise unit override / RPE-calibration window editors.
/// Phase 5 will add MEV/MAV/MRV and plateau threshold editors.
public struct SettingsView: View {
    @Query private var settingsList: [UserSettings]

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                if let settings = settingsList.first {
                    unitsSection(settings: settings)
                    aboutSectionPlaceholder
                } else {
                    Section {
                        Text("Settings unavailable — library seed not yet complete.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Units section (SET-01 anchor)

    /// Builds the "Units" section bound to the singleton `UserSettings`
    /// row. `@Bindable` projects the `@Model` for two-way Toggle binding.
    @ViewBuilder
    private func unitsSection(settings: UserSettings) -> some View {
        @Bindable var s = settings
        Section {
            Toggle(isOn: Binding(
                get: { s.weightUnit == .kg },
                set: { newValue in s.weightUnit = newValue ? .kg : .lb }
            )) {
                HStack {
                    Text("Weight Unit")
                    Spacer()
                    Text(s.weightUnit == .kg ? "kg" : "lb")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Units")
        } footer: {
            Text("Affects display only. Logged session history is stored in a single canonical unit and re-rendered on the fly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - About section placeholder

    /// "About" header is allowed in Phase 1 per UI-SPEC, but no rows
    /// yet — version display + dataset attribution are deferred to a
    /// later polish pass. The placeholder header sets up the visual
    /// structure so future rows land in a familiar place.
    @ViewBuilder
    private var aboutSectionPlaceholder: some View {
        Section {
            EmptyView()
        } header: {
            Text("About")
        }
    }
}

// MARK: - Previews

#Preview("Settings (seeded)") {
    SettingsView()
        .modelContainer(PreviewModelContainer.make())
}

#Preview("Settings (no UserSettings row)") {
    SettingsView()
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
