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
    /// A timed row has a time and one more value, each as wide as the
    /// weight, and no reps or effort column. Last time takes the room they
    /// leave: "20:00 2.5mi" needs it.
    static let timedPrevious: CGFloat = previous + reps + effort - weight + spacing
}

public struct SetRow: View {
    @Bindable public var entry: SetEntry
    public let sessionExercise: SessionExercise
    /// Phase 3 (plan 03-08): the prescribed weight from SessionExercise.
    public let prescribed: Double?
    /// Phase 3 (plan 03-08): the full PrescriptionExplanation recomputed by
    /// SessionExerciseCard.currentExplanation().
    public let explanation: PrescriptionExplanation?
    public let suggestion: WorkoutSetSuggestion
    public let onCommit: () -> Void
    public let onTapEmptyCell: () -> Void
    /// Tap on a completed checkmark: un-complete the set.
    public let onUncomplete: () -> Void
    /// A weight or reps field finished editing: persist now.
    public let onEditCommitted: () -> Void

    @State private var repsText: String = ""
    /// A timed set's time as typed, such as "1:30", and its distance or level.
    @State private var timeText = ""
    @State private var secondText = ""
    @State private var presentingSetNote: Bool = false
    @Binding private var expandedEffortSetID: UUID?
    /// While the weight field has focus, the weight it holds; the row
    /// scrolls clear of the keyboard for it. The plates for it no longer
    /// show under the row (FT-11): the plate calculator is the one place.
    @State private var enteredWeight: Double?
    @FocusState private var repsFocused: Bool
    @FocusState private var timedFocus: TimedField?

    private enum TimedField { case time, second }

    @Environment(\.weightUnit) private var defaultUnit
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    /// The exercise's own unit wins over the app-wide one.
    private var unit: WeightUnit {
        .effective(for: sessionExercise.exercise, default: defaultUnit)
    }

    /// What the row's fields record. A set whose exercise is gone keeps the
    /// weight and reps fields.
    private var tracking: Tracking {
        sessionExercise.exercise?.tracking ?? .weightReps
    }

    public init(
        entry: SetEntry,
        sessionExercise: SessionExercise,
        prescribed: Double? = nil,
        explanation: PrescriptionExplanation? = nil,
        suggestion: WorkoutSetSuggestion = .init(),
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
        self.suggestion = suggestion
        self._expandedEffortSetID = expandedEffortSetID
        self.onCommit = onCommit
        self.onTapEmptyCell = onTapEmptyCell
        self.onUncomplete = onUncomplete
        self.onEditCommitted = onEditCommitted
    }

    public var body: some View {
        let canComplete = draftIsCurrent && SessionSetActions.canComplete(entry, suggestion: suggestion)
        VStack(alignment: .leading, spacing: 6) {
            inputLayout {
                setActions

                PreviousColumn(
                    exerciseID: sessionExercise.exercise?.id,
                    intentRaw: sessionExercise.session?.intentRaw ?? Intent.strength.rawValue,
                    currentSessionID: sessionExercise.session?.id,
                    unit: unit
                )
                .frame(width: previousWidth, alignment: .leading)

                if tracking.isTimed {
                    timedFields
                } else {
                    loadFields
                    effortButton
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }

                // Completion button — SetCompletionGlyph replaces SF Symbol checkmark
                // Shared validation keeps UI and persistence behavior aligned.
                // Tapping a completed set's checkmark un-completes it.
                Button {
                    if entry.isComplete {
                        onUncomplete()
                    } else if canComplete {
                        onCommit()
                    }
                } label: {
                    SetCompletionGlyph(isComplete: entry.isComplete)
                }
                .buttonStyle(.plain)
                .frame(minWidth: WorkoutSetColumns.done, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(!entry.isComplete && !canComplete)
                .accessibilityLabel(
                    entry.isComplete
                    ? "Set \(displayNumber) complete"
                    : "Mark set \(displayNumber) complete"
                )
                .accessibilityHint(entry.isComplete ? "Double tap to mark as not done" : completionHint)
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
        // While one of its fields has focus, the row scrolls clear of the
        // keyboard and its DONE (T125, T39).
        .revealsAboveKeyboard(enteredWeight != nil || repsFocused || timedFocus != nil)
        .onAppear {
            repsText = entry.reps == 0 ? "" : String(entry.reps)
            showStoredTimedValues()
        }
        // Reps set outside the field, such as a logged set's carried
        // forward (FT-06), show unless the field is being typed in.
        .onChange(of: entry.reps) { _, reps in
            if !repsFocused { repsText = reps == 0 ? "" : String(reps) }
        }
        // The same for a timed set's values, such as an accepted offer.
        .onChange(of: entry.durationSeconds) { _, _ in
            if timedFocus != .time { timeText = storedTimeText }
        }
        .onChange(of: entry.distanceMeters) { _, _ in
            if timedFocus != .second { secondText = storedSecondText }
        }
        .onChange(of: entry.level) { _, _ in
            if timedFocus != .second { secondText = storedSecondText }
        }
        // A timed field that finished editing shows the value as stored
        // ("90" typed reads "1:30") and persists now.
        .onChange(of: timedFocus) { previous, _ in
            guard previous != nil else { return }
            showStoredTimedValues()
            onEditCommitted()
        }
    }

    // MARK: - Fields

    private var previousWidth: CGFloat? {
        if dynamicTypeSize.isAccessibilitySize { return nil }
        return tracking.isTimed ? WorkoutSetColumns.timedPrevious : WorkoutSetColumns.previous
    }

    /// The text in the reps or time field is the value Done would save, so
    /// an unreadable draft keeps Done off.
    private var draftIsCurrent: Bool {
        if tracking.isTimed {
            return timeText.isEmpty
                || SetText.seconds(fromTyped: timeText) == suggestion.durationSeconds(for: entry)
        }
        return repsText.isEmpty || Int(repsText) == suggestion.reps(for: entry)
    }

    private var completionHint: String {
        switch tracking {
        case .weightReps: "Enter a weight and reps first"
        case .reps: "Enter reps first; added weight is optional"
        case .assistedReps: "Enter reps first; assistance is optional"
        case .duration, .durationDistance, .durationLevel: "Enter a time first"
        }
    }

    /// A field's name above it in the stacked accessibility-size layout,
    /// which has no column headings.
    @ViewBuilder
    private func stackedLabel(_ text: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(text)
                .font(BRUFont.labelSmall)
                .foregroundStyle(Color.bruMuted)
                .accessibilityHidden(true)
        }
    }

    /// Weight and reps, as most lifts log them. An assisted exercise shows
    /// its assistance in the weight cell.
    @ViewBuilder
    private var loadFields: some View {
        let assisted = tracking == .assistedReps
        let repsOffer = entry.isComplete ? nil : suggestion.reps
        let repsPrompt = repsOffer.map { String($0) } ?? "—"

        stackedLabel("\(assisted ? "Assistance" : "Weight") (\(unit.rawValue))")
        weightCell(assisted: assisted)
        stackedLabel("Reps")

        // Reps TextField: mono emphasis + readable signal when complete
        TextField("Reps", text: $repsText, prompt: Text(repsPrompt).foregroundStyle(Color.bruMuted))
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
            .accessibilityValue(repsText.isEmpty ? repsPrompt : repsText)
            .accessibilityHint(repsOffer != nil && repsText.isEmpty ? "Suggested reps. Tap to edit." : "")
            .accessibilityIdentifier("set.reps.\(identifierSuffix)")
    }

    /// The set's load. Assistance is stored as a negative weight
    /// (ARCHITECTURE.md) and shown and typed as a positive number.
    private func weightCell(assisted: Bool = false) -> some View {
        PrescriptionWeightCell(
            weight: assisted ? assistance : $entry.weight,
            prescribed: assisted ? nil : prescribed,
            range: explanation?.range,
            offeredWeight: assisted ? suggestion.weight.map { -$0 } : suggestion.weight,
            unitLabel: unit.rawValue,
            label: assisted ? "Assistance" : "Weight",
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
    }

    private var assistance: Binding<Double> {
        Binding(
            get: { entry.weight == 0 ? 0 : -entry.weight },
            set: { entry.weight = $0 == 0 ? 0 : -$0 }
        )
    }

    /// A timed set: its time, then an optional load, a distance or a level.
    /// A field writes its value only while it is being typed in: the text
    /// it shows is rounded, and must not be read back over the stored value.
    @ViewBuilder
    private var timedFields: some View {
        let offered = entry.isComplete ? WorkoutSetSuggestion() : suggestion

        stackedLabel("Time")
        valueField("Time", text: $timeText, offer: offered.durationSeconds.map(SetText.duration), field: .time)
            .keyboardType(.numberPad)
            .onChange(of: timeText) { _, text in
                // Digits read as a time while they are typed: "130" shows
                // "1:30". The value is written in this same pass: SwiftUI
                // does not call back for the text this action sets.
                let entered = SetText.timeEntry(text)
                if entered != text { timeText = entered }
                if timedFocus == .time { entry.durationSeconds = SetText.seconds(fromTyped: entered) }
            }
            .accessibilityIdentifier("set.time.\(identifierSuffix)")

        switch sessionExercise.exercise?.timedValue {
        case .weight:
            stackedLabel("Weight (\(unit.rawValue))")
            weightCell()
        case .distance:
            let name = SetText.distanceUnit(unit)
            stackedLabel("Distance (\(name))")
            valueField(
                "Distance in \(name)", text: $secondText,
                offer: offered.distanceMeters.map { SetText.distance($0, unit: unit) }, field: .second
            )
            .keyboardType(.decimalPad)
            .onChange(of: secondText) { _, text in
                if timedFocus == .second {
                    entry.distanceMeters = SetText.meters(fromTyped: text, unit: unit, locale: locale)
                }
            }
            .accessibilityIdentifier("set.distance.\(identifierSuffix)")
        case .level:
            stackedLabel("Level")
            valueField("Level", text: $secondText, offer: offered.level.map(NumberText.weight), field: .second)
                .keyboardType(.decimalPad)
                .onChange(of: secondText) { _, text in
                    if timedFocus == .second {
                        entry.level = SetText.number(fromTyped: text, locale: locale)
                    }
                }
                .accessibilityIdentifier("set.level.\(identifierSuffix)")
        case nil:
            EmptyView()
        }
    }

    /// One of a timed set's text fields, styled like the reps field and as
    /// wide as the weight.
    private func valueField(
        _ title: String, text: Binding<String>, offer: String?, field: TimedField
    ) -> some View {
        TextField(title, text: text, prompt: Text(offer ?? "—").foregroundStyle(Color.bruMuted))
            .font(BRUFont.bodyEmphasis)
            .monospacedDigit()
            .foregroundStyle(entry.isComplete ? Color.bruSignalText : Color.bruInk)
            .focused($timedFocus, equals: field)
            .selectsAllOnFocus(timedFocus == field)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : WorkoutSetColumns.weight)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            // A tap anywhere in the tall target ends the rest and gives
            // the field focus, as for reps (T39, F264).
            .onTapGesture {
                if !entry.isComplete { onTapEmptyCell() }
                timedFocus = field
            }
            .accessibilityLabel("\(title), set \(displayNumber)")
            .accessibilityValue(text.wrappedValue.isEmpty ? offer ?? "none" : text.wrappedValue)
            .accessibilityHint(offer != nil && text.wrappedValue.isEmpty ? "From your last set. Tap to edit." : "")
    }

    private var storedTimeText: String {
        entry.durationSeconds.map(SetText.duration) ?? ""
    }

    private var storedSecondText: String {
        switch sessionExercise.exercise?.timedValue {
        case .distance: entry.distanceMeters.map { SetText.distance($0, unit: unit) } ?? ""
        case .level: entry.level.map(NumberText.weight) ?? ""
        case .weight, nil: ""
        }
    }

    private func showStoredTimedValues() {
        timeText = storedTimeText
        secondText = storedSecondText
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
                // Orange marks logged values, as the weight and reps beside it.
                .foregroundStyle(rating == nil ? Color.bruMuted : entry.isComplete ? Color.bruSignalText : Color.bruInk)
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
            if !entry.isComplete, let suggested = explanation?.suggestedWeight {
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
