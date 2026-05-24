// SetCompletionGlyph.swift
// fitbod — Phase 2.1 Plan 03
//
// The 22pt set-completion square used in SessionLoggerView set rows.
//
// UI-SPEC v2 line 385-386:
//   Incomplete: hollow bruInk 1.5pt outlined 22pt square
//   Complete:   filled bruSignal 22pt square
//
// TOUCH TARGET NOTE (threat T-02.1-03-03):
//   This view renders at 22pt visual size. The consumer (Plan 02.1-07 SetRow)
//   MUST wrap it with:
//     .frame(minWidth: 44, minHeight: 44)
//     .contentShape(Rectangle())
//   to meet the iOS HIG 44pt minimum touch target per UI-SPEC v2 line 79.
//   Do NOT add the hit-area extension here — it would interfere with layout
//   in contexts where the visual 22pt size is load-bearing (e.g., week ticker).
//
// USAGE:
//   SetCompletionGlyph(isComplete: false)
//   SetCompletionGlyph(isComplete: true)
//
//   // With hit-area extension (required in SetRow):
//   SetCompletionGlyph(isComplete: set.isComplete)
//       .frame(minWidth: 44, minHeight: 44)
//       .contentShape(Rectangle())
//       .onTapGesture { toggleComplete() }

import SwiftUI

// MARK: - SetCompletionGlyph

/// 22pt square that is hollow (ink-outlined) when incomplete and filled (signal) when complete.
///
/// The visual is intentionally minimal — a hard-edged square with no rounded corners,
/// consistent with the BRU brutalist aesthetic.
///
/// Consumer responsibility: wrap in `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())`
/// to satisfy the iOS HIG 44pt touch target requirement.
public struct SetCompletionGlyph: View {

    // MARK: Properties

    private let isComplete: Bool

    // MARK: Init

    public init(isComplete: Bool) {
        self.isComplete = isComplete
    }

    // MARK: Body

    public var body: some View {
        Group {
            if isComplete {
                Rectangle()
                    .fill(Color.bruSignal)
            } else {
                Rectangle()
                    .stroke(Color.bruInk, lineWidth: 1.5)
            }
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Both states side by side") {
    HStack(spacing: 24) {
        VStack(spacing: 8) {
            SetCompletionGlyph(isComplete: false)
            Text("Incomplete")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }

        VStack(spacing: 8) {
            SetCompletionGlyph(isComplete: true)
            Text("Complete")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
    }
    .padding()
    .background(Color.bruPaper)
}

#Preview("With required 44pt hit area (SetRow usage)") {
    HStack(spacing: 16) {
        SetCompletionGlyph(isComplete: false)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())

        SetCompletionGlyph(isComplete: true)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
    .padding()
    .background(Color.bruBg2)
}
#endif
