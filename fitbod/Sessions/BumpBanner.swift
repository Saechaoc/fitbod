//
//  BumpBanner.swift
//  fitbod
//
//  Phase 3.2 plan 02 — 52pt flat bruInk slab rendered at the top of a
//  `SessionExerciseCard` when DoubleProgressionStrategy detects a weight bump
//  (all working sets hit the top of the rep range last session).
//
//  BRU contract (03-UI-SPEC § BumpBannerSlab):
//    - Full-width ink-background slab. Height: 52pt. NO Capsule, NO RoundedRectangle.
//    - bruPaper text in labelSmall 10pt, .textCase(.uppercase), tracking 1.2.
//    - Leading SF Symbol removed — BRU has no SF Symbols (03-UI-SPEC § Icon library).
//    - Tap-dismiss delegated to the parent SessionExerciseCard's onTapGesture.
//
//  Copy verbatim per 03-UI-SPEC line 215:
//    "BUMPING TO {weight} {unit} — YOU CLEARED THE TOP OF THE RANGE LAST TIME."
//

import SwiftUI

public struct BumpBanner: View {
    @Binding public var isVisible: Bool
    public let bumpedToWeight: Double
    public let unitLabel: String

    public init(isVisible: Binding<Bool>, bumpedToWeight: Double, unitLabel: String = "kg") {
        self._isVisible = isVisible
        self.bumpedToWeight = bumpedToWeight
        self.unitLabel = unitLabel
    }

    public var body: some View {
        if isVisible {
            HStack {
                Text(bannerText)
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruPaper)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.bruInk)
            .accessibilityLabel(
                "Weight bump: bumping to \(formatted(bumpedToWeight)) \(unitLabel). Tap to dismiss."
            )
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Private

    private var bannerText: String {
        "BUMPING TO \(formatted(bumpedToWeight)) \(unitLabel.uppercased()) \u{2014} YOU CLEARED THE TOP OF THE RANGE LAST TIME."
    }

    private func formatted(_ d: Double) -> String {
        String(format: "%g", d)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("BRU — 102.5 kg bump (visible)") {
    @Previewable @State var isVisible: Bool = true
    return VStack(spacing: 0) {
        BumpBanner(isVisible: $isVisible, bumpedToWeight: 102.5, unitLabel: "kg")
        Rectangle()
            .fill(Color.bruPaper)
            .frame(height: 120)
            .overlay(
                Text(isVisible ? "tap ink slab row to dismiss" : "Banner dismissed")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            )
        Button("Reset") { isVisible = true }
            .padding()
    }
    .background(Color.bruBg)
}

#Preview("BRU — hidden state") {
    @Previewable @State var isVisible: Bool = false
    return VStack(spacing: 0) {
        BumpBanner(isVisible: $isVisible, bumpedToWeight: 102.5, unitLabel: "kg")
        Rectangle()
            .fill(Color.bruPaper)
            .frame(height: 120)
            .overlay(
                Text("Banner is hidden (isVisible = false)")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            )
        Button("Show banner") { isVisible = true }
            .padding()
    }
    .background(Color.bruBg)
}

#Preview("BRU — lb unit") {
    @Previewable @State var isVisible: Bool = true
    return BumpBanner(isVisible: $isVisible, bumpedToWeight: 225, unitLabel: "lb")
        .background(Color.bruBg)
}
#endif
