//
//  BumpBanner.swift
//  fitbod
//
//  Phase 3 plan 06 — 44pt pill banner rendered at the top of a
//  `SessionExerciseCard` when DoubleProgressionStrategy has detected a
//  weight bump (all working sets hit top of rep range last session).
//
//  UI-SPEC § Bump banner — verbatim copy:
//    "Bumping to {weight} kg — you cleared the top of the range last time."
//
//  Background: `Color(.systemGreen).opacity(0.15)` — NOT accent per
//  UI-SPEC "Explicitly NOT accent" list. Success/affirmation state.
//
//  Leading icon: `arrow.up.circle` (.caption-sized, NOT accent per
//  UI-SPEC § SF Symbols — the icon reinforces the success message but
//  is not a primary interactive affordance).
//
//  Tap-dismiss: delegated to the parent SessionExerciseCard's onTapGesture
//  (plan 03-08 wires this). BumpBanner does NOT add its own onTapGesture.
//
//  Analogous to `ResumeWorkoutBanner` for overall shape, but substitutes
//  the green-tint background + single-line copy + no action buttons.
//

import SwiftUI

public struct BumpBanner: View {
    @Binding public var isVisible: Bool
    public let bumpedToWeight: Double

    public init(isVisible: Binding<Bool>, bumpedToWeight: Double) {
        self._isVisible = isVisible
        self.bumpedToWeight = bumpedToWeight
    }

    public var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)                                  // NOT accent per UI-SPEC

                Text("Bumping to \(String(format: "%g", bumpedToWeight)) kg \u{2014} you cleared the top of the range last time.")
                    .font(.headline)
                    .foregroundStyle(Color(.label))                              // NOT accent per UI-SPEC

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: 44)                                                   // UI-SPEC § Spacing exception: 44pt
            .background(Color(.systemGreen).opacity(0.15))                       // UI-SPEC verbatim, NOT accent
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityLabel(
                "Weight bump: bumping to \(String(format: "%g", bumpedToWeight)) kg. Tap to dismiss."
            )                                                                    // UI-SPEC verbatim
            .accessibilityHint("Tap anywhere on this exercise card to dismiss.") // UI-SPEC verbatim
            .accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - Previews

#Preview("standard 102.5 kg bump") {
    @Previewable @State var isVisible: Bool = true
    return VStack {
        BumpBanner(isVisible: $isVisible, bumpedToWeight: 102.5)
        if !isVisible {
            Text("Banner dismissed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Button("Reset") { isVisible = true }
            .padding()
    }
    .padding()
}

#Preview("hidden state") {
    @Previewable @State var isVisible: Bool = false
    return VStack {
        BumpBanner(isVisible: $isVisible, bumpedToWeight: 102.5)
        Text("Banner is hidden (isVisible = false)")
            .font(.caption)
            .foregroundStyle(.secondary)
        Button("Show banner") { isVisible = true }
            .padding()
    }
    .padding()
}
