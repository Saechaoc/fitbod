// RestTimerLockScreenView.swift
// FitbodWidgets
//
// BRU brutalist lock-screen Live Activity card — rewritten for Phase 2.1
// (UI-REVIEW Wave E item 54). The legacy `.headline` / `.title2.semibold`
// system fonts and accentColor tint are replaced with the BRU palette.
//
// Layout: paper-on-ink hero (UI-SPEC v2 line 384).
//   - Background: Color.bruInk (full-bleed)
//   - HStack: VStack(leading) { "REST TIMER" labelSmall + exercise name
//             displayLarge } + Spacer + countdown displayHero (trailing)
//   - Bottom overlay: 4pt Color.bruSignal progress bar (UI-SPEC line 421)
//
// Stateless presentation — `state` and `exerciseName` are pushed in from
// the parent `ActivityConfiguration` content closure on every render.
// No internal Timer; redraw cadence is driven by ActivityKit.
//
// UI-REVIEW Wave E item 54 (lock screen card).

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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                // Header label — labelSmall bruPaper, UPPERCASE
                Text("REST TIMER")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper)

                // Exercise name — displayLarge bruPaper
                Text(exerciseName)
                    .font(BRUFont.displayLarge)
                    .tracking(-0.3)
                    .foregroundStyle(Color.bruPaper)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Countdown — displayHero bruPaper, right-aligned
            Text(remainingText)
                .font(BRUFont.displayHero)
                .monospacedDigit()
                .foregroundStyle(Color.bruPaper)
        }
        .padding(16)
        .background(Color.bruInk)  // paper-on-ink hero (UI-SPEC line 384)
        // 4pt bruSignal progress bar at the bottom (UI-SPEC line 421)
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.bruFaint)
                        .frame(height: 4)
                    Rectangle()
                        .fill(Color.bruSignal)
                        .frame(width: geo.size.width * progressFraction, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Helpers

    /// Elapsed seconds since the rest started.
    private var elapsed: Double {
        max(0, Date.now.timeIntervalSince(state.startedAt))
    }

    /// Remaining time clamped at 0 — "0:00" when overrun.
    private var remainingText: String {
        let remaining = max(0, Double(state.targetSeconds) - elapsed)
        let s = Int(remaining)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Progress fraction: 1.0 at start, 0.0 at complete.
    private var progressFraction: Double {
        let total = max(1, Double(state.targetSeconds))
        let remaining = max(0, total - elapsed)
        return min(1, remaining / total)
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
        ),
        exerciseName: "Bench Press"
    )
    .frame(maxWidth: .infinity)
}

@available(iOS 16.1, *)
#Preview("Lock Screen — 0:15 remaining") {
    RestTimerLockScreenView(
        state: RestTimerAttributes.ContentState(
            startedAt: Date.now.addingTimeInterval(-165),
            targetSeconds: 180
        ),
        exerciseName: "Romanian Deadlift"
    )
    .frame(maxWidth: .infinity)
}
#endif
