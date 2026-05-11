//
//  RestTimerLockScreenView.swift
//  FitbodWidgets
//
//  The non-Dynamic-Island Live Activity layout — the lock-screen card and
//  banner pull-down. UI-SPEC § Live Activity (non-Dynamic-Island, iPhone
//  14+ lock screen card) verbatim:
//
//    - Header: "Rest Timer" (`.headline`)
//    - Body: the current exercise's name (`.body`, `.secondaryLabel`)
//    - Trailing: countdown in `.title2 .semibold .monospacedDigit`
//    - Bottom: a thin accent-color progress bar inset 16pt
//
//  Spacing follows UI-SPEC § Spacing tokens — `sm` (8pt) between rows,
//  parent applies `lg` (16pt) padding in `RestTimerLiveActivity` body.
//
//  Stateless presentation — `state` and `exerciseName` are pushed in from
//  the parent `ActivityConfiguration` content closure on every render.
//  No internal `Timer`; redraw cadence is driven by ActivityKit.
//

import SwiftUI

@available(iOS 16.1, *)
public struct RestTimerLockScreenView: View {
    public let state: RestTimerAttributes.ContentState
    public let exerciseName: String

    public init(state: RestTimerAttributes.ContentState, exerciseName: String) {
        self.state = state
        self.exerciseName = exerciseName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {                            // UI-SPEC § Spacing sm
            HStack {
                Text("Rest Timer")                                           // UI-SPEC verbatim header
                    .font(.headline)
                Spacer()
                Text(remainingText)                                          // countdown trailing
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Text(exerciseName)                                               // UI-SPEC verbatim body
                .font(.body)
                .foregroundStyle(.secondary)
            ProgressView(value: elapsed, total: max(1, Double(state.targetSeconds)))
                .tint(Color.accentColor)                                     // UI-SPEC accent surface #17
        }
    }

    /// Elapsed seconds since the rest started. Computed every render pass.
    private var elapsed: Double {
        max(0, Date.now.timeIntervalSince(state.startedAt))
    }

    /// Formatted "M:SS" countdown — see `RestTimerLiveActivity.remainingText`
    /// for the post-zero overrun behavior (clamps at "0:00").
    private var remainingText: String {
        let remaining = max(0, Double(state.targetSeconds) - elapsed)
        let s = Int(remaining)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
