// RestTimerDynamicIslandExpandedView.swift
// FitbodWidgets
//
// BRU brutalist Dynamic Island expanded presentation view.
// Per UI-SPEC v2 lines 413-417 + 570.
//
// Layout (top to bottom):
//   - Live countdown digits in displayHero 56pt bruPaper
//   - 4pt-tall live progress bar: bruFaint track + bruSignal fill
//
// Both are system timer views so they tick without app updates. The
// exercise name is not shown; the timer is the only content.
// Text colors are bruPaper (paper-on-ink contract, UI-SPEC line 384).

import SwiftUI

/// Dynamic Island expanded center view: live countdown + signal progress bar.
@available(iOS 16.1, *)
public struct RestTimerDynamicIslandExpandedView: View {
    public let state: RestTimerAttributes.ContentState

    public init(state: RestTimerAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 12) {
            RestTimerCountdownText(state: state)
                .font(BRUFont.displayHero)
                .multilineTextAlignment(.center)

            RestTimerProgressBar(state: state)
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 16.1, *)
#Preview("Expanded Dynamic Island — 2:30 remaining") {
    RestTimerDynamicIslandExpandedView(
        state: RestTimerAttributes.ContentState(
            startedAt: Date.now.addingTimeInterval(-30),
            targetSeconds: 180
        )
    )
    .padding(16)
    .background(Color.bruInk)  // paper-on-ink hero
}
#endif
