// BottomActionBar.swift
// fitbod — Phase 2.1 Plan 05
//
// The 2-button bottom strip for RoutineBuilderView.
//
// Layout (top to bottom):
//   2pt bruInk top rule (BRUDivider(.ink))
//   HStack:
//     BRUButton(.ghost, "Discard")          ← left, half-width
//     2pt bruInk vertical Rectangle         ← separator
//     BRUButton(.signal, "Save routine ▸")  ← right, half-width, disabled when !isValid
//   bruPaper fill
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .buttonStyle(.bordered) — always .plain via BRUButton internals.
//
// Reference: bru-screens/routine-builder.jsx lines 160-168
// Verbatim copy: "Discard" / "Save routine ▸" — anchored in RoutineBuilderBRUCopyTests.

import SwiftUI

// MARK: - BottomActionBar

/// Two-button bottom strip for the routine builder.
///
/// Left slot: ghost "Discard" button.
/// Right slot: signal "Save routine ▸" button, disabled when `isValid == false`.
/// A 2pt `bruInk` top rule separates the bar from the scroll content above;
/// a 2pt `bruInk` vertical rectangle separates the two buttons.
public struct BottomActionBar: View {

    // MARK: Properties

    public let onDiscard: () -> Void
    public let onSave: () -> Void
    public let isValid: Bool

    // MARK: Init

    public init(
        onDiscard: @escaping () -> Void,
        onSave: @escaping () -> Void,
        isValid: Bool
    ) {
        self.onDiscard = onDiscard
        self.onSave = onSave
        self.isValid = isValid
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 0) {
            // 2pt bruInk top rule — section-level boundary per UI-SPEC v2 line 82
            BRUDivider(.ink)

            HStack(spacing: 0) {
                // Left: ghost "Discard"
                BRUButton("Discard", kind: .ghost, size: .md, action: onDiscard)

                // 2pt bruInk vertical separator
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 2)

                // Right: signal "Save routine ▸" — disabled + dimmed when draft invalid
                BRUButton("Save routine ▸", kind: .signal, size: .md, action: onSave)
                    .disabled(!isValid)
                    .opacity(isValid ? 1.0 : 0.4)
            }
            .background(Color.bruPaper)
        }
        .background(Color.bruPaper)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BottomActionBar — valid") {
    VStack {
        Spacer()
        BottomActionBar(
            onDiscard: {},
            onSave: {},
            isValid: true
        )
    }
    .background(Color.bruPaper)
}

#Preview("BottomActionBar — invalid (save disabled)") {
    VStack {
        Spacer()
        BottomActionBar(
            onDiscard: {},
            onSave: {},
            isValid: false
        )
    }
    .background(Color.bruPaper)
}
#endif
