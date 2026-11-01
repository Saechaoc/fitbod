//
//  StallBadge.swift
//  fitbod
//
//  Phase 5.1 Plan 02 — BRU reskin: filled bruSignal mini-banner replacing
//  the original Color(.systemOrange).opacity(0.15) capsule.
//
//  BRU contract per must_haves + bru-screens/plateau.jsx ▲ STALL DETECTED pattern:
//   - Text("Stalled".uppercased()) — visible label is uppercase per BRU labelSmall
//   - Rectangle fill Color.bruSignal (NOT systemOrange capsule)
//   - Foreground Color.bruPaper (NOT orange-on-orange-tint)
//   - Sharp corners — NO Capsule() / NO RoundedRectangle
//
//  Public init signature UNCHANGED: (exerciseName: String, sessionCount: Int)
//  Accessibility label PRESERVED VERBATIM per UI-SPEC §Accessibility Contract:
//    "Stalled: {exerciseName} has been flat for {sessionCount} sessions."
//  Accessibility trait PRESERVED: .isStaticText
//

import SwiftUI

public struct StallBadge: View {
    public let exerciseName: String
    public let sessionCount: Int

    public init(exerciseName: String, sessionCount: Int) {
        self.exerciseName = exerciseName
        self.sessionCount = sessionCount
    }

    public var body: some View {
        Text("Stalled".uppercased())
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .foregroundStyle(Color.bruPaper)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.bruSignal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Stalled: \(exerciseName) has been flat for \(BRUCountLabel.text(sessionCount, "session")).")
            .accessibilityAddTraits(.isStaticText)
    }
}
