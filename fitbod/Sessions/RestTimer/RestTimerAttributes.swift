//
//  RestTimerAttributes.swift
//  fitbod
//
//  The `ActivityAttributes` value type for the rest-timer Live Activity.
//  Per Apple's ActivityKit contract, this type MUST be visible to BOTH the
//  main app target (which calls `Activity<RestTimerAttributes>.request(...)`)
//  AND the widget extension target (which declares
//  `ActivityConfiguration(for: RestTimerAttributes.self)`). Cross-target
//  membership is non-negotiable (RESEARCH § Pattern 3).
//
//  This file therefore lives under `fitbod/Sessions/RestTimer/` (the main
//  app's auto-discovered group) but is referenced symbolically by the
//  widget extension's source list as well — see `FitbodWidgets/SOURCES.md`
//  for the manual Xcode wiring required to add it to the widget target's
//  membership.
//
//  Shape (RESEARCH § Pattern 3 / Code Example 3):
//
//    - `sessionStartedAt: Date` — static attribute, set once at .request()
//      time, never updates. The wall-clock moment the session began.
//    - `exerciseName: String` — static attribute, set once at .request()
//      time. The current exercise label rendered in the Live Activity body
//      and Dynamic Island center region.
//
//  Nested `ContentState`:
//    - `startedAt: Date` — the moment the rest period started. Both the
//      main app and the widget compute `elapsed = Date.now -
//      startedAt`. Updates are pushed when the user presses ±15s; the
//      `startedAt` does NOT move on adjustment (matches the
//      `RestTimerEngine` semantics from plan 02-01).
//    - `targetSeconds: Int` — total rest in seconds. The widget computes
//      `remaining = target - elapsed`. Set to 0 to signal "stopped" to the
//      lock-screen card before dismissal.
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Wall-clock start time. Both the main app and the widget compute
        /// elapsed off `Date.now`. Updates are pushed when the user
        /// presses ±15s; `startedAt` does NOT move (matches the
        /// `RestTimerEngine` semantics from plan 02-01).
        public var startedAt: Date

        /// Total rest in seconds. UI computes remaining = target - elapsed.
        /// Set to 0 to signal "stopped" to the lock-screen card before
        /// dismissal.
        public var targetSeconds: Int

        public init(startedAt: Date, targetSeconds: Int) {
            self.startedAt = startedAt
            self.targetSeconds = targetSeconds
        }
    }

    /// Static — set once at .request() time, never updates.
    public var sessionStartedAt: Date

    /// Static — set once at .request() time, never updates. The exercise
    /// the user is resting between sets of.
    public var exerciseName: String

    public init(sessionStartedAt: Date, exerciseName: String) {
        self.sessionStartedAt = sessionStartedAt
        self.exerciseName = exerciseName
    }
}
