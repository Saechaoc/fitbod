//
//  WhyThisWeightSheet.swift
//  fitbod
//
//  Phase 3 plan 06 — medium-detent sheet that renders a `PrescriptionExplanation`
//  value type. Shows the full calculation breakdown for why the session logger
//  prescribed a specific weight: last session data, formula name, computed e1RM
//  line (RPE autoreg only), rounding result, and calibration status.
//
//  UI-SPEC § WhyThisWeightSheet content rows — all copy is verbatim.
//  Mirrors `DecimalRPEPickerSheet` for the NavigationStack + dismissal shape.
//
//  Presentation: `.sheet(isPresented:) { WhyThisWeightSheet(...).presentationDetents([.medium]) }`.
//  No "Done" toolbar button — iOS sheet dismiss gesture is the affordance per UI-SPEC.
//

import SwiftUI

public struct WhyThisWeightSheet: View {
    public let explanation: PrescriptionExplanation
    /// Called (and sheet dismissed) when the user taps "Use Suggested Weight"
    /// while a manual override is active. Plan 03-08 wires this to write
    /// `roundedWeight` back to `SetEntry.actualWeight`.
    public var onUseSuggested: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    public init(
        explanation: PrescriptionExplanation,
        onUseSuggested: (() -> Void)? = nil
    ) {
        self.explanation = explanation
        self.onUseSuggested = onUseSuggested
    }

    public var body: some View {
        NavigationStack {
            List {
                // MARK: Last session row
                Section {
                    row(
                        label: "Last session",                                   // UI-SPEC verbatim
                        value: explanation.lastSessionLine ?? "No prior data — starting fresh."  // UI-SPEC verbatim
                    )

                    // MARK: Formula row
                    row(
                        label: "Formula",                                        // UI-SPEC verbatim
                        value: explanation.formulaName
                    )

                    // MARK: Computed row — only for RPE autoreg
                    if let computed = explanation.computedLine {
                        row(label: "Computed", value: computed)                  // UI-SPEC verbatim
                    }

                    // MARK: Rounded row
                    row(
                        label: "Rounded",                                        // UI-SPEC verbatim
                        value: explanation.roundedLine
                    )

                    // MARK: Status row
                    statusRow()
                }
                .listRowSeparator(.hidden, edges: .all)

                // MARK: "Use Suggested Weight" button — only when override is active
                if let useSuggested = onUseSuggested {
                    Section {
                        Button {
                            useSuggested()
                            dismiss()
                        } label: {
                            Text("Use Suggested Weight")                         // UI-SPEC verbatim
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .accessibilityLabel(
                            "Use suggested weight of \(String(format: "%g", explanation.roundedWeight)) kg"
                        )
                    }
                }
            }
            .navigationTitle("Why this weight?")                                 // UI-SPEC verbatim
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Private helpers

    @ViewBuilder
    private func row(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    @ViewBuilder
    private func statusRow() -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Status")                                                       // UI-SPEC verbatim
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            statusValueView()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(statusAccessibilityText())")
    }

    @ViewBuilder
    private func statusValueView() -> some View {
        switch explanation.status {
        case .calibrating(let n, let threshold):
            // Calibrating: gray capsule per UI-SPEC item 19 (transitional state, NOT accent)
            Text("Calibrating (\(n) / \(threshold) sets)")                      // UI-SPEC verbatim
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())

        case .calibrated:
            // Calibrated: accent capsule per UI-SPEC item 19
            Text("Calibrated")                                                   // UI-SPEC verbatim
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())

        case .notApplicable:
            // Double progression — status row shows bump or first-session copy
            if explanation.bumpOccurred {
                Text(bumpStatusText())
                    .font(.body)
                    .multilineTextAlignment(.trailing)
            } else if explanation.lastSessionLine == nil {
                Text("No prior data — starting at prescribed weight.")           // UI-SPEC verbatim
                    .font(.body)
                    .multilineTextAlignment(.trailing)
            } else {
                EmptyView()
            }
        }
    }

    private func bumpStatusText() -> String {
        // Extract increment from roundedLine if possible, fall back to generic copy.
        // The roundedLine format is "→ {rounded} kg (rounded down to {increment} kg plates)"
        // UI-SPEC § WhyThisWeightSheet: "All sets hit top of range last time → bumping by {increment} kg"
        return "All sets hit top of range last time → bumping by \(incrementText()) kg"  // UI-SPEC verbatim
    }

    private func incrementText() -> String {
        // Parse increment from roundedLine: "→ 102.5 kg (rounded down to 2.5 kg plates)"
        // Capture the number before " kg plates)"
        let line = explanation.roundedLine
        if let range = line.range(of: #"to (\d+\.?\d*) kg plates"#, options: .regularExpression) {
            let match = String(line[range])
            // Extract number from "to X kg plates"
            let parts = match.components(separatedBy: " ")
            if parts.count >= 2, let _ = Double(parts[1]) {
                return parts[1]
            }
        }
        return "?"
    }

    private func statusAccessibilityText() -> String {
        switch explanation.status {
        case .calibrating(let n, let threshold):
            return "Calibrating: \(n) of \(threshold) sets"
        case .calibrated:
            return "Calibrated"
        case .notApplicable:
            if explanation.bumpOccurred { return bumpStatusText() }
            if explanation.lastSessionLine == nil { return "No prior data — starting at prescribed weight." }
            return "Not applicable"
        }
    }
}

// MARK: - Previews

#Preview("calibrating — RPE autoreg") {
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
    return Text("Tap to see sheet")
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(explanation: explanation)
                .presentationDetents([.medium])
        }
}

#Preview("calibrated — RPE autoreg") {
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: "Target e1RM 122 kg → 88% × 8 → 107.5 kg",
        roundedWeight: 107.5,
        roundedLine: "→ 107.5 kg (rounded down to 2.5 kg plates)",
        status: .calibrated,
        bumpOccurred: false,
        range: nil
    )
    return Text("Tap to see sheet")
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(explanation: explanation)
                .presentationDetents([.medium])
        }
}

#Preview("bump occurred — double progression") {
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg × 12 @ RPE 8.5 (May 15)",
        formulaName: "Double progression",
        computedLine: nil,
        roundedWeight: 102.5,
        roundedLine: "→ 102.5 kg (rounded down to 2.5 kg plates)",
        status: .notApplicable,
        bumpOccurred: true,
        range: nil
    )
    return Text("Tap to see sheet")
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(explanation: explanation)
                .presentationDetents([.medium])
        }
}

#Preview("first session — double progression") {
    let explanation = PrescriptionExplanation(
        lastSessionLine: nil,
        formulaName: "Double progression",
        computedLine: nil,
        roundedWeight: 60.0,
        roundedLine: "→ 60 kg (rounded down to 2.5 kg plates)",
        status: .notApplicable,
        bumpOccurred: false,
        range: nil
    )
    return Text("Tap to see sheet")
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(explanation: explanation)
                .presentationDetents([.medium])
        }
}

#Preview("override active — shows Use Suggested Weight button") {
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: "Target e1RM 122 kg → 88% × 8 → 107.5 kg",
        roundedWeight: 107.5,
        roundedLine: "→ 107.5 kg (rounded down to 2.5 kg plates)",
        status: .calibrated,
        bumpOccurred: false,
        range: nil
    )
    return Text("Tap to see sheet")
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(
                explanation: explanation,
                onUseSuggested: { /* write back to SetEntry.actualWeight in plan 03-08 */ }
            )
            .presentationDetents([.medium])
        }
}
