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
//      system circular ProgressView(timerInterval:) tinted bruSignal.
//      NOT Image(systemName: "timer") — banned by UI-SPEC line 43.
//
//   4. Dynamic Island expanded (long-press):
//      RestTimerDynamicIslandExpandedView in .center slot.
//
// Every countdown and bar is a system timer view (`Text(timerInterval:)`,
// `ProgressView(timerInterval:)`). ActivityKit only re-renders on a pushed
// update, so anything computed from `Date.now` in a view body freezes.
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
            RestTimerLockScreenView(state: context.state)
            .activityBackgroundTint(Color.bruInk)  // paper-on-ink (UI-SPEC line 730)
            .activitySystemActionForegroundColor(Color.bruSignal)
            // A tap on the lock screen opens the workout, as the island does.
            .widgetURL(URL(string: "fitbod://session/active"))

        } dynamicIsland: { context in
            DynamicIsland {
                // ── Dynamic Island expanded: live countdown + bar only ────
                DynamicIslandExpandedRegion(.center) {
                    RestTimerDynamicIslandExpandedView(state: context.state)
                }
            } compactLeading: {
                // ── Compact leading: ink-square glyph (NOT SF Symbol) ─────
                RestTimerDynamicIslandCompactLeading()
            } compactTrailing: {
                // ── Compact trailing: live countdown digits ───────────────
                RestTimerDynamicIslandCompactTrailing(state: context.state)
            } minimal: {
                // ── Minimal: live bruSignal ring that drains over the rest ─
                ProgressView(timerInterval: context.state.restInterval, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(Color.bruSignal)
            }
            .widgetURL(URL(string: "fitbod://session/active"))
        }
    }
}
