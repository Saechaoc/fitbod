// SetRow.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 33).
// UI-SPEC v2 § Session logger line 367-389.
//
// Per-set logging row, two lines:
//   [S{N}] [Previous] [Weight] [Reps] [✎] [SetCompletionGlyph]
//   [WHY, open sets only] [RPE chips] [SetTypeChip]
//
// KEY CHANGES from v1:
//   - SF Symbol checkmark.circle.fill → SetCompletionGlyph(isComplete:)
//   - SF Symbol square.and.pencil     → Text("✎") typographic glyph
//   - system accent color → removed; completed numerics override to bruSignal
//   - .font(.body) / .font(.title2) / .font(.caption) → BRUFont.*
//   - Both action buttons wrapped in .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
//     per UI-SPEC line 79 + T-02.1-03-03 touch-target mitigation
//
// PRESERVED VERBATIM:
//   - @Bindable SetEntry + all closures (onCommit, onTapEmptyCell)
//   - Shared commit validation; zero added weight is valid for bodyweight.
//   - Haptic on commit (T-02.1-07-03)
//   - PrescriptionWeightCell wiring + PlateStackDisclosure
//   - Per-set notes sheet (PerSetNoteSheet)
//   - Numeric weight keyboard; milestone entries use non-negative added load.
//   - accessibilityLabel on note button + completion button
//
// BRU contract: NO capsule shapes / NO RoundedRectangle / NO accent color
//               NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//               NO bordered button style / NO Color(.system*)

import SwiftUI
import SwiftData

public struct SetRow: View {
    @Bindable public var entry: SetEntry
    public let sessionExercise: SessionExercise
    /// Phase 3 (plan 03-08): the prescribed weight from SessionExercise.
    public let prescribed: Double?
    /// Phase 3 (plan 03-08): the full PrescriptionExplanation recomputed by
    /// SessionExerciseCard.currentExplanation().
    public let explanation: PrescriptionExplanation?
    /// Phase 3 (plan 03-08): single-disclosure-at-a-time coordination.
    @Binding public var expandedPlateSetID: UUID?
    public let onCommit: () -> Void
    public let onTapEmptyCell: () -> Void
    /// Tap on a completed checkmark: un-complete the set.
    public let onUncomplete: () -> Void
    /// A weight or reps field finished editing: persist now.
    public let onEditCommitted: () -> Void

    @State private var repsText: String = ""
    @State private var presentingSetNote: Bool = false
    /// The WHY control opens Why-this-weight; the weight cell presents it.
    @State private var explainingWeight: Bool = false
    @FocusState private var repsFocused: Bool

    @Query private var inventories: [PlateInventory]
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
        expandedPlateSetID: Binding<UUID?> = .constant(nil),
        onCommit: @escaping () -> Void,
        onTapEmptyCell: @escaping () -> Void,
        onUncomplete: @escaping () -> Void = {},
        onEditCommitted: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.sessionExercise = sessionExercise
        self.prescribed = prescribed
        self.explanation = explanation
        self._expandedPlateSetID = expandedPlateSetID
        self.onCommit = onCommit
        self.onTapEmptyCell = onTapEmptyCell
        self.onUncomplete = onUncomplete
        self.onEditCommitted = onEditCommitted
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: Main set row — two-line layout (approved 2026-06-10)
            // Single-line layout overflowed all device widths (~532pt required,
            // ~350pt available on 390pt devices). RPE chips + SetTypeChip move
            // to line 2, indented to align under the PREV column.
            VStack(alignment: .leading, spacing: 6) {
                // LINE 1 — numbers + action buttons
                inputLayout {
                    // S{N} / W{N} leading label — BRUFont.bodyDefault per UI-SPEC line 369
                    // A tap opens the set-type menu; a working set has no
                    // set-type chip, so this is where its type changes.
                    Menu {
                        SetTypeMenuItems(setTypeRaw: setTypeRaw)
                    } label: {
                        Text(setLabel)
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 32, alignment: .leading)
                            // A 44pt target over the 32pt column; the
                            // negative padding below keeps the layout.
                            .padding(.horizontal, 6)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, -6)
                    .accessibilityLabel("Set \(displayNumber) type")
                    .accessibilityValue(SetTypeChip.label(for: SetType(rawValue: entry.setTypeRaw) ?? .working))
                    .accessibilityIdentifier("set.type.\(identifierSuffix)")

                    PreviousColumn(
                        exerciseID: sessionExercise.exercise?.id,
                        intentRaw: sessionExercise.session?.intentRaw ?? Intent.strength.rawValue,
                        currentSessionID: sessionExercise.session?.id
                    )
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 80, alignment: .leading)

                    if dynamicTypeSize.isAccessibilitySize {
                        Text("Weight (\(unit.rawValue))")
                            .font(BRUFont.labelSmall)
                            .foregroundStyle(Color.bruMuted)
                            .accessibilityHidden(true)
                    }

                    // Weight cell — PrescriptionWeightCell handles prescribed/range/override display.
                    // Tap on cell area (not info icon) toggles plate stack disclosure.
                    PrescriptionWeightCell(
                        weight: $entry.weight,
                        prescribed: prescribed,
                        range: explanation?.range,
                        explanation: explanation,
                        targetReps: Self.targetReps(
                            low: sessionExercise.targetRepsLow,
                            high: sessionExercise.targetRepsHigh
                        ),
                        targetRPE: sessionExercise.targetRPE,
                        setType: entry.setType,
                        unitLabel: unit.rawValue,
                        wasManualOverride: $entry.wasManualOverride,
                        isComplete: entry.isComplete,
                        onTapEmptyCell: onTapEmptyCell,
                        onEditCommitted: onEditCommitted,
                        isExplaining: $explainingWeight
                    )
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 60)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        togglePlateDisclosure()
                        if !entry.isComplete { onTapEmptyCell() }
                    }
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
                        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 44)
                        .frame(minHeight: 44)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !entry.isComplete { onTapEmptyCell() }
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

                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }

                    // Per-set notes button — typographic "✎" glyph (NOT SF Symbol)
                    // per UI-SPEC line 199: "square.and.pencil → '✎' glyph"
                    Button {
                        presentingSetNote = true
                    } label: {
                        Text("✎")
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(entry.notes != nil ? Color.bruInk : Color.bruMuted)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)                          // UI-SPEC HIG 44pt
                    .contentShape(Rectangle())
                    .accessibilityLabel("Note for set \(displayNumber)")         // UI-SPEC verbatim a11y
                    .sheet(isPresented: $presentingSetNote) {
                        PerSetNoteSheet(entry: entry)
                    }

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
                    .frame(minWidth: 44, minHeight: 44)                          // UI-SPEC HIG 44pt
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

                // LINE 2 — WHY + RPE chips + set-type chip
                // WHY takes the 40pt indent under the set label, so the chips
                // move 10pt right and line 2 still fits a set-type chip at
                // 390pt. Rows without an explanation keep the indent, which
                // aligns the chips under the PREV column. A logged set shows
                // no WHY but keeps its space, so its chips stay in line with
                // the open sets'; at AX sizes WHY has a line of its own,
                // which a logged set drops.
                inputLayout {
                    if explanation != nil {
                        if !entry.isComplete {
                            whyButton
                        } else if !dynamicTypeSize.isAccessibilitySize {
                            whyButton
                                .hidden()
                                .accessibilityHidden(true)
                        }
                    }

                    InlineRPEChipRow(rpe: Binding(
                        get: { entry.rpe },
                        set: { entry.rpe = $0; onEditCommitted() }
                    ))

                    SetTypeChip(setTypeRaw: setTypeRaw)

                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                }
                .padding(.leading, dynamicTypeSize.isAccessibilitySize || explanation != nil ? 0 : 40)
            }
            .padding(.vertical, 12)                                              // UI-SPEC md

            // MARK: PlateStackDisclosure (Phase 3 plan 03-08)
            if expandedPlateSetID == entry.id {
                let ekind = SessionFactory.equipmentKind(
                    for: sessionExercise.exercise?.equipment ?? .other
                )
                if let inv = inventories.first(where: { $0.equipmentKind == ekind }) {
                    let targetWeight = entry.weight > 0
                        ? entry.weight
                        : (prescribed ?? 0)
                    let barW = sessionExercise.exercise?.barWeightOverride ?? inv.barWeight
                    PlateStackDisclosure(
                        targetWeight: targetWeight,
                        barWeight: barW,
                        plates: inv.availablePlates,
                        unitLabel: unit.rawValue
                    )
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            repsText = entry.reps == 0 ? "" : String(entry.reps)
        }
    }

    private var inputLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 6))
    }

    /// Opens Why-this-weight (Milestone 1 decision 8). The weight cell
    /// presents the sheet and ends editing first.
    private var whyButton: some View {
        Button {
            explainingWeight = true
        } label: {
            Text("WHY")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(Color.bruInk)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Why this weight")
        .accessibilityIdentifier("set.why.\(identifierSuffix)")
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
        let n = displayNumber
        return entry.isWarmup ? "W\(n)" : "S\(n)"
    }

    private var displayNumber: Int {
        SessionSetActions.displayNumber(of: entry)
    }

    /// "{exercise position}.{set label}", e.g. "1.S2", for UI test queries.
    private var identifierSuffix: String {
        "\(sessionExercise.orderIndex + 1).\(setLabel)"
    }

    /// Shared by the set label's menu and the set-type chip.
    private var setTypeRaw: Binding<String> {
        Binding(
            get: { entry.setTypeRaw },
            set: { entry.setTypeRaw = $0; onEditCommitted() }
        )
    }

    /// Toggles the plate-stack disclosure for this row.
    private func togglePlateDisclosure() {
        if expandedPlateSetID == entry.id {
            expandedPlateSetID = nil
        } else {
            expandedPlateSetID = entry.id
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("set row") {
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
            onCommit: {},
            onTapEmptyCell: {}
        )
    }
    .modelContainer(container)
}
#endif
