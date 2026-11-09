// RestTimerLockScreenView.swift
// FitbodWidgets
//
// BRU brutalist lock-screen Live Activity card.
//
// Layout: paper-on-ink hero (UI-SPEC v2 line 384).
//   - Background: Color.bruInk (full-bleed)
//   - HStack: "REST" labelSmall + Spacer + live countdown displayHero
//   - Bottom: 4pt-tall bruSignal progress bar (UI-SPEC line 421)
//
// The countdown and bar are system timer views (`Text(timerInterval:)`,
// `ProgressView(timerInterval:)`): ActivityKit does not re-render a Live
// Activity on its own, so a string computed from `Date.now` would freeze.
// The exercise name is not shown; it truncated next to the hero countdown.

import SwiftUI

@available(iOS 16.1, *)
public struct RestTimerLockScreenView: View {
    public let state: RestTimerAttributes.ContentState

    public init(state: RestTimerAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("REST")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruPaper)

                Spacer()

                RestTimerCountdownText(state: state)
                    .font(BRUFont.displayHero)
                    .multilineTextAlignment(.trailing)
            }

            RestTimerProgressBar(state: state)
        }
        .padding(16)
        .background(Color.bruInk)  // paper-on-ink hero (UI-SPEC line 384)
    }
}

// MARK: - Shared live timer pieces

@available(iOS 16.1, *)
extension RestTimerAttributes.ContentState {
    /// The rest window the system timer views count down across.
    var restInterval: ClosedRange<Date> {
        startedAt...startedAt.addingTimeInterval(Double(max(0, targetSeconds)))
    }
}

/// Live "M:SS" countdown that the system ticks; stops at 0:00.
@available(iOS 16.1, *)
struct RestTimerCountdownText: View {
    let state: RestTimerAttributes.ContentState

    var body: some View {
        Text(timerInterval: state.restInterval, countsDown: true, showsHours: false)
            .monospacedDigit()
            .foregroundStyle(Color.bruPaper)
    }
}

/// Live 4pt bar that drains from full to empty over the rest window.
@available(iOS 16.1, *)
struct RestTimerProgressBar: View {
    let state: RestTimerAttributes.ContentState

    var body: some View {
        ProgressView(timerInterval: state.restInterval, countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(Color.bruSignal)
        .background(Color.bruFaint)
        .frame(height: 4)
        .clipShape(Rectangle())
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 16.1, *)
#Preview("Lock Screen — 2:30 remaining") {
    RestTimerLockScreenView(
        state: RestTimerAttributes.ContentState(
            startedAt: Date.now.addingTimeInterval(-30),
            targetSeconds: 180
        )
    )
    .frame(maxWidth: .infinity)
}

@available(iOS 16.1, *)
#Preview("Lock Screen — 0:15 remaining") {
    RestTimerLockScreenView(
        state: RestTimerAttributes.ContentState(
            startedAt: Date.now.addingTimeInterval(-165),
            targetSeconds: 180
        )
    )
    .frame(maxWidth: .infinity)
}
#endif
