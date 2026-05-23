//
//  SuggestedActionChip.swift
//  fitbod
//
//  Phase 5 PROG-06 — accent-tinted capsule chip rendered alongside
//  StallBadge on SessionExerciseCard. Label is D-13 verbatim per
//  UI-SPEC §Copywriting Contract. Tap routes per UI-SPEC §Interaction
//  & Motion action table (parent handles the route).
//

import SwiftUI

public extension SuggestedAction {
    /// D-13 verbatim labels. Used by SuggestedActionChip + accessibility.
    var label: String {
        switch self {
        case .addVolume:     return "Add volume"
        case .dropIntensity: return "Drop intensity"
        case .deload:        return "Consider deload"
        case .tryVariation:  return "Try variation"
        }
    }

    /// Accessibility hint per action (VoiceOver users hear the route
    /// destination as the tap purpose).
    var accessibilityHint: String {
        switch self {
        case .addVolume:     return "Tap to see muscle detail and adjust volume targets."
        case .dropIntensity: return "Tap to edit prescription."
        case .deload:        return "Tap to see fatigue signal details."
        case .tryVariation:  return "Tap to see alternative exercises."
        }
    }
}

public struct SuggestedActionChip: View {
    public let action: SuggestedAction
    public let onTap: () -> Void

    public init(action: SuggestedAction, onTap: @escaping () -> Void) {
        self.action = action
        self.onTap = onTap
    }

    public var body: some View {
        Text(action.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
            .contentShape(Rectangle())
            .frame(minHeight: 32)
            .onTapGesture { onTap() }
            .accessibilityLabel("Suggested: \(action.label).")
            .accessibilityHint(action.accessibilityHint)
            .accessibilityAddTraits(.isButton)
    }
}
