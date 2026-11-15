// BRUCheckBox.swift
// fitbod
//
// The 24pt check box on a row that checks: the superset sheet's partners and
// the session editor's library picker (RM-026).
//
//   Unchecked: 2pt bruInk outline
//   Checked:   bruSignal fill, 2pt bruInk outline and a ✓ in bruOnSignal
//   Locked:    an unchecked box that cannot change draws a bruHair outline
//
// The row owns the tap, the 44pt target and the selected trait, and tints
// itself with `checkedRowFill` while checked; the box is hidden from
// VoiceOver.
//
// References: bru-screens/Fitbod-Session/screens/phase-2--modal-superset.png,
// phase-2--exercise-picker.png.
//
// BRU contract: NO Capsule / NO RoundedRectangle / NO Image(systemName:)

import SwiftUI

public struct BRUCheckBox: View {

    /// The tint of a checked row.
    public static let checkedRowFill = Color.bruSignal.opacity(0.1)

    private let isChecked: Bool
    private let isEnabled: Bool

    /// `isEnabled: false` marks a box its row cannot change; unchecked, it
    /// draws a bruHair outline.
    public init(isChecked: Bool, isEnabled: Bool = true) {
        self.isChecked = isChecked
        self.isEnabled = isEnabled
    }

    public var body: some View {
        Rectangle()
            .fill(isChecked ? Color.bruSignal : Color.clear)
            .frame(width: 24, height: 24)
            .overlay(Rectangle().strokeBorder(
                isChecked || isEnabled ? Color.bruInk : Color.bruHair,
                lineWidth: BRUMetrics.Border.structural))
            .overlay {
                if isChecked {
                    Text("✓").font(BRUFont.labelLarge).foregroundStyle(Color.bruOnSignal)
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Unchecked, checked, locked") {
    HStack(spacing: 24) {
        BRUCheckBox(isChecked: false)
        BRUCheckBox(isChecked: true)
        BRUCheckBox(isChecked: false, isEnabled: false)
    }
    .padding()
    .background(Color.bruPaper)
}
#endif
