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
//      [set#] [Previous] [Weight] [Reps] [RPE chips] [type chip] [✓]
//
//  - `set#` — "1", "2", "W1" for warm-ups (UI-SPEC verbatim format).
//  - `Previous` — `PreviousColumn` showing matching-intent prior set
//    (e.g. "175 × 8 @ 8 (Mon)") or "—" when no prior data exists.
//  - `Weight` / `Reps` — `TextField` with UI-SPEC verbatim placeholder "—".
//  - `RPE chips` — `InlineRPEChipRow` with 5 integer chips + long-press
//    decimal sheet.
//  - `type chip` — `SetTypeChip` cycling through working/warmup/drop/
//    failure/restPause.
//  - `✓` — completion button toggles between `circle` (incomplete) and
//    `checkmark.circle.fill` (complete) in `Color.accentColor`.
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
//
//  ## Anti-patterns avoided
//
//  - The TextField text is seeded from `entry.weight` ONLY when the value
//    is non-zero — otherwise the field shows the placeholder "—" instead
//    of "0.0" (the planner's "Anti-Patterns to Avoid" callout).
//  - The `PreviousColumn` query fires once in `.task`, not on every body
//    invocation (RESEARCH § Anti-Patterns to Avoid).
//

import SwiftUI
import SwiftData

public struct SetRow: View {
    @Bindable public var entry: SetEntry
    public let sessionExercise: SessionExercise
    public let onCommit: () -> Void
    public let onTapEmptyCell: () -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    /// Wave-4 plan 04-03 — per-set note sheet presentation flag. Plan
    /// 04-01 anchored the note-button placement here as a stub; this plan
    /// ships the real PerSetNoteSheet wire.
    @State private var presentingSetNote: Bool = false

    public init(
        entry: SetEntry,
        sessionExercise: SessionExercise,
        onCommit: @escaping () -> Void,
        onTapEmptyCell: @escaping () -> Void
    ) {
        self.entry = entry
        self.sessionExercise = sessionExercise
        self.onCommit = onCommit
        self.onTapEmptyCell = onTapEmptyCell
    }

    public var body: some View {
        HStack(spacing: 8) {                                                   // UI-SPEC sm
            Text(setLabel)                                                     // "1", "2", "W1" for warmup
                .font(.body)
                .frame(width: 32, alignment: .leading)
            PreviousColumn(
                exerciseID: sessionExercise.exercise?.id,
                intentRaw: sessionExercise.intentRaw
            )
            .frame(width: 80, alignment: .leading)
            TextField("—", text: $weightText)                                  // UI-SPEC verbatim placeholder
                .keyboardType(weightKeyboardType)
                .frame(width: 60)
                .onTapGesture {
                    if !entry.isComplete { onTapEmptyCell() }
                }
                .onChange(of: weightText) { _, newValue in
                    if let d = Double(newValue) { entry.weight = d }
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
        .onAppear {
            // Seed the local TextField text from the model. We render the
            // placeholder "—" instead of "0.0" when the underlying value
            // is zero (the planner's "Anti-Patterns to Avoid" callout).
            weightText = entry.weight == 0 ? "" : trimmedNumber(entry.weight)
            repsText = entry.reps == 0 ? "" : String(entry.reps)
        }
    }

    /// "1", "2", "W1" for warmup sets — UI-SPEC § Session logger
    /// "Set-row 'Set N' leading label".
    private var setLabel: String {
        let n = entry.orderIndex + 1
        return entry.isWarmup ? "W\(n)" : "\(n)"
    }

    /// SESS-09 — bodyweight equipment uses `.numbersAndPunctuation` so the
    /// user can enter a signed numeric value (negative = assist machine,
    /// positive = added weight). Non-bodyweight exercises use `.decimalPad`.
    private var weightKeyboardType: UIKeyboardType {
        if sessionExercise.exercise?.equipment == .bodyweight {
            return .numbersAndPunctuation
        }
        return .decimalPad
    }

    /// Renders weight without a trailing ".0" when the value is an
    /// integer (e.g. "175" not "175.0"). For decimal weights the natural
    /// decimal representation is preserved (e.g. "177.5").
    private func trimmedNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(value)
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
    ctx.insert(se)
    let entry = SetEntry()
    entry.sessionExercise = se
    entry.weight = 185
    entry.reps = 5
    ctx.insert(entry)
    try? ctx.save()
    return List {
        SetRow(
            entry: entry,
            sessionExercise: se,
            onCommit: {},
            onTapEmptyCell: {}
        )
    }
    .modelContainer(container)
}
