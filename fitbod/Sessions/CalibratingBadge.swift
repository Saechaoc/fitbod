//
//  CalibratingBadge.swift
//  fitbod
//
//  Phase 3 plan 06 — small capsule badge rendered inline in the
//  `SessionExerciseCard` header when RPE autoreg is in calibrating mode
//  (logged working sets < minCalibrationSets for this exercise + intent pair).
//
//  UI-SPEC § Calibrating badge — verbatim copy:
//    badge label:  "calibrating"
//    a11y label:   "Calibrating: {n} of {threshold} sets logged. Weight shown as a range."
//
//  Background: `Color(.systemGray5)` — NOT accent per UI-SPEC item 19 exclusion.
//  The calibrating state is TRANSITIONAL (incomplete) and must not draw the
//  same visual weight as the accent-colored "Calibrated" capsule in
//  WhyThisWeightSheet. The muted gray signals "work in progress" not "success".
//
//  Analogous to `SetTypeChip` for the capsule shape; no tap-cycling behavior.
//

import SwiftUI

public struct CalibratingBadge: View {
    public let current: Int
    public let threshold: Int

    public init(current: Int, threshold: Int) {
        self.current = current
        self.threshold = threshold
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(.systemGray3))                                       // muted dot, NOT accent
                .frame(width: 6, height: 6)

            Text("calibrating")                                                  // UI-SPEC verbatim
                .font(.caption)
                .foregroundStyle(.secondary)                                     // NOT accent per UI-SPEC item 19
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))                                         // UI-SPEC verbatim, NOT accent
        .clipShape(Capsule())
        .accessibilityLabel(
            "Calibrating: \(current) of \(threshold) sets logged. Weight shown as a range."
        )                                                                        // UI-SPEC verbatim
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Previews

#Preview("4 of 10 sets") {
    CalibratingBadge(current: 4, threshold: 10)
        .padding()
}

#Preview("9 of 10 sets (near calibrated)") {
    CalibratingBadge(current: 9, threshold: 10)
        .padding()
}
