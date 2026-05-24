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
import UniformTypeIdentifiers

/// Settings tab body — Phase 1 contract is the lb/kg toggle (SET-01).
/// Phase 3 will add per-equipment plate inventory / smallest-increment
/// / per-exercise unit override / RPE-calibration window editors.
/// Phase 5 will add MEV/MAV/MRV and plateau threshold editors.
public struct SettingsView: View {
    @Query private var settingsList: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    // Wave-4 plan 06-09b — async-render state for the Data section
    // ShareLink rows. Each export's render runs off-main via @ModelActor
    // ExportService; the resulting Sendable Transferable file lands here
    // and switches the row into ShareLink mode.
    @State private var csvFile: CSVFile?
    @State private var jsonFile: JSONFile?
    @State private var csvRendering = false
    @State private var jsonRendering = false
    @State private var csvError: String?
    @State private var jsonError: String?

    // Wave-5 plan 06-10 — async-archive + restore state for the
    // backup rows. Backup follows the same render-then-ShareLink
    // pattern as CSV/JSON; restore introduces .fileImporter + two-step
    // destructive confirmation + post-restore restart alert.
    @State private var backupFile: FitbodBackupFile?
    @State private var backupRendering = false
    @State private var backupError: String?
    @State private var showingImporter = false
    @State private var pendingURL: URL?
    @State private var pendingManifest: BackupManifest?
    @State private var showingDestructiveConfirm = false
    @State private var showingRestoreComplete = false
    @State private var preflightError: BackupRestorer.RestoreError?
    @State private var isRestoring = false
    private let restorer = BackupRestorer()

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                if let settings = settingsList.first {
                    unitsSection(settings: settings)
                    smartProgressionSection(settings: settings)
                    volumeTargetsSection(settings: settings)
                    dataSection
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

    // MARK: - Data section (Wave-4 plan 06-09b — EXP-01 + EXP-02)

    /// Settings → Data section with four rows: CSV export + JSON export
    /// (06-09b) + Create backup + Restore from backup (Wave-5 plan
    /// 06-10). Backup writes a .fitbodbackup ZIP via BackupArchiver and
    /// shares via ShareLink; Restore mounts .fileImporter + two-step
    /// destructive confirmation + post-restore restart.
    ///
    /// All alert copy in this section is UI-SPEC verbatim per 06-UI-SPEC
    /// §Restore confirmation flow.
    @ViewBuilder
    private var dataSection: some View {
        Section {
            csvRow
            jsonRow
            createBackupRow
            restoreBackupRow
        } header: {
            Text("Data")
        } footer: {
            Text("Exports include every set you've logged. Backups can be shared via Files, iCloud Drive, or AirDrop.")
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.fitbodBackup],
            allowsMultipleSelection: false,
            onCompletion: handleFileImporterResult
        )
        .alert(
            "Restore from backup?",
            isPresented: $showingDestructiveConfirm,
            presenting: pendingURL
        ) { url in
            Button("Restore", role: .destructive) {
                Task { await runRestore(from: url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This will replace all current data with the backup. This cannot be undone.")
        }
        .alert(
            "Restore complete",
            isPresented: $showingRestoreComplete
        ) {
            Button("OK") { restorer.restart() }
        } message: {
            Text("Fitbod will restart to load your data.")
        }
        .alert(
            preflightErrorTitle,
            isPresented: Binding(
                get: { preflightError != nil },
                set: { if !$0 { preflightError = nil } }
            )
        ) {
            Button("OK") { preflightError = nil }
        } message: {
            Text(preflightErrorMessage)
        }
    }

    @ViewBuilder
    private var csvRow: some View {
        if let file = csvFile {
            ShareLink(item: file, preview: SharePreview(file.filename)) {
                Text("Share CSV")
            }
        } else {
            Button {
                Task { await renderCSV() }
            } label: {
                HStack {
                    Text("Export as CSV")
                    Spacer()
                    if csvRendering {
                        ProgressView()
                    }
                }
            }
            .disabled(csvRendering)
        }
        if let err = csvError {
            Text(err)
                .font(.caption)
                .foregroundStyle(Color(.systemRed))
        }
    }

    @ViewBuilder
    private var jsonRow: some View {
        if let file = jsonFile {
            ShareLink(item: file, preview: SharePreview(file.filename)) {
                Text("Share JSON")
            }
        } else {
            Button {
                Task { await renderJSON() }
            } label: {
                HStack {
                    Text("Export as JSON")
                    Spacer()
                    if jsonRendering {
                        ProgressView()
                    }
                }
            }
            .disabled(jsonRendering)
        }
        if let err = jsonError {
            Text(err)
                .font(.caption)
                .foregroundStyle(Color(.systemRed))
        }
    }

    // MARK: - Backup rows (Wave-5 plan 06-10)

    /// Row 3 — "Create backup". Async-renders a .fitbodbackup ZIP
    /// via BackupArchiver; once non-nil swaps to a ShareLink that
    /// the user can route to Files / iCloud Drive / AirDrop.
    @ViewBuilder
    private var createBackupRow: some View {
        if let file = backupFile {
            ShareLink(item: file, preview: SharePreview(file.filename)) {
                Text("Share backup")
            }
        } else {
            Button {
                Task { await renderBackup() }
            } label: {
                HStack {
                    Text("Create backup")
                    Spacer()
                    if backupRendering {
                        ProgressView()
                    }
                }
            }
            .disabled(backupRendering)
        }
        if let err = backupError {
            Text(err)
                .font(.caption)
                .foregroundStyle(Color(.systemRed))
        }
    }

    /// Row 4 — "Restore from backup" (destructive). Mounts
    /// .fileImporter for [.fitbodBackup]; on selection runs preflight,
    /// then presents the destructive-confirmation alert via
    /// $showingDestructiveConfirm; on confirm runs performRestore
    /// then the "Restore complete" alert; OK calls restart().
    @ViewBuilder
    private var restoreBackupRow: some View {
        Button(role: .destructive) {
            showingImporter = true
        } label: {
            HStack {
                Text("Restore from backup")
                    .foregroundStyle(Color(.systemRed))
                Spacer()
                if isRestoring {
                    ProgressView()
                }
            }
        }
        .disabled(isRestoring)
    }

    @MainActor
    private func renderBackup() async {
        backupRendering = true
        backupError = nil
        let archiver = BackupArchiver(modelContainer: modelContext.container)
        do {
            let file = try await archiver.archive()
            backupFile = file
        } catch {
            backupError = "Couldn't create backup. Try again."
        }
        backupRendering = false
    }

    /// Handler for the .fileImporter completion callback. Routes to
    /// preflight on success; reports .fileUnreadable on .failure.
    nonisolated private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { @MainActor in
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                do {
                    let m = try await restorer.preflight(url: url, context: modelContext)
                    pendingURL = url
                    pendingManifest = m
                    showingDestructiveConfirm = true
                } catch let e as BackupRestorer.RestoreError {
                    preflightError = e
                } catch {
                    preflightError = .fileUnreadable
                }
            }
        case .failure:
            Task { @MainActor in
                preflightError = .fileUnreadable
            }
        }
    }

    @MainActor
    private func runRestore(from url: URL) async {
        guard let manifest = pendingManifest else {
            preflightError = .fileUnreadable
            return
        }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await restorer.performRestore(
                url: url,
                manifest: manifest,
                currentContainer: modelContext.container
            )
            showingRestoreComplete = true
        } catch let e as BackupRestorer.RestoreError {
            preflightError = e
        } catch {
            preflightError = .fileUnreadable
        }
    }

    // MARK: - Preflight error copy (UI-SPEC verbatim)
    //
    // Switch on the cached RestoreError case to produce the title +
    // body for the alert. Strings are 1:1 with 06-UI-SPEC §Restore
    // confirmation flow.

    private var preflightErrorTitle: String {
        switch preflightError {
        case .fileUnreadable, .missingManifest, .missingStoreJSON, .zipParseFailed, .decodeFailed, .none:
            return "Couldn't read backup"
        case .checksumMismatch:
            return "Backup is damaged"
        case .schemaVersionMismatch:
            return "Backup version not supported"
        case .activeSessionInProgress:
            return "Finish your session first"
        case .pathTraversalDetected:
            return "Backup contains unsafe entries"
        case .decompressionBombExceeded:
            return "Backup too large"
        }
    }

    private var preflightErrorMessage: String {
        switch preflightError {
        case .fileUnreadable, .missingManifest, .missingStoreJSON, .zipParseFailed, .decodeFailed, .none:
            return "Make sure the file is a `.fitbodbackup` file from Fitbod."
        case .checksumMismatch:
            return "This backup file's contents don't match its checksum. Try a different backup."
        case .schemaVersionMismatch:
            return "This backup is from a different version of Fitbod. Restore not supported."
        case .activeSessionInProgress:
            return "Restore replaces your data. Complete or discard your active session before restoring."
        case .pathTraversalDetected:
            return "This backup includes file paths that can't be safely restored."
        case .decompressionBombExceeded:
            return "This backup exceeds the safe restore limit."
        }
    }

    // MARK: - CSV/JSON renderers (06-09b)

    @MainActor
    private func renderCSV() async {
        csvRendering = true
        csvError = nil
        let service = ExportService(modelContainer: modelContext.container)
        do {
            let file = try await service.renderCSV()
            csvFile = file
        } catch {
            csvError = "Couldn't prepare export. Try again."
        }
        csvRendering = false
    }

    @MainActor
    private func renderJSON() async {
        jsonRendering = true
        jsonError = nil
        let service = ExportService(modelContainer: modelContext.container)
        do {
            let file = try await service.renderJSON()
            jsonFile = file
        } catch {
            jsonError = "Couldn't prepare export. Try again."
        }
        jsonRendering = false
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

    // MARK: - Smart Progression section (Phase 3 — SET-03, SET-04, SET-07)
    // Reskinned in plan 03.2-08 — BRUSectionHead header + BRUFont labels/footers.
    // Color(.systemRed) lines in the Data section (lines 196/223/255/271) are
    // Phase 6 scope (Wave-4 plan 06-09b) and are NOT touched here per
    // threat model T-03.2-15.

    /// Builds the "SMART PROGRESSION" section with a NavigationLink to
    /// `PlateInventoryEditor`, a default-weight-increment Stepper, and an
    /// RPE-calibration-window Stepper. All copy is verbatim from UI-SPEC
    /// § Settings — Smart Progression (line 292). BRU tokens throughout.
    @ViewBuilder
    private func smartProgressionSection(settings: UserSettings) -> some View {
        @Bindable var s = settings
        let unitLabel = s.weightUnit == .kg ? "kg" : "lb"

        Section {
            // Navigation row — disclosure chevron is automatic with NavigationLink.
            // BRUFont.bodyDefault + Color.bruInk per 03.2-08 reskin contract.
            NavigationLink {
                PlateInventoryEditor()
            } label: {
                Text("Plate Inventory")                                         // UI-SPEC verbatim
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
            }

            // Default weight increment Stepper.
            // Label: BRUFont.labelSmall UPPERCASE 1.2 tracking bruMuted per UI-SPEC line 294.
            // Value: BRUFont.bodyDefault bruMuted per UI-SPEC line 295.
            Stepper(value: $s.defaultIncrementKg, in: 0.25...10.0, step: 0.25) {
                HStack {
                    Text("DEFAULT WEIGHT INCREMENT")                            // UI-SPEC verbatim
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                    Spacer()
                    Text("\(s.defaultIncrementKg, specifier: "%g") \(unitLabel)")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                }
            }

            // RPE calibration window Stepper.
            // Label: BRUFont.labelSmall UPPERCASE 1.2 tracking bruMuted per UI-SPEC line 297.
            // Value: BRUFont.bodyDefault bruMuted per UI-SPEC line 299.
            Stepper(value: $s.minCalibrationSets, in: 5...30, step: 1) {
                HStack {
                    Text("SETS BEFORE CALIBRATING")                             // UI-SPEC verbatim
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                    Spacer()
                    Text("\(s.minCalibrationSets) sets")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                }
            }
        } header: {
            BRUSectionHead("SMART PROGRESSION")                                // UI-SPEC line 292
        } footer: {
            // UI-SPEC verbatim footers (lines 296 + 300) — stacked in VStack since
            // SwiftUI Section only takes a single footer view.
            // BRUFont.bodyDefault + Color.bruMuted replacing .font(.caption)/.secondary.
            VStack(alignment: .leading, spacing: 4) {
                Text("Used when an exercise has no specific increment set. Applied by all progression strategies when rounding.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                Text("RPE autoregulation uses the Tuchscherer table until this many working sets are logged per exercise.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
        }
    }

    // MARK: - Volume Targets section (Phase 5 SET-05 + D-03)

    /// Adds the Settings entry point to `MuscleVolumeTargetEditor`
    /// per CONTEXT Claude's Discretion ("Settings is the primary
    /// entry point") + the global frequency-hit-threshold Stepper
    /// per D-03 + VOL-06. The threshold is the minimum stimulus-
    /// weighted set contribution for a session to count as a
    /// frequency hit for a muscle (default 2 sets).
    @ViewBuilder
    private func volumeTargetsSection(settings: UserSettings) -> some View {
        @Bindable var s = settings

        Section {
            NavigationLink {
                MuscleVolumeTargetEditor()
            } label: {
                HStack {
                    Text("Volume Targets")
                    Spacer()
                    Text("17 muscles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $s.frequencyHitMinSets, in: 1...5, step: 1) {
                LabeledContent("Frequency hit threshold") {
                    Text("\(s.frequencyHitMinSets) sets")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Frequency hit threshold")
            .accessibilityValue("\(s.frequencyHitMinSets) sets")
        } header: {
            Text("Volume Targets")
        } footer: {
            Text("Frequency hit threshold: a session counts as a 'hit' for a muscle when the stimulus-weighted set contribution is at least this many sets.")
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
