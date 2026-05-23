//
//  SetRow.swift
//  fitbod
//
//  Wave-4 plan 04-01 — one row per `SetEntry` inside a `SessionExerciseCard`.
//  This is the user-facing per-set logging surface: weight | reps | RPE chips
//  | set-type chip | completion checkmark.
//
//  ## Layout (UI-SPEC § Session logger)
//
//      [set#] [Previous] [Weight/PrescriptionWeightCell] [Reps] [RPE chips] [type chip] [✓]
//      [PlateStackDisclosure (conditional, below)]
//
//  Phase 3 (plan 03-08) additions:
//    - Weight `TextField` replaced by `PrescriptionWeightCell` which renders:
//        * The prescribed weight with an `info.circle` button (WhyThisWeightSheet)
//        * A read-only "{low} – {high} kg" Text when `range != nil` (calibrating)
//        * An "M" badge when the user overrides the prescribed weight
//    - `PlateStackDisclosure` injected as a conditional VStack child below the
//      main HStack when `expandedPlateSetID == entry.id`.
//    - `expandedPlateSetID: Binding<UUID?>` for single-disclosure-at-a-time
//      coordination across all set rows in a card.
//    - `prescribed: Double?` — the session-exercise prescribed weight
//    - `explanation: PrescriptionExplanation?` — recomputed by card
//
//  ## Commit semantics (SESS-04 — rest timer integration)
//
//  The completion button is GUARDED — it only fires `onCommit()` when
//  `entry.weight > 0 && entry.reps > 0`. This guard is load-bearing for
//  the matching-intent query: without it, an accidental tap would flip
//  `isComplete = true` on a zero-weight/zero-rep set, corrupting future
//  `PreviousMatchingIntent` reads (which filter on `reps > 0`).
//
//  When `onCommit()` fires, the parent `SessionLoggerView`:
//    1. Sets `entry.isComplete = true` + `entry.completedAt = .now`.
//    2. Calls `try? ctx.save()` to persist the committed set.
//    3. Fires `engine.start(seconds: prescribedRest, exerciseName:)` to
//       kick off the rest period. RESEARCH §6 Pitfall 2 — the save MUST
//       precede the engine.start so the committed set is in the store
//       before the rest period begins.
//
//  ## Auto-stop on next-set entry (SESS-04)
//
//  When the user taps a weight or reps cell on a STILL-INCOMPLETE set
//  (i.e. starting to log the next set), `onTapEmptyCell()` fires which
//  calls `engine.stop()` in the parent. The empty-cell-tap pattern keeps
//  ±15s button taps + decimal-RPE long-presses from re-cancelling the
//  notification (they fire on bordered button presses, not on the cell tap).
//
//  ## Bodyweight signed weight (SESS-09)
//
//  For exercises with `equipment == .bodyweight`, the weight TextField
//  uses `.numbersAndPunctuation` keyboard so the user can enter a signed
//  value (negative weight = assistance from a machine; positive = added
//  weight on a belt). Non-bodyweight exercises use `.decimalPad`.
//  (This setting is now passed to PrescriptionWeightCell.)
//
//  ## Plate-stack inline disclosure (plan 03-08 / UI-SPEC § Plate-stack)
//
//  Tapping the weight cell area (NOT the info.circle icon) toggles the
//  PlateStackDisclosure. Only one disclosure is open at a time — managed by
//  the `expandedPlateSetID` binding owned by SessionExerciseCard.
//
//  ## Anti-patterns avoided
//
//  - PrescriptionWeightCell handles the TextField text seeding internally;
//    SetRow no longer manages `weightText` state.
//  - The `PreviousColumn` query fires once in `.task`, not on every body
//    invocation (RESEARCH § Anti-Patterns to Avoid).
//

import SwiftUI
import SwiftData

public struct SetRow: View {
    @Bindable public var entry: SetEntry
    public let sessionExercise: SessionExercise
    /// Phase 3 (plan 03-08): the prescribed weight from SessionExercise,
    /// forwarded to PrescriptionWeightCell. Nil for Phase 2 sessions started
    /// before Phase 3 shipped.
    public let prescribed: Double?
    /// Phase 3 (plan 03-08): the full PrescriptionExplanation recomputed by
    /// SessionExerciseCard.currentExplanation(). Nil for first sessions or
    /// Phase 2 sessions. The `range` field inside drives the read-only
    /// calibrating display per CONTEXT.md Area 1.
    public let explanation: PrescriptionExplanation?
    /// Phase 3 (plan 03-08): shared single-disclosure-at-a-time coordination.
    /// When the user taps the weight cell area, this toggles to entry.id;
    /// when another row is tapped, this card automatically collapses because
    /// expandedPlateSetID changes.
    @Binding public var expandedPlateSetID: UUID?
    public let onCommit: () -> Void
    public let onTapEmptyCell: () -> Void

    @State private var repsText: String = ""
    /// Wave-4 plan 04-03 — per-set note sheet presentation flag. Plan
    /// 04-01 anchored the note-button placement here as a stub; this plan
    /// ships the real PerSetNoteSheet wire.
    @State private var presentingSetNote: Bool = false

    /// Phase 3 (plan 03-08): plate inventory for the PlateStackDisclosure.
    /// Read-only query — no write-through.
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
            HStack(spacing: 8) {                                                   // UI-SPEC sm
                Text(setLabel)                                                     // "1", "2", "W1" for warmup
                    .font(.body)
                    .frame(width: 32, alignment: .leading)
                PreviousColumn(
                    exerciseID: sessionExercise.exercise?.id,
                    intentRaw: sessionExercise.intentRaw
                )
                .frame(width: 80, alignment: .leading)

                // Phase 3 (plan 03-08): PrescriptionWeightCell replaces the
                // plain weight TextField. It renders:
                //   - An editable TextField (when range == nil)
                //   - A read-only "{low} – {high} kg" Text (when range != nil)
                //   - An "M" badge when wasManualOverride == true
                //   - An info.circle button that opens WhyThisWeightSheet
                //
                // CRITICAL: `range: explanation?.range` MUST be passed here so
                // calibrating-with-prior-data sessions render the read-only
                // range display per CONTEXT.md Area 1 + UI-SPEC § Prescribed
                // weight cell. This is the key integration wiring of plan 03-08.
                PrescriptionWeightCell(
                    weight: $entry.weight,
                    prescribed: prescribed,
                    range: explanation?.range,   // CONTEXT.md Area 1 — calibrating range
                    explanation: explanation,
                    wasManualOverride: $entry.wasManualOverride,
                    isComplete: entry.isComplete,
                    onTapEmptyCell: onTapEmptyCell
                )
                .frame(width: 60)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tap on weight cell area (NOT info.circle — that button
                    // intercepts its own tap) toggles the plate stack disclosure.
                    // UI-SPEC § Plate-stack inline disclosure flow §3: TextField
                    // focus takes precedence; only toggle when not in range-mode
                    // (read-only Text) or explicitly tapping the cell background.
                    togglePlateDisclosure()
                    if !entry.isComplete { onTapEmptyCell() }
                }

                TextField("—", text: $repsText)                                    // UI-SPEC verbatim placeholder
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
                // Wave-4 plan 04-03 — per-set notes button (UI-SPEC § Session
                // logger "Per-set notes button accessibility label" + symbol
                // anchor placement from plan 04-01). Icon-only button before
                // the completion checkmark. Foreground tints to accent when a
                // note is populated as a visual signal; secondary-label
                // otherwise so empty-notes buttons stay quiet.
                Button {
                    presentingSetNote = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.caption)
                        .foregroundStyle(entry.notes != nil ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .accessibilityLabel("Note for set \(entry.orderIndex + 1)")        // UI-SPEC verbatim a11y
                .sheet(isPresented: $presentingSetNote) {
                    PerSetNoteSheet(entry: entry)
                }
                Button {
                    // Guard: never commit a zero-weight/zero-rep set. Without
                    // this guard an empty checkmark-tap would flip
                    // `isComplete = true` and corrupt future matching-intent
                    // reads. UI-SPEC § Anti-Patterns to Avoid.
                    if entry.weight > 0 && entry.reps > 0 {
                        onCommit()
                    }
                } label: {
                    Image(systemName: entry.isComplete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(entry.isComplete ? Color.accentColor : Color.secondary)
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)                        // UI-SPEC HIG 44pt
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    entry.isComplete
                    ? "Set \(entry.orderIndex + 1) complete"
                    : "Mark set \(entry.orderIndex + 1) complete"
                )
            }
            .padding(.vertical, 12)                                                // UI-SPEC md

            // MARK: PlateStackDisclosure (Phase 3 plan 03-08)
            //
            // Rendered as a VStack sibling below the main HStack when the
            // user has tapped this row's weight cell. Single-disclosure-
            // at-a-time: expandedPlateSetID must equal this entry's id.
            // Animation is handled inside PlateStackDisclosure itself via
            // @Environment(\.accessibilityReduceMotion).
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
                    .padding(.vertical, 8)                                         // UI-SPEC sm
                }
            }
        }
        .onAppear {
            // Seed the reps text field. PrescriptionWeightCell manages the
            // weight text field internally (seeding from prescribed weight or
            // current weight on .onAppear).
            repsText = entry.reps == 0 ? "" : String(entry.reps)
        }
    }

    // MARK: - Private helpers

    /// "1", "2", "W1" for warmup sets — UI-SPEC § Session logger
    /// "Set-row 'Set N' leading label".
    private var setLabel: String {
        let n = entry.orderIndex + 1
        return entry.isWarmup ? "W\(n)" : "\(n)"
    }

    /// Toggles the plate-stack disclosure for this row. If this row's
    /// disclosure is already open, closes it. If another row's disclosure
    /// is open, this row takes over (single-disclosure-at-a-time).
    private func togglePlateDisclosure() {
        if expandedPlateSetID == entry.id {
            expandedPlateSetID = nil
        } else {
            expandedPlateSetID = entry.id
        }
    }
}

#Preview("set row") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let se = SessionExercise()
    se.exercise = ex
    se.intentRaw = "strength"
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
