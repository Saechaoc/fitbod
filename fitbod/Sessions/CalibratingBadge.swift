//
//  CalibratingBadge.swift
//  fitbod
//
//  Phase 3.2 plan 02 — flat bruMuted rectangle badge rendered inline in the
//  `SessionExerciseCard` header when RPE autoreg is in calibrating mode
//  (logged working sets < minCalibrationSets for this exercise + intent pair).
//
//  BRU contract (03-UI-SPEC § Calibrating badge):
//    - Flat rectangle (NOT Capsule, NOT RoundedRectangle) — BRU has no rounded shapes.
//    - bruMuted fill with bruPaper text. NOT signal — this is transitional state.
//    - labelMicro 8pt JetBrains Mono Bold, .textCase(.uppercase), tracking 1.2.
//    - Dot is Unicode '●' (U+25CF) in bruMuted Text — NOT a Circle().fill() shape.
//      (03-UI-SPEC § Glyphs: typographic glyphs preferred over shapes.)
//    - BRUCornerBadge NOT used here: it uses SpaceGrotesk-Bold 7pt, but the spec
//      requires JetBrainsMono-Bold (labelMicro). Rendered inline instead.
//
//  03-UI-SPEC line 147:
//    "The calibrating badge '●' on SessionExerciseCard header when calibrating mode
//     — uses bruMuted dot (NOT signal). Signal appears inside WhyThisWeightSheet only."
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
            Text("●")
                .font(BRUFont.labelMicro)
                .foregroundStyle(Color.bruMuted)

            Text("CALIBRATING")
                .font(BRUFont.labelMicro)
                .foregroundStyle(Color.bruPaper)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.bruMuted)
        .accessibilityLabel(
            "Calibrating: \(current) of \(BRUCountLabel.text(threshold, "set")) logged. Weight shown as a range."
        )
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("BRU — 4 of 10 sets") {
    HStack(spacing: 8) {
        Text("Bench Press")
            .font(BRUFont.bodyEmphasis)
            .foregroundStyle(Color.bruInk)
        CalibratingBadge(current: 4, threshold: 10)
    }
    .padding()
    .background(Color.bruPaper)
}

#Preview("BRU — 9 of 10 sets (near calibrated)") {
    HStack(spacing: 8) {
        Text("Squat")
            .font(BRUFont.bodyEmphasis)
            .foregroundStyle(Color.bruInk)
        CalibratingBadge(current: 9, threshold: 10)
    }
    .padding()
    .background(Color.bruPaper)
}

#Preview("BRU — dark background contrast") {
    HStack(spacing: 8) {
        Text("Deadlift")
            .font(BRUFont.bodyEmphasis)
            .foregroundStyle(Color.bruPaper)
        CalibratingBadge(current: 2, threshold: 10)
    }
    .padding()
    .background(Color.bruInk)
}
#endif
