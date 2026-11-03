// WorkoutEditView.swift
// fitbod
//
// Edit workout: corrects a finished workout, opened by EDIT on its summary
// (docs/design-map/mockups/history-editing.html, approved 2026-11-01).
//
// Date and Start move the whole workout. Each logged set's weight, reps and
// RPE can change, − deletes a set and + Add set appends a copy of the last.
// A changed value shows what was logged. Duration stays as logged and the
// exercises stay as they are (docs/ROADMAP.md, "Decided").
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
    @Environment(HistoryEdits.self) private var historyEdits: HistoryEdits?

    private let session: Session
    private let onDeleted: () -> Void

    @State private var draft: WorkoutEditDraft
    @State private var picking: StartPart?
    @State private var confirmingCancel = false
    @State private var confirmingDelete = false
    @State private var failure: String?

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
                right: HeaderAction("Save", isSignal: true, isEnabled: draft.hasChanges) { save() }
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
                Text(setsLine(exercise.rows))
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .accessibilityElement(children: .combine)
            if !exercise.rows.isEmpty {
                WorkoutEditGrid.header
            }
            ForEach(Array(exercise.rows.enumerated()), id: \.element.id) { index, row in
                WorkoutEditSetRow(
                    number: index + 1,
                    row: row,
                    onChange: { values in update(row.id, in: exercise.id, to: values) },
                    onDelete: { draft.deleteRow(row.id, from: exercise.id) }
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

    private func update(_ rowID: UUID, in exerciseID: UUID, to values: WorkoutEdit.Values) {
        guard let e = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let r = draft.exercises[e].rows.firstIndex(where: { $0.id == rowID })
        else { return }
        draft.exercises[e].rows[r].values = values
    }

    private func cancel() {
        if draft.hasChanges {
            confirmingCancel = true
        } else {
            dismiss()
        }
    }

    private func save() {
        do {
            try SessionEditService.save(draft.edit, to: session, context: ctx)
        } catch SessionEditError.invalidSet {
            failure = "Each set needs reps above zero, and a weight above zero unless the exercise is bodyweight."
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

    private func setsLine(_ rows: [WorkoutEditDraft.Row]) -> String {
        let sets = BRUCountLabel.text(rows.count, "set")
        let volume = rows.reduce(0) { $0 + $1.values.weight * Double($1.values.reps) }
        guard volume > 0 else { return sets }
        return "\(sets) · \(Int(volume.rounded()).formatted(.number.grouping(.automatic))) \(weightUnit.rawValue)"
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

    static var header: some View {
        HStack(spacing: 8) {
            Text("S").frame(width: number, alignment: .leading)
            Text("Weight").frame(maxWidth: .infinity, alignment: .leading)
            Text("Reps").frame(width: small, alignment: .leading)
            Text("RPE").frame(width: small, alignment: .leading)
            Color.clear.frame(width: delete, height: 1)
        }
        .font(BRUFont.labelMicro)
        .tracking(1.5)
        .textCase(.uppercase)
        .foregroundStyle(Color.bruMuted)
        .accessibilityHidden(true)
    }
}

/// One set in the grid: weight and reps fields, an RPE menu and −. A value
/// that differs from the logged one gets a 2pt ink border, and the row
/// says what was logged.
private struct WorkoutEditSetRow: View {
    let number: Int
    let row: WorkoutEditDraft.Row
    let onChange: (WorkoutEdit.Values) -> Void
    let onDelete: () -> Void

    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var focus: Field?

    private enum Field { case weight, reps }

    private static let rpeOptions: [Double] = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    init(
        number: Int,
        row: WorkoutEditDraft.Row,
        onChange: @escaping (WorkoutEdit.Values) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.number = number
        self.row = row
        self.onChange = onChange
        self.onDelete = onDelete
        _weightText = State(initialValue: Self.text(row.values.weight))
        _repsText = State(initialValue: row.values.reps > 0 ? "\(row.values.reps)" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("S\(number)")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruMuted)
                    .frame(width: WorkoutEditGrid.number, alignment: .leading)
                    .accessibilityHidden(true)
                field($weightText, .weight, keyboard: .decimalPad, changed: row.logged.map { $0.weight != row.values.weight } ?? false)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Weight, set \(number)")
                    .onChange(of: weightText) { _, text in
                        var values = row.values
                        values.weight = Double(text) ?? 0
                        onChange(values)
                    }
                field($repsText, .reps, keyboard: .numberPad, changed: row.logged.map { $0.reps != row.values.reps } ?? false)
                    .frame(width: WorkoutEditGrid.small)
                    .accessibilityLabel("Reps, set \(number)")
                    .onChange(of: repsText) { _, text in
                        var values = row.values
                        values.reps = Int(text) ?? 0
                        onChange(values)
                    }
                rpeMenu
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
                Text("Was \(Self.label(logged))")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .padding(.leading, WorkoutEditGrid.number + 8)
            }
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
                Button(Self.text(value)) { setRPE(value) }
            }
        } label: {
            Text(row.values.rpe.map(Self.text) ?? "—")
                .font(BRUFont.bodyEmphasis)
                .monospacedDigit()
                .foregroundStyle(Color.bruInk)
                .frame(width: WorkoutEditGrid.small, height: 44)
                .background(Color.bruBg2)
                .overlay(Rectangle().strokeBorder(changed ? Color.bruInk : Color.bruHair, lineWidth: changed ? 2 : 1))
        }
        .accessibilityLabel("RPE, set \(number)")
        .accessibilityValue(row.values.rpe.map(Self.text) ?? "none")
    }

    private func setRPE(_ rpe: Double?) {
        var values = row.values
        values.rpe = rpe
        onChange(values)
    }

    private static func text(_ value: Double) -> String {
        String(format: "%g", value)
    }

    private static func label(_ values: WorkoutEdit.Values) -> String {
        let base = "\(text(values.weight)) × \(values.reps)"
        return values.rpe.map { "\(base) @ \(text($0))" } ?? base
    }
}
