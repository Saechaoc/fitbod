// RestTimerLiveActivity.swift
// FitbodWidgets
//
// BRU brutalist Live Activity declaration — rewritten for Phase 2.1
// (UI-REVIEW Wave E items 51-54).
//
// CRITICAL — Swift 6 + ActivityKit pattern (project memory):
//   @preconcurrency import ActivityKit
//   Build ContentState / ActivityContent inside the Task body.
//   NEVER capture ContentState values from outer scope.
//
// Three presentations driven by Apple's runtime:
//
//   1. Lock screen / banner — RestTimerLockScreenView (bruInk background,
//      bruPaper text, bruSignal 4pt progress bar bottom).
//
//   2. Dynamic Island compact (top status bar inline):
//      - Leading: RestTimerDynamicIslandCompactLeading (12×12 ink rectangle)
//      - Trailing: RestTimerDynamicIslandCompactTrailing (countdown bodyEmphasis bruPaper)
//      NOT Image(systemName: "timer") — banned by UI-SPEC line 43.
//
//   3. Dynamic Island minimal (multiple-activity competition):
//      22pt circle with bruSignal progress sweep (Canvas-drawn arc).
//      NOT Image(systemName: "timer") — banned by UI-SPEC line 43.
//
//   4. Dynamic Island expanded (long-press):
//      RestTimerDynamicIslandExpandedView in .center slot.
//
// activityBackgroundTint: Color.bruInk — paper-on-ink contract (UI-SPEC line 730).
// activitySystemActionForegroundColor: Color.bruSignal.
//
// UI-REVIEW Wave E items 51-54.

@preconcurrency import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
public struct RestTimerLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // ── Lock screen / banner ──────────────────────────────────────
            RestTimerLockScreenView(
                state: context.state,
                exerciseName: context.attributes.exerciseName
            )
            .padding(16)
            .activityBackgroundTint(Color.bruInk)  // paper-on-ink (UI-SPEC line 730)
            .activitySystemActionForegroundColor(Color.bruSignal)

        } dynamicIsland: { context in
            DynamicIsland {
                // ── Dynamic Island expanded ───────────────────────────────
                // Leading region — unused (compact leading absorbs it)
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                // Trailing region — unused (center takes full width)
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                // Center — full expanded BRU layout
                DynamicIslandExpandedRegion(.center) {
                    RestTimerDynamicIslandExpandedView(
                        exerciseName: context.attributes.exerciseName,
                        countdownText: remainingText(state: context.state),
                        progress: progressFraction(state: context.state)
                    )
                }
                // Bottom — progress bar already inside the expanded view;
                // mount nothing extra here to avoid double-rendering.
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                // ── Compact leading: ink-square glyph (NOT SF Symbol) ─────
                RestTimerDynamicIslandCompactLeading(
                    countdownText: remainingText(state: context.state)
                )
            } compactTrailing: {
                // ── Compact trailing: countdown digits ────────────────────
                RestTimerDynamicIslandCompactTrailing(
                    countdownText: remainingText(state: context.state)
                )
            } minimal: {
                // ── Minimal: 22pt Canvas progress sweep in bruSignal ──────
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 2
                    let progress = progressFraction(state: context.state)

                    // Track (faint full circle)
                    var track = Path()
                    track.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                    ctx.stroke(track, with: .color(Color.bruFaint), lineWidth: 2)

                    // Signal arc (progress, starts at top -90°)
                    guard progress > 0 else { return }
                    var arc = Path()
                    arc.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * progress),
                        clockwise: false
                    )
                    ctx.stroke(arc, with: .color(Color.bruSignal), lineWidth: 2)
                }
                .frame(width: 22, height: 22)
            }
            .widgetURL(URL(string: "fitbod://session/active"))
        }
    }

    // MARK: - Helpers

    /// Elapsed seconds since the rest started.
    private func elapsed(state: RestTimerAttributes.ContentState) -> Double {
        max(0, Date.now.timeIntervalSince(state.startedAt))
    }

    /// Formatted "M:SS" countdown clamped at "0:00" on overrun.
    private func remainingText(state: RestTimerAttributes.ContentState) -> String {
        let remaining = max(0, Double(state.targetSeconds) - elapsed(state: state))
        let s = Int(remaining)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Progress fraction: 1.0 at start, 0.0 at complete.
    private func progressFraction(state: RestTimerAttributes.ContentState) -> Double {
        let total = max(1, Double(state.targetSeconds))
        let remaining = max(0, total - elapsed(state: state))
        return min(1, remaining / total)
    }
}
