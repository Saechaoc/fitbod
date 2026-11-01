// CalibratingProgressMeter.swift
// fitbod/Design
//
// BRU primitive — calibration progress card.
// Rendered inside WhyThisWeightSheet (plan 03.2-05) when an exercise is in
// calibration mode (fewer than UserSettings.minCalibrationSets working sets logged).
//
// Visual reference: bru-screens/why-weight.jsx lines 81-92
// Spec: 03-UI-SPEC.md lines 47, 64, 76, 134, 188-189, 496, 503
// Threat model: T-03.2-01 (token typos → compile errors via public Color extensions)
//               T-03.2-03 (current > threshold clamped to prevent negative frame width)

import SwiftUI

// MARK: - CalibratingProgressMeter

/// A transitional-state card showing RPE calibration progress.
///
/// Displays a 6pt-tall signal-fill progress bar inside a 1.5pt bruInk-bordered
/// rectangle on bruBg2 fill. Two labels sit above the track:
///   - Left: "CALIBRATING · {current} / {threshold} SETS" in bruInk
///   - Right: "RANGE {rangeText}" in bruSignal
///
/// This component is **not** a CTA — it is an informational readout (hence the
/// thin 6pt bar rather than a standard 44pt touch-target height).
///
/// Usage:
/// ```swift
/// CalibratingProgressMeter(current: 8, threshold: 10, rangeText: "± 5 LB")
/// ```
public struct CalibratingProgressMeter: View {

    // MARK: Properties

    /// Number of working sets logged so far.
    public let current: Int
    /// Minimum sets required before the calibration period ends.
    public let threshold: Int
    /// Right-label text, e.g. "± 5 LB" or "± 2.5 KG".
    public let rangeText: String

    // MARK: Init

    /// - Parameters:
    ///   - current: Sets logged so far.
    ///   - threshold: `UserSettings.minCalibrationSets` target.
    ///   - rangeText: Pre-formatted range string, e.g. "± 5 LB".
    public init(current: Int, threshold: Int, rangeText: String) {
        self.current = current
        self.threshold = threshold
        self.rangeText = rangeText
    }

    // MARK: Computed

    /// Fill ratio clamped to 0...1 to guard against `current > threshold`
    /// (threat model T-03.2-03 — prevents negative GeometryReader frame width).
    private var fillRatio: Double {
        let numerator = min(max(Double(current), 0), Double(threshold))
        let denominator = Double(max(threshold, 1))
        return numerator / denominator
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Labels row
            HStack {
                Text("CALIBRATING · \(current) / \(BRUCountLabel.text(threshold, "SET"))")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruInk)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Spacer()

                Text("RANGE \(rangeText)")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruSignal)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }

            // Progress track — 6pt tall (03-UI-SPEC § Spacing exception "Calibration progress bar height: 6pt")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background (unfilled portion)
                    Rectangle()
                        .fill(Color.bruPaper)

                    // Signal fill — width proportional to fillRatio
                    Rectangle()
                        .fill(Color.bruSignal)
                        .frame(width: geo.size.width * fillRatio)
                }
            }
            .frame(height: 6)
        }
        .padding(10)
        .background(Color.bruBg2)
        .overlay {
            // 1.5pt bruInk border (03-UI-SPEC § new primitive description verbatim)
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1.5)
        }
        // MARK: Accessibility (03-UI-SPEC line 496)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calibrating: \(current) of \(BRUCountLabel.text(threshold, "set")) logged.")
        .accessibilityValue("\(current) out of \(threshold).")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("In-progress (8 of 10)") {
    CalibratingProgressMeter(current: 8, threshold: 10, rangeText: "± 5 LB")
        .padding(16)
        .background(Color.bruPaper)
}

#Preview("Near-complete (9 of 10)") {
    CalibratingProgressMeter(current: 9, threshold: 10, rangeText: "± 5 LB")
        .padding(16)
        .background(Color.bruPaper)
}

#Preview("Edge — zero sets (0 of 10)") {
    CalibratingProgressMeter(current: 0, threshold: 10, rangeText: "± 2.5 KG")
        .padding(16)
        .background(Color.bruPaper)
}
#endif
