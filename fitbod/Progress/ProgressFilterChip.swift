//
//  ProgressFilterChip.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — rebuilt as a BRU inverted-active rectangular chip.
//  Supersedes the Phase 6 baseline which used Capsule() + Color.accentColor.
//
//  BRU visual states (06-UI-SPEC §Design Pivot key replacement 3):
//  | State      | Background      | Foreground      | Border             |
//  |------------|-----------------|-----------------|--------------------|
//  | Selected   | Color.bruInk    | Color.bruPaper  | 1pt bruInk (match) |
//  | Unselected | Color.clear     | Color.bruInk    | 1pt bruInk outline |
//
//  BRU contract: NO Capsule / NO RoundedRectangle / NO accentColor /
//  NO Image(systemName:) / NO .buttonStyle(.bordered) / NO .font(.body|caption)
//
//  Accessibility:
//  - `accessibilityLabel` carries the explicit name (e.g. "Top set series").
//  - `accessibilityValue` is "selected" or "hidden" for VoiceOver toggle state.
//  - `.frame(minHeight: 44)` provides the HIG-mandated touch target.
//
//  Haptics: `.selectionChanged()` on tap (UI-SPEC item 627 haptics anchor).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// BRU inverted-active rectangular filter chip used by Phase 6 chart surfaces.
public struct ProgressFilterChip: View {
    public let label: String
    public let accessibilityName: String
    public let isActive: Bool
    public let action: () -> Void

    public init(
        label: String,
        accessibilityName: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.accessibilityName = accessibilityName
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button {
            #if canImport(UIKit)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
            action()
        } label: {
            Text(label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isActive ? Color.bruInk : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(Color.bruInk, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(minHeight: 44)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(isActive ? "selected" : "hidden")
    }
}

#Preview("Unselected") {
    ProgressFilterChip(
        label: "Top set",
        accessibilityName: "Top set series",
        isActive: false
    ) {}
    .padding()
    .background(Color.bruBg)
}

#Preview("Selected") {
    ProgressFilterChip(
        label: "All-set avg",
        accessibilityName: "All-set average series",
        isActive: true
    ) {}
    .padding()
    .background(Color.bruBg)
}
