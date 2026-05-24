// SessionExerciseCard.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 32).
// UI-SPEC v2 § Session logger line 363-391.
//
// One card per snapshotted SessionExercise inside SessionLoggerView.
//
// KEY CHANGES from v1:
//   - Color.accentColor on "Add Set" button → BRUButton(.ghost, .sm) with
//     .foregroundStyle(Color.bruSignal) override (signal text button)
//   - .font(.headline) on exercise name → BRUFont.bodyEmphasis
//   - .font(.caption) on column headers → BRUFont.labelSmall + tracking(1.2)
//   - .foregroundStyle(.secondary) on column headers → Color.bruMuted
//   - Column header strip layout updated to UI-SPEC line 367 format:
//     "S · PREVIOUS · WEIGHT · REPS · RPE" all in labelSmall 9pt 1.2 bruMuted
//   - SF Symbol context menu icons replaced with plain text label actions
//     (system contextMenu chrome is HIG-acceptable per UI-SPEC line 261)
//   - 3-row BRU card header per UI-SPEC line 363-368
//   - BRUDivider(.hair) between SetRows
//
// PRESERVED VERBATIM (Phase 3, 3.1, 5):
//   - currentExplanation(), evaluatePlateau(), handleSuggestedAction()
//   - BumpBanner, CalibratingBadge, WarmupRampRows, StallBadge, SuggestedActionChip
//   - PinnedNoteCapsule mount point (rewritten in Plan 02.1-08)
//   - @Bindable SessionExercise, all closures, @Query state
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor
//               NO Image(systemName:) in chrome (contextMenu is HIG-acceptable)
//               NO .font(.body/.headline/.title/.caption/.subheadline/.footnote)
//               NO .buttonStyle(.bordered) / NO Color(.system*)

import SwiftUI
import SwiftData

public struct SessionExerciseCard: View {
    @Environment(\.modelContext) private var ctx
    @Bindable public var sessionExercise: SessionExercise
    public let engine: RestTimerEngine
    public let onCommitSet: (SetEntry) -> Void
    public let onTapEmptyCell: () -> Void
    public let onSwap: (SessionExercise) -> Void
    public let onRemove: (SessionExercise) -> Void
    public let onEditPinnedNote: (SessionExercise) -> Void

    // MARK: - Phase 3 state

    @State private var bannerDismissed: Bool = false
    @State private var expandedPlateSetID: UUID? = nil
    @Query private var settingsList: [UserSettings]
    @Query private var inventories: [PlateInventory]

    // MARK: - Phase 5 state

    @State private var plateauSignal: PlateauSignal = .notEnoughData
    @State private var suggestedAction: SuggestedAction? = nil
    @State private var presentingTryVariation: Bool = false
    @State private var presentingDeloadSignalSheet: Bool = false

    @Environment(\.modelContext) private var phase5ModelContext

    public init(
        sessionExercise: SessionExercise,
        engine: RestTimerEngine,
        onCommitSet: @escaping (SetEntry) -> Void,
        onTapEmptyCell: @escaping () -> Void,
        onSwap: @escaping (SessionExercise) -> Void = { _ in },
        onRemove: @escaping (SessionExercise) -> Void = { _ in },
        onEditPinnedNote: @escaping (SessionExercise) -> Void = { _ in }
    ) {
        self.sessionExercise = sessionExercise
        self.engine = engine
        self.onCommitSet = onCommitSet
        self.onTapEmptyCell = onTapEmptyCell
        self.onSwap = onSwap
        self.onRemove = onRemove
        self.onEditPinnedNote = onEditPinnedNote
    }

    public var body: some View {
        let explanation = currentExplanation()

        Section {
            // MARK: Card body — VStack(spacing: 0) per UI-SPEC line 363

            VStack(spacing: 0) {
                // Row 1: Index + Exercise name + equipment sub-line + drag handle
                // UI-SPEC line 364-366
                HStack(spacing: 12) {
                    Text(String(format: "%02d", (sessionExercise.orderIndex) + 1))
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .frame(width: 32, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sessionExercise.exercise?.name ?? "Exercise")
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)

                        Text(equipmentSubline)
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                    }

                    Spacer()

                    // Drag handle — typographic "⋮⋮" per UI-SPEC line 338 (NOT SF Symbol)
                    Text("⋮⋮")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contextMenu {
                    Button {
                        onSwap(sessionExercise)
                    } label: {
                        // System contextMenu chrome is HIG-acceptable per UI-SPEC line 261.
                        // Icon suppressed for BRU — label-only is fine in contextMenu.
                        Text("Swap Exercise…")                                   // UI-SPEC verbatim
                    }
                    Button {
                        onEditPinnedNote(sessionExercise)
                    } label: {
                        Text("Edit Pinned Note")                                 // UI-SPEC verbatim
                    }
                    Button(role: .destructive) {
                        onRemove(sessionExercise)
                    } label: {
                        Text("Remove from Session")                              // UI-SPEC verbatim
                    }
                }

                BRUDivider(.hair)

                // Row 2: Optional PinnedNoteCapsule mount point (rewritten in Plan 02.1-08)
                if let note = sessionExercise.pinnedNote, !note.isEmpty {
                    PinnedNoteCapsule(note: note) {
                        onEditPinnedNote(sessionExercise)
                    }
                    BRUDivider(.hair)
                }

                // Phase 3 conditional: BumpBanner
                if let exp = explanation, exp.bumpOccurred, !bannerDismissed {
                    BumpBanner(
                        isVisible: Binding(
                            get: { !bannerDismissed },
                            set: { newValue in bannerDismissed = !newValue }
                        ),
                        bumpedToWeight: exp.roundedWeight
                    )
                    BRUDivider(.hair)
                }

                // Phase 3 conditional: WarmupRampRows
                let warmupSets = warmupEntries
                if !warmupSets.isEmpty {
                    WarmupRampRows(
                        warmupSets: warmupSets,
                        onSkip: { handleSkipWarmups() },
                        sessionExercise: sessionExercise
                    )
                    BRUDivider(.hair)
                }

                // Phase 5: Plateau badges (only when stalled)
                if case .stalled = plateauSignal {
                    HStack(spacing: 8) {
                        StallBadge(
                            exerciseName: sessionExercise.exercise?.name ?? "Exercise",
                            sessionCount: settingsList.first?.plateauWindowSessions ?? 4
                        )
                        if let action = suggestedAction {
                            SuggestedActionChip(action: action) {
                                handleSuggestedAction(action)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    BRUDivider(.hair)
                }

                // Phase 3 conditional: CalibratingBadge (inline header row)
                if let exp = explanation, case .calibrating(let n, let threshold) = exp.status {
                    HStack {
                        CalibratingBadge(current: n, threshold: threshold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    BRUDivider(.hair)
                }

                // Row 3: Column header strip per UI-SPEC line 367
                // "S · PREVIOUS · WEIGHT · REPS · RPE" — labelSmall 9pt 1.2 bruMuted
                HStack(spacing: 6) {
                    Text("S")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .frame(width: 32, alignment: .leading)
                    Text("PREVIOUS")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .frame(width: 80, alignment: .leading)
                    Text("WEIGHT")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .frame(width: 60, alignment: .leading)
                    Text("REPS")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .frame(width: 40, alignment: .leading)
                    Text("RPE")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                    Spacer()
                }
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                BRUDivider(.hair)

                // SetRows
                ForEach(sortedSets) { set in
                    VStack(spacing: 4) {
                        SetRow(
                            entry: set,
                            sessionExercise: sessionExercise,
                            prescribed: sessionExercise.prescribedWeight,
                            explanation: explanation,
                            expandedPlateSetID: $expandedPlateSetID,
                            onCommit: { onCommitSet(set) },
                            onTapEmptyCell: onTapEmptyCell
                        )
                        if sessionExercise.tracksTempo {
                            TempoEntryRow(entry: set)
                        }
                        if sessionExercise.tracksPartialReps {
                            PartialRepsRow(entry: set)
                        }
                        if set.setType == .restPause {
                            ClusterSubRepChipRow(entry: set)
                        }
                    }
                    BRUDivider(.hair)
                }

                // "+ ADD SET" signal text button per UI-SPEC line 387
                Button {
                    addSet()
                } label: {
                    Text("+ ADD SET")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruSignal)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        } header: {
            // Empty header — card header is embedded in body VStack above.
            EmptyView()
        }
        // Tap-anywhere-on-card dismisses the bump banner
        .onTapGesture {
            if !bannerDismissed {
                bannerDismissed = true
            }
        }
        // Phase 5 PROG-06 — evaluate plateau signal on first appear + exercise change
        .task(id: sessionExercise.id) {
            evaluatePlateau()
        }
        // Phase 5 PROG-06 Branch 4 — TryVariationSheet
        .sheet(isPresented: $presentingTryVariation) {
            if let source = sessionExercise.exercise {
                TryVariationSheet(sourceExercise: source) { _ in
                    presentingTryVariation = false
                }
            }
        }
        // Phase 5 PROG-06 Branch 3 — DeloadSignalDetailSheet
        .sheet(isPresented: $presentingDeloadSignalSheet) {
            if let settings = settingsList.first {
                let weekStart = Date.now.mondayAtMidnightForToday(
                    weekStartsMonday: settings.weekStartsMonday
                )
                let report = DeloadAdvisor.signalReport(
                    weekStart: weekStart,
                    in: phase5ModelContext,
                    settings: settings
                )
                DeloadSignalDetailSheet(report: report)
            }
        }
    }

    // MARK: - Phase 5 PROG-06 helpers

    @MainActor
    private func evaluatePlateau() {
        guard let exerciseID = sessionExercise.exercise?.id,
              let intent = sessionExercise.session?.intent,
              let settings = settingsList.first
        else {
            plateauSignal = .notEnoughData
            suggestedAction = nil
            return
        }
        plateauSignal = PlateauDetector.evaluate(
            exerciseID: exerciseID,
            intent: intent,
            in: phase5ModelContext,
            settings: settings
        )
        if case .stalled = plateauSignal {
            suggestedAction = PlateauDetector.suggestedAction(
                exerciseID: exerciseID,
                intent: intent,
                in: phase5ModelContext,
                settings: settings
            )
        } else {
            suggestedAction = nil
        }
    }

    @MainActor
    private func handleSuggestedAction(_ action: SuggestedAction) {
        switch action {
        case .addVolume:
            break
        case .dropIntensity:
            break
        case .deload:
            presentingDeloadSignalSheet = true
        case .tryVariation:
            presentingTryVariation = true
        }
    }

    // MARK: - Private computed properties

    /// Equipment sub-line for card header — UI-SPEC line 366.
    /// "{equipment} · {prescription summary}" in labelSmall bruMuted.
    private var equipmentSubline: String {
        let equip = sessionExercise.exercise?.equipment.rawValue.capitalized ?? "Equipment"
        // Build a minimal snapshot prescription summary
        let setsCount = (sessionExercise.sets ?? []).count
        let parts = [equip, "\(setsCount) SETS"]
        return parts.joined(separator: " · ")
    }

    private var sortedSets: [SetEntry] {
        (sessionExercise.sets ?? [])
            .filter { !$0.isWarmup }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var warmupEntries: [SetEntry] {
        (sessionExercise.sets ?? [])
            .filter { $0.isWarmup }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - currentExplanation (Phase 3 plan 03-08)

    private func currentExplanation() -> PrescriptionExplanation? {
        let se = sessionExercise
        let userSettings = settingsList.first

        let exerciseID = se.exercise?.id
        let intentRaw = se.session?.intentRaw ?? Intent.strength.rawValue

        let ekind = SessionFactory.equipmentKind(
            for: se.exercise?.equipment ?? .other
        )
        let inventory = inventories.first { $0.equipmentKind == ekind }

        let barWeight: Double
        let plates: [(weight: Double, countPerSide: Int)]
        if let inv = inventory {
            barWeight = se.exercise?.barWeightOverride ?? inv.barWeight
            plates = inv.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        } else {
            let unit = userSettings?.weightUnit ?? .kg
            barWeight = se.exercise?.barWeightOverride
                ?? PlateInventoryDefaults.barWeight(for: ekind, unitSystem: unit)
            plates = PlateInventoryDefaults.make(for: ekind, unitSystem: unit)
                .map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        }

        let smallestIncrement = se.exercise?.smallestIncrement
            ?? userSettings?.defaultIncrementKg
            ?? 2.5
        let minCalibrationSets = userSettings?.minCalibrationSets ?? 10

        let historyPoints = SessionFactory.fetchHistoryPoints(
            exerciseID: exerciseID,
            intentRaw: intentRaw,
            context: ctx
        )
        let lastRepsArray = SessionFactory.lastSessionWorkingReps(
            exerciseID: exerciseID,
            intentRaw: intentRaw,
            context: ctx
        )
        let lastHint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exerciseID,
            intentRaw: intentRaw,
            context: ctx
        )

        let strategy = ProgressionStrategyFactory.make(for: se.session?.progressionKind ?? .double)
        let (_, explanation) = strategy.prescribe(
            history: historyPoints,
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE,
            lastSessionRepsArray: lastRepsArray.isEmpty ? nil : lastRepsArray,
            smallestIncrement: smallestIncrement,
            plates: plates,
            barWeight: barWeight,
            minCalibrationSets: minCalibrationSets,
            lastSessionWeight: lastHint?.weight,
            lastSessionReps: lastHint?.reps,
            lastSessionRPE: lastHint?.rpe,
            lastSessionDate: lastHint?.sessionStartedAt,
            block: se.session?.block,
            today: se.session?.startedAt ?? Date.now
        )
        var enriched = explanation
        enriched.sessionIntent = se.session?.intent
        return enriched
    }

    // MARK: - handleSkipWarmups

    private func handleSkipWarmups() {
        for warmup in warmupEntries {
            warmup.isComplete = true
        }
        try? ctx.save()
    }

    // MARK: - addSet

    private func addSet() {
        let entry = SetEntry()
        entry.sessionExercise = sessionExercise
        let allSets = sessionExercise.sets ?? []
        entry.orderIndex = allSets.count
        entry.setTypeRaw = SetType.working.rawValue
        entry.isComplete = false
        entry.weight = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: sessionExercise.exercise?.id,
            intentRaw: sessionExercise.session?.intentRaw ?? Intent.strength.rawValue,
            context: ctx
        )?.weight ?? 0
        ctx.insert(entry)
        try? ctx.save()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("exercise card") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let session = Session()
    session.intentRaw = Intent.strength.rawValue
    ctx.insert(session)
    let se = SessionExercise()
    se.session = session
    se.exercise = ex
    se.targetSets = 3
    ctx.insert(se)
    for i in 0..<3 {
        let entry = SetEntry()
        entry.sessionExercise = se
        entry.orderIndex = i
        ctx.insert(entry)
    }
    try? ctx.save()
    let engine = RestTimerEngine()
    return List {
        SessionExerciseCard(
            sessionExercise: se,
            engine: engine,
            onCommitSet: { _ in },
            onTapEmptyCell: {}
        )
    }
    .modelContainer(container)
}
#endif
