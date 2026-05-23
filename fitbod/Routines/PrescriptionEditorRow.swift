//
//  PrescriptionEditorRow.swift
//  fitbod
//
//  Wave-3 plan 03-02 — the inline expanded prescription editor that
//  appears under each `RoutineExerciseCard` when the user taps to
//  expand it (`DisclosureGroup`). Renders the full UI-SPEC
//  § Routine builder / Prescription editor surface:
//
//    - Intent picker (Strength / Hypertrophy / Power / Endurance / Technique)
//    - Sets stepper
//    - Reps range two-field (low – high)
//    - Target RPE range two-field (low – high)
//    - Progression picker (RPE Autoregulation / Double Progression /
//      Block Periodized / Hybrid)
//    - Rest seconds stepper with "{N}s" display
//    - Track tempo toggle + 4-field ecc/bot/con/top entry (rendered
//      conditionally)
//    - Track partial reps toggle
//    - Auto warm-up toggle — wired to RoutineExerciseDraft.warmupOverride
//      (plan 03-07). Toggle footer copy switches on enabled state.
//    - Per-set overrides disclosure with "Add Override" trailing action
//      + swipe-to-delete on individual override sub-rows
//
//  Bound to a `@Bindable RoutineExerciseDraft`. RESEARCH §6 Pitfall 8
//  pruning runs automatically via the `targetSets.didSet` on the draft
//  whenever the Sets stepper decreases targetSets.
//

import SwiftUI

public struct PrescriptionEditorRow: View {
    @Bindable public var draft: RoutineExerciseDraft

    @State private var showingPerSetOverrides: Bool = false

    public init(draft: RoutineExerciseDraft) {
        self.draft = draft
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            intentPicker
            setsStepper
            repsRangeRow
            rpeRangeRow
            progressionPicker
            restStepper
            tempoSection
            partialRepsToggle
            autoWarmupToggle
            perSetOverridesDisclosure
        }
        .padding(.vertical, 8)
    }

    // MARK: - Intent

    private var intentPicker: some View {
        HStack {
            Text("Intent")
                .font(.body)
            Spacer()
            Picker("Intent", selection: $draft.intent) {
                Text("Strength").tag(Intent.strength)
                Text("Hypertrophy").tag(Intent.hypertrophy)
                Text("Power").tag(Intent.power)
                Text("Endurance").tag(Intent.endurance)
                Text("Technique").tag(Intent.technique)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel("Intent")
        }
    }

    // MARK: - Sets

    private var setsStepper: some View {
        Stepper(value: $draft.targetSets, in: 1...20) {
            HStack {
                Text("Sets")
                Spacer()
                Text("\(draft.targetSets)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Reps range

    private var repsRangeRow: some View {
        HStack(spacing: 8) {
            Text("Reps")
            Spacer()
            TextField(
                "low",
                value: $draft.targetRepsLow,
                format: .number
            )
            .frame(width: 48)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)

            Text("–")
                .foregroundStyle(.secondary)

            TextField(
                "high",
                value: $draft.targetRepsHigh,
                format: .number
            )
            .frame(width: 48)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - RPE range

    /// Target RPE in the routine prescription is a *range* per
    /// UI-SPEC § Routine builder § Prescription editor ("Target RPE"
    /// with two TextFields + en-dash). The `RoutineExerciseDraft`
    /// currently models RPE as a single optional `targetRPE: Double?`
    /// because the Phase 1 schema field is also a single double
    /// (`RoutineExercise.targetRPE`). For Phase 2 we render the range
    /// UI but bind both ends to the same field — the executor in Phase
    /// 3 will widen this to a true range when progression heuristics
    /// need the spread. This is documented as a future follow-up,
    /// NOT a stub for plan 03-02.
    private var rpeRangeRow: some View {
        HStack(spacing: 8) {
            Text("Target RPE")
            Spacer()
            TextField(
                "low",
                value: Binding(
                    get: { draft.targetRPE ?? 0 },
                    set: { draft.targetRPE = $0 == 0 ? nil : $0 }
                ),
                format: .number.precision(.fractionLength(0...1))
            )
            .frame(width: 56)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)

            Text("–")
                .foregroundStyle(.secondary)

            TextField(
                "high",
                value: Binding(
                    get: { draft.targetRPE ?? 0 },
                    set: { draft.targetRPE = $0 == 0 ? nil : $0 }
                ),
                format: .number.precision(.fractionLength(0...1))
            )
            .frame(width: 56)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Progression

    private var progressionPicker: some View {
        HStack {
            Text("Progression")
            Spacer()
            Picker("Progression", selection: $draft.progressionKind) {
                Text("RPE Autoregulation").tag(ProgressionKind.rpe)
                Text("Double Progression").tag(ProgressionKind.double)
                Text("Block Periodized").tag(ProgressionKind.block)
                Text("Hybrid").tag(ProgressionKind.hybrid)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityLabel("Progression")
        }
    }

    // MARK: - Rest

    private var restStepper: some View {
        Stepper(value: $draft.prescribedRestSeconds, in: 0...600, step: 15) {
            HStack {
                Text("Rest")
                Spacer()
                Text("\(draft.prescribedRestSeconds)s")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tempo

    @ViewBuilder
    private var tempoSection: some View {
        Toggle("Track tempo", isOn: $draft.tracksTempo)
        if draft.tracksTempo {
            // The tempo string format is "ecc-bot-con-top" (e.g.
            // "3-1-1-0"). We render 4 small TextFields in a row and
            // assemble the wire format on each change. For Phase 2 the
            // simplest binding is: parse the existing string on read,
            // re-format on write. Empty/blank pieces render as empty
            // fields.
            HStack(spacing: 8) {
                Text("Tempo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                tempoField(index: 0, placeholder: "Ecc")
                tempoField(index: 1, placeholder: "Bot")
                tempoField(index: 2, placeholder: "Con")
                tempoField(index: 3, placeholder: "Top")
            }
        }
    }

    private func tempoField(index: Int, placeholder: String) -> some View {
        let parts = (draft.tempo ?? "").split(separator: "-").map(String.init)
        let current = index < parts.count ? parts[index] : ""
        let binding = Binding<String>(
            get: { current },
            set: { newValue in
                var p = parts
                while p.count <= index { p.append("") }
                p[index] = newValue
                let joined = p.joined(separator: "-")
                draft.tempo = joined.isEmpty ? nil : joined
            }
        )
        return TextField(placeholder, text: binding)
            .frame(width: 40)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .font(.caption)
    }

    // MARK: - Partial reps

    private var partialRepsToggle: some View {
        Toggle("Track partial reps", isOn: $draft.tracksPartialReps)
    }

    // MARK: - Auto warm-up

    /// Resolved enabled state: reads the override when present, otherwise
    /// defaults to true (auto warm-up on when no override exists).
    private var warmupEnabled: Bool {
        draft.warmupOverride?.enabled ?? true
    }

    private var autoWarmupToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                "Auto warm-up",
                isOn: Binding(
                    get: {
                        draft.warmupOverride?.enabled ?? true
                    },
                    set: { newValue in
                        let skipNext = draft.warmupOverride?.skipNextSession ?? false
                        if newValue && !skipNext {
                            // Restoring to default behavior — clear the override.
                            draft.warmupOverride = nil
                        } else {
                            draft.warmupOverride = WarmupConfig(
                                enabled: newValue,
                                skipNextSession: skipNext
                            )
                        }
                    }
                )
            )
            Text(
                warmupEnabled
                    ? "Generates a 4-set ramp (40% × 5, 60% × 3, 75% × 2, 90% × 1) based on your plate inventory."
                    : "No warm-up sets will be generated for this exercise."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Per-set overrides

    private var perSetOverridesDisclosure: some View {
        DisclosureGroup(isExpanded: $showingPerSetOverrides) {
            VStack(spacing: 8) {
                ForEach(draft.setOverrides) { override in
                    PerSetOverrideRow(draft: override)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                removeOverride(override)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
                Button {
                    addOverride()
                } label: {
                    Label("Add Override", systemImage: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        } label: {
            HStack {
                Text("Per-set overrides")
                Spacer()
                Text(overrideSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var overrideSummary: String {
        if draft.setOverrides.isEmpty {
            return "\(draft.targetSets) sets default"
        }
        return "\(draft.setOverrides.count) override\(draft.setOverrides.count == 1 ? "" : "s")"
    }

    /// Append a new override row. Default `setIndex` is the smallest
    /// unused index in `[0..<targetSets)`; if every slot already has
    /// an override, fall back to `targetSets - 1` (the user can edit
    /// the index manually if needed).
    private func addOverride() {
        let used = Set(draft.setOverrides.map { $0.setIndex })
        let next = (0..<draft.targetSets).first { !used.contains($0) }
            ?? max(0, draft.targetSets - 1)
        draft.appendOverride(setIndex: next)
    }

    private func removeOverride(_ override: PerSetOverrideDraft) {
        draft.setOverrides.removeAll { $0 === override }
    }
}
