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
    public let onUncompleteSet: (SetEntry) -> Void
    public let onDeleteSet: (SetEntry) -> Void
    public let onAddSet: (SessionExercise) -> Void
    public let onEditCommitted: () -> Void

    // MARK: - Phase 3 state

    @State private var bannerDismissed: Bool = false
    /// Folded to its header row: name, equipment and sets done (FT-12).
    @State private var collapsed = false
    /// Why this weight? from the exercise menu, open after logging too (FT-09).
    @State private var explainingExercise = false
    @Query private var settingsList: [UserSettings]
    @Query private var inventories: [PlateInventory]
    @Environment(\.weightUnit) private var defaultUnit
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Phase 5 state

    @State private var plateauSignal: PlateauSignal = .notEnoughData
    @State private var suggestedAction: SuggestedAction? = nil
    @State private var presentingTryVariation: Bool = false
    @State private var presentingDeloadSignalSheet: Bool = false
    /// Captured inputs and prescription, retained until Undo succeeds.
    @State private var variationUndo: VariationUndoSnapshot?
    @State private var undoFailed = false
    /// "View all similar exercises" asks for the full swap list, which
    /// opens once the variation sheet has gone.
    @State private var swapListAfterVariation = false

    @Environment(\.modelContext) private var phase5ModelContext

    public init(
        sessionExercise: SessionExercise,
        engine: RestTimerEngine,
        onCommitSet: @escaping (SetEntry) -> Void,
        onTapEmptyCell: @escaping () -> Void,
        onSwap: @escaping (SessionExercise) -> Void = { _ in },
        onRemove: @escaping (SessionExercise) -> Void = { _ in },
        onEditPinnedNote: @escaping (SessionExercise) -> Void = { _ in },
        onUncompleteSet: @escaping (SetEntry) -> Void = { _ in },
        onDeleteSet: @escaping (SetEntry) -> Void = { _ in },
        onAddSet: @escaping (SessionExercise) -> Void = { _ in },
        onEditCommitted: @escaping () -> Void = {}
    ) {
        self.sessionExercise = sessionExercise
        self.engine = engine
        self.onCommitSet = onCommitSet
        self.onTapEmptyCell = onTapEmptyCell
        self.onSwap = onSwap
        self.onRemove = onRemove
        self.onEditPinnedNote = onEditPinnedNote
        self.onUncompleteSet = onUncompleteSet
        self.onDeleteSet = onDeleteSet
        self.onAddSet = onAddSet
        self.onEditCommitted = onEditCommitted
    }

    public var body: some View {
        let explanation = currentExplanation()

        Section {
            // MARK: Card body
            // The card is split into separate List rows (header block, one
            // row per set, add-set row) so each set gets the native
            // swipe-to-delete. Rows drop the system separators and insets;
            // BRUDivider draws the rules exactly as the single-VStack card did.

            VStack(spacing: 0) {
                // Row 1: Index + Exercise name + equipment sub-line, a
                // button that folds the exercise to this row (FT-12), then
                // the exercise menu (FT-03). UI-SPEC line 364-366
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Button {
                        bannerDismissed = true
                        withAnimation(.easeInOut(duration: 0.2)) { collapsed.toggle() }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(format: "%02d", (sessionExercise.orderIndex) + 1))
                                .font(BRUFont.displayMedium)
                                .foregroundStyle(Color.bruInk)
                                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 32, alignment: .leading)
                                .lineLimit(1)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(exerciseName)
                                    .font(BRUFont.bodyEmphasis)
                                    .foregroundStyle(Color.bruInk)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(equipmentSubline)
                                    .font(BRUFont.labelSmall)
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.bruMuted)
                            }

                            Spacer(minLength: 0)

                            Text(collapsed ? "▸" : "▾")
                                .font(BRUFont.bodyDefault)
                                .foregroundStyle(Color.bruMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
                    .accessibilityHint("Shows or hides its sets")
                    .accessibilityIdentifier("card.toggle.\(sessionExercise.orderIndex + 1)")
                    // The long-press menu stays beside the visible one.
                    .contextMenu { exerciseMenuItems(explanation) }

                    Menu {
                        exerciseMenuItems(explanation)
                    } label: {
                        Text("•••")
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(exerciseName) actions")
                    .accessibilityIdentifier("card.menu.\(sessionExercise.orderIndex + 1)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if collapsed {
                    BRUDivider(.ink)
                } else {
                    headerDetails(explanation)
                }
            }
            .cardRow()
            // Tap-anywhere-on-header dismisses the bump banner
            .onTapGesture {
                if !bannerDismissed {
                    bannerDismissed = true
                }
            }
            // Present from one concrete row, not the multi-row Section.
            .sheet(isPresented: $presentingTryVariation, onDismiss: {
                guard swapListAfterVariation else { return }
                swapListAfterVariation = false
                variationUndo = nil
                onSwap(sessionExercise)
            }) {
                if let source = sessionExercise.exercise {
                    TryVariationSheet(sourceExercise: source) { picked in
                        if let picked {
                            let original = VariationUndoSnapshot(sessionExercise)
                            SwapExerciseSheet.swap(sessionExercise, to: picked, context: ctx)
                            variationUndo = original
                        } else {
                            swapListAfterVariation = true
                        }
                        presentingTryVariation = false
                    }
                }
            }
            // Why this weight? from the exercise menu: the frozen
            // prescription against the heaviest logged working set (FT-09).
            .sheet(isPresented: $explainingExercise) {
                if let exp = currentExplanation() {
                    WhyThisWeightSheet(
                        explanation: exp,
                        reps: SetRow.targetReps(low: sessionExercise.targetRepsLow, high: sessionExercise.targetRepsHigh),
                        rpe: sessionExercise.targetRPE,
                        unitLabel: unit.rawValue,
                        loggedWeight: topLoggedWeight
                    )
                    .presentationDetents([.medium])
                }
            }
            .alert("Couldn't undo variation", isPresented: $undoFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The workout wasn't restored. Your undo is still available; try again.")
            }

            if !collapsed {
                // SetRows — one List row each so swipe-to-delete works.
                ForEach(sortedSets) { set in
                    VStack(spacing: 0) {
                        VStack(spacing: 4) {
                            SetRow(
                                entry: set,
                                sessionExercise: sessionExercise,
                                prescribed: sessionExercise.prescribedWeight,
                                explanation: explanation,
                                onCommit: {
                                    onCommitSet(set)
                                    if set.isComplete { variationUndo = nil }
                                },
                                onTapEmptyCell: onTapEmptyCell,
                                onUncomplete: { onUncompleteSet(set) },
                                onEditCommitted: onEditCommitted
                            )
                            // A swap/Undo changes the inputs behind these local
                            // text fields, not the persisted set's identity.
                            .id(sessionExercise.exercise?.id)
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
                        .padding(.horizontal, 16)
                        BRUDivider(.hair)
                    }
                    .cardRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDeleteSet(set)
                        } label: {
                            Text("Delete")
                        }
                    }
                    .accessibilityAction(named: "Delete set") {
                        onDeleteSet(set)
                    }
                }

                // "+ ADD SET" signal text button per UI-SPEC line 387, then the
                // 2pt ink rule that closes the exercise block.
                VStack(spacing: 0) {
                    Button {
                        onAddSet(sessionExercise)
                    } label: {
                        Text("+ ADD SET")
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruSignalText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("card.addSet.\(sessionExercise.orderIndex + 1)")
                    .padding(.vertical, 4)

                    BRUDivider(.ink)
                }
                .cardRow()
            }
        } header: {
            // Empty header — card header is embedded in body VStack above.
            EmptyView()
        }
        .listSectionSeparator(.hidden)
        // Phase 5 PROG-06 — evaluate plateau signal on first appear and
        // whenever a swap changes the exercise.
        .task(id: sessionExercise.exercise?.id) {
            evaluatePlateau()
        }
        .onChange(of: hasLoggedWorkingSet) { _, logged in
            if logged { variationUndo = nil }
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

    private func undoVariation() {
        guard let original = variationUndo else { return }
        do {
            try original.restore(to: sessionExercise, context: ctx)
            variationUndo = nil
        } catch {
            undoFailed = true
        }
    }

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
            // One more working set for this exercise today.
            onAddSet(sessionExercise)
            suggestedAction = nil
        case .dropIntensity:
            // Lighten the sets not yet done by 10%, rounded down to the
            // smallest plate increment.
            let increment = sessionExercise.exercise?.smallestIncrement
                ?? settingsList.first?.defaultIncrementKg
                ?? 2.5
            SessionSetActions.dropIntensity(
                of: sessionExercise,
                fraction: 0.10,
                increment: increment,
                context: ctx
            )
            suggestedAction = nil
        case .deload:
            presentingDeloadSignalSheet = true
        case .tryVariation:
            presentingTryVariation = true
        }
    }

    /// Everything under the header row: the variation undo, pinned note,
    /// bump banner, warm-up ramp, plateau and calibrating badges and the
    /// column strip. Hidden while the exercise is collapsed.
    @ViewBuilder
    private func headerDetails(_ explanation: PrescriptionExplanation?) -> some View {
        BRUDivider(.hair)

        // A picked variation can be undone until a set of it is
        // logged; after that the logged sets belong to it.
        if let original = variationUndo, !hasLoggedWorkingSet {
            HStack(spacing: 8) {
                Text("Swapped from \(original.displayName)")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    undoVariation()
                } label: {
                    Text("Undo")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruSignalText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo, back to \(original.displayName)")
                .accessibilityIdentifier("card.undoVariation")
            }
            .padding(.horizontal, 16)
            BRUDivider(.hair)
        }

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
                bumpedToWeight: exp.roundedWeight,
                unitLabel: unit.rawValue
            )
            BRUDivider(.hair)
        }

        // Phase 3 conditional: WarmupRampRows
        let warmupSets = warmupEntries
        if !warmupSets.isEmpty {
            let setup = plateSetup
            WarmupRampRows(
                warmupSets: warmupSets,
                onSkip: { handleSkipWarmups() },
                onUndoSkip: { handleUndoSkipWarmups() },
                sessionExercise: sessionExercise,
                barWeight: setup.barWeight,
                plates: setup.plates,
                unitLabel: unit.rawValue
            )
            BRUDivider(.hair)
        }

        // Phase 5: Plateau badges (only when stalled)
        // The detector returns one e1RM per session in the window it
        // used, the exercise's own window or the user's setting, so
        // the badge names that window.
        if case .stalled(let e1RMs, _) = plateauSignal {
            HStack(spacing: 8) {
                StallBadge(
                    exerciseName: exerciseName,
                    sessionCount: e1RMs.count
                )
                // A variation takes over the whole card, its logged
                // sets too, so like UNDO it is offered only before a
                // working set is logged.
                if let action = suggestedAction,
                   action != .tryVariation || !hasLoggedWorkingSet {
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
        // Stacked accessibility inputs carry their own labels; the
        // fixed-width table headings would split into fragments.
        if !dynamicTypeSize.isAccessibilitySize {
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
        }

        BRUDivider(.hair)
    }

    /// The exercise's actions, in its ••• menu and its long-press menu.
    /// System menu chrome is HIG-acceptable per UI-SPEC line 261.
    @ViewBuilder
    private func exerciseMenuItems(_ explanation: PrescriptionExplanation?) -> some View {
        if explanation != nil {
            Button {
                explainingExercise = true
            } label: {
                Text("Why this weight?")
            }
        }
        Button {
            variationUndo = nil
            onSwap(sessionExercise)
        } label: {
            Text("Swap Exercise…")                                               // UI-SPEC verbatim
        }
        Button {
            onEditPinnedNote(sessionExercise)
        } label: {
            Text("Edit Pinned Note")                                             // UI-SPEC verbatim
        }
        Button(role: .destructive) {
            onRemove(sessionExercise)
        } label: {
            Text("Remove from workout")
        }
    }

    // MARK: - Private computed properties

    /// Equipment sub-line for card header — UI-SPEC line 366.
    /// "{equipment} · {done}/{working sets} done" in labelSmall bruMuted, so
    /// a collapsed exercise still shows its progress (FT-12). Working sets
    /// only; warm-ups have their own ramp block above.
    private var equipmentSubline: String {
        let equip = sessionExercise.exercise?.equipment.rawValue.capitalized ?? "Equipment"
        let working = (sessionExercise.sets ?? []).filter { !$0.isWarmup }
        let done = working.filter(\.isComplete).count
        return "\(equip) · \(done)/\(BRUCountLabel.text(working.count, "set")) done"
    }

    /// The heaviest logged working set's weight, for Why this weight? to
    /// name against the recommendation; nil before one is logged.
    private var topLoggedWeight: Double? {
        (sessionExercise.sets ?? []).filter { $0.isComplete && !$0.isWarmup }.map(\.weight).max()
    }

    /// Log-time snapshot name, falling back to the live catalog name.
    private var exerciseName: String {
        let name = sessionExercise.displayName
        return name.isEmpty ? "Exercise" : name
    }

    /// A working set of this exercise is logged.
    private var hasLoggedWorkingSet: Bool {
        (sessionExercise.sets ?? []).contains { $0.isComplete && !$0.isWarmup }
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

    // MARK: - Unit and plates

    /// The exercise's own unit wins over the app-wide one.
    private var unit: WeightUnit {
        .effective(for: sessionExercise.exercise, default: defaultUnit)
    }

    /// Bar and plates for this exercise, with no inventory for nonplate equipment.
    /// SessionFactory uses the same equipment mapping for its prescription and ramp.
    private var plateSetup: (barWeight: Double, plates: [(weight: Double, countPerSide: Int)]) {
        let exercise = sessionExercise.exercise
        guard let ekind = SessionFactory.plateEquipmentKind(for: exercise?.equipment ?? .other) else {
            return (exercise?.barWeightOverride ?? 0, [])
        }
        if let inv = inventories.first(where: { $0.equipmentKind == ekind }) {
            return (
                exercise?.barWeightOverride ?? inv.barWeight,
                inv.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
            )
        }
        return (
            exercise?.barWeightOverride
                ?? PlateInventoryDefaults.barWeight(for: ekind, unitSystem: unit),
            PlateInventoryDefaults.make(for: ekind, unitSystem: unit)
                .map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        )
    }

    // MARK: - currentExplanation (Phase 3 plan 03-08)

    /// What WHY explains: `SessionFactory`'s prescription for this
    /// exercise, frozen at the weight the sets were started with.
    private func currentExplanation() -> PrescriptionExplanation? {
        let se = sessionExercise
        guard let session = se.session else { return nil }
        var explanation = SessionFactory.prescription(
            for: se.exercise,
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE,
            in: session,
            strategy: ProgressionStrategyFactory.make(for: session.progressionKind),
            userSettings: settingsList.first,
            context: ctx
        ).explanation
        explanation.sessionIntent = session.intent
        return explanation.frozen(at: se.prescribedWeight, unitLabel: unit.rawValue)
    }

    // MARK: - handleSkipWarmups

    private func handleSkipWarmups() {
        for warmup in warmupEntries {
            warmup.isComplete = true
        }
        try? ctx.save()
    }

    private func handleUndoSkipWarmups() {
        for warmup in warmupEntries {
            warmup.isComplete = false
        }
        try? ctx.save()
    }
}

private extension View {
    /// Card rows draw their own rules and padding: no system separator,
    /// no inset, paper background.
    func cardRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.bruPaper)
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
