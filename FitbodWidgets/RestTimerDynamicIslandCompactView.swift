// RestTimerDynamicIslandCompactView.swift
// FitbodWidgets
//
// BRU brutalist Dynamic Island compact presentation views.
// Per UI-SPEC v2 lines 412 + 569.
//
// Two top-level views mounted at the compactLeading and compactTrailing
// presentation slots inside DynamicIsland(_:) in RestTimerLiveActivity.
//
// compactLeading  — RestTimerDynamicIslandCompactLeading:
//   Small ink-square glyph (12×12 Rectangle, Color.bruInk).
//   NOT the "timer" SF Symbol (banned by UI-SPEC line 43).
//
// compactTrailing — RestTimerDynamicIslandCompactTrailing:
//   Countdown digits in BRUFont.bodyEmphasis + monospacedDigit, Color.bruPaper.
//   Apple's compact trailing slot is ≤ 116pt wide — the mono countdown fits.
//
// UI-REVIEW Wave E item 52 (compact Dynamic Island).

import SwiftUI

/// Compact leading slot: small ink-square glyph (12×12 Rectangle).
/// Replaces Image(systemName: "timer") banned by UI-SPEC line 43.
public struct RestTimerDynamicIslandCompactLeading: View {
    public let countdownText: String

    public init(countdownText: String) {
        self.countdownText = countdownText
    }

    public var body: some View {
        Rectangle()
            .fill(Color.bruInk)
            .frame(width: 12, height: 12)
    }
}

/// Compact trailing slot: countdown digits in BRUMono bodyEmphasis bruPaper.
public struct RestTimerDynamicIslandCompactTrailing: View {
    public let countdownText: String

    public init(countdownText: String) {
        self.countdownText = countdownText
    }

    public var body: some View {
        Text(countdownText)
            .font(BRUFont.bodyEmphasis)
            .monospacedDigit()
            .foregroundStyle(Color.bruPaper)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Compact Dynamic Island — mock") {
    HStack(spacing: 16) {
        // Simulated Dynamic Island compact shape (small dark pill)
        HStack(spacing: 6) {
            RestTimerDynamicIslandCompactLeading(countdownText: "2:30")
            RestTimerDynamicIslandCompactTrailing(countdownText: "2:30")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.bruInk)

        Text("← compact leading + trailing")
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)
    }
    .padding(24)
    .background(Color.bruPaper)
}
#endif
