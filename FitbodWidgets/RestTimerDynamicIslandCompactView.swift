// RestTimerDynamicIslandCompactView.swift
// FitbodWidgets
//
// BRU brutalist Dynamic Island compact presentation views.
// Per UI-SPEC v2 lines 412 + 569.
//
// compactLeading  — RestTimerDynamicIslandCompactLeading:
//   Small ink-square glyph (12×12 Rectangle, Color.bruInk).
//   NOT the "timer" SF Symbol (banned by UI-SPEC line 43).
//
// compactTrailing — RestTimerDynamicIslandCompactTrailing:
//   Live countdown digits in BRUFont.bodyEmphasis + monospacedDigit, bruPaper.

import SwiftUI

/// Compact leading slot: small ink-square glyph (12×12 Rectangle).
/// Replaces Image(systemName: "timer") banned by UI-SPEC line 43.
public struct RestTimerDynamicIslandCompactLeading: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.bruInk)
            .frame(width: 12, height: 12)
    }
}

/// Compact trailing slot: live countdown digits in BRUMono bodyEmphasis bruPaper.
@available(iOS 16.1, *)
public struct RestTimerDynamicIslandCompactTrailing: View {
    public let state: RestTimerAttributes.ContentState

    public init(state: RestTimerAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        RestTimerCountdownText(state: state)
            .font(BRUFont.bodyEmphasis)
            .multilineTextAlignment(.trailing)
            // A timer Text reserves its widest width; cap it to "M:SS".
            .frame(maxWidth: 44, alignment: .trailing)
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 16.1, *)
#Preview("Compact Dynamic Island — mock") {
    HStack(spacing: 6) {
        RestTimerDynamicIslandCompactLeading()
        RestTimerDynamicIslandCompactTrailing(
            state: RestTimerAttributes.ContentState(
                startedAt: Date.now.addingTimeInterval(-30),
                targetSeconds: 180
            )
        )
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.bruInk)
    .padding(24)
    .background(Color.bruPaper)
}
#endif
