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
//    BRUChip("{m:ss} rest")                      ← ink outline
//
//  Below: SetRowsContainer(exercise:) — the 1.5pt bruInk bordered per-set grid.
//
//  All Phase 3 functional behavior is preserved via a collapsible
//  "Advanced" section for sets/reps/RPE/rest/tempo/partial reps/warm-up.
//  Per-set overrides remain fully editable inside SetRowsContainer.
//
//  Verbatim copy preserved for RoutineBuilderCopyTests:
//    "Sets" / "Min reps" / "Max reps" / "Target RPE" / "Rest" /
//    "Track tempo" / "Track partial reps" / "Auto warm-up" /
//    "Per-set overrides" / "Add Override" / "Remove"
//
//  Target reps are two steppers and target RPE is one chip row with an
//  explicit no-target chip, so no number is ever typed over (Milestone 1
//  review items 5 and 6).
//
//  Rest reads as minutes and seconds, such as "3:00", in the chip and the
//  stepper, as on the rest timer. The three switches use the BRU toggle
//  style, and at accessibility sizes their labels wrap, the tempo fields
//  drop their fixed widths and the overrides count moves under its label,
//  so nothing is clipped (Milestone 1 review items 12 and 13).
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule /
//  NO RoundedRectangle / NO Apple HIG semantic fonts
//

import SwiftUI

public struct PrescriptionEditorRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        "\(restClock(draft.prescribedRestSeconds)) rest"
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
                repsSteppers
                rpeRow
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

    /// Each end of the range stops at the other, so low never passes high.
    private var repsSteppers: some View {
        VStack(alignment: .leading, spacing: 14) {
            BRUStepper("Min reps", value: $draft.targetRepsLow, in: draft.targetRepsLowRange, step: 1) { "\($0)" }
                .accessibilityIdentifier("prescription.reps.low")
            BRUStepper("Max reps", value: $draft.targetRepsHigh, in: draft.targetRepsHighRange, step: 1) { "\($0)" }
                .accessibilityIdentifier("prescription.reps.high")
        }
    }

    // MARK: - Target RPE

    /// One target RPE, picked like the logger's (long-press a chip for a
    /// decimal), or no target at all.
    private var rpeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target RPE")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            InlineRPEChipRow(rpe: $draft.targetRPE, noneLabel: "No target")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("prescription.rpe")
    }

    // MARK: - Rest

    private var restStepper: some View {
        BRUStepper("Rest", value: $draft.prescribedRestSeconds, in: 0...600, step: 15) { restClock($0) }
            .accessibilityIdentifier("prescription.rest")
    }

    // MARK: - Tempo

    @ViewBuilder
    private var tempoSection: some View {
        Toggle("Track tempo", isOn: $draft.tracksTempo)
            .toggleStyle(.bru)

        if draft.tracksTempo {
            if dynamicTypeSize.isAccessibilitySize {
                // Four 40pt fields would clip their text, so they share the
                // row under the label instead.
                VStack(alignment: .leading, spacing: 8) {
                    tempoLabel
                    tempoFields(width: nil)
                }
            } else {
                HStack {
                    tempoLabel
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    tempoFields(width: 40)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    private var tempoLabel: some View {
        Text("Tempo")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
    }

    /// The four tempo fields, each `width` wide, or sharing the row when
    /// `width` is nil.
    private func tempoFields(width: CGFloat?) -> some View {
        HStack(spacing: 6) {
            tempoField(index: 0, placeholder: "Ecc", width: width)
            tempoField(index: 1, placeholder: "Bot", width: width)
            tempoField(index: 2, placeholder: "Con", width: width)
            tempoField(index: 3, placeholder: "Top", width: width)
        }
    }

    private func tempoField(index: Int, placeholder: String, width: CGFloat?) -> some View {
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
            .frame(width: width)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(BRUFont.bodyDefault)
    }

    // MARK: - Partial reps

    private var partialRepsToggle: some View {
        Toggle("Track partial reps", isOn: $draft.tracksPartialReps)
            .toggleStyle(.bru)
    }

    // MARK: - Auto warm-up

    private var warmupEnabled: Bool {
        draft.warmupOverride?.enabled ?? true
    }

    private var autoWarmupToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Auto warm-up", isOn: Binding(
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
            ))
            .toggleStyle(.bru)

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
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        // Beside the label, the count would be pushed off
                        // the right edge.
                        VStack(alignment: .leading, spacing: 4) {
                            overridesTitle
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                overridesCount
                                Spacer(minLength: 0)
                                overridesGlyph
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            overridesTitle
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 8)
                            // Wraps rather than clips when the label leaves it little room.
                            overridesCount
                                .multilineTextAlignment(.trailing)
                            overridesGlyph
                        }
                    }
                }
                .frame(minHeight: 44)
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

    private var overridesTitle: some View {
        Text("Per-set overrides")
            .font(BRUFont.bodyEmphasis)
            .foregroundStyle(Color.bruInk)
    }

    private var overridesCount: some View {
        Text(overrideSummary)
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
    }

    private var overridesGlyph: some View {
        Text(showingPerSetOverrides ? "▴" : "▾")
            .font(BRUFont.labelSmall)
            .foregroundStyle(Color.bruMuted)
    }

    private var overrideSummary: String {
        if draft.setOverrides.isEmpty {
            return "\(BRUCountLabel.text(draft.targetSets, "set")) default"
        }
        return BRUCountLabel.text(draft.setOverrides.count, "override")
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

// MARK: - Rest time

/// Rest as minutes and seconds, such as "3:00" for 180 seconds, the way the
/// rest timer counts it down.
func restClock(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
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
