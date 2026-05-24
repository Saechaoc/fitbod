// SetRow.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 33).
// UI-SPEC v2 § Session logger line 367-389.
//
// Per-set logging row: [S{N}] [Previous] [Weight] [Reps] [RPE chips] [SetTypeChip] [✎] [SetCompletionGlyph]
//
// KEY CHANGES from v1:
//   - SF Symbol checkmark.circle.fill → SetCompletionGlyph(isComplete:)
//   - SF Symbol square.and.pencil     → Text("✎") typographic glyph
//   - Color.accentColor → removed; completed numerics override to bruSignal
//   - .font(.body) / .font(.title2) / .font(.caption) → BRUFont.*
//   - Both action buttons wrapped in .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
//     per UI-SPEC line 79 + T-02.1-03-03 touch-target mitigation
//
// PRESERVED VERBATIM:
//   - @Bindable SetEntry + all closures (onCommit, onTapEmptyCell)
//   - Commit guard: entry.weight > 0 && entry.reps > 0 (T-02.1-07-01)
//   - Haptic on commit (T-02.1-07-03)
//   - PrescriptionWeightCell wiring + PlateStackDisclosure
//   - Per-set notes sheet (PerSetNoteSheet)
//   - Bodyweight signed weight keyboard (.numbersAndPunctuation per SESS-09)
//   - accessibilityLabel on note button + completion button
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor
//               NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//               NO .buttonStyle(.bordered) / NO Color(.system*)

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

    @State private var repsText: String = ""
    @State private var presentingSetNote: Bool = false

    @Query private var inventories: [PlateInventory]

    public init(
        entry: SetEntry,
        sessionExercise: SessionExercise,
        prescribed: Double? = nil,
        explanation: PrescriptionExplanation? = nil,
        expandedPlateSetID: Binding<UUID?> = .constant(nil),
        onCommit: @escaping () -> Void,
        onTapEmptyCell: @escaping () -> Void
    ) {
        self.entry = entry
        self.sessionExercise = sessionExercise
        self.prescribed = prescribed
        self.explanation = explanation
        self._expandedPlateSetID = expandedPlateSetID
        self.onCommit = onCommit
        self.onTapEmptyCell = onTapEmptyCell
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: Main set row HStack
            HStack(spacing: 8) {
                // S{N} / W{N} leading label — BRUFont.bodyDefault per UI-SPEC line 369
                Text(setLabel)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .frame(width: 32, alignment: .leading)

                PreviousColumn(
                    exerciseID: sessionExercise.exercise?.id,
                    intentRaw: sessionExercise.session?.intentRaw ?? Intent.strength.rawValue
                )
                .frame(width: 80, alignment: .leading)

                // Weight cell — PrescriptionWeightCell handles prescribed/range/override display.
                // Tap on cell area (not info icon) toggles plate stack disclosure.
                PrescriptionWeightCell(
                    weight: $entry.weight,
                    prescribed: prescribed,
                    range: explanation?.range,
                    explanation: explanation,
                    wasManualOverride: $entry.wasManualOverride,
                    isComplete: entry.isComplete,
                    onTapEmptyCell: onTapEmptyCell
                )
                .frame(width: 60)
                .contentShape(Rectangle())
                .onTapGesture {
                    togglePlateDisclosure()
                    if !entry.isComplete { onTapEmptyCell() }
                }
                // Completed set: weight/reps numerics turn bruSignal per UI-SPEC line 241
                .foregroundStyle(entry.isComplete ? Color.bruSignal : Color.bruInk)

                // Reps TextField — mono emphasis + bruSignal when complete
                TextField("—", text: $repsText)                                  // UI-SPEC verbatim "—"
                    .font(BRUFont.bodyEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(entry.isComplete ? Color.bruSignal : Color.bruInk)
                    .keyboardType(.numberPad)
                    .frame(width: 40)
                    .onTapGesture {
                        if !entry.isComplete { onTapEmptyCell() }
                    }
                    .onChange(of: repsText) { _, newValue in
                        if let i = Int(newValue) { entry.reps = i }
                    }

                InlineRPEChipRow(rpe: Binding(
                    get: { entry.rpe },
                    set: { entry.rpe = $0 }
                ))

                SetTypeChip(setTypeRaw: Binding(
                    get: { entry.setTypeRaw },
                    set: { entry.setTypeRaw = $0 }
                ))

                Spacer()

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
                .frame(minWidth: 44, minHeight: 44)                              // UI-SPEC HIG 44pt
                .contentShape(Rectangle())
                .accessibilityLabel("Note for set \(entry.orderIndex + 1)")      // UI-SPEC verbatim a11y
                .sheet(isPresented: $presentingSetNote) {
                    PerSetNoteSheet(entry: entry)
                }

                // Completion button — SetCompletionGlyph replaces SF Symbol checkmark
                // Guard: entry.weight > 0 && entry.reps > 0 (T-02.1-07-01)
                Button {
                    if entry.weight > 0 && entry.reps > 0 {
                        onCommit()
                    }
                } label: {
                    SetCompletionGlyph(isComplete: entry.isComplete)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)                              // UI-SPEC HIG 44pt
                .contentShape(Rectangle())
                .accessibilityLabel(
                    entry.isComplete
                    ? "Set \(entry.orderIndex + 1) complete"
                    : "Mark set \(entry.orderIndex + 1) complete"
                )
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
                        plates: inv.availablePlates
                    )
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            repsText = entry.reps == 0 ? "" : String(entry.reps)
        }
    }

    // MARK: - Private helpers

    /// "1", "2", "W1" for warmup sets — UI-SPEC § Session logger line 369.
    private var setLabel: String {
        let n = entry.orderIndex + 1
        return entry.isWarmup ? "W\(n)" : "S\(n)"
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
