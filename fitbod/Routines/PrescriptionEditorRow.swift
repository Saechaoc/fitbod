//
//  PrescriptionEditorRow.swift
//  fitbod
//
//  The inline expanded prescription editor that appears under each
//  `RoutineExerciseCard` when the user taps to expand it. Renders the
//  per-exercise prescription surface as an 8-row VStack:
//
//      1. Sets (stepper)
//      2. Reps range (two TextFields with en-dash)
//      3. Target RPE range (two TextFields with en-dash)
//      4. Rest (stepper, "{N}s")
//      5. Track tempo (toggle) → tempo 4-field row (when toggle on)
//      6. Track partial reps (toggle)
//      7. Auto warm-up (toggle, with footnote)
//      8. Per-set overrides (disclosure)
//
//  ## Phase 3.1 (PIVOT-04 / D-10) — Intent + Progression hoisted to the routine
//
//  In Phase 2/3 this row rendered a 10-row VStack that ALSO included a
//  per-exercise Intent picker (Strength / Hypertrophy / Power /
//  Endurance / Technique) and a per-exercise Progression picker (RPE
//  Autoregulation / Double Progression / Block Periodized / Hybrid).
//
//  Phase 3.1 hoisted both fields from `RoutineExercise` (per-exercise)
//  to `Routine` (per-routine / session-level). The user-facing pickers
//  now live in `RoutineBuilderView`'s top Form Section as
//  `intentHeaderRow` + `progressionHeaderRow` (Plan 04) — a single
//  control surface for the whole routine. This editor row is now
//  strictly the per-exercise prescription detail.
//
//  Per UI-SPEC § Component Inventory — Removed views: the two Phase
//  2/3 per-exercise picker view functions are gone; the body VStack
//  enumerates the canonical 8-row order.
//
//  Bound to a `@Bindable RoutineExerciseDraft`. RESEARCH §6 Pitfall 8
//  pruning runs automatically via the `targetSets.didSet` on the draft
//  whenever the Sets stepper decreases targetSets.
//

import SwiftUI

public struct PrescriptionEditorRow: View {
    @Bindable public var draft: RoutineExerciseDraft
    public let hasBlock: Bool

    @State private var showingPerSetOverrides: Bool = false

    public init(draft: RoutineExerciseDraft, hasBlock: Bool = false) {
        self.draft = draft
        self.hasBlock = hasBlock
    }

    public var body: some View {
        // Phase 3.1 canonical 8-row editor — Intent + Progression are
        // session-level now (RoutineBuilderView header pickers per
        // PIVOT-04 / D-10). See file header for full rationale.
        VStack(alignment: .leading, spacing: 14) {
            setsStepper
            repsRangeRow
            rpeRangeRow
            restStepper
            tempoSection
            partialRepsToggle
            autoWarmupToggle
            perSetOverridesDisclosure
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    /// Single-line, non-shrinking label used by every row in the editor.
    /// Keeping the label at its natural width prevents the
    /// character-by-character wrapping that happens when an active-edit
    /// List squeezes content into a narrow center column.
    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Sets

    private var setsStepper: some View {
        Stepper(value: $draft.targetSets, in: 1...20) {
            LabeledContent {
                Text("\(draft.targetSets)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } label: {
                rowLabel("Sets")
            }
        }
    }

    // MARK: - Reps range

    private var repsRangeRow: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(
                    "low",
                    value: $draft.targetRepsLow,
                    format: .number
                )
                .frame(width: 48)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)

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
                .textFieldStyle(.roundedBorder)
            }
            .fixedSize(horizontal: true, vertical: false)
        } label: {
            rowLabel("Reps")
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
        LabeledContent {
            HStack(spacing: 8) {
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
                .textFieldStyle(.roundedBorder)

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
                .textFieldStyle(.roundedBorder)
            }
            .fixedSize(horizontal: true, vertical: false)
        } label: {
            rowLabel("Target RPE")
        }
    }

    // MARK: - Rest

    private var restStepper: some View {
        Stepper(value: $draft.prescribedRestSeconds, in: 0...600, step: 15) {
            LabeledContent {
                Text("\(draft.prescribedRestSeconds)s")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } label: {
                rowLabel("Rest")
            }
        }
    }

    // MARK: - Tempo

    @ViewBuilder
    private var tempoSection: some View {
        Toggle("Track tempo", isOn: $draft.tracksTempo)
            .lineLimit(1)
        if draft.tracksTempo {
            // The tempo string format is "ecc-bot-con-top" (e.g.
            // "3-1-1-0"). We render 4 small TextFields in a row and
            // assemble the wire format on each change. For Phase 2 the
            // simplest binding is: parse the existing string on read,
            // re-format on write. Empty/blank pieces render as empty
            // fields.
            LabeledContent {
                HStack(spacing: 6) {
                    tempoField(index: 0, placeholder: "Ecc")
                    tempoField(index: 1, placeholder: "Bot")
                    tempoField(index: 2, placeholder: "Con")
                    tempoField(index: 3, placeholder: "Top")
                }
                .fixedSize(horizontal: true, vertical: false)
            } label: {
                Text("Tempo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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
            .lineLimit(1)
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
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showingPerSetOverrides.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    rowLabel("Per-set overrides")
                    Spacer(minLength: 8)
                    Text(overrideSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showingPerSetOverrides ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showingPerSetOverrides {
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
                .transition(.opacity)
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
