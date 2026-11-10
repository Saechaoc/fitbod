// WorkoutEditView.swift
// fitbod
//
// Edit workout: corrects a finished workout, opened by EDIT on its summary
// (docs/design-map/mockups/history-editing.html, approved 2026-11-01).
//
// Date and Start move the whole workout. Each logged set's weight, reps and
// RPE can change, − deletes a set and + Add set appends a copy of the last.
// A timed set edits its time and its load, distance or level instead, and
// an assisted set its assistance. A changed value shows what was logged.
// The workout's length stays as logged and the exercises stay as they are
// (docs/ROADMAP.md, "Decided").
//
// Nothing is written while editing: SAVE makes one SessionEditService save
// and returns to the summary; CANCEL asks first when anything changed.
// Delete workout asks, deletes, and leaves for the list the summary came
// from. The body reads only the draft, never the workout, so a delete
// cannot make it read a deleted row.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor
//               NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)

import SwiftUI
import SwiftData

struct WorkoutEditView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.locale) private var locale
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?

    private let session: Session
    private let onDeleted: () -> Void

    @State private var draft: WorkoutEditDraft
    @State private var picking: StartPart?
    @State private var confirmingCancel = false
    @State private var confirmingDelete = false
    @State private var failure: String?
    @State private var invalidRows: Set<UUID> = []

    init(session: Session, onDeleted: @escaping () -> Void) {
        self.session = session
        self.onDeleted = onDeleted
        _draft = State(initialValue: WorkoutEditDraft(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                startRow
                BRUDivider(.ink)
                BRUSectionHead("Exercises", right: "\(draft.exercises.count)")
                ForEach(draft.exercises) { exercise in
                    exerciseBlock(exercise)
                    BRUDivider(.hair)
                }
                BRUButton("Delete workout", kind: .ghost, size: .lg) { confirmingDelete = true }
                    .accessibilityIdentifier("edit.delete")
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("Cancel") { cancel() },
                center: "Edit workout",
                right: HeaderAction("Save", isSignal: true, isEnabled: draft.hasChanges && invalidRows.isEmpty) { save() }
            )
        }
        // Number pads have no return key (T39).
        .keyboardDone()
        .sheet(item: $picking) { part in
            startPicker(part)
        }
        .confirmationDialog("Discard changes?", isPresented: $confirmingCancel, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .confirmationDialog("Delete this workout?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) { deleteWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its sets leave your history, records and volume. This can't be undone.")
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            )
        ) {
            Button("OK", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Editing")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            Text(draft.name)
                .font(BRUFont.displayLarge)
                .tracking(-0.3)
                .foregroundStyle(Color.bruInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var startRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                startCell("Date", value: draft.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), part: .date)
                startCell("Start", value: draft.startedAt.formatted(date: .omitted, time: .shortened), part: .time)
            }
            if draft.startedAt != draft.loggedStart {
                Text("Was " + draft.loggedStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func startCell(_ label: String, value: String, part: StartPart) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BRUFont.labelMicro)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
                .accessibilityHidden(true)
            Button {
                picking = part
            } label: {
                HStack(spacing: 4) {
                    Text(value)
                        .font(BRUFont.bodyEmphasis)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text("›")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(Rectangle().strokeBorder(Color.bruInk, lineWidth: 1.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label), \(value)")
            .accessibilityIdentifier("edit.\(part.rawValue)")
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseBlock(_ exercise: WorkoutEditDraft.Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(setsLine(exercise.rows, unit: exercise.unitOverride ?? weightUnit))
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .accessibilityElement(children: .combine)
            ForEach(Array(exercise.rows.enumerated()), id: \.element.id) { index, row in
                // Column names sit over each run of rows of one shape: a
                // retagged exercise can hold rep sets and timed sets.
                let previous = index > 0 ? exercise.rows[index - 1] : nil
                if previous?.isTimed != row.isTimed || previous?.isAssisted != row.isAssisted {
                    WorkoutEditGrid.header(for: row, timedValue: exercise.timedValue, unit: exercise.unitOverride ?? weightUnit)
                }
                WorkoutEditSetRow(
                    number: index + 1,
                    row: row,
                    timedValue: exercise.timedValue,
                    unit: exercise.unitOverride ?? weightUnit,
                    locale: locale,
                    onChange: { values, valid in update(row.id, in: exercise.id, to: values, isValid: valid) },
                    onDelete: {
                        invalidRows.remove(row.id)
                        draft.deleteRow(row.id, from: exercise.id)
                    }
                )
            }
            Button {
                draft.addSet(to: exercise.id)
            } label: {
                Text("+ Add set")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a set to \(exercise.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func startPicker(_ part: StartPart) -> some View {
        // The workout keeps its length, so it may start no later than its
        // length before now.
        let latest = Date.now.addingTimeInterval(-draft.duration)
        VStack(spacing: 0) {
            BRUHeaderBar(
                center: part == .date ? "Date" : "Start",
                right: HeaderAction("Done", isSignal: true) { picking = nil }
            )
            if part == .date {
                DatePicker("Date", selection: $draft.startedAt, in: ...latest, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 16)
            } else {
                DatePicker("Start", selection: $draft.startedAt, in: ...latest, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            Spacer(minLength: 0)
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .presentationDetents([part == .date ? .large : .medium])
    }

    // MARK: - Actions

    private func update(_ rowID: UUID, in exerciseID: UUID, to values: WorkoutEdit.Values, isValid: Bool) {
        guard let e = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let r = draft.exercises[e].rows.firstIndex(where: { $0.id == rowID })
        else { return }
        draft.exercises[e].rows[r].values = values
        if isValid {
            invalidRows.remove(rowID)
        } else {
            invalidRows.insert(rowID)
        }
    }

    private func cancel() {
        if draft.hasChanges || !invalidRows.isEmpty {
            confirmingCancel = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard draft.hasChanges, invalidRows.isEmpty else { return }
        do {
            try SessionEditService.save(draft.edit, to: session, context: ctx)
        } catch SessionEditError.invalidSet {
            failure = "Each set needs reps above zero, and a weight above zero unless the exercise is bodyweight or assisted. A timed set needs a time."
            return
        } catch SessionEditError.endsInFuture {
            failure = "A workout can't end in the future. Pick an earlier date or start."
            return
        } catch {
            failure = "The changes weren't saved. Try again."
            return
        }
        historyEdits?.recordSave()
        dismiss()
    }

    private func deleteWorkout() {
        do {
            try SessionSetActions.deleteWorkout(session, context: ctx)
        } catch {
            failure = "The workout wasn't deleted. Try again."
            return
        }
        historyEdits?.recordSave()
        onDeleted()
    }

    // MARK: - Formatting

    private func setsLine(_ rows: [WorkoutEditDraft.Row], unit: WeightUnit) -> String {
        let volume = rows.reduce(0) { $0 + SetEntry.tonnage(weight: $1.values.weight, reps: $1.values.reps) }
        return SessionHistoryFormat.setsLine(count: rows.count, volume: volume, unit: unit)
    }

    enum StartPart: String, Identifiable {
        case date, time
        var id: String { rawValue }
    }
}

// MARK: - Set grid

/// Column widths shared by the grid head and its rows.
private enum WorkoutEditGrid {
    static let number: CGFloat = 28
    static let small: CGFloat = 60
    static let delete: CGFloat = 44
    static let spacing: CGFloat = 8
    /// A timed row's second field spans the reps and RPE columns.
    static let wide: CGFloat = small * 2 + spacing

    /// The column names over rows shaped like `row`.
    static func header(for row: WorkoutEditDraft.Row, timedValue: TimedValue?, unit: WeightUnit) -> some View {
        HStack(spacing: spacing) {
            Text("S").frame(width: number, alignment: .leading)
            if row.isTimed {
                Text("Time").frame(maxWidth: .infinity, alignment: .leading)
                if let name = secondName(timedValue, unit: unit) {
                    Text(name).frame(width: wide, alignment: .leading)
                }
            } else {
                Text(row.isAssisted ? "Assist" : "Weight").frame(maxWidth: .infinity, alignment: .leading)
                Text("Reps").frame(width: small, alignment: .leading)
                Text("RPE").frame(width: small, alignment: .leading)
            }
            Color.clear.frame(width: delete, height: 1)
        }
        .font(BRUFont.labelMicro)
        .tracking(1.5)
        .textCase(.uppercase)
        .foregroundStyle(Color.bruMuted)
        .accessibilityHidden(true)
    }

    /// A timed row's second field, as its column and VoiceOver name it.
    static func secondName(_ value: TimedValue?, unit: WeightUnit) -> String? {
        switch value {
        case .weight: "Weight"
        case .distance: unit == .lb ? "Miles" : "Km"
        case .level: "Level"
        case nil: nil
        }
    }
}

/// One set in the grid: weight and reps fields, an RPE menu and −; a timed
/// set has its time and its load, distance or level. A value that differs
/// from the logged one gets a 2pt ink border, and the row says what was
/// logged.
private struct WorkoutEditSetRow: View {
    let number: Int
    let row: WorkoutEditDraft.Row
    let timedValue: TimedValue?
    let unit: WeightUnit
    let locale: Locale
    let onChange: (WorkoutEdit.Values, Bool) -> Void
    let onDelete: () -> Void

    /// The values a field's text is compared with: the logged ones, or an
    /// added row's current ones. A field whose text still matches keeps its
    /// value from here: a shown distance is rounded and assistance shows
    /// without its sign, so neither may be read back from the text.
    private var opened: WorkoutEdit.Values { row.logged ?? row.values }
    @State private var weightText: String
    @State private var repsText: String
    @State private var timeText: String
    @State private var secondText: String
    @FocusState private var focus: Field?

    private enum Field { case weight, reps, time, second }

    private static let rpeOptions: [Double] = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    init(
        number: Int,
        row: WorkoutEditDraft.Row,
        timedValue: TimedValue?,
        unit: WeightUnit,
        locale: Locale,
        onChange: @escaping (WorkoutEdit.Values, Bool) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.number = number
        self.row = row
        self.timedValue = timedValue
        self.unit = unit
        self.locale = locale
        self.onChange = onChange
        self.onDelete = onDelete
        _weightText = State(initialValue: Self.weightText(row.values, locale: locale))
        _repsText = State(initialValue: Self.repsText(row.values))
        _timeText = State(initialValue: Self.timeText(row.values))
        _secondText = State(initialValue: Self.secondText(row.values, timedValue, unit: unit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: WorkoutEditGrid.spacing) {
                Text("S\(number)")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruMuted)
                    .frame(width: WorkoutEditGrid.number, alignment: .leading)
                    .accessibilityHidden(true)
                if row.isTimed {
                    timedFields
                } else {
                    field($weightText, .weight, keyboard: .decimalPad, changed: row.logged.map { $0.weight != row.values.weight } ?? false)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(row.isAssisted ? "Assistance" : "Weight"), set \(number)")
                    field($repsText, .reps, keyboard: .numberPad, changed: row.logged.map { $0.reps != row.values.reps } ?? false)
                        .frame(width: WorkoutEditGrid.small)
                        .accessibilityLabel("Reps, set \(number)")
                    rpeMenu
                }
                Button(action: onDelete) {
                    Text("−")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                        .frame(width: WorkoutEditGrid.delete, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete set \(number)")
            }
            if row.isChanged, let logged = row.logged {
                Text("Was \(Self.label(logged, unit: unit))")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.leading, WorkoutEditGrid.number + WorkoutEditGrid.spacing)
            }
        }
        .onAppear { updateValues(rpe: row.values.rpe) }
        .onChange(of: [weightText, repsText, timeText, secondText]) { _, _ in updateValues(rpe: row.values.rpe) }
    }

    /// The time, then the load, distance or level its exercise's timed sets take.
    @ViewBuilder
    private var timedFields: some View {
        field($timeText, .time, keyboard: .numberPad, changed: row.logged.map { $0.durationSeconds != row.values.durationSeconds } ?? false)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Time, set \(number)")
            // Digits read as a time while they are typed: "130" shows "1:30".
            .onChange(of: timeText) { _, text in
                let entered = SetText.timeEntry(text)
                if entered != text { timeText = entered }
            }
        if let name = WorkoutEditGrid.secondName(timedValue, unit: unit) {
            let changed = row.logged.map {
                $0.weight != row.values.weight || $0.distanceMeters != row.values.distanceMeters || $0.level != row.values.level
            } ?? false
            field(timedValue == .weight ? $weightText : $secondText, timedValue == .weight ? .weight : .second, keyboard: .decimalPad, changed: changed)
                .frame(width: WorkoutEditGrid.wide)
                .accessibilityLabel("\(name), set \(number)")
        } else {
            // A time alone stays as wide as a time beside a second value.
            Color.clear.frame(width: WorkoutEditGrid.wide, height: 1)
        }
    }

    private func field(_ text: Binding<String>, _ field: Field, keyboard: UIKeyboardType, changed: Bool) -> some View {
        TextField("—", text: text)
            .font(BRUFont.bodyEmphasis)
            .monospacedDigit()
            .foregroundStyle(Color.bruInk)
            .keyboardType(keyboard)
            .focused($focus, equals: field)
            // A typed number replaces the value the field shows (T39).
            .selectsAllOnFocus(focus == field)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background(Color.bruBg2)
            .overlay(Rectangle().strokeBorder(changed ? Color.bruInk : Color.bruHair, lineWidth: changed ? 2 : 1))
            .contentShape(Rectangle())
            .onTapGesture { focus = field }
    }

    private var rpeMenu: some View {
        let changed = row.logged.map { $0.rpe != row.values.rpe } ?? false
        return Menu {
            Button("No RPE") { setRPE(nil) }
            ForEach(Self.rpeOptions, id: \.self) { value in
                Button(NumberText.weight(value)) { setRPE(value) }
            }
        } label: {
            Text(row.values.rpe.map(NumberText.weight) ?? "—")
                .font(BRUFont.bodyEmphasis)
                .monospacedDigit()
                .foregroundStyle(Color.bruInk)
                .frame(width: WorkoutEditGrid.small, height: 44)
                .background(Color.bruBg2)
                .overlay(Rectangle().strokeBorder(changed ? Color.bruInk : Color.bruHair, lineWidth: changed ? 2 : 1))
        }
        .accessibilityLabel("RPE, set \(number)")
        .accessibilityValue(row.values.rpe.map(NumberText.weight) ?? "none")
    }

    private func setRPE(_ rpe: Double?) {
        updateValues(rpe: rpe)
    }

    /// Sends the row's values and whether every field reads. A field writes
    /// only once its text has changed; a rep row that changed at all takes
    /// the sign its weight column stands for.
    private func updateValues(rpe: Double?) {
        var values = opened
        var isValid = true
        if row.isTimed {
            let seconds = SetText.seconds(fromTyped: timeText)
            isValid = seconds != nil
            if timeText != Self.timeText(opened), let seconds { values.durationSeconds = seconds }
            switch timedValue {
            case .weight:
                isValid = readWeight(into: &values) && isValid
            case .distance, .level:
                let number = SetText.number(fromTyped: secondText, locale: locale)
                isValid = (secondText.isEmpty || number != nil) && isValid
                if secondText != Self.secondText(opened, timedValue, unit: unit) {
                    if timedValue == .level {
                        values.level = number
                    } else {
                        values.distanceMeters = SetText.meters(fromTyped: secondText, unit: unit, locale: locale)
                    }
                }
            case nil:
                break
            }
        } else {
            let reps = WorkoutCorrectionInput.reps(repsText)
            isValid = readWeight(into: &values) && reps != nil
            if repsText != Self.repsText(opened), let reps { values.reps = reps }
        }
        values.rpe = rpe
        if !row.isTimed, values != opened {
            values.weight = WorkoutEditDraft.signed(values.weight, assisted: row.isAssisted)
        }
        onChange(values, isValid)
    }

    /// Reads the weight field, which holds a size without a sign.
    private func readWeight(into values: inout WorkoutEdit.Values) -> Bool {
        guard let weight = WorkoutCorrectionInput.weight(weightText, locale: locale) else { return false }
        if weightText != Self.weightText(opened, locale: locale) { values.weight = weight }
        return true
    }

    // MARK: - Field text

    private static func weightText(_ values: WorkoutEdit.Values, locale: Locale) -> String {
        WorkoutCorrectionInput.weightText(abs(values.weight), locale: locale)
    }

    private static func repsText(_ values: WorkoutEdit.Values) -> String {
        values.reps > 0 ? "\(values.reps)" : ""
    }

    private static func timeText(_ values: WorkoutEdit.Values) -> String {
        values.durationSeconds.map(SetText.duration) ?? ""
    }

    private static func secondText(_ values: WorkoutEdit.Values, _ timedValue: TimedValue?, unit: WeightUnit) -> String {
        switch timedValue {
        case .distance: values.distanceMeters.map { SetText.distance($0, unit: unit) } ?? ""
        case .level: values.level.map(NumberText.weight) ?? ""
        case .weight, nil: ""
        }
    }

    private static func label(_ values: WorkoutEdit.Values, unit: WeightUnit) -> String {
        let base = SetText.result(
            weight: values.weight, reps: values.reps,
            durationSeconds: values.durationSeconds, distanceMeters: values.distanceMeters, level: values.level,
            unit: unit
        )
        return values.rpe.map { "\(base) @ \(NumberText.weight($0))" } ?? base
    }
}
