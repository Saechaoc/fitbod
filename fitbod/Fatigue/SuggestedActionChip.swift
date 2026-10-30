//
//  SuggestedActionChip.swift
//  fitbod
//
//  Phase 5.1 Plan 02 — BRU reskin: outline ink chip replacing the original
//  Color.accentColor.opacity(0.15) capsule treatment.
//
//  BRU contract per must_haves + bru-screens/plateau.jsx:
//   - Label uses BRU short forms (uppercase): ADD VOLUME / DROP INTENSITY /
//     CONSIDER DELOAD / TRY VARIATION
//   - Rendered as BRUChip(label, color: .bruInk, fill: false) — outline ink chip
//   - 44pt minimum hit area via .frame(minHeight: 44) and a rectangular
//     content shape on the Button's label (a frame outside the Button does
//     not grow what it takes taps on)
//   - NO Color.accentColor / NO Capsule() / NO .font(.caption)
//
//  Public init signature UNCHANGED: (action: SuggestedAction, onTap: () -> Void)
//  Tap routing UNCHANGED: parent call sites in SessionExerciseCard handle navigation.
//  Accessibility labels PRESERVED VERBATIM per UI-SPEC §Copywriting Contract:
//    label: "Suggested: {action.label}."
//    hint:  action.accessibilityHint
//    trait: .isButton
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

    // MARK: - BRU short-form label (visible on chip)
    // UI-SPEC §Copy overlay table — uppercase BRU short forms for chip rendering.
    // These differ from action.label (title-case semantic form used for accessibility).
    public var brShortLabel: String {
        switch action {
        case .addVolume:     return "ADD VOLUME"
        case .dropIntensity: return "DROP INTENSITY"
        case .deload:        return "CONSIDER DELOAD"
        case .tryVariation:  return "TRY VARIATION"
        }
    }

    // MARK: - Accessibility label (title-case semantic form per UI-SPEC §Copywriting Contract)
    // Note: stored as a computed property for testability.
    public var accessibilityChipLabel: String {
        "Suggested: \(action.label)."
    }

    public var body: some View {
        Button(action: onTap) {
            // Frame and hit shape sit inside the label, so the whole 44pt
            // band takes the tap rather than the card header's tap gesture.
            BRUChip(brShortLabel, color: .bruInk, fill: false)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityChipLabel)
        .accessibilityHint(action.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}
