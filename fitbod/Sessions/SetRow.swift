//
//  SetRow.swift
//  fitbod
//
//  Chalkline set-entry row — the most-used control in the app. One row per
//  `SetEntry` in the active workout:
//
//      SET  PREVIOUS   LB    REPS  RPE   ✓
//       2   185 × 5   [185]  [ 5]   8   (●)
//
//  Design goals (docs/design/screens.md § Active workout):
//    - Fast: weight is pre-filled (previous / prescription), tapping the
//      Previous value copies last time's weight × reps, and the keyboard
//      toolbar's Next walks weight → reps → next set.
//    - One-handed: the 48 pt check button sits at the trailing edge, in
//      thumb reach; inputs are 44 pt tall.
//    - Honest data: completing requires reps (and a positive weight unless
//      the lift is bodyweight-based). A missing value shows the danger
//      outline + an inline message instead of silently logging.
//    - Accessible: at accessibility text sizes the row stacks into two
//      lines; every control has a label that reads its value.
//
//  Values are written to the model on every keystroke and saved by the
//  parent, so a relaunch mid-set keeps what was typed.
//

import SwiftUI
import SwiftData
import UIKit

/// Focus identity for the numeric fields in the workout list.
public enum SetField: Hashable, Sendable {
    case weight(UUID)
    case reps(UUID)
}

public struct SetEntryRow: View {
    @Bindable public var entry: SetEntry
    let setLabel: String
    let previous: PreviousPerformance.Line?
    let targetRepsText: String
    let unitLabel: String
    let allowsSignedWeight: Bool
    let isNext: Bool
    let validation: SetValidation
    let identifierPrefix: String
    let focus: FocusState<SetField?>.Binding
    let onComplete: () -> Void
    let onUncomplete: () -> Void
    let onUsePrevious: () -> Void
    let onEdited: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var weightWidth: CGFloat = 74
    @ScaledMetric(relativeTo: .title3) private var repsWidth: CGFloat = 54
    @ScaledMetric(relativeTo: .title3) private var rpeWidth: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var setWidth: CGFloat = 28

    public init(
        entry: SetEntry,
        setLabel: String,
        previous: PreviousPerformance.Line?,
        targetRepsText: String,
        unitLabel: String,
        allowsSignedWeight: Bool,
        isNext: Bool,
        validation: SetValidation,
        identifierPrefix: String,
        focus: FocusState<SetField?>.Binding,
        onComplete: @escaping () -> Void,
        onUncomplete: @escaping () -> Void,
        onUsePrevious: @escaping () -> Void,
        onEdited: @escaping () -> Void
    ) {
        self.entry = entry
        self.setLabel = setLabel
        self.previous = previous
        self.targetRepsText = targetRepsText
        self.unitLabel = unitLabel
        self.allowsSignedWeight = allowsSignedWeight
        self.isNext = isNext
        self.validation = validation
        self.identifierPrefix = identifierPrefix
        self.focus = focus
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
        self.onUsePrevious = onUsePrevious
        self.onEdited = onEdited
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                stackedLayout
            } else {
                singleLineLayout
            }
            if let message = validation.message(setLabel: setLabel) {
                ChalkValidationText(message)
                    .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : setWidth + Chalk.Space.sm)
                    .accessibilityIdentifier("\(identifierPrefix).error")
            }
        }
        .padding(.vertical, Chalk.Space.xs)
        .accessibilityElement(children: .contain)
    }

    // MARK: Layouts

    private var singleLineLayout: some View {
        HStack(spacing: 6) {
            setNumber
                .frame(width: setWidth)
            previousButton
                .frame(maxWidth: .infinity, alignment: .leading)
            weightField
                .frame(width: weightWidth)
            repsField
                .frame(width: repsWidth)
            rpeMenu
                .frame(width: rpeWidth)
            checkButton
        }
    }

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Set \(setLabel)")
                    .font(.chalkSubtitle)
                    .textCase(.uppercase)
                    .foregroundStyle(isNext ? Color.chalkAccentInk : Color.chalkInk)
                Spacer(minLength: Chalk.Space.sm)
                previousButton
            }
            HStack(spacing: Chalk.Space.sm) {
                VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                    Text(unitLabel).chalkLabelStyle()
                    weightField
                }
                VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                    Text("Reps").chalkLabelStyle()
                    repsField
                }
            }
            HStack(spacing: Chalk.Space.sm) {
                VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                    Text("RPE").chalkLabelStyle()
                    rpeMenu
                }
                Spacer(minLength: Chalk.Space.sm)
                checkButton
            }
        }
    }

    // MARK: Cells

    private var setNumber: some View {
        Text(setLabel)
            .font(.chalkMetric)
            .foregroundStyle(isNext ? Color.chalkAccentInk : Color.chalkInk)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel(Text("Set \(setLabel)"))
    }

    @ViewBuilder
    private var previousButton: some View {
        if let previous {
            Button(action: onUsePrevious) {
                Text(previousText(previous))
                    .font(.chalkFootnote)
                    .foregroundStyle(.chalkInk2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(minHeight: Chalk.Size.minTouch, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(entry.isComplete)
            .accessibilityLabel(Text("Previous: \(previousSpoken(previous))"))
            .accessibilityHint(Text(entry.isComplete ? "" : "Double-tap to copy into this set"))
            .accessibilityIdentifier("\(identifierPrefix).previous")
        } else {
            Text("—")
                .font(.chalkFootnote)
                .foregroundStyle(.chalkInk3)
                .accessibilityLabel(Text("No previous set"))
        }
    }

    private var weightField: some View {
        SetNumberField(
            value: entry.weight,
            isInteger: false,
            allowsNegative: allowsSignedWeight,
            placeholder: allowsSignedWeight ? "BW" : "0",
            showsZero: false,
            isComplete: entry.isComplete,
            isError: validation == .missingWeight,
            isNext: isNext,
            accessibilityLabel: "Set \(setLabel) weight, \(unitLabel)",
            identifier: "\(identifierPrefix).weight",
            focus: focus,
            field: .weight(entry.id),
            onChange: { newValue in
                entry.weight = newValue ?? 0
                if newValue != nil, entry.wasManualOverride == false,
                   let prescribed = entry.sessionExercise?.prescribedWeight,
                   abs((newValue ?? 0) - prescribed) > 0.001 {
                    entry.wasManualOverride = true
                }
                onEdited()
            }
        )
    }

    private var repsField: some View {
        SetNumberField(
            value: Double(entry.reps),
            isInteger: true,
            allowsNegative: false,
            placeholder: targetRepsText,
            showsZero: false,
            isComplete: entry.isComplete,
            isError: validation == .missingReps,
            isNext: false,
            accessibilityLabel: "Set \(setLabel) reps",
            identifier: "\(identifierPrefix).reps",
            focus: focus,
            field: .reps(entry.id),
            onChange: { newValue in
                entry.reps = max(0, Int(newValue ?? 0))
                onEdited()
            }
        )
    }

    private var rpeMenu: some View {
        Menu {
            Button("No RPE") {
                entry.rpe = nil
                onEdited()
            }
            ForEach(Self.rpeOptions, id: \.self) { value in
                Button(ChalkFormat.rpe(value)) {
                    entry.rpe = value
                    onEdited()
                }
            }
        } label: {
            Text(entry.rpe.map { ChalkFormat.rpe($0) } ?? "–")
                .font(.chalkMetric)
                .foregroundStyle(entry.rpe == nil ? Color.chalkInk3 : Color.chalkInk)
                .frame(maxWidth: .infinity, minHeight: Chalk.Size.input)
                .background(
                    entry.isComplete ? Color.clear : Color.chalkSunken,
                    in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Set \(setLabel) RPE"))
        .accessibilityValue(Text(entry.rpe.map { ChalkFormat.rpe($0) } ?? "not set"))
        .accessibilityIdentifier("\(identifierPrefix).rpe")
    }

    private var checkButton: some View {
        let label: String = entry.isComplete ? "Set \(setLabel) complete" : "Complete set \(setLabel)"
        return Button {
            if entry.isComplete { onUncomplete() } else { onComplete() }
        } label: {
            ZStack {
                Circle()
                    .fill(entry.isComplete ? Color.chalkInk : Color.chalkSurface)
                Circle()
                    .strokeBorder(checkBorder, lineWidth: isNext && !entry.isComplete ? Chalk.Line.focus : Chalk.Line.strong)
                if entry.isComplete {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.heavy))
                        .foregroundStyle(.chalkCanvas)
                }
            }
            .frame(width: Chalk.Size.minTouch, height: Chalk.Size.minTouch)
            .frame(width: Chalk.Size.setCheck, height: Chalk.Size.setCheck)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(entry.isComplete ? "complete" : "open"))
        .accessibilityHint(Text(entry.isComplete ? "Double-tap to edit this set" : "Logs the set and starts rest"))
        .accessibilityIdentifier("\(identifierPrefix).complete")
    }

    private var checkBorder: Color {
        if entry.isComplete { return .chalkInk }
        if validation != .ok { return .chalkDanger }
        return isNext ? .chalkAccent : .chalkInk
    }

    // MARK: Text

    static let rpeOptions: [Double] = [10, 9.5, 9, 8.5, 8, 7.5, 7, 6.5, 6]

    private func previousText(_ line: PreviousPerformance.Line) -> String {
        let weight = allowsSignedWeight && line.weight > 0 ? "+" + ChalkFormat.weight(line.weight) : ChalkFormat.weight(line.weight)
        let base = line.weight == 0 && allowsSignedWeight ? "BW × \(line.reps)" : "\(weight) × \(line.reps)"
        if let rpe = line.rpe {
            return base + " @" + ChalkFormat.rpe(rpe)
        }
        return base
    }

    private func previousSpoken(_ line: PreviousPerformance.Line) -> String {
        var text = "\(ChalkFormat.weight(line.weight)) \(unitLabel) for \(line.reps) reps"
        if let rpe = line.rpe {
            text += " at RPE \(ChalkFormat.rpe(rpe))"
        }
        return text
    }
}

/// Numeric text input backed by local text state, so typing "187." or a
/// leading "-" is never reformatted mid-keystroke. Parsed values are pushed
/// to the model on every change; external model changes (Previous, Add
/// set) refresh the text.
struct SetNumberField: View {
    let value: Double
    let isInteger: Bool
    let allowsNegative: Bool
    let placeholder: String
    let showsZero: Bool
    let isComplete: Bool
    let isError: Bool
    let isNext: Bool
    let accessibilityLabel: String
    let identifier: String
    let focus: FocusState<SetField?>.Binding
    let field: SetField
    let onChange: (Double?) -> Void

    @State private var text: String = ""
    @State private var loaded = false

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Color.chalkInk3))
            .font(.chalkMetric)
            .foregroundStyle(.chalkInk)
            .multilineTextAlignment(.center)
            .keyboardType(keyboard)
            .focused(focus, equals: field)
            .disabled(isComplete)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, Chalk.Space.xs)
            .frame(maxWidth: .infinity, minHeight: Chalk.Size.input)
            .background(
                isComplete ? Color.clear : (isError ? Color.chalkSurface : Color.chalkSunken),
                in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isError ? Chalk.Line.strong : Chalk.Line.focus)
            }
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityValue(Text(text.isEmpty ? (isError ? "empty, required" : "empty") : text))
            .accessibilityIdentifier(identifier)
            .onAppear {
                if !loaded {
                    text = Self.format(value, isInteger: isInteger, showsZero: showsZero)
                    loaded = true
                }
            }
            .onChange(of: text) { _, newText in
                let sanitized = Self.sanitize(newText, allowsNegative: allowsNegative, isInteger: isInteger)
                if sanitized != newText {
                    text = sanitized
                    return
                }
                onChange(Self.parse(sanitized))
            }
            .onChange(of: value) { _, newValue in
                let current = Self.parse(text) ?? 0
                if abs(current - newValue) > 0.0001 {
                    text = Self.format(newValue, isInteger: isInteger, showsZero: showsZero)
                }
            }
    }

    private var keyboard: UIKeyboardType {
        if allowsNegative { return .numbersAndPunctuation }
        return isInteger ? .numberPad : .decimalPad
    }

    private var borderColor: Color {
        if isError { return .chalkDanger }
        if focus.wrappedValue == field { return .chalkAccent }
        return .clear
    }

    static func format(_ value: Double, isInteger: Bool, showsZero: Bool) -> String {
        if value == 0 && !showsZero { return "" }
        return isInteger ? String(Int(value)) : ChalkFormat.weight(value)
    }

    /// Keeps digits, one decimal separator (`,` normalised to `.`), and a
    /// leading minus when allowed.
    static func sanitize(_ text: String, allowsNegative: Bool, isInteger: Bool) -> String {
        var result = ""
        var hasDot = false
        for (index, ch) in text.enumerated() {
            if ch.isASCII && ch.isNumber {
                result.append(ch)
            } else if (ch == "." || ch == ",") && !isInteger && !hasDot {
                result.append(".")
                hasDot = true
            } else if (ch == "-" || ch == "−") && allowsNegative && index == 0 {
                result.append("-")
            } else if ch == "+" && allowsNegative && index == 0 {
                continue
            }
        }
        return String(result.prefix(7))
    }

    /// nil for empty or a lone "-" / ".".
    static func parse(_ text: String) -> Double? {
        let trimmed = text.hasSuffix(".") ? String(text.dropLast()) : text
        guard !trimmed.isEmpty, trimmed != "-" else { return nil }
        return Double(trimmed)
    }
}

private struct SetRowsPreview: View {
    @FocusState private var focus: SetField?
    let done: SetEntry
    let next: SetEntry
    let error: SetEntry

    var body: some View {
        List {
            SetEntryRow(entry: done, setLabel: "1", previous: .init(weight: 185, reps: 5, rpe: 7), targetRepsText: "4–6", unitLabel: "lb", allowsSignedWeight: false, isNext: false, validation: .ok, identifierPrefix: "p.0", focus: $focus, onComplete: {}, onUncomplete: {}, onUsePrevious: {}, onEdited: {})
                .listRowBackground(Color.chalkComplete)
            SetEntryRow(entry: next, setLabel: "2", previous: .init(weight: 185, reps: 5, rpe: nil), targetRepsText: "4–6", unitLabel: "lb", allowsSignedWeight: false, isNext: true, validation: .ok, identifierPrefix: "p.1", focus: $focus, onComplete: {}, onUncomplete: {}, onUsePrevious: {}, onEdited: {})
            SetEntryRow(entry: error, setLabel: "3", previous: nil, targetRepsText: "4–6", unitLabel: "lb", allowsSignedWeight: false, isNext: false, validation: .missingReps, identifierPrefix: "p.2", focus: $focus, onComplete: {}, onUncomplete: {}, onUsePrevious: {}, onEdited: {})
        }
    }
}

#Preview("Set rows") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let done = SetEntry()
    done.weight = 185
    done.reps = 5
    done.rpe = 8
    done.isComplete = true
    let next = SetEntry()
    next.weight = 185
    let error = SetEntry()
    error.weight = 185
    [done, next, error].forEach { ctx.insert($0) }
    return SetRowsPreview(done: done, next: next, error: error)
        .modelContainer(container)
}
