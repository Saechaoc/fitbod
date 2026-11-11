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
//  It offers no per-set overrides: the logger never applies them, so the
//  section is gone and stored overrides stay untouched (T110).
//
//  Verbatim copy:
//    "Sets" / "Min reps" / "Max reps" / "Target RPE" / "Rest" /
//    "Track tempo" / "Track partial reps" / "Auto warm-up"
//
//  Target reps are two steppers and target RPE is one chip row with an
//  explicit no-target chip, so no number is ever typed over (Milestone 1
//  review items 5 and 6).
//
//  Rest reads as minutes and seconds, such as "3:00", in the chip and the
//  stepper, as on the rest timer. The three switches use the BRU toggle
//  style, and at accessibility sizes their labels wrap and the tempo
//  fields drop their fixed widths, so nothing is clipped (Milestone 1
//  review items 12 and 13).
//
//  Each tempo field keeps its drawn size, and its touch target reaches 2pt
//  into each gap beside it and up and down to 44pt, where a tap focuses
//  the field (T111). A field selects its digit as it takes focus, so a
//  digit typed into it replaces the one it shows (T39). The fields read
//  and write the tempo through TempoParts, so a blank part keeps its
//  place and editing one part leaves the others where they were (T145).
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule /
//  NO RoundedRectangle / NO Apple HIG semantic fonts
//

import SwiftUI

public struct PrescriptionEditorRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weightUnit) private var defaultUnit
    @Environment(\.locale) private var locale
    @Bindable public var draft: RoutineExerciseDraft
    public let hasBlock: Bool

    @State private var showingAdvanced: Bool = false
    /// A cardio plan's fields as typed: its time, then the level or speed,
    /// or a treadmill's speed and incline (RM-062).
    @State private var planTexts: [CardioPlanField: String] = [:]
    @FocusState private var focusedPlanField: CardioPlanField?
    @State private var tempoError: String?
    @FocusState private var focusedTempoField: Int?
    /// One tempo field's drawn height, which sets how far its touch target
    /// reaches up and down.
    @State private var tempoFieldHeight: CGFloat = BRUMetrics.touchTarget

    /// How far a tempo field's touch target reaches into the 6pt gap on each
    /// side, so a 40pt field gets a 44pt target.
    private static let tempoTargetReach: CGFloat = 2

    public init(draft: RoutineExerciseDraft, hasBlock: Bool = false) {
        self.draft = draft
        self.hasBlock = hasBlock
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Prescription chip row ──
            chipRow

            // ── SetRowsContainer ── Cardio is one bout, with no set grid.
            if !isCardio {
                SetRowsContainer(exercise: draft)
            }

            // ── Advanced / editable prescription block ──
            advancedSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Chip Row

    private var chipRow: some View {
        // Constrain long labels and reflow at accessibility text sizes.
        let allChips = [
            (repsChipLabel, Color.bruInk),
            (rpeChipLabel, Color.bruInk),
            (restChipLabel, Color.bruInk),
        ]
        // A timed exercise has no rep or effort target: its rest alone.
        // Cardio has no rest either: its plan, one chip per value (RM-062).
        let plan = isCardio ? draft.planParts(tracking: draft.exercise?.tracking, unit: unit) : []
        let chips = isCardio
            ? (plan.isEmpty ? ["No plan yet"] : plan).map { ($0, Color.bruInk) }
            : isTimed ? Array(allChips.suffix(1)) : allChips
        return BRUFlowLayout(spacing: 5, lineSpacing: 5) {
            ForEach(chips.indices, id: \.self) { i in
                let (label, color) = chips[i]
                BRUChip(label, color: color, fill: false, textCase: nil)
            }
        }
    }

    /// The exercise logs a time: it has sets and rest, and none of the rep
    /// options.
    private var isTimed: Bool {
        draft.exercise?.tracking.isTimed == true
    }

    /// Cardio is one bout with a planned time and machine settings, and no
    /// sets or rest (RM-062).
    private var isCardio: Bool {
        draft.exercise?.isCardio == true
    }

    /// The exercise's own unit wins over the app-wide one, as in the logger.
    private var unit: WeightUnit {
        .effective(for: draft.exercise, default: defaultUnit)
    }

    // MARK: Chip Labels

    private var repsChipLabel: String {
        if draft.targetRepsLow == draft.targetRepsHigh {
            return BRUCountLabel.text(draft.targetRepsLow, "rep")
        }
        return "\(draft.targetRepsLow)–\(BRUCountLabel.text(draft.targetRepsHigh, "rep"))"
    }

    private var rpeChipLabel: String {
        guard let rpe = draft.targetRPE else { return "RPE —" }
        let rpeStr = rpe == rpe.rounded() ? "\(Int(rpe))" : String(format: "%.1f", rpe)
        return "RPE \(rpeStr)"
    }

    private var restChipLabel: String {
        "\(NumberText.minutesSeconds(draft.prescribedRestSeconds)) rest"
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
                if isCardio {
                    cardioPlanFields
                } else if isTimed {
                    setsStepper
                    restStepper
                } else {
                    setsStepper
                    repsSteppers
                    rpeRow
                    restStepper
                    tempoSection
                    partialRepsToggle
                    autoWarmupToggle
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Cardio plan

    /// The bout's time, then the machine's level or stair speed, or a
    /// treadmill's speed and incline, each typed as the logger takes them:
    /// "2000" is 20:00. A value that does not read is not planned.
    @ViewBuilder
    private var cardioPlanFields: some View {
        planField(.time, label: "Time", keyboard: .numberPad)
        ForEach(planValueFields, id: \.self) { field in
            planField(field, label: label(for: field), keyboard: .decimalPad)
        }
    }

    /// The plan's fields beside its time, by what the machine records.
    private var planValueFields: [CardioPlanField] {
        (draft.exercise?.timedValues ?? []).compactMap {
            switch $0 {
            case .level: .level
            case .speed: .speed
            case .incline: .incline
            case .weight, .distance: nil
            }
        }
    }

    private func label(for field: CardioPlanField) -> String {
        switch field {
        case .time: "Time"
        case .level: (draft.exercise?.tracking.levelName ?? "level").capitalized
        case .speed: "Speed (\(SetText.speedUnit(unit)))"
        case .incline: "Incline (%)"
        }
    }

    private func planField(
        _ field: CardioPlanField, label: String, keyboard: UIKeyboardType
    ) -> some View {
        HStack {
            Text(label)
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruInk)
            Spacer()
            TextField(label, text: planText(field), prompt: Text("—").foregroundStyle(Color.bruMuted))
                .font(BRUFont.bodyEmphasis)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
                .focused($focusedPlanField, equals: field)
                .selectsAllOnFocus(focusedPlanField == field)
                .frame(width: 96)
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
                .overlay(Rectangle().stroke(Color.bruInk, lineWidth: 1.5))
                .contentShape(Rectangle())
                .onTapGesture { focusedPlanField = field }
                .revealsAboveKeyboard(focusedPlanField == field)
                .accessibilityIdentifier("prescription.plan.\(field.rawValue)")
        }
        .onAppear { planTexts[field] = storedPlanText(field) }
        // A field that finished editing shows what was planned, as stored:
        // "2000" reads "20:00", and a value that did not read clears.
        .onChange(of: focusedPlanField) { previous, _ in
            if previous == field { planTexts[field] = storedPlanText(field) }
        }
    }

    /// A field's text; typing writes the plan at once, so Save never
    /// misses the last keystroke.
    private func planText(_ field: CardioPlanField) -> Binding<String> {
        Binding(
            get: { planTexts[field] ?? "" },
            set: { text in
                planTexts[field] = text
                switch field {
                case .time:
                    draft.targetDurationSeconds = SetText.seconds(fromTyped: text)
                        .flatMap { $0 < WorkoutCorrectionInput.durationLimit ? $0 : nil }
                case .level:
                    draft.targetLevel = planNumber(text)
                case .speed:
                    draft.targetSpeedKmh = planNumber(text) == nil
                        ? nil : SetText.kmh(fromTyped: text, unit: unit, locale: locale)
                case .incline:
                    draft.targetIncline = planNumber(text)
                }
            }
        )
    }

    /// A typed level, speed or incline the plan can hold, or nil.
    private func planNumber(_ text: String) -> Double? {
        guard let number = SetText.number(fromTyped: text, locale: locale),
              WorkoutCorrectionInput.isSupported(number) else { return nil }
        return number
    }

    private func storedPlanText(_ field: CardioPlanField) -> String {
        switch field {
        case .time: draft.targetDurationSeconds.map(SetText.duration) ?? ""
        case .level: draft.targetLevel.map { SetText.entry(level: $0, locale: locale) } ?? ""
        case .speed: draft.targetSpeedKmh.map { SetText.entry(speed: $0, unit: unit, locale: locale) } ?? ""
        case .incline: draft.targetIncline.map { SetText.entry(level: $0, locale: locale) } ?? ""
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
        BRUStepper("Rest", value: $draft.prescribedRestSeconds, in: 0...600, step: 15) { NumberText.minutesSeconds($0) }
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
            if let tempoError {
                Text(tempoError)
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruSignalText)
                    .accessibilityIdentifier("prescription.tempo.error")
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
        let parts = TempoParts.split(draft.tempo)
        let binding = Binding<String>(
            get: { parts[index] },
            set: { newValue in
                var edited = TempoParts.split(draft.tempo)
                edited[index] = newValue
                do {
                    draft.tempo = try TempoParts.join(edited)
                    tempoError = nil
                } catch {
                    tempoError = error.localizedDescription
                }
            }
        )
        let verticalReach = max(0, (BRUMetrics.touchTarget - tempoFieldHeight) / 2)
        return TextField(placeholder, text: binding)
            .frame(width: width)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(BRUFont.bodyDefault)
            .focused($focusedTempoField, equals: index)
            // A digit typed into the field replaces the one it shows (T39).
            .selectsAllOnFocus(focusedTempoField == index)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tempoFieldHeight = $0 }
            // The touch target: the padding reaches past the field, a tap
            // there focuses it, and the negative padding gives the layout
            // back, so nothing drawn moves.
            .padding(.horizontal, Self.tempoTargetReach)
            .padding(.vertical, verticalReach)
            .contentShape(Rectangle())
            .onTapGesture { focusedTempoField = index }
            // The whole target scrolls clear of the keyboard and its DONE
            // while the field has focus (T39).
            .revealsAboveKeyboard(focusedTempoField == index)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("prescription.tempo.\(index + 1)")
            .padding(.horizontal, -Self.tempoTargetReach)
            .padding(.vertical, -verticalReach)
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
}

/// A cardio plan's fields in the prescription editor (RM-062).
enum CardioPlanField: String, Hashable {
    case time, level, speed, incline
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
