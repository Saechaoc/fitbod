//
//  PrescriptionWeightCell.swift
//  fitbod
//
//  Phase 3.2-04 BRU rewrite — prescribed-weight input cell.
//
//  BRU conformance (03-UI-SPEC lines 388, 409, 494):
//    - info.circle SF Symbol + Button block DELETED (was lines 101–113 of v1)
//    - Color.accentColor DELETED (was on info.circle button)
//    - Why-this-weight opens from SetRow's visible WHY control or the
//      "Why this weight" accessibility action (Milestone 1 decision 8). The
//      long press that replaced info.circle never fired reliably on a cell
//      holding a TextField, so it is gone.
//    - BRUFont.bodyEmphasis for editable weight value (was Font.body)
//    - BRUFont.bodyDefault for range display (was Font.body)
//    - BRUFont.labelMicro + .tracking(1.0) for the "M" badge (was Font.caption)
//    - Zero Color(.system*), zero RoundedRectangle, zero Capsule, zero SF Symbols
//
//  Layout:
//    [weight input OR read-only range]
//    The "M" badge marks a weight typed away from the prescription. It sits
//    as a superscript right after the digits, inside the cell's own width,
//    so it never reaches the reps column (review item 18). A prescribed
//    weight of 0 is no prescription: the field keeps its "—" placeholder.
//    A calibrating range of 0 to 0 is no suggestion either: the read-only
//    cell shows the same "—", and VoiceOver reads "none".
//    An open calibrating set shows its range until the lifter picks a
//    weight (ticket T80). Override brings in the weight field, holding the
//    set's weight; a weight typed away from the prescription, or one that
//    equals a suggestion above 0, then keeps showing, and a logged set
//    shows the weight it logged.
//    The cell presents WhyThisWeightSheet when explanation != nil, with the
//    set's rep range, target RPE and set type for its hero. Opening it
//    ends editing, so the keyboard never covers the sheet. Use writes the
//    suggested weight into the set and clears the badge; Override closes the
//    sheet and focuses the weight field.
//    While the field has focus, the cell reports the weight it holds, and
//    SetRow shows the set's plates for it (ticket T125).
//    The field selects its weight as it takes focus, so a typed weight
//    replaces it, and a field left with no number in it shows the set's
//    weight again, the weight the set logs (ticket T39).
//
//  The 44pt touch target is preserved via the cell's vertical padding (12pt) +
//  TextField height, and a tap anywhere on it focuses the field (T39).
//

import SwiftUI

public struct PrescriptionWeightCell: View {
    @Binding public var weight: Double
    public let prescribed: Double?
    /// When non-nil, the set is calibrating: until the lifter picks a
    /// weight, an open set renders the read-only range Text instead of the
    /// editable TextField (see `showsRange`). Format:
    /// "{low} \u{2013} {high} {unitLabel}"; a range of 0 to 0 shows the
    /// field's "—" placeholder instead.
    public let range: ClosedRange<Double>?
    public let explanation: PrescriptionExplanation?
    /// The set's rep range, target RPE and type, which Why-this-weight's
    /// hero and steps show.
    public let targetReps: ClosedRange<Int>?
    public let targetRPE: Double?
    public let setType: SetType
    /// Unit label for the weight ("lb" or "kg"). No default: the caller
    /// passes the exercise's effective unit.
    public var unitLabel: String
    @Binding public var wasManualOverride: Bool
    public var isComplete: Bool = false
    public var onTapEmptyCell: () -> Void = {}
    /// Fired when the weight field loses focus so the caller can persist.
    public var onEditCommitted: () -> Void = {}
    /// SetRow's WHY control opens Why-this-weight through this binding.
    /// Without one (previews), the cell keeps the state itself.
    private let isExplaining: Binding<Bool>?
    /// SetRow shows the set's plates from this: while the weight field has
    /// focus, the weight it holds (0 when it holds none); nil without focus.
    private let enteredWeight: Binding<Double?>?

    @State private var weightText: String
    @State private var showWhySheet: Bool = false
    /// Set by Override: the weight field takes focus once the sheet is gone.
    @State private var focusAfterSheet = false
    /// Set by Override on a calibrating set: the weight field stands in for
    /// the range until editing ends.
    @State private var isOverridingRange = false
    @FocusState private var weightFocused: Bool

    public init(
        weight: Binding<Double>,
        prescribed: Double?,
        range: ClosedRange<Double>?,
        explanation: PrescriptionExplanation?,
        targetReps: ClosedRange<Int>? = nil,
        targetRPE: Double? = nil,
        setType: SetType = .default,
        unitLabel: String,
        wasManualOverride: Binding<Bool>,
        isComplete: Bool = false,
        onTapEmptyCell: @escaping () -> Void = {},
        onEditCommitted: @escaping () -> Void = {},
        isExplaining: Binding<Bool>? = nil,
        enteredWeight: Binding<Double?>? = nil
    ) {
        self._weight = weight
        self.prescribed = prescribed
        self.range = range
        self.explanation = explanation
        self.targetReps = targetReps
        self.targetRPE = targetRPE
        self.setType = setType
        self.unitLabel = unitLabel
        self._wasManualOverride = wasManualOverride
        self.isComplete = isComplete
        self.onTapEmptyCell = onTapEmptyCell
        self.onEditCommitted = onEditCommitted
        self.isExplaining = isExplaining
        self.enteredWeight = enteredWeight
        // The field's text starts as the set's weight; onAppear seeds a
        // prescription into an empty set.
        self._weightText = State(initialValue: Self.text(for: weight.wrappedValue))
    }

    public var body: some View {
        HStack(spacing: 4) {
            if showsRange, let r = range {
                // MARK: Read-only calibrating-range display
                // 03-UI-SPEC line 206 verbatim: "{low} \u{2013} {high} unit" with U+2013 en-dash
                if let text = rangeText {
                    Text(text)
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .accessibilityValue("\(formatted(r.lowerBound)) to \(formatted(r.upperBound)) \(unitLabel), calibrating")
                } else {
                    // A range of 0 to 0 is no suggestion: the field's empty
                    // "—", in its font and place, read as "none".
                    Text("—")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruMuted)
                        .frame(minWidth: 60, minHeight: 44, alignment: .leading)
                }
            } else {
                // MARK: Editable weight TextField
                TextField("—", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($weightFocused)
                    // A weight typed into the field replaces the one it
                    // shows (T39).
                    .selectsAllOnFocus(weightFocused)
                    .frame(minWidth: 60, minHeight: 44)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(isComplete ? Color.bruSignalText : Color.bruInk)
                    // Only typing changes the weight and the override flag.
                    // Seeding, Use and changes made outside the field write
                    // both themselves, so a weight Use wrote stays unmarked.
                    .onChange(of: weightText) { _, new in
                        guard weightFocused, let d = Double(new) else { return }
                        weight = d
                        wasManualOverride = isManualOverride(d)
                    }
                    .onChange(of: weightFocused) { _, focused in
                        if !focused {
                            // A field left with no number in it keeps the
                            // set's weight, so it shows that weight again
                            // (T39, tradeoffs "Emptied weight field").
                            if Double(weightText) == nil {
                                weightText = Self.text(for: weight)
                            }
                            // A calibrating set keeps the field only for a
                            // weight the lifter picked.
                            isOverridingRange = false
                            onEditCommitted()
                        }
                    }
                    // Override on a calibrating set brings the field in;
                    // it takes focus as it appears.
                    .onAppear {
                        if isOverridingRange && focusAfterSheet {
                            focusAfterSheet = false
                            weightFocused = true
                        }
                    }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !showsRange else { return }
            if weightText.isEmpty { onTapEmptyCell() }
            // The target is taller than the text field inside it, so a tap
            // above or below the text gives the field focus too (T39).
            weightFocused = true
        }
        // Accessibility per 03-UI-SPEC line 494
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(accessibilityValueText)
        // Like SetRow's visible WHY, only an open set offers the action.
        .accessibilityActions {
            if explanation != nil && !isComplete {
                Button("Why this weight") { explaining.wrappedValue = true }
            }
        }
        // MARK: Manual override "M" badge
        // Added after the cell's accessibility so the badge keeps its own label.
        .overlay(alignment: .leading) {
            if !showsRange && wasManualOverride && !weightText.isEmpty {
                overrideBadge
            }
        }
        .sheet(isPresented: explaining, onDismiss: focusAfterOverride) {
            if let exp = explanation {
                WhyThisWeightSheet(
                    explanation: exp,
                    onUseSuggested: { use(exp.roundedWeight) },
                    onOverride: { focusAfterSheet = true },
                    reps: targetReps,
                    rpe: targetRPE,
                    setTypeLabel: SetTypeChip.label(for: setType),
                    unitLabel: unitLabel
                )
                .presentationDetents([.medium])
            }
        }
        // However the sheet opens, end editing first so the keyboard never
        // covers it; the field's focus change persists any edit.
        .onChange(of: explaining.wrappedValue) { _, open in
            if open {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                )
            }
        }
        // Reflect weight changes made outside the field (swap re-seed,
        // plateau "drop intensity") without fighting the user's own typing.
        // The text keeps up while a calibrating set shows its range too, so
        // the field holds the set's weight when it comes in.
        .onChange(of: weight) { _, new in
            if !weightFocused, Double(weightText) != new {
                weightText = Self.text(for: new)
            }
        }
        // The set's plates follow the field while it has focus.
        .onChange(of: weightInField) { _, entered in
            enteredWeight?.wrappedValue = entered
        }
        .onAppear {
            // Seed the text field from the prescribed weight or current weight.
            // With no prescription, a weight of 0 keeps the "—" placeholder.
            // A calibrating set never takes the prescription: it keeps the
            // weight its workout seeded until the lifter picks one.
            if range == nil, let p = prescription, weight == 0 {
                // The prescription itself is never a manual override.
                weightText = formatted(p)
                weight = p
                wasManualOverride = false
            } else if weight > 0 {
                weightText = formatted(weight)
            }
        }
    }

    // MARK: - Private helpers

    /// SetRow's binding when it passes one, otherwise the cell's own state.
    private var explaining: Binding<Bool> {
        isExplaining ?? $showWhySheet
    }

    /// The prescribed weight, or nil when there is none. A strategy with no
    /// history prescribes 0, which is no prescription.
    private var prescription: Double? {
        guard let prescribed, prescribed > 0 else { return nil }
        return prescribed
    }

    /// The weight in the field while it has focus: 0 when it holds no
    /// number, such as when it is empty. Nil while it has no focus.
    private var weightInField: Double? {
        weightFocused ? Double(weightText) ?? 0 : nil
    }

    /// What the field shows, for VoiceOver: "100 lb", or "none" over the
    /// placeholder.
    private var weightDescription: String {
        weightText.isEmpty ? "none" : "\(formatted(weight)) \(unitLabel)"
    }

    /// Whether the cell shows its calibrating range, or the dash for a
    /// range of 0 to 0, in place of the weight field. An open calibrating
    /// set shows its range until the lifter picks a weight: Override brings
    /// in the field, and a weight typed away from the prescription or one
    /// that equals a suggestion above 0, as Use writes it, keeps showing.
    /// A logged set shows the weight it logged.
    var showsRange: Bool {
        guard range != nil, !isComplete, !isOverridingRange, !weightFocused else { return false }
        return !wasManualOverride && !holdsSuggestion
    }

    /// The set's weight is a suggestion above 0: Why-this-weight's, which
    /// Use writes, or the prescription.
    private var holdsSuggestion: Bool {
        [explanation?.roundedWeight, prescription].contains { suggestion in
            guard let suggestion, suggestion > 0 else { return false }
            return abs(weight - suggestion) <= 0.001
        }
    }

    /// The read-only calibrating range, "95 – 105 lb", or nil when there is
    /// none to show. A range of 0 to 0, a bodyweight lift calibrating with
    /// no added load, is no suggestion, so the cell shows the field's "—".
    var rangeText: String? {
        guard let range, range.upperBound > 0 else { return nil }
        return "\(formatted(range.lowerBound)) \u{2013} \(formatted(range.upperBound)) \(unitLabel)"
    }

    /// VoiceOver's label: the calibrating range, or what the field shows.
    /// A range of 0 to 0 reads like the empty field.
    var accessibilityLabelText: String {
        guard showsRange, let range else { return "Prescribed weight: \(weightDescription)" }
        guard rangeText != nil else { return "Prescribed weight: none" }
        return "Prescribed weight range: \(formatted(range.lowerBound)) to \(formatted(range.upperBound)) \(unitLabel)"
    }

    /// VoiceOver's value: the field's reading, or "none" for a range of 0
    /// to 0. A range's text has its own.
    var accessibilityValueText: String {
        guard showsRange else { return weightDescription }
        return rangeText == nil ? "none" : ""
    }

    /// The "M" as a superscript right after the digits. A hidden copy of
    /// the digits takes their width; when the cell is too narrow, it
    /// truncates first, so the badge stays inside the cell. Taps pass
    /// through to the field.
    private var overrideBadge: some View {
        HStack(alignment: .top, spacing: 2) {
            Text(weightText)
                .font(BRUFont.bodyEmphasis)
                .lineLimit(1)
                .hidden()
                .accessibilityHidden(true)
            Text("M")
                .font(BRUFont.labelMicro)
                .foregroundStyle(Color.bruMuted)
                .tracking(1.0)
                .fixedSize()
                .layoutPriority(1)
                // No .textCase(.uppercase): it would uppercase this label too.
                .accessibilityLabel("changed from prescription")
        }
        .allowsHitTesting(false)
    }

    /// A typed weight that differs from the prescription is a manual override.
    /// A calibrating range is the prescription: one of 0 to 0 prescribes no
    /// load, so a load typed over it is a change too.
    func isManualOverride(_ d: Double) -> Bool {
        guard let p = prescription ?? (range == nil ? nil : 0) else { return false }
        return abs(d - p) > 0.001
    }

    /// Use in Why-this-weight: the suggested weight becomes the set's weight,
    /// and the set is no longer marked as changed from the prescription.
    private func use(_ suggested: Double) {
        weightText = Self.text(for: suggested)
        weight = suggested
        wasManualOverride = false
        onEditCommitted()
    }

    /// Override in Why-this-weight: once the sheet is gone, focus the field.
    /// A calibrating set showing its range has no field yet, so Override
    /// brings it in, holding the set's weight, and it takes focus as it
    /// appears.
    private func focusAfterOverride() {
        guard focusAfterSheet else { return }
        if showsRange {
            weightText = Self.text(for: weight)
            isOverridingRange = true
        } else {
            focusAfterSheet = false
            weightFocused = true
        }
    }

    /// Formats a Double without trailing zeros: "100" not "100.0", "102.5" not "102.500".
    private func formatted(_ d: Double) -> String {
        String(format: "%g", d)
    }

    /// The field's text for a weight: "102.5", or empty for 0 so the field
    /// shows its "—" placeholder.
    private static func text(for weight: Double) -> String {
        weight > 0 ? String(format: "%g", weight) : ""
    }
}

// MARK: - Previews

#Preview("with prescription (editable)") {
    @Previewable @State var weight: Double = 0
    @Previewable @State var wasManualOverride: Bool = false
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg \u{00D7} 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: "Target e1RM 122 kg \u{2192} 88% \u{00D7} 8 \u{2192} 102.5 kg",
        roundedWeight: 102.5,
        roundedLine: "\u{2192} 102.5 kg (rounded down to 2.5 kg plates)",
        status: .calibrated,
        bumpOccurred: false,
        range: nil
    )
    return VStack {
        Text("Prescription weight cell — editable (range nil)")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
        PrescriptionWeightCell(
            weight: $weight,
            prescribed: 102.5,
            range: nil,
            explanation: explanation,
            unitLabel: "lb",
            wasManualOverride: $wasManualOverride
        )
        .padding()
        .background(Color.bruPaper)
        .overlay { Rectangle().stroke(Color.bruInk, lineWidth: 1) }
        .padding()
    }
}

#Preview("with override (M badge visible)") {
    @Previewable @State var weight: Double = 105.0
    @Previewable @State var wasManualOverride: Bool = true
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg \u{00D7} 8 @ RPE 8.5 (May 15)",
        formulaName: "Double progression",
        computedLine: nil,
        roundedWeight: 100.0,
        roundedLine: "\u{2192} 100 kg (rounded down to 2.5 kg plates)",
        status: .notApplicable,
        bumpOccurred: false,
        range: nil
    )
    return VStack {
        Text("Prescription weight cell — manual override, M badge visible")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
        PrescriptionWeightCell(
            weight: $weight,
            prescribed: 100.0,
            range: nil,
            explanation: explanation,
            unitLabel: "lb",
            wasManualOverride: $wasManualOverride
        )
        .padding()
        .background(Color.bruPaper)
        .overlay { Rectangle().stroke(Color.bruInk, lineWidth: 1) }
        .padding()
    }
}

#Preview("calibrating range (read-only)") {
    // Last workout's weight, away from the suggestion: the set shows its range.
    @Previewable @State var weight: Double = 110.0
    @Previewable @State var wasManualOverride: Bool = false
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg \u{00D7} 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: nil,
        roundedWeight: 100.0,
        roundedLine: "\u{2192} 100 kg (rounded down to 2.5 kg plates)",
        status: .calibrating(current: 4, threshold: 10),
        bumpOccurred: false,
        range: 95.0...105.0
    )
    return VStack {
        Text("Prescription weight cell — calibrating range, read-only")
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
        PrescriptionWeightCell(
            weight: $weight,
            prescribed: 100.0,
            range: 95.0...105.0,
            explanation: explanation,
            unitLabel: "lb",
            wasManualOverride: $wasManualOverride
        )
        .padding()
        .background(Color.bruPaper)
        .overlay { Rectangle().stroke(Color.bruInk, lineWidth: 1) }
        .padding()
    }
}
