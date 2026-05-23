//
//  PrescriptionWeightCell.swift
//  fitbod
//
//  Phase 3 plan 06 — compound control for the prescribed-weight input cell.
//  Replaces the plain weight `TextField` in `SetRow` (plan 03-08 wires this in).
//
//  Layout:
//    [weight input OR read-only range] [M badge?] [info.circle button?]
//
//  When `range != nil` (RPE autoreg calibrating-with-prior-data state per
//  CONTEXT.md Area 1), the cell renders a NON-EDITABLE Text view showing
//  "{low} – {high} {unitLabel}" using a literal U+2013 en-dash.
//
//  When `range == nil` (calibrated / double-progression / first-session),
//  the cell renders the editable `TextField` + optional "M" manual-override badge.
//
//  The `info.circle` button appears whenever `explanation != nil`. It opens
//  `WhyThisWeightSheet` in a `.medium` detent sheet.
//
//  UI-SPEC § Prescribed weight cell — 44pt minimum touch target on info.circle.
//  UI-SPEC § Color — accent on info.circle (item 18 reserved-for list).
//  UI-SPEC § Copywriting — en-dash U+2013 in range display, NOT hyphen-minus.
//

import SwiftUI

public struct PrescriptionWeightCell: View {
    @Binding public var weight: Double
    public let prescribed: Double?
    /// When non-nil, renders the read-only calibrating-range Text instead of
    /// the editable TextField. Format: "{low} – {high} {unitLabel}".
    public let range: ClosedRange<Double>?
    public let explanation: PrescriptionExplanation?
    /// Unit label for the range display. Defaults to "kg"; plan 03-08 passes
    /// per-exercise unitOverride when it wires this at the call site.
    public var unitLabel: String = "kg"
    @Binding public var wasManualOverride: Bool
    public var isComplete: Bool = false
    public var onTapEmptyCell: () -> Void = {}

    @State private var weightText: String = ""
    @State private var showWhySheet: Bool = false

    public init(
        weight: Binding<Double>,
        prescribed: Double?,
        range: ClosedRange<Double>?,
        explanation: PrescriptionExplanation?,
        unitLabel: String = "kg",
        wasManualOverride: Binding<Bool>,
        isComplete: Bool = false,
        onTapEmptyCell: @escaping () -> Void = {}
    ) {
        self._weight = weight
        self.prescribed = prescribed
        self.range = range
        self.explanation = explanation
        self.unitLabel = unitLabel
        self._wasManualOverride = wasManualOverride
        self.isComplete = isComplete
        self.onTapEmptyCell = onTapEmptyCell
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let r = range {
                // MARK: Read-only calibrating-range display
                // UI-SPEC verbatim: "{low} – {high} kg" with U+2013 en-dash
                Text("\(formatted(r.lowerBound)) \u{2013} \(formatted(r.upperBound)) \(unitLabel)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        "Calibrating range: \(formatted(r.lowerBound)) to \(formatted(r.upperBound)) \(unitLabel). Weight will become editable once calibration completes."
                    )
            } else {
                // MARK: Editable weight TextField
                TextField("—", text: $weightText)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .onChange(of: weightText) { _, new in
                        if let d = Double(new) {
                            weight = d
                            wasManualOverride = (prescribed != nil) &&
                                abs(d - (prescribed ?? d)) > 0.001
                        }
                    }
                    .onTapGesture {
                        if weightText.isEmpty { onTapEmptyCell() }
                    }

                // MARK: Manual override "M" badge
                if wasManualOverride {
                    Text("M")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: info.circle button — shown whenever explanation is available
            if explanation != nil {
                Button {
                    showWhySheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentColor)                      // UI-SPEC item 18
                        .contentShape(Rectangle())
                        .frame(minWidth: 44, minHeight: 44)                      // UI-SPEC 44pt touch target
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Why this weight?")                          // UI-SPEC verbatim
                .accessibilityHint("Shows how this weight was calculated.")      // UI-SPEC verbatim
            }
        }
        .padding(.vertical, 12)
        .sheet(isPresented: $showWhySheet) {
            if let exp = explanation {
                WhyThisWeightSheet(explanation: exp)
                    .presentationDetents([.medium])
            }
        }
        .onAppear {
            // Seed the text field from the prescribed weight or current weight.
            // Only seed when range == nil (read-only mode doesn't use weightText).
            if range == nil {
                if let p = prescribed, weight == 0 {
                    weightText = formatted(p)
                    weight = p
                } else if weight > 0 {
                    weightText = formatted(weight)
                }
            }
        }
    }

    // MARK: - Private helpers

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
        lastSessionLine: "100 kg × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: "Target e1RM 122 kg → 88% × 8 → 102.5 kg",
        roundedWeight: 102.5,
        roundedLine: "→ 102.5 kg (rounded down to 2.5 kg plates)",
        status: .calibrated,
        bumpOccurred: false,
        range: nil
    )
    return VStack {
        Text("Prescription weight cell — editable (range nil)")
            .font(.caption)
            .foregroundStyle(.secondary)
        PrescriptionWeightCell(
            weight: $weight,
            prescribed: 102.5,
            range: nil,
            explanation: explanation,
            wasManualOverride: $wasManualOverride
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}

#Preview("with override (M badge visible)") {
    @Previewable @State var weight: Double = 105.0
    @Previewable @State var wasManualOverride: Bool = true
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg × 8 @ RPE 8.5 (May 15)",
        formulaName: "Double progression",
        computedLine: nil,
        roundedWeight: 100.0,
        roundedLine: "→ 100 kg (rounded down to 2.5 kg plates)",
        status: .notApplicable,
        bumpOccurred: false,
        range: nil
    )
    return VStack {
        Text("Prescription weight cell — manual override, M badge visible")
            .font(.caption)
            .foregroundStyle(.secondary)
        PrescriptionWeightCell(
            weight: $weight,
            prescribed: 100.0,
            range: nil,
            explanation: explanation,
            wasManualOverride: $wasManualOverride
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}

#Preview("calibrating range (read-only)") {
    @Previewable @State var weight: Double = 100.0
    @Previewable @State var wasManualOverride: Bool = false
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: nil,
        roundedWeight: 100.0,
        roundedLine: "→ 100 kg (rounded down to 2.5 kg plates)",
        status: .calibrating(current: 4, threshold: 10),
        bumpOccurred: false,
        range: 95.0...105.0
    )
    return VStack {
        Text("Prescription weight cell — calibrating range, read-only")
            .font(.caption)
            .foregroundStyle(.secondary)
        PrescriptionWeightCell(
            weight: $weight,
            prescribed: 100.0,
            range: 95.0...105.0,
            explanation: explanation,
            wasManualOverride: $wasManualOverride
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}
