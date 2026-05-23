//
//  StallBadge.swift
//  fitbod
//
//  Phase 5 PROG-06 — orange "Stalled" capsule rendered on
//  SessionExerciseCard when PlateauDetector.evaluate returns .stalled.
//
//  UI-SPEC §Spacing Scale (24pt capsule) + §Color (Color(.systemOrange)
//  family — semantic, not literal) + §Copywriting Contract ("Stalled"
//  verbatim).
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
        Text("Stalled")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemOrange).opacity(0.15))
            .foregroundStyle(Color(.systemOrange))
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Stalled: \(exerciseName) has been flat for \(sessionCount) sessions.")
            .accessibilityAddTraits(.isStaticText)
    }
}
