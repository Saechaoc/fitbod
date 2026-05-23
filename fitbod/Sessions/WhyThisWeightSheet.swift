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
//  Phase 3.1 (PIVOT-04 / D-12): the Status row prepends the session
//  intent on the .calibrating and .calibrated branches when
//  `explanation.sessionIntent` is non-nil:
//    - "Strength session — calibrating (4 / 10 sets)"
//    - "Strength session — calibrated"
//  Em-dash U+2014 ("—") with single-space padding per UI-SPEC
//  Verification anchor. The .notApplicable branch (DoubleProgression
//  bump + no-prior-data) is unchanged. When sessionIntent is nil the
//  status row falls back to the Phase 3 unprefixed copy ("Calibrating
//  (4 / 10 sets)" / "Calibrated") so pre-3.1 callers and pure-test
//  fixtures still render legibly.
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
            // Calibrating: gray capsule per UI-SPEC item 19 (transitional state, NOT accent).
            //
            // Phase 3.1 (PIVOT-04 / D-12): when sessionIntent is non-nil,
            // prefix the status copy with "{Intent.capitalized} session — "
            // (em-dash U+2014, single-space padding) per UI-SPEC
            // Verification anchor: `"\(Intent.capitalized) session —
            // calibrating (\(n) / \(threshold) sets)"`. Note the lowercase
            // "calibrating" in the prefixed form (UI-SPEC anchor verbatim);
            // the unprefixed fallback keeps the Phase 3 "Calibrating"
            // (capital C) copy when sessionIntent is nil.
            Text(calibratingStatusText(current: n, threshold: threshold))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())

        case .calibrated:
            // Calibrated: accent capsule per UI-SPEC item 19.
            //
            // Phase 3.1 (PIVOT-04 / D-12): prefix with "{Intent.capitalized}
            // session — calibrated" when sessionIntent is non-nil per
            // UI-SPEC Verification anchor: `"\(Intent.capitalized) session
            // — calibrated"`. Lowercase "calibrated" in the prefixed form;
            // unprefixed fallback keeps "Calibrated" (capital C).
            Text(calibratedStatusText())
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())

        case .notApplicable:
            // Double progression — status row shows bump or first-session copy.
            // Phase 3.1 UI-SPEC: the .notApplicable branch does NOT prefix
            // with the session intent (bump + no-prior-data copy stays
            // exactly as Phase 3 shipped).
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

    /// Phase 3.1 (PIVOT-04 / D-12) — calibrating status copy with
    /// optional session-intent prefix. UI-SPEC Verification anchor:
    /// `"\(Intent.capitalized) session — calibrating (\(n) / \(threshold) sets)"`.
    /// Falls back to Phase 3 "Calibrating (n / threshold sets)" when
    /// sessionIntent is nil.
    private func calibratingStatusText(current n: Int, threshold: Int) -> String {
        if let sessionIntent = explanation.sessionIntent {
            return "\(sessionIntent.rawValue.capitalized) session — calibrating (\(n) / \(threshold) sets)"
        }
        return "Calibrating (\(n) / \(threshold) sets)"
    }

    /// Phase 3.1 (PIVOT-04 / D-12) — calibrated status copy with
    /// optional session-intent prefix. UI-SPEC Verification anchor:
    /// `"\(Intent.capitalized) session — calibrated"`.
    /// Falls back to Phase 3 "Calibrated" when sessionIntent is nil.
    private func calibratedStatusText() -> String {
        if let sessionIntent = explanation.sessionIntent {
            return "\(sessionIntent.rawValue.capitalized) session — calibrated"
        }
        return "Calibrated"
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
            // Phase 3.1 (PIVOT-04 / D-12): mirror the visible copy so
            // VoiceOver announces the same "{Intent} session — calibrating
            // (n / threshold sets)" form when sessionIntent is non-nil.
            if let sessionIntent = explanation.sessionIntent {
                return "\(sessionIntent.rawValue.capitalized) session — calibrating: \(n) of \(threshold) sets"
            }
            return "Calibrating: \(n) of \(threshold) sets"
        case .calibrated:
            if let sessionIntent = explanation.sessionIntent {
                return "\(sessionIntent.rawValue.capitalized) session — calibrated"
            }
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
    // Phase 3.1 (PIVOT-04 / D-12): sessionIntent: .strength exercises the
    // prefixed status copy "Strength session — calibrating (4 / 10 sets)".
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: nil,
        roundedWeight: 100.0,
        roundedLine: "→ 100 kg (rounded down to 2.5 kg plates)",
        status: .calibrating(current: 4, threshold: 10),
        bumpOccurred: false,
        range: 95.0...105.0,
        sessionIntent: .strength
    )
    return Text("Tap to see sheet")
        .sheet(isPresented: .constant(true)) {
            WhyThisWeightSheet(explanation: explanation)
                .presentationDetents([.medium])
        }
}

#Preview("calibrated — RPE autoreg") {
    // Phase 3.1 (PIVOT-04 / D-12): sessionIntent: .hypertrophy exercises
    // the prefixed status copy "Hypertrophy session — calibrated" so the
    // preview covers a different Intent case than the calibrating one.
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: "Target e1RM 122 kg → 88% × 8 → 107.5 kg",
        roundedWeight: 107.5,
        roundedLine: "→ 107.5 kg (rounded down to 2.5 kg plates)",
        status: .calibrated,
        bumpOccurred: false,
        range: nil,
        sessionIntent: .hypertrophy
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
    // Phase 3.1 (PIVOT-04 / D-12): third sessionIntent-bearing preview;
    // covers the .calibrated branch with override-active button visible.
    let explanation = PrescriptionExplanation(
        lastSessionLine: "100 kg × 8 @ RPE 8.5 (May 15)",
        formulaName: "RPE autoregulation",
        computedLine: "Target e1RM 122 kg → 88% × 8 → 107.5 kg",
        roundedWeight: 107.5,
        roundedLine: "→ 107.5 kg (rounded down to 2.5 kg plates)",
        status: .calibrated,
        bumpOccurred: false,
        range: nil,
        sessionIntent: .strength
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
