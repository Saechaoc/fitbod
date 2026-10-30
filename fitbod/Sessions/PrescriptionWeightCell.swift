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
//    The cell presents WhyThisWeightSheet when explanation != nil. Opening it
//    ends editing, so the keyboard never covers the sheet. Use writes the
//    suggested weight into the set and clears the badge; Override closes the
//    sheet and focuses the weight field.
//
//  The 44pt touch target is preserved via the cell's vertical padding (12pt) +
//  TextField height.
//

import SwiftUI

public struct PrescriptionWeightCell: View {
    @Binding public var weight: Double
    public let prescribed: Double?
    /// When non-nil, renders the read-only calibrating-range Text instead of
    /// the editable TextField. Format: "{low} \u{2013} {high} {unitLabel}".
    public let range: ClosedRange<Double>?
    public let explanation: PrescriptionExplanation?
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

    @State private var weightText: String = ""
    @State private var showWhySheet: Bool = false
    /// Set by Override: the weight field takes focus once the sheet is gone.
    @State private var focusAfterSheet = false
    @FocusState private var weightFocused: Bool

    public init(
        weight: Binding<Double>,
        prescribed: Double?,
        range: ClosedRange<Double>?,
        explanation: PrescriptionExplanation?,
        unitLabel: String,
        wasManualOverride: Binding<Bool>,
        isComplete: Bool = false,
        onTapEmptyCell: @escaping () -> Void = {},
        onEditCommitted: @escaping () -> Void = {},
        isExplaining: Binding<Bool>? = nil
    ) {
        self._weight = weight
        self.prescribed = prescribed
        self.range = range
        self.explanation = explanation
        self.unitLabel = unitLabel
        self._wasManualOverride = wasManualOverride
        self.isComplete = isComplete
        self.onTapEmptyCell = onTapEmptyCell
        self.onEditCommitted = onEditCommitted
        self.isExplaining = isExplaining
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let r = range {
                // MARK: Read-only calibrating-range display
                // 03-UI-SPEC line 206 verbatim: "{low} \u{2013} {high} unit" with U+2013 en-dash
                Text("\(formatted(r.lowerBound)) \u{2013} \(formatted(r.upperBound)) \(unitLabel)")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .accessibilityValue("\(formatted(r.lowerBound)) to \(formatted(r.upperBound)) \(unitLabel), calibrating")
            } else {
                // MARK: Editable weight TextField
                TextField("—", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($weightFocused)
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
                        if !focused { onEditCommitted() }
                    }
                    // Reflect weight changes made outside the field (swap
                    // re-seed, plateau "drop intensity") without fighting
                    // the user's own typing.
                    .onChange(of: weight) { _, new in
                        if !weightFocused, Double(weightText) != new {
                            weightText = new > 0 ? formatted(new) : ""
                        }
                    }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if range == nil && weightText.isEmpty { onTapEmptyCell() }
        }
        // Accessibility per 03-UI-SPEC line 494
        .accessibilityLabel(
            range != nil
                ? "Prescribed weight range: \(formatted(range!.lowerBound)) to \(formatted(range!.upperBound)) \(unitLabel)"
                : "Prescribed weight: \(weightDescription)"
        )
        .accessibilityValue(range == nil ? weightDescription : "")
        // Like SetRow's visible WHY, only an open set offers the action.
        .accessibilityActions {
            if explanation != nil && !isComplete {
                Button("Why this weight") { explaining.wrappedValue = true }
            }
        }
        // MARK: Manual override "M" badge
        // Added after the cell's accessibility so the badge keeps its own label.
        .overlay(alignment: .leading) {
            if range == nil && wasManualOverride && !weightText.isEmpty {
                overrideBadge
            }
        }
        .sheet(isPresented: explaining, onDismiss: focusAfterOverride) {
            if let exp = explanation {
                WhyThisWeightSheet(
                    explanation: exp,
                    onUseSuggested: { use(exp.roundedWeight) },
                    onOverride: { focusAfterSheet = true },
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
        .onAppear {
            // Seed the text field from the prescribed weight or current weight.
            // With no prescription, a weight of 0 keeps the "—" placeholder.
            // Only seed when range == nil (read-only mode doesn't use weightText).
            if range == nil {
                if let p = prescription, weight == 0 {
                    // The prescription itself is never a manual override.
                    weightText = formatted(p)
                    weight = p
                    wasManualOverride = false
                } else if weight > 0 {
                    weightText = formatted(weight)
                }
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

    /// What the field shows, for VoiceOver: "100 lb", or "none" over the
    /// placeholder.
    private var weightDescription: String {
        weightText.isEmpty ? "none" : "\(formatted(weight)) \(unitLabel)"
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
    private func isManualOverride(_ d: Double) -> Bool {
        guard let p = prescription else { return false }
        return abs(d - p) > 0.001
    }

    /// Use in Why-this-weight: the suggested weight becomes the set's weight,
    /// and the set is no longer marked as changed from the prescription.
    private func use(_ suggested: Double) {
        weightText = suggested > 0 ? formatted(suggested) : ""
        weight = suggested
        wasManualOverride = false
        onEditCommitted()
    }

    /// Override in Why-this-weight: once the sheet is gone, focus the field.
    private func focusAfterOverride() {
        guard focusAfterSheet else { return }
        focusAfterSheet = false
        weightFocused = true
    }

    /// Formats a Double without trailing zeros: "100" not "100.0", "102.5" not "102.500".
    private func formatted(_ d: Double) -> String {
        String(format: "%g", d)
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
    @Previewable @State var weight: Double = 100.0
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
