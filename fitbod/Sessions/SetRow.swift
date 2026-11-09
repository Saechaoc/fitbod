// SetRow.swift
// fitbod
//
// One logging row. Effort expands in place only for the set being rated.

import SwiftUI
import SwiftData

/// Shared by the set row and the exercise's column headings.
enum WorkoutSetColumns {
    static let number: CGFloat = 32
    static let previous: CGFloat = 80
    static let weight: CGFloat = 60
    static let reps: CGFloat = 44
    static let effort: CGFloat = 56
    static let done: CGFloat = 44
    static let spacing: CGFloat = 6
}

public struct SetRow: View {
    @Bindable public var entry: SetEntry
    public let sessionExercise: SessionExercise
    /// Phase 3 (plan 03-08): the prescribed weight from SessionExercise.
    public let prescribed: Double?
    /// Phase 3 (plan 03-08): the full PrescriptionExplanation recomputed by
    /// SessionExerciseCard.currentExplanation().
    public let explanation: PrescriptionExplanation?
    public let onCommit: () -> Void
    public let onTapEmptyCell: () -> Void
    /// Tap on a completed checkmark: un-complete the set.
    public let onUncomplete: () -> Void
    /// A weight or reps field finished editing: persist now.
    public let onEditCommitted: () -> Void

    @State private var repsText: String = ""
    @State private var presentingSetNote: Bool = false
    @Binding private var expandedEffortSetID: UUID?
    /// While the weight field has focus, the weight it holds; the row
    /// scrolls clear of the keyboard for it. The plates for it no longer
    /// show under the row (FT-11): the plate calculator is the one place.
    @State private var enteredWeight: Double?
    @FocusState private var repsFocused: Bool

    @Environment(\.weightUnit) private var defaultUnit
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The exercise's own unit wins over the app-wide one.
    private var unit: WeightUnit {
        .effective(for: sessionExercise.exercise, default: defaultUnit)
    }

    public init(
        entry: SetEntry,
        sessionExercise: SessionExercise,
        prescribed: Double? = nil,
        explanation: PrescriptionExplanation? = nil,
        expandedEffortSetID: Binding<UUID?>,
        onCommit: @escaping () -> Void,
        onTapEmptyCell: @escaping () -> Void,
        onUncomplete: @escaping () -> Void = {},
        onEditCommitted: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.sessionExercise = sessionExercise
        self.prescribed = prescribed
        self.explanation = explanation
        self._expandedEffortSetID = expandedEffortSetID
        self.onCommit = onCommit
        self.onTapEmptyCell = onTapEmptyCell
        self.onUncomplete = onUncomplete
        self.onEditCommitted = onEditCommitted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            inputLayout {
                setActions

                PreviousColumn(
                    exerciseID: sessionExercise.exercise?.id,
                    intentRaw: sessionExercise.session?.intentRaw ?? Intent.strength.rawValue,
                    currentSessionID: sessionExercise.session?.id
                )
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : WorkoutSetColumns.previous, alignment: .leading)

                if dynamicTypeSize.isAccessibilitySize {
                    Text("Weight (\(unit.rawValue))")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                        .accessibilityHidden(true)
                }

                PrescriptionWeightCell(
                    weight: $entry.weight,
                    prescribed: prescribed,
                    range: explanation?.range,
                    unitLabel: unit.rawValue,
                    wasManualOverride: $entry.wasManualOverride,
                    isComplete: entry.isComplete,
                    onTapEmptyCell: onTapEmptyCell,
                    onEditCommitted: onEditCommitted,
                    enteredWeight: $enteredWeight
                )
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : WorkoutSetColumns.weight)
                .accessibilityIdentifier("set.weight.\(identifierSuffix)")
                // Completed set: weight/reps numerics turn bruSignal per UI-SPEC line 241
                .foregroundStyle(entry.isComplete ? Color.bruSignalText : Color.bruInk)

                if dynamicTypeSize.isAccessibilitySize {
                    Text("Reps")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                        .accessibilityHidden(true)
                }

                // Reps TextField — mono emphasis + readable signal when complete
                TextField("—", text: $repsText)                              // UI-SPEC verbatim "—"
                    .font(BRUFont.bodyEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(entry.isComplete ? Color.bruSignalText : Color.bruInk)
                    .keyboardType(.numberPad)
                    .focused($repsFocused)
                    // Reps typed into the field replace the ones it
                    // shows (T39).
                    .selectsAllOnFocus(repsFocused)
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : WorkoutSetColumns.reps)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    // The target is taller than the text field inside
                    // it, so a tap that ends the rest above or below the
                    // text gives the field focus too, and the first digit
                    // typed lands (T39, F264).
                    .onTapGesture {
                        if !entry.isComplete { onTapEmptyCell() }
                        repsFocused = true
                    }
                    .onChange(of: repsText) { _, newValue in
                        if let i = Int(newValue) {
                            entry.reps = i
                        } else if newValue.isEmpty {
                            entry.reps = 0
                        }
                    }
                    // Persist as soon as the field loses focus, not
                    // only when the set is checked off.
                    .onChange(of: repsFocused) { _, focused in
                        if !focused { onEditCommitted() }
                    }
                    // The "—" placeholder would read as "em dash".
                    .accessibilityLabel("Reps, set \(displayNumber)")
                    .accessibilityIdentifier("set.reps.\(identifierSuffix)")

                effortButton
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }

                // Completion button — SetCompletionGlyph replaces SF Symbol checkmark
                // Shared validation keeps UI and persistence behavior aligned.
                // Tapping a completed set's checkmark un-completes it.
                Button {
                    if entry.isComplete {
                        onUncomplete()
                    } else if SessionSetActions.canComplete(entry) {
                        onCommit()
                    }
                } label: {
                    SetCompletionGlyph(isComplete: entry.isComplete)
                }
                .buttonStyle(.plain)
                .frame(minWidth: WorkoutSetColumns.done, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(!entry.isComplete && !SessionSetActions.canComplete(entry))
                .accessibilityLabel(
                    entry.isComplete
                    ? "Set \(displayNumber) complete"
                    : "Mark set \(displayNumber) complete"
                )
                .accessibilityHint(entry.isComplete ? "Double tap to mark as not done" : "Enter valid reps and weight first; bodyweight exercises may use zero added weight")
                .accessibilityIdentifier("set.complete.\(identifierSuffix)")
            }

            if expandedEffortSetID == entry.id { effortPicker }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $presentingSetNote) {
            NoteSheet(
                title: "SET \(displayNumber) NOTE",
                hint: "e.g. right knee caved on rep 7",
                text: entry.notes
            ) {
                entry.notes = $0
                onEditCommitted()
            }
        }
        // While its weight or reps field has focus, the row scrolls clear
        // of the keyboard and its DONE (T125, T39).
        .revealsAboveKeyboard(enteredWeight != nil || repsFocused)
        .onAppear {
            repsText = entry.reps == 0 ? "" : String(entry.reps)
        }
        // Reps set outside the field, such as a logged set's carried
        // forward (FT-06), show unless the field is being typed in.
        .onChange(of: entry.reps) { _, reps in
            if !repsFocused { repsText = reps == 0 ? "" : String(reps) }
        }
    }

    private var inputLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: WorkoutSetColumns.spacing))
    }

    private var effortButton: some View {
        let rating = entry.rpe.map(NumberText.weight)
        let expanded = expandedEffortSetID == entry.id
        return Button {
            expandedEffortSetID = expanded ? nil : entry.id
        } label: {
            Text(dynamicTypeSize.isAccessibilitySize ? "Effort (RPE) · \(rating ?? "Add")" : rating ?? "Add")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(rating == nil ? Color.bruMuted : Color.bruSignalText)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : WorkoutSetColumns.effort)
        .accessibilityLabel("Effort (RPE), set \(displayNumber)")
        .accessibilityValue(rating ?? "No rating")
        .accessibilityHint(expanded ? "Hides the ratings" : "Shows effort ratings")
        .accessibilityIdentifier("set.effort.\(identifierSuffix)")
    }

    private var effortPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How many more reps could you have done?")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruInk)
            InlineRPEChipRow(
                rpe: Binding(
                    get: { entry.rpe },
                    set: {
                        entry.rpe = $0
                        onEditCommitted()
                        expandedEffortSetID = nil
                    }
                ),
                noneLabel: entry.rpe == nil ? nil : "Clear",
                showsRepsLeft: true
            )
            Text("Hold a rating for half steps.")
                .font(BRUFont.labelSmall)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.bruFaint)
    }

    private var setActions: some View {
        Menu {
            SetTypeMenuItems(setTypeRaw: setTypeRaw)
            Button(entry.notes?.isEmpty == false ? "Edit set note" : "Add set note") {
                presentingSetNote = true
            }
            if !entry.isComplete, let suggested = explanation?.roundedWeight, suggested.isFinite, suggested > 0 {
                Button("Use \(NumberText.weight(suggested)) \(unit.rawValue)") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                    entry.weight = suggested
                    entry.wasManualOverride = false
                    onEditCommitted()
                }
                .accessibilityIdentifier("set.useSuggested.\(identifierSuffix)")
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text(setLabel).font(BRUFont.bodyDefault)
                    Text(entry.notes?.isEmpty == false ? "✎" : "▾").font(BRUFont.labelMicro)
                }
                .foregroundStyle(Color.bruMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                if let tag = SetTypeChip.tag(for: entry.setType) {
                    Text(tag)
                        .font(BRUFont.labelMicro)
                        .foregroundStyle(Color.bruInk)
                }
            }
            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : WorkoutSetColumns.number, alignment: .leading)
            .padding(.horizontal, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -6)
        .accessibilityLabel("Set \(displayNumber) actions")
        .accessibilityValue(SetTypeChip.label(for: entry.setType))
        .accessibilityIdentifier("set.type.\(identifierSuffix)")
    }

    /// The exercise's rep range for Why-this-weight, such as 5...8, or nil
    /// when its targets make no range.
    static func targetReps(low: Int, high: Int) -> ClosedRange<Int>? {
        guard low > 0, low <= high else { return nil }
        return low...high
    }

    // MARK: - Private helpers

    /// "S1", "S2", "W1" for warmup sets — UI-SPEC § Session logger line 369.
    /// Numbered by position among sets of the same kind, so working sets
    /// start at S1 even after a warm-up ramp and stay gap-free after a
    /// set is deleted.
    private var setLabel: String {
        Self.setLabel(for: entry)
    }

    private static func setLabel(for entry: SetEntry) -> String {
        let n = SessionSetActions.displayNumber(of: entry)
        return entry.isWarmup ? "W\(n)" : "S\(n)"
    }

    private var displayNumber: Int {
        SessionSetActions.displayNumber(of: entry)
    }

    /// "{exercise position}.{set label}", e.g. "1.S2", for UI test queries.
    private var identifierSuffix: String {
        Self.identifierSuffix(for: entry, in: sessionExercise)
    }

    /// The end of a set's identifiers, such as "1.S2" for the first
    /// exercise's second working set. The set's tempo and partial-reps rows
    /// use it too.
    static func identifierSuffix(for entry: SetEntry, in sessionExercise: SessionExercise?) -> String {
        "\((sessionExercise?.orderIndex ?? 0) + 1).\(setLabel(for: entry))"
    }

    /// The set label's picker writes the type and saves.
    private var setTypeRaw: Binding<String> {
        Binding(
            get: { entry.setTypeRaw },
            set: { entry.setTypeRaw = $0; onEditCommitted() }
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("set row") {
    @Previewable @State var expandedEffortSetID: UUID?
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
    se.prescribedWeight = 100.0
    ctx.insert(se)
    let entry = SetEntry()
    entry.sessionExercise = se
    entry.weight = 100
    entry.reps = 5
    ctx.insert(entry)
    try? ctx.save()
    return List {
        SetRow(
            entry: entry,
            sessionExercise: se,
            prescribed: 100.0,
            explanation: nil,
            expandedEffortSetID: $expandedEffortSetID,
            onCommit: {},
            onTapEmptyCell: {}
        )
    }
    .modelContainer(container)
}
#endif
