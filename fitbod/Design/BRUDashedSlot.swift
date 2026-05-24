// BRUDashedSlot.swift
// fitbod — Phase 2.1 Plan 03
//
// The "+ Add exercise ↘ FROM LIBRARY" dashed-border action slot.
// Used in RoutineBuilderView and SessionLoggerView.
//
// Reference: bru-screens/routine-builder.jsx line 149-157
// UI-SPEC v2 line 521: StrokeStyle(lineWidth: 2, dash: [6, 4])
//
// USAGE:
//   BRUDashedSlot(
//       label: "Add exercise",
//       hint: "↘ FROM LIBRARY",
//       action: { showLibraryPicker = true }
//   )

import SwiftUI

// MARK: - BRUDashedSlot

/// Dashed-border rectangle slot used for additive actions.
///
/// Layout:
/// ```
/// ┌ - - - - - - - - - - - - - - - - - - ┐  ← 2pt bruInk dashed (6, 4)
/// │  + [label]              ↘ FROM LIB  │  14pt vertical padding
/// └ - - - - - - - - - - - - - - - - - - ┘
/// ```
///
/// NO rounded corners. The dashed border is a `Rectangle` stroke with
/// `StrokeStyle(lineWidth: 2, dash: [6, 4])` per UI-SPEC v2 line 521.
///
/// The leading glyph renders at `BRUFont.displayMedium` (22pt fits the slot).
/// The label and hint render at `BRUFont.labelSmall` UPPERCASE 1.2 letterspacing.
public struct BRUDashedSlot: View {

    // MARK: Properties

    private let label: String
    private let hint: String?
    private let leadingGlyph: String
    private let action: @Sendable () -> Void

    // MARK: Init

    public init(
        label: String,
        hint: String? = nil,
        leadingGlyph: String = "+",
        action: @escaping @Sendable () -> Void
    ) {
        self.label = label
        self.hint = hint
        self.leadingGlyph = leadingGlyph
        self.action = action
    }

    // MARK: Body

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(leadingGlyph)
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)

                Text(label)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)

                Spacer()

                if let hint {
                    Text(hint)
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .overlay(
                Rectangle()
                    .stroke(
                        Color.bruInk,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("+ Add exercise — from library") {
    VStack(spacing: 16) {
        BRUDashedSlot(
            label: "Add exercise",
            hint: "↘ FROM LIBRARY",
            action: {}
        )

        BRUDashedSlot(
            label: "Add exercise",
            action: {}
        )

        BRUDashedSlot(
            label: "Add set",
            leadingGlyph: "+",
            action: {}
        )
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
