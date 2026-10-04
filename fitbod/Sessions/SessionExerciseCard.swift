//
//  SessionExerciseCard.swift
//  fitbod
//
//  One exercise inside the active workout, rendered as a List section so
//  set rows keep native swipe-to-delete:
//
//    1. Header row — order badge, name (wraps; long names are common),
//       prescription line ("Strength · 4 × 4–6 · RPE 8 · rest 3:00"),
//       prescribed weight with "Why this weight?", and the ⋯ menu
//       (swap, pinned note, skip warm-ups, remove).
//    2. Pinned note capsule (when set).
//    3. Warm-up rows (W1…), loggable, with "Skip warm-ups".
//    4. Column labels (SET · PREVIOUS · LB · REPS · RPE) over a 1.5 pt rule.
//    5. Working set rows (`SetEntryRow`) — swipe to delete, long-press for
//       set type / note — plus optional tempo / partials / cluster rows.
//    6. "Add set" (copies the last set's weight).
//
//  Previous performance and the prescription explanation are loaded once
//  per appearance (`.task`), not on every keystroke.
//
//  Scoping (PITFALLS-doc #1): the card reads/writes this SessionExercise
//  and its SetEntry rows only — never the source routine.
//

import SwiftUI
import SwiftData

public struct SessionExerciseCard: View {
    @Environment(\.modelContext) private var ctx
    @Bindable public var sessionExercise: SessionExercise
    let exerciseIndex: Int
    let unitLabel: String
    let nextSetID: UUID?
    let errors: [UUID: SetValidation]
    let focus: FocusState<SetField?>.Binding
    let onComplete: (SetEntry) -> Void
    let onUncomplete: (SetEntry) -> Void
    let onSetEdited: (SetEntry) -> Void
    let onSwap: (SessionExercise) -> Void
    let onRemove: (SessionExercise) -> Void
    let onEditPinnedNote: (SessionExercise) -> Void
    let onEditSetNote: (SetEntry) -> Void

    @State private var previous: PreviousPerformance?
    @State private var explanation: PrescriptionExplanation?
    @State private var presentingWhy = false
    @State private var presentingPlateMath = false
    @State private var bannerDismissed = false
    @State private var tableWidth: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var metrics = SetTableMetrics()
    @Query private var settingsList: [UserSettings]
    @Query private var inventories: [PlateInventory]

    public init(
        sessionExercise: SessionExercise,
        exerciseIndex: Int,
        unitLabel: String,
        nextSetID: UUID?,
        errors: [UUID: SetValidation],
        focus: FocusState<SetField?>.Binding,
        onComplete: @escaping (SetEntry) -> Void,
        onUncomplete: @escaping (SetEntry) -> Void,
        onSetEdited: @escaping (SetEntry) -> Void,
        onSwap: @escaping (SessionExercise) -> Void,
        onRemove: @escaping (SessionExercise) -> Void,
        onEditPinnedNote: @escaping (SessionExercise) -> Void,
        onEditSetNote: @escaping (SetEntry) -> Void
    ) {
        self.sessionExercise = sessionExercise
        self.exerciseIndex = exerciseIndex
        self.unitLabel = unitLabel
        self.nextSetID = nextSetID
        self.errors = errors
        self.focus = focus
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
        self.onSetEdited = onSetEdited
        self.onSwap = onSwap
        self.onRemove = onRemove
        self.onEditPinnedNote = onEditPinnedNote
        self.onEditSetNote = onEditSetNote
    }

    public var body: some View {
        Section {
            header
                .task(id: sessionExercise.exercise?.id) {
                    loadContext()
                }
                .sheet(isPresented: $presentingWhy) {
                    if let explanation {
                        WhyThisWeightSheet(explanation: explanation, onUseSuggested: { useSuggested() })
                    }
                }
                .sheet(isPresented: $presentingPlateMath) {
                    if let kind = plateKind {
                        PlateCalculatorSheet(
                            equipment: kind,
                            inventory: SessionFactory.plateInventory(for: kind, context: ctx),
                            initialTarget: plateMathTarget
                        )
                        .presentationDetents([.medium, .large])
                    }
                }

            if let note = sessionExercise.pinnedNote, !note.isEmpty {
                PinnedNoteCapsule(note: note) {
                    onEditPinnedNote(sessionExercise)
                }
            }

            if let explanation, explanation.bumpOccurred, !bannerDismissed {
                BumpBanner(
                    isVisible: Binding(
                        get: { !bannerDismissed },
                        set: { bannerDismissed = !$0 }
                    ),
                    bumpedToWeight: explanation.roundedWeight,
                    unitLabel: unitLabel
                )
            }

            let warmups = WorkoutLogging.warmupSets(of: sessionExercise)
            if !warmups.isEmpty {
                ForEach(Array(warmups.enumerated()), id: \.element.id) { offset, set in
                    row(for: set, label: "W\(offset + 1)", previousLine: nil, identifierPrefix: "warmup.\(exerciseIndex).\(offset)")
                        .listRowBackground(set.isComplete ? Color.chalkComplete : Color.chalkSurface)
                }
                Button("Skip warm-ups") {
                    WorkoutLogging.skipWarmups(of: sessionExercise, context: ctx)
                }
                .buttonStyle(.chalk(.ghost, size: .compact))
                .accessibilityHint(Text("Removes the warm-up sets for this exercise"))
            }

            columnLabels

            let working = WorkoutLogging.workingSets(of: sessionExercise)
            ForEach(Array(working.enumerated()), id: \.element.id) { offset, set in
                row(for: set, label: "\(offset + 1)", previousLine: previous?.line(forSetIndex: offset), identifierPrefix: "set.\(exerciseIndex).\(offset)")
                    .listRowBackground(set.isComplete ? Color.chalkComplete : Color.chalkSurface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            WorkoutLogging.delete(set, context: ctx)
                        } label: {
                            Label("Delete set", systemImage: "trash")
                        }
                    }
                    .contextMenu { setMenu(for: set) }
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

            Button {
                WorkoutLogging.addSet(to: sessionExercise, context: ctx)
            } label: {
                Label("Add set", systemImage: "plus")
            }
            .buttonStyle(.chalk(.secondary, size: .compact, fullWidth: true))
            .accessibilityIdentifier("exercise.\(exerciseIndex).addSet")
            .listRowSeparator(.hidden)
        }
        .listRowBackground(Color.chalkSurface)
        .listRowSeparatorTint(Color.chalkDivider)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: Chalk.Space.md) {
            Text("\(exerciseIndex + 1)")
                .font(.chalkSubtitle)
                .foregroundStyle(.chalkCanvas)
                .frame(minWidth: 28, minHeight: 28)
                .background(Color.chalkInk, in: RoundedRectangle(cornerRadius: Chalk.Radius.sm, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                Text(sessionExercise.exercise?.name ?? "Removed exercise")
                    .font(.chalkHeadline)
                    .foregroundStyle(.chalkInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(prescriptionLine)
                    .font(.chalkFootnote)
                    .foregroundStyle(.chalkInk2)
                    .fixedSize(horizontal: false, vertical: true)
                if let prescribed = sessionExercise.prescribedWeight, prescribed > 0 {
                    Button {
                        presentingWhy = true
                    } label: {
                        HStack(spacing: Chalk.Space.xs) {
                            Text("Prescribed \(ChalkFormat.weight(prescribed)) \(unitLabel)")
                            Image(systemName: "info.circle")
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.chalkAccentInk)
                        .frame(minHeight: Chalk.Size.minTouch)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(explanation == nil)
                    .accessibilityHint(Text("Explains how this weight was chosen"))
                }
                if let explanation, case .calibrating(let n, let threshold) = explanation.status {
                    CalibratingBadge(current: n, threshold: threshold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button {
                    onSwap(sessionExercise)
                } label: {
                    Label("Swap exercise", systemImage: "arrow.left.arrow.right")
                }
                Button {
                    onEditPinnedNote(sessionExercise)
                } label: {
                    Label("Pinned note", systemImage: "pin")
                }
                if plateKind != nil {
                    Button {
                        presentingPlateMath = true
                    } label: {
                        Label("Plate math", systemImage: "circle.grid.2x1")
                    }
                }
                if !WorkoutLogging.warmupSets(of: sessionExercise).isEmpty {
                    Button {
                        WorkoutLogging.skipWarmups(of: sessionExercise, context: ctx)
                    } label: {
                        Label("Skip warm-ups", systemImage: "forward")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    onRemove(sessionExercise)
                } label: {
                    Label("Remove from workout", systemImage: "trash")
                }
            } label: {
                ChalkIconGlyph(systemImage: "ellipsis")
            }
            .accessibilityLabel(Text("Options for \(sessionExercise.exercise?.name ?? "exercise")"))
            .accessibilityIdentifier("exercise.\(exerciseIndex).menu")
        }
        .padding(.vertical, Chalk.Space.xs)
    }

    // MARK: Plate math

    /// Barbell and dumbbell lifts get the plate calculator.
    private var plateKind: PlateEquipmentKind? {
        switch sessionExercise.exercise?.equipment {
        case .barbell?: return .barbell
        case .dumbbell?: return .dumbbell
        default: return nil
        }
    }

    /// The weight to load next: the first open working set, else the
    /// prescription, else the last set.
    private var plateMathTarget: Double? {
        let working = WorkoutLogging.workingSets(of: sessionExercise)
        if let open = working.first(where: { !$0.isComplete && $0.weight > 0 }) {
            return open.weight
        }
        if let prescribed = sessionExercise.prescribedWeight, prescribed > 0 {
            return prescribed
        }
        return working.last?.weight
    }

    private var prescriptionLine: String {
        let se = sessionExercise
        var parts: [String] = [se.intent.rawValue.capitalized]
        let reps = se.targetRepsLow == se.targetRepsHigh ? "\(se.targetRepsLow)" : "\(se.targetRepsLow)–\(se.targetRepsHigh)"
        parts.append("\(se.targetSets) × \(reps)")
        if let rpe = se.targetRPE {
            parts.append("RPE \(ChalkFormat.rpe(rpe))")
        }
        parts.append("rest \(ChalkFormat.duration(seconds: se.prescribedRestSeconds))")
        return parts.joined(separator: " · ")
    }

    // MARK: Column labels

    /// Same scaled widths and stacking rule as `SetEntryRow`, so the labels
    /// sit exactly over their columns — or collapse to one "Sets" label
    /// when the rows stack.
    private var columnLabels: some View {
        VStack(spacing: Chalk.Space.xs) {
            Group {
                if metrics.usesStackedLayout(width: tableWidth, dynamicTypeSize: dynamicTypeSize) {
                    Text("Sets").frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: SetTableMetrics.spacing) {
                        Text("Set").frame(width: metrics.setWidth)
                        Text("Previous").frame(maxWidth: .infinity, alignment: .leading)
                        Text(unitLabel).frame(width: metrics.weightWidth)
                        Text("Reps").frame(width: metrics.repsWidth)
                        Text("RPE").frame(width: metrics.rpeWidth)
                        Color.clear.frame(width: Chalk.Size.setCheck, height: 1)
                    }
                }
            }
            .chalkLabelStyle()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                tableWidth = width
            }
            Rectangle()
                .fill(Color.chalkInk)
                .frame(height: Chalk.Line.strong)
        }
        .accessibilityHidden(true)
        .listRowSeparator(.hidden)
    }

    // MARK: Rows

    private func row(for set: SetEntry, label: String, previousLine: PreviousPerformance.Line?, identifierPrefix: String) -> some View {
        SetEntryRow(
            entry: set,
            setLabel: label,
            previous: previousLine,
            targetRepsText: set.isWarmup ? "\(max(set.reps, 1))" : targetRepsText,
            unitLabel: unitLabel,
            allowsSignedWeight: WorkoutLogging.allowsZeroOrNegativeWeight(sessionExercise.exercise?.equipment),
            isNext: set.id == nextSetID,
            validation: errors[set.id] ?? .ok,
            identifierPrefix: identifierPrefix,
            focus: focus,
            onComplete: { onComplete(set) },
            onUncomplete: { onUncomplete(set) },
            onUsePrevious: {
                if let previousLine {
                    WorkoutLogging.apply(previousLine, to: set, context: ctx)
                    onSetEdited(set)
                }
            },
            onEdited: { onSetEdited(set) }
        )
    }

    private var targetRepsText: String {
        let se = sessionExercise
        return se.targetRepsLow == se.targetRepsHigh ? "\(se.targetRepsLow)" : "\(se.targetRepsLow)–\(se.targetRepsHigh)"
    }

    @ViewBuilder
    private func setMenu(for set: SetEntry) -> some View {
        Menu("Set type") {
            ForEach(SetType.allCases, id: \.self) { type in
                Button {
                    set.setTypeRaw = type.rawValue
                    try? ctx.save()
                } label: {
                    if set.setType == type {
                        Label(Self.title(for: type), systemImage: "checkmark")
                    } else {
                        Text(Self.title(for: type))
                    }
                }
            }
        }
        Button {
            onEditSetNote(set)
        } label: {
            Label(set.notes == nil ? "Add note" : "Edit note", systemImage: "square.and.pencil")
        }
        if set.isComplete {
            Button {
                onUncomplete(set)
            } label: {
                Label("Edit set", systemImage: "pencil")
            }
        }
        Button(role: .destructive) {
            WorkoutLogging.delete(set, context: ctx)
        } label: {
            Label("Delete set", systemImage: "trash")
        }
    }

    static func title(for type: SetType) -> String {
        switch type {
        case .working: return "Working"
        case .warmup: return "Warm-up"
        case .drop: return "Drop Set"
        case .failure: return "To Failure"
        case .restPause: return "Rest-Pause"
        }
    }

    // MARK: Loading

    private func loadContext() {
        let se = sessionExercise
        previous = PreviousPerformance.lookup(
            exerciseID: se.exercise?.id,
            intentRaw: se.intentRaw,
            excludingSessionID: se.session?.id,
            context: ctx
        )
        guard se.prescribedWeight != nil else {
            explanation = nil
            return
        }
        explanation = computeExplanation()
    }

    /// Same inputs `SessionFactory.start` used to prescribe the weight
    /// (plan 03-08), recomputed for the "Why this weight?" sheet.
    private func computeExplanation() -> PrescriptionExplanation? {
        let se = sessionExercise
        let userSettings = settingsList.first
        let ekind = SessionFactory.equipmentKind(for: se.exercise?.equipment ?? .other)
        let inventory = inventories.first { $0.equipmentKind == ekind }
        let barWeight: Double
        let plates: [(weight: Double, countPerSide: Int)]
        if let inventory {
            barWeight = se.exercise?.barWeightOverride ?? inventory.barWeight
            plates = inventory.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        } else {
            let unit = userSettings?.weightUnit ?? .lb
            barWeight = se.exercise?.barWeightOverride ?? PlateInventoryDefaults.barWeight(for: ekind, unitSystem: unit)
            plates = PlateInventoryDefaults.make(for: ekind, unitSystem: unit)
                .map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        }
        let exerciseID = se.exercise?.id
        let history = SessionFactory.fetchHistoryPoints(exerciseID: exerciseID, intentRaw: se.intentRaw, context: ctx)
        let lastReps = SessionFactory.lastSessionWorkingReps(exerciseID: exerciseID, intentRaw: se.intentRaw, context: ctx)
        let lastHint = PreviousMatchingIntent.fetchTopWorkingSet(exerciseID: exerciseID, intentRaw: se.intentRaw, context: ctx)
        let strategy = ProgressionStrategyFactory.make(for: se.progressionKind)
        let (_, explanation) = strategy.prescribe(
            history: history,
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE,
            lastSessionRepsArray: lastReps.isEmpty ? nil : lastReps,
            smallestIncrement: se.exercise?.smallestIncrement ?? userSettings?.defaultIncrementKg ?? 2.5,
            plates: plates,
            barWeight: barWeight,
            minCalibrationSets: userSettings?.minCalibrationSets ?? 10,
            lastSessionWeight: lastHint?.weight,
            lastSessionReps: lastHint?.reps,
            lastSessionRPE: lastHint?.rpe,
            lastSessionDate: lastHint?.sessionStartedAt
        )
        return explanation
    }

    /// "Use suggested" in the sheet: apply the prescribed weight to every
    /// open working set.
    private func useSuggested() {
        guard let prescribed = sessionExercise.prescribedWeight else { return }
        for set in WorkoutLogging.workingSets(of: sessionExercise) where !set.isComplete {
            set.weight = prescribed
            set.wasManualOverride = false
        }
        try? ctx.save()
        presentingWhy = false
    }
}
