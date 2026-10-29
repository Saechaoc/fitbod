//
//  PrescriptionEditorRow.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — replaces the 8-row VStack prescription
//  editor with the BRU prescription chip row + SetRowsContainer.
//
//  Top row: actual prescription values in a wrapping BRUFlowLayout:
//    BRUChip("{repsMin}–{repsMax} reps")        ← ink outline
//    BRUChip("RPE {rpeMin}–{rpeMax}")           ← ink outline
//    BRUChip("{rest} min rest")                  ← ink outline
//
//  Below: SetRowsContainer(exercise:) — the 1.5pt bruInk bordered per-set grid.
//
//  All Phase 3 functional behavior is preserved via a collapsible
//  "Advanced" section for sets/reps/RPE/rest/tempo/partial reps/warm-up.
//  Per-set overrides remain fully editable inside SetRowsContainer.
//
//  Verbatim copy preserved for RoutineBuilderCopyTests:
//    "Sets" / "Reps" / "Target RPE" / "Rest" / "Track tempo" /
//    "Track partial reps" / "Auto warm-up" / "Per-set overrides" /
//    "Add Override" / "Remove"
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule /
//  NO RoundedRectangle / NO Apple HIG semantic fonts
//

import SwiftUI

public struct PrescriptionEditorRow: View {
    @Bindable public var draft: RoutineExerciseDraft
    public let hasBlock: Bool

    @State private var showingPerSetOverrides: Bool = false
    @State private var showingAdvanced: Bool = false

    public init(draft: RoutineExerciseDraft, hasBlock: Bool = false) {
        self.draft = draft
        self.hasBlock = hasBlock
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Prescription chip row ──
            chipRow

            // ── SetRowsContainer ──
            SetRowsContainer(exercise: draft)

            // ── Advanced / editable prescription block ──
            advancedSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Chip Row

    private var chipRow: some View {
        // Constrain long labels and reflow at accessibility text sizes.
        let chips = [
            (repsChipLabel, Color.bruInk),
            (rpeChipLabel, Color.bruInk),
            (restChipLabel, Color.bruInk),
        ]
        return BRUFlowLayout(spacing: 5, lineSpacing: 5) {
            ForEach(chips.indices, id: \.self) { i in
                let (label, color) = chips[i]
                BRUChip(label, color: color, fill: false, textCase: nil)
            }
        }
    }

    // MARK: Chip Labels

    private var repsChipLabel: String {
        if draft.targetRepsLow == draft.targetRepsHigh {
            return "\(draft.targetRepsLow) reps"
        }
        return "\(draft.targetRepsLow)–\(draft.targetRepsHigh) reps"
    }

    private var rpeChipLabel: String {
        guard let rpe = draft.targetRPE else { return "RPE —" }
        let rpeStr = rpe == rpe.rounded() ? "\(Int(rpe))" : String(format: "%.1f", rpe)
        return "RPE \(rpeStr)"
    }

    private var restChipLabel: String {
        let mins = draft.prescribedRestSeconds / 60
        let secs = draft.prescribedRestSeconds % 60
        if secs == 0 {
            return "\(mins) min rest"
        }
        return "\(draft.prescribedRestSeconds)s rest"
    }

    // MARK: - Advanced Section

    @ViewBuilder
    private var advancedSection: some View {
        // "Advanced" toggle exposes the full Phase 3 prescription editor.
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showingAdvanced.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(showingAdvanced ? "HIDE DETAILS" : "EDIT PRESCRIPTION")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                Spacer()
                Text(showingAdvanced ? "▴" : "▾")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("prescription.details")
        .buttonStyle(.plain)

        if showingAdvanced {
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
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Sets

    private var setsStepper: some View {
        BRUStepper("Sets", value: $draft.targetSets, in: 1...20, step: 1) { "\($0)" }
        .accessibilityIdentifier("prescription.sets")
    }

    // MARK: - Reps range

    private var repsRangeRow: some View {
        HStack {
            Text("Reps")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer()
            HStack(spacing: 8) {
                TextField(
                    "low",
                    value: $draft.targetRepsLow,
                    format: .number
                )
                .frame(width: 48)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(BRUFont.bodyDefault)
                .frame(minHeight: 44)
                .accessibilityLabel("Minimum target reps")
                .accessibilityIdentifier("prescription.reps.low")

                Text("–")
                    .foregroundStyle(Color.bruMuted)
                    .font(BRUFont.bodyDefault)

                TextField(
                    "high",
                    value: $draft.targetRepsHigh,
                    format: .number
                )
                .frame(width: 48)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(BRUFont.bodyDefault)
                .frame(minHeight: 44)
                .accessibilityLabel("Maximum target reps")
                .accessibilityIdentifier("prescription.reps.high")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - RPE range

    private var rpeRangeRow: some View {
        HStack {
            Text("Target RPE")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer()
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
                .font(BRUFont.bodyDefault)

                Text("–")
                    .foregroundStyle(Color.bruMuted)
                    .font(BRUFont.bodyDefault)

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
                .font(BRUFont.bodyDefault)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Rest

    private var restStepper: some View {
        BRUStepper("Rest", value: $draft.prescribedRestSeconds, in: 0...600, step: 15) { "\($0)s" }
    }

    // MARK: - Tempo

    @ViewBuilder
    private var tempoSection: some View {
        Toggle(isOn: $draft.tracksTempo) {
            Text("Track tempo")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
        }
        .lineLimit(1)

        if draft.tracksTempo {
            HStack {
                Text("Tempo")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer()
                HStack(spacing: 6) {
                    tempoField(index: 0, placeholder: "Ecc")
                    tempoField(index: 1, placeholder: "Bot")
                    tempoField(index: 2, placeholder: "Con")
                    tempoField(index: 3, placeholder: "Top")
                }
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
            .font(BRUFont.bodyDefault)
    }

    // MARK: - Partial reps

    private var partialRepsToggle: some View {
        Toggle(isOn: $draft.tracksPartialReps) {
            Text("Track partial reps")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
        }
        .lineLimit(1)
    }

    // MARK: - Auto warm-up

    private var warmupEnabled: Bool {
        draft.warmupOverride?.enabled ?? true
    }

    private var autoWarmupToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { draft.warmupOverride?.enabled ?? true },
                set: { newValue in
                    let skipNext = draft.warmupOverride?.skipNextSession ?? false
                    if newValue && !skipNext {
                        draft.warmupOverride = nil
                    } else {
                        draft.warmupOverride = WarmupConfig(
                            enabled: newValue,
                            skipNextSession: skipNext
                        )
                    }
                }
            )) {
                Text("Auto warm-up")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
            }

            Text(
                warmupEnabled
                    ? "Generates a 4-set ramp (40% × 5, 60% × 3, 75% × 2, 90% × 1) based on your plate inventory."
                    : "No warm-up sets will be generated for this exercise."
            )
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
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
                    Text("Per-set overrides")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    Text(overrideSummary)
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .lineLimit(1)
                    Text(showingPerSetOverrides ? "▴" : "▾")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
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
                                    Text("Remove")
                                }
                            }
                    }
                    // "+ ADD OVERRIDE" signal text button per verbatim copy
                    Button {
                        addOverride()
                    } label: {
                        Text("+ ADD OVERRIDE")
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruSignalText)
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

// MARK: - Preview

#if DEBUG
#Preview("PrescriptionEditorRow") {
    let draft = RoutineExerciseDraft()
    draft.targetSets = 4
    draft.targetRepsLow = 6
    draft.targetRepsHigh = 8
    draft.targetRPE = 8.0
    draft.prescribedRestSeconds = 180
    return ScrollView {
        PrescriptionEditorRow(draft: draft, hasBlock: false)
            .padding(16)
    }
    .background(Color.bruPaper)
}
#endif
