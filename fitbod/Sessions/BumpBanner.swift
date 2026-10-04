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
    public let unitLabel: String

    public init(isVisible: Binding<Bool>, bumpedToWeight: Double, unitLabel: String = "kg") {
        self._isVisible = isVisible
        self.bumpedToWeight = bumpedToWeight
        self.unitLabel = unitLabel
    }

    public var body: some View {
        if isVisible {
            // Chalkline: earning the bump is meaningful emphasis, so the
            // icon uses accent-ink on a sunken well; tap dismisses.
            Button {
                isVisible = false
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.sm) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.chalkAccentInk)
                    Text("Bumping to \(ChalkFormat.weight(bumpedToWeight)) \(unitLabel) — you cleared the top of the range last time.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.chalkInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.chalkInk2)
                }
                .padding(Chalk.Space.md)
                .frame(minHeight: Chalk.Size.minTouch)
                .background(Color.chalkSunken, in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Weight bump: bumping to \(ChalkFormat.weight(bumpedToWeight)) \(unitLabel)."))
            .accessibilityHint(Text("Double-tap to dismiss."))
        }
    }
}

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
