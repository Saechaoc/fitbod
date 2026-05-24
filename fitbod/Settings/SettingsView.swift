//
//  SettingsView.swift
//  fitbod
//
//  Phase 06.1 plan 05 — BRU full reskin of SettingsView.
//
//  Prior structure (Form/Section/NavigationTitle) replaced with:
//    NavigationStack → VStack(spacing: 0) → BRUHeaderBar(center: "Settings")
//      → ScrollView → LazyVStack(spacing: 0)
//
//  Sections:
//    Profile band (bruInk-bordered avatar + name/subtitle)
//    Units & Calibration — BRUSectionHead + BRURow rows
//    Volume Targets — BRUSectionHead + BRURow rows
//    Smart Progression — BRUSectionHead + BRURow rows (PRESERVED verbatim from 03.2-08)
//    Export — BRUSectionHead(right:) + 2-card grid (CSV / JSON)
//    Backup — BRUSectionHead + 2pt bruInk-outlined panel with CREATE/RESTORE footer
//    About — BRUSectionHead + BRURow rows (Version / Source / Reset)
//
//  Wired actions preserved:
//    ShareLink(item: csvFile) / ShareLink(item: jsonFile)
//    ShareLink(item: backupFile)
//    .fileImporter + 2-step destructive confirm + preflight alerts
//
//  Banned tokens eliminated: Form, List, .insetGrouped, .navigationTitle,
//  .toolbar, Color.accentColor, Color(.systemRed), Color(.systemGroupedBackground),
//  Color(.secondaryLabel), .font(.body|.headline|.title*|.caption),
//  RoundedRectangle, Capsule, .buttonStyle(.bordered)
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - SettingsView

/// Settings tab — BRU-reskinned root. All functional wires preserved from
/// prior wave plans (06-09b CSV/JSON, 06-10 Backup/Restore, 03.2-08 Smart Progression).
public struct SettingsView: View {
    @Query private var settingsList: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    // Wave-4 plan 06-09b — async-render state for Export section
    @State private var csvFile: CSVFile?
    @State private var jsonFile: JSONFile?
    @State private var csvRendering = false
    @State private var jsonRendering = false
    @State private var csvError: String?
    @State private var jsonError: String?

    // Wave-5 plan 06-10 — backup + restore state
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

    // Sheet state for Picker overlays
    @State private var showingUnitPicker = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BRUHeaderBar(center: "Settings")

                if let settings = settingsList.first {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            profileBand
                            BRUDivider(.ink)
                            unitsCalibrSection(settings: settings)
                            volumeTargetsSection(settings: settings)
                            smartProgressionSection(settings: settings)
                            exportSection
                            backupSection
                            aboutSection(settings: settings)
                        }
                    }
                } else {
                    Spacer()
                    Text("Settings unavailable — library seed not yet complete.")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .padding(32)
                    Spacer()
                }
            }
            .background(Color.bruPaper.ignoresSafeArea())
        }
        // Modifiers scoped to the NavigationStack for file-importer + alerts
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

    // MARK: - Profile band

    /// bruInk-bordered avatar band at the top of the scroll surface.
    /// Avatar initial "F", Display name "Fitbod", subtitle "1.0.0 · SCHEMA V6"
    @ViewBuilder
    private var profileBand: some View {
        HStack(spacing: 14) {
            // Square avatar — bruInk fill, paper "F" hero initial
            Rectangle()
                .fill(Color.bruInk)
                .frame(width: 56, height: 56)
                .overlay(
                    Text("F")
                        .font(BRUFont.displayHero)
                        .foregroundStyle(Color.bruPaper)
                )

            VStack(alignment: .leading, spacing: 2) {
                BRUDisplay("Fitbod", size: .medium)
                Text("1.0.0 · SCHEMA V6")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.bruPaper)
    }

    // MARK: - Units & Calibration section

    @ViewBuilder
    private func unitsCalibrSection(settings: UserSettings) -> some View {
        @Bindable var s = settings
        let unitLabel = s.weightUnit == .kg ? "KG" : "LB"

        BRUSectionHead("Units & Calibration")

        // Weight unit — BRURow wrapping a Toggle trailing
        BRURow(
            label: "Weight Unit",
            value: unitLabel,
            trailing: AnyView(
                Toggle("", isOn: Binding(
                    get: { s.weightUnit == .kg },
                    set: { newValue in s.weightUnit = newValue ? .kg : .lb }
                ))
                .labelsHidden()
                .tint(Color.bruInk)
            )
        )
        BRUDivider(.hair)

        // Plate Inventory — NavigationLink
        NavigationLink {
            PlateInventoryEditor()
        } label: {
            BRURowLabel(label: "Plate Inventory", value: nil)
        }
        .buttonStyle(.plain)
        BRUDivider(.ink)

        // Footer note
        Text("Affects display only. Logged history is stored in a canonical unit and re-rendered on the fly.")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    // MARK: - Volume Targets section

    @ViewBuilder
    private func volumeTargetsSection(settings: UserSettings) -> some View {
        @Bindable var s = settings

        BRUSectionHead("Volume Targets")

        // Volume Targets editor
        NavigationLink {
            MuscleVolumeTargetEditor()
        } label: {
            BRURowLabel(label: "Volume Targets", value: "17 MUSCLES")
        }
        .buttonStyle(.plain)
        BRUDivider(.hair)

        // Frequency hit threshold stepper
        BRURow(
            label: "Frequency Hit Threshold",
            value: "\(s.frequencyHitMinSets) SETS",
            trailing: AnyView(
                Stepper("", value: $s.frequencyHitMinSets, in: 1...5, step: 1)
                    .labelsHidden()
            )
        )
        .accessibilityLabel("Frequency hit threshold")
        .accessibilityValue("\(s.frequencyHitMinSets) sets")
        BRUDivider(.ink)

        Text("Frequency hit threshold: a session counts as a 'hit' for a muscle when the stimulus-weighted set contribution is at least this many sets.")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    // MARK: - Smart Progression section (Phase 3 — SET-03, SET-04, SET-07)
    // Reskinned in plan 03.2-08 — BRUSectionHead header + BRUFont labels/footers.
    // PRESERVED VERBATIM per 06.1-05 plan requirement.

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

    // MARK: - Export section (BRU 2-card grid)

    /// Export section with BRUSectionHead + 2-card horizontal grid.
    /// Each card: 2pt bruInk outline, BRUDisplay kind label, bodyEmphasis label, labelMicro sub.
    /// Cards are wrapped in ShareLink containers that present the system share sheet on tap.
    @ViewBuilder
    private var exportSection: some View {
        BRUSectionHead("Export", right: "DATA")

        HStack(spacing: 8) {
            // CSV card
            if let file = csvFile {
                ShareLink(item: file, preview: SharePreview(file.filename)) {
                    ExportCard(
                        kind: "CSV",
                        label: "Export CSV",
                        sub: "ONE ROW PER SET",
                        isLoading: false
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await renderCSV() }
                } label: {
                    ExportCard(
                        kind: "CSV",
                        label: "Export CSV",
                        sub: "ONE ROW PER SET",
                        isLoading: csvRendering
                    )
                }
                .buttonStyle(.plain)
                .disabled(csvRendering)
            }

            // JSON card
            if let file = jsonFile {
                ShareLink(item: file, preview: SharePreview(file.filename)) {
                    ExportCard(
                        kind: "JSON",
                        label: "Export JSON",
                        sub: "VERSION-STAMPED",
                        isLoading: false
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await renderJSON() }
                } label: {
                    ExportCard(
                        kind: "JSON",
                        label: "Export JSON",
                        sub: "VERSION-STAMPED",
                        isLoading: jsonRendering
                    )
                }
                .buttonStyle(.plain)
                .disabled(jsonRendering)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)

        // Inline error messages
        if let err = csvError {
            Text(err)
                .font(BRUFont.labelMicro)
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruSignal)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        if let err = jsonError {
            Text(err)
                .font(BRUFont.labelMicro)
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruSignal)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }

        BRUDivider(.ink)
    }

    // MARK: - Backup section (2pt bruInk-outlined panel)

    /// Backup section: BRUSectionHead + 2pt bruInk-outlined panel.
    /// Panel top: FULL BACKUP header + last-backup display + entity count.
    /// Panel footer: CREATE (ghost ShareLink) | RESTORE (signal) split by 1pt bruInk divider.
    @ViewBuilder
    private var backupSection: some View {
        BRUSectionHead("Backup")

        VStack(spacing: 0) {
            // Top region — backup metadata
            VStack(alignment: .leading, spacing: 4) {
                Text("FULL BACKUP")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                BRUDisplay(lastBackupDescription, size: .medium)
                Text(entityCountLine)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            BRUDivider(.ink)

            // Footer — CREATE (ghost) | RESTORE (signal) split by 1pt line
            HStack(spacing: 0) {
                // CREATE button — wraps ShareLink if backupFile is ready, else renders button
                if let file = backupFile {
                    ShareLink(item: file, preview: SharePreview(file.filename)) {
                        Text("CREATE")
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await renderBackup() }
                    } label: {
                        Group {
                            if backupRendering {
                                ProgressView()
                                    .tint(Color.bruInk)
                            } else {
                                Text("CREATE")
                                    .font(BRUFont.labelSmall)
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.bruInk)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(backupRendering)
                }

                // 1pt vertical separator
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 1)

                // RESTORE button — signal fill
                Button {
                    showingImporter = true
                } label: {
                    Group {
                        if isRestoring {
                            ProgressView()
                                .tint(Color.bruPaper)
                        } else {
                            Text("RESTORE")
                                .font(BRUFont.labelSmall)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.bruPaper)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.bruSignal)
                }
                .buttonStyle(.plain)
                .disabled(isRestoring)
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 2)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        // Backup error inline
        if let err = backupError {
            Text(err)
                .font(BRUFont.labelMicro)
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruSignal)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }

        BRUDivider(.ink)
    }

    // MARK: - About section

    @ViewBuilder
    private func aboutSection(settings: UserSettings) -> some View {
        BRUSectionHead("About")

        BRURow(label: "Version", value: "1.0.0 · SCHEMA V6")
        BRUDivider(.hair)

        BRURow(label: "Source", value: "MIT · GITHUB") {
            if let url = URL(string: "https://github.com") {
                UIApplication.shared.open(url)
            }
        }
        BRUDivider(.hair)

        BRURow(
            label: "Reset all data",
            accent: Color.bruSignal
        )
        BRUDivider(.ink)
    }

    // MARK: - Backup computed metadata

    private var lastBackupDescription: String {
        // v1 placeholder — real last-backup timestamp would require persisted metadata
        "No backup yet"
    }

    private var entityCountLine: String {
        // v1 placeholder — real counts would query the store
        "Create a backup to protect your data"
    }

    // MARK: - Backup/Restore handlers (Wave-5 plan 06-10)

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
}

// MARK: - BRURow helper (fileprivate)

/// A reusable row primitive matching the bru-screens/settings.jsx `Row` component.
///
/// Renders either a `Button` (when `action` is non-nil) or a plain `HStack` (non-interactive).
///
/// Layout: HStack → Text(label) + Spacer + optional value Text + optional trailing view.
/// If neither `value` nor `trailing` is provided, shows a "›" chevron in bruMuted.
private struct BRURow: View {

    let label: String
    var value: String? = nil
    var accent: Color? = nil
    var trailing: AnyView? = nil
    var action: (() -> Void)? = nil

    // Convenience init with a trailing closure action
    init(
        label: String,
        value: String? = nil,
        accent: Color? = nil,
        trailing: AnyView? = nil,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.accent = accent
        self.trailing = trailing
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) {
                rowContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(accent ?? Color.bruInk)
            Spacer()
            if let value {
                Text(value.uppercased())
                    .font(BRUFont.labelSmall)
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            if let trailing {
                trailing
            } else if value == nil && action != nil {
                Text("›")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bruPaper)
    }
}

// MARK: - BRURowLabel helper (fileprivate)

/// Renders the standard label + value HStack used inside NavigationLink labels.
/// Keeps NavigationLink's native chevron while applying BRU typography.
private struct BRURowLabel: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Spacer()
            if let value {
                Text(value)
                    .font(BRUFont.labelSmall)
                    .tracking(0.5)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bruPaper)
    }
}

// MARK: - ExportCard helper (fileprivate)

/// 2pt bruInk-outlined card for the Export section grid.
/// Used inside ShareLink or Button label closures.
private struct ExportCard: View {
    let kind: String      // "CSV" / "JSON"
    let label: String     // "Export CSV" / "Export JSON"
    let sub: String       // "ONE ROW PER SET" / "VERSION-STAMPED"
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLoading {
                ProgressView()
                    .tint(Color.bruInk)
                    .frame(height: 28)
            } else {
                BRUDisplay(kind, size: .large)
            }
            Text(label)
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text(sub)
                .font(BRUFont.labelMicro)
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 2)
        )
        .background(Color.bruPaper)
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
