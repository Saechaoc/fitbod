//
//  RestTimerLiveActivity.swift
//  FitbodWidgets
//
//  The `ActivityKit` Live Activity declaration for the rest timer. Hosts
//  three presentations that Apple's runtime picks between based on the
//  current display context:
//
//    1. Lock-screen / banner — `RestTimerLockScreenView` (the standalone
//       card shown on iPhone models without a Dynamic Island, and as the
//       banner pull-down on Pro models).
//    2. Dynamic Island compact (top status bar inline) — small `timer`
//       SF Symbol leading, countdown trailing. UI-SPEC § Dynamic Island
//       compact verbatim.
//    3. Dynamic Island minimal (when multiple activities compete for the
//       cutout) — single accent-color `timer` glyph.
//    4. Dynamic Island expanded (long-press) — exercise name center,
//       countdown trailing, progress bar bottom. UI-SPEC § Dynamic Island
//       expanded verbatim.
//
//  Per RESEARCH § Pattern 3 + UI-SPEC § Rest timer + Asset Contract: the
//  `timer` SF Symbol is the canonical leading glyph, accent color drives
//  the progress bar tint, the countdown uses `.title2` + `.semibold` +
//  monospaced digits.
//
//  Notes on `TimelineView` vs computed-on-render:
//
//  ActivityKit ContentState updates fire whenever the main app calls
//  `activity.update(...)` — debounced 200ms per `RestTimerActivityController`.
//  Between updates the widget re-renders by computing `remaining = target -
//  (Date.now - startedAt)` on every `body` evaluation. Apple drives widget
//  redraw cadence; the widget itself does not own a `Timer`. This is the
//  RESEARCH §6 Pattern 2 mitigation against PITFALLS-doc #4 (timer drift
//  on lock), applied to the widget side.
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
public struct RestTimerLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock screen / banner view (iPhone < Pro, or all phones when
            // Dynamic Island can't render).
            RestTimerLockScreenView(
                state: context.state,
                exerciseName: context.attributes.exerciseName
            )
            .padding(16)                                                    // UI-SPEC § Spacing lg
            .activityBackgroundTint(Color(.secondarySystemGroupedBackground))
            .activitySystemActionForegroundColor(Color.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                // UI-SPEC § Dynamic Island expanded layout —
                //   leading: timer icon
                //   trailing: countdown
                //   center: exercise name
                //   bottom: accent progress bar
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")                              // UI-SPEC § Asset Contract
                        .foregroundStyle(Color.accentColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(remainingText(state: context.state))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.exerciseName)
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: elapsed(state: context.state),
                        total: max(1, Double(context.state.targetSeconds))
                    )
                    .tint(Color.accentColor)                                // UI-SPEC accent surface #17
                }
            } compactLeading: {
                Image(systemName: "timer")                                  // UI-SPEC § Dynamic Island compact
            } compactTrailing: {
                Text(remainingText(state: context.state))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")                                  // UI-SPEC § Dynamic Island minimal
                    .foregroundStyle(Color.accentColor)
            }
            .widgetURL(URL(string: "fitbod://session/active"))
        }
    }

    /// Elapsed seconds since the rest started. Computed on every render
    /// pass; ActivityKit drives the redraw cadence. Clamped at >=0 so the
    /// progress bar never reads negative if the system fires a redraw
    /// before `ContentState` updates after `start()`.
    private func elapsed(state: RestTimerAttributes.ContentState) -> Double {
        max(0, Date.now.timeIntervalSince(state.startedAt))
    }

    /// Formatted "M:SS" countdown. Clamped at >=0 so an overrun (target
    /// reached but engine hasn't received `stop()` yet) reads as "0:00".
    /// The main app handles the post-zero overrun copy ("Rest complete ·
    /// +Ns") in the overlay; the Live Activity stays at "0:00" until end.
    private func remainingText(state: RestTimerAttributes.ContentState) -> String {
        let remaining = max(0, Double(state.targetSeconds) - elapsed(state: state))
        let s = Int(remaining)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
