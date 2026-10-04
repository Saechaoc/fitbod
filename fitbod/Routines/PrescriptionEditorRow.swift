//
//  PrescriptionEditorRow.swift
//  fitbod
//
//  Per-exercise prescription editor inside the routine builder (Chalkline
//  redesign of plan 03-02). The everyday fields are big ± steppers with
//  44 pt targets — no keyboard needed to set up a routine:
//
//    Sets · Reps (low–high, kept ordered) · Target RPE (Off, 6–10 by ½)
//    · Rest (15 s steps) · Intent · Progression
//
//  "Advanced" holds the specialist options from Phase 2/3: tempo tracking,
//  partial reps, the auto warm-up toggle + settings, and per-set
//  overrides.
//
//  Progression shows the strategies implemented today (double progression,
//  RPE autoregulation); block-periodized and hybrid arrive with Phase 4
//  and only appear here if a routine already uses one.
//

import SwiftUI

public struct PrescriptionEditorRow: View {
    @Bindable public var draft: RoutineExerciseDraft
    let identifierPrefix: String
    let onEditWarmup: () -> Void
    @State private var showingAdvanced = false

    static let rpeOptions: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    public init(draft: RoutineExerciseDraft, identifierPrefix: String = "builder", onEditWarmup: @escaping () -> Void = {}) {
        self.draft = draft
        self.identifierPrefix = identifierPrefix
        self.onEditWarmup = onEditWarmup
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChalkStepperRow("Sets", value: $draft.targetSets, in: 1...10, identifier: "\(identifierPrefix).sets")
            divider
            repsRow
            divider
            ChalkStepperRow("Target RPE", value: rpeIndex, in: 0...Self.rpeOptions.count, identifier: "\(identifierPrefix).rpe") { index in
                index == 0 ? "Off" : ChalkFormat.rpe(Self.rpeOptions[index - 1])
            }
            divider
            ChalkStepperRow("Rest", value: $draft.prescribedRestSeconds, in: 0...600, step: 15, identifier: "\(identifierPrefix).rest") { seconds in
                ChalkFormat.duration(seconds: seconds)
            }
            divider
            pickerRow("Intent") {
                Picker("Intent", selection: $draft.intent) {
                    ForEach(Intent.allCases, id: \.self) { intent in
                        Text(intent.rawValue.capitalized).tag(intent)
                    }
                }
            }
            divider
            pickerRow("Progression") {
                Picker("Progression", selection: $draft.progressionKind) {
                    ForEach(progressionOptions, id: \.self) { kind in
                        Text(Self.title(for: kind)).tag(kind)
                    }
                }
            }
            divider
            advanced
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.chalkDivider)
            .frame(height: Chalk.Line.hairline)
    }

    // MARK: Reps

    private var repsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Chalk.Space.sm) {
                Text("Reps").font(.chalkBody).foregroundStyle(.chalkInk)
                Spacer(minLength: Chalk.Space.sm)
                repsSteppers
            }
            VStack(alignment: .leading, spacing: Chalk.Space.xs) {
                Text("Reps").font(.chalkBody).foregroundStyle(.chalkInk)
                repsSteppers
            }
        }
        .padding(.vertical, Chalk.Space.xs)
    }

    private var repsSteppers: some View {
        HStack(spacing: Chalk.Space.xs) {
            ChalkStepper("Lowest reps", value: repsLow, in: 1...30, compact: true, identifier: "\(identifierPrefix).repsLow")
            Text("to")
                .font(.chalkFootnote)
                .foregroundStyle(.chalkInk2)
                .accessibilityHidden(true)
            ChalkStepper("Highest reps", value: repsHigh, in: 1...30, compact: true, identifier: "\(identifierPrefix).repsHigh")
        }
    }

    /// Keeps low ≤ high: raising low past high drags high along.
    private var repsLow: Binding<Int> {
        Binding(
            get: { draft.targetRepsLow },
            set: { newValue in
                draft.targetRepsLow = newValue
                if draft.targetRepsHigh < newValue { draft.targetRepsHigh = newValue }
            }
        )
    }

    private var repsHigh: Binding<Int> {
        Binding(
            get: { draft.targetRepsHigh },
            set: { newValue in
                draft.targetRepsHigh = newValue
                if draft.targetRepsLow > newValue { draft.targetRepsLow = newValue }
            }
        )
    }

    // MARK: RPE

    /// 0 = off, 1… = index into `rpeOptions` + 1.
    private var rpeIndex: Binding<Int> {
        Binding(
            get: {
                guard let rpe = draft.targetRPE,
                      let index = Self.rpeOptions.firstIndex(of: rpe) else { return 0 }
                return index + 1
            },
            set: { newValue in
                draft.targetRPE = newValue == 0 ? nil : Self.rpeOptions[min(newValue, Self.rpeOptions.count) - 1]
            }
        )
    }

    // MARK: Pickers

    private func pickerRow<P: View>(_ title: String, @ViewBuilder picker: () -> P) -> some View {
        HStack {
            Text(title).font(.chalkBody).foregroundStyle(.chalkInk)
            Spacer(minLength: Chalk.Space.sm)
            picker()
                .pickerStyle(.menu)
                .tint(Color.chalkAccentInk)
                .labelsHidden()
        }
        .frame(minHeight: Chalk.Size.minTouch)
    }

    private var progressionOptions: [ProgressionKind] {
        var options: [ProgressionKind] = [.double, .rpe]
        if !options.contains(draft.progressionKind) {
            options.append(draft.progressionKind)
        }
        return options
    }

    static func title(for kind: ProgressionKind) -> String {
        switch kind {
        case .double: return "Double progression"
        case .rpe: return "RPE autoregulation"
        case .block: return "Block periodized"
        case .hybrid: return "Hybrid"
        }
    }

    // MARK: Advanced

    private var advanced: some View {
        DisclosureGroup(isExpanded: $showingAdvanced) {
            VStack(alignment: .leading, spacing: Chalk.Space.md) {
                Toggle("Track tempo", isOn: $draft.tracksTempo)
                if draft.tracksTempo {
                    HStack(spacing: Chalk.Space.sm) {
                        tempoField(index: 0, placeholder: "Ecc")
                        tempoField(index: 1, placeholder: "Bot")
                        tempoField(index: 2, placeholder: "Con")
                        tempoField(index: 3, placeholder: "Top")
                    }
                }
                Toggle("Track partial reps", isOn: $draft.tracksPartialReps)
                Toggle("Auto warm-up", isOn: warmupEnabled)
                Text(warmupFootnote)
                    .font(.chalkFootnote)
                    .foregroundStyle(.chalkInk2)
                Button("Warm-up settings…", action: onEditWarmup)
                    .buttonStyle(.chalk(.ghost, size: .compact))
                overrides
            }
            .font(.chalkBody)
            .tint(Color.chalkInk)
            .padding(.vertical, Chalk.Space.sm)
        } label: {
            Text("Advanced")
                .font(.chalkBody)
                .foregroundStyle(.chalkInk)
                .frame(minHeight: Chalk.Size.minTouch)
        }
        .tint(Color.chalkInk)
    }

    private var warmupFootnote: String {
        if draft.warmupOverride?.enabled ?? true {
            return "First qualifying compound gets a plate-rounded ramp (40/60/75/90%)."
        }
        return "No warm-up sets will be generated for this exercise."
    }

    private var warmupEnabled: Binding<Bool> {
        Binding(
            get: { draft.warmupOverride?.enabled ?? true },
            set: { newValue in
                let skipNext = draft.warmupOverride?.skipNextSession ?? false
                if newValue && !skipNext {
                    draft.warmupOverride = nil
                } else {
                    draft.warmupOverride = WarmupConfig(enabled: newValue, skipNextSession: skipNext)
                }
            }
        )
    }

    private func tempoField(index: Int, placeholder: String) -> some View {
        let parts = (draft.tempo ?? "").split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        let current = index < parts.count ? parts[index] : ""
        let binding = Binding<String>(
            get: { current },
            set: { newValue in
                var p = parts
                while p.count <= index { p.append("") }
                p[index] = newValue
                let joined = p.joined(separator: "-")
                draft.tempo = joined.replacingOccurrences(of: "-", with: "").isEmpty ? nil : joined
            }
        )
        return TextField(placeholder, text: binding)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(minWidth: 44, minHeight: Chalk.Size.minTouch)
            .background(Color.chalkSunken, in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous))
            .accessibilityLabel(Text("Tempo \(placeholder)"))
    }

    private var overrides: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            Text("Per-set overrides").chalkLabelStyle()
            ForEach(draft.setOverrides, id: \.objectID) { item in
                HStack {
                    PerSetOverrideRow(draft: item)
                    Button {
                        draft.setOverrides.removeAll { $0 === item }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.chalkDanger)
                            .frame(width: Chalk.Size.minTouch, height: Chalk.Size.minTouch)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove override for set \(item.setIndex + 1)"))
                }
            }
            Button("Add override") {
                let used = Set(draft.setOverrides.map(\.setIndex))
                let next = (0..<draft.targetSets).first { !used.contains($0) } ?? max(0, draft.targetSets - 1)
                draft.appendOverride(setIndex: next)
            }
            .buttonStyle(.chalk(.ghost, size: .compact))
        }
    }
}
