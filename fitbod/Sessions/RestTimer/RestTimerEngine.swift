//
//  RestTimerEngine.swift
//  fitbod
//
//  The canonical `Date`-based rest timer controller for Phase 2 — the
//  load-bearing mitigation for PITFALLS-doc #4 ("rest timer drifts when
//  the phone locks"). The #1 user-visible failure mode of a workout
//  tracker if implemented incorrectly.
//
//  Engine shape (RESEARCH §6 Pattern 2):
//
//    - `startedAt: Date?` — the wall-clock moment the user tapped the
//      set-complete checkmark. NIL when the timer is not running.
//    - `targetSeconds: Int` — the rest duration the user has prescribed
//      (mutated by ±15s buttons; the persisted `startedAt` does NOT move).
//    - `currentExerciseName: String` — the exercise label shown in the
//      lock-screen notification + UI overlay.
//
//  Remaining time is COMPUTED on read as `Double(targetSeconds) -
//  now().timeIntervalSince(startedAt)`. No foreground `Timer`-based
//  publisher drives the countdown — that pattern stops/drifts when iOS suspends
//  the app, which is the entire pitfall. The UI re-renders via a
//  `TimelineView(.periodic(from: startedAt, by: 1))` upstream (plan 02-02
//  wires that piece). This file's only job is the value-holder + the
//  notification scheduling side effects.
//
//  Notification scheduling is delegated to `RestTimerNotificationScheduling`
//  (injected via the initializer) so:
//    1. Unit tests can pass a recording stub and avoid the permission prompt.
//    2. Plan 02-02 can swap in a Live-Activity-aware decorator without
//       touching the engine's call sites.
//
//  The clock is also injected (`now: () -> Date`) so tests can advance a
//  synthetic clock without sleeping — the `dateMathSurvivesSimulatedBackground`
//  test in `RestTimerEngineTests` simulates a 3-minute lock-screen wait by
//  mutating the clock closure's captured `Date`, proving the Date-math is
//  correct without any actual elapsed wall time.
//
//  Out of scope for this plan: ActivityKit / Live Activity wiring (plan 02-02),
//  Dynamic Island view declarations (plan 02-03), SwiftUI overlay views
//  (plan 04-01). The engine exposes the surface those plans consume.
//

import Foundation
import SwiftUI
import UserNotifications

@Observable
@MainActor
public final class RestTimerEngine {
    // MARK: - Published state

    /// The moment the rest period started, or `nil` when the timer is not
    /// running. The UI computes remaining seconds from this + `targetSeconds`
    /// — NEVER from a separately ticking counter (PITFALLS-doc #4).
    public private(set) var startedAt: Date?

    /// The current rest target in seconds. Mutated by ±15s buttons via
    /// `adjust(deltaSeconds:)`. The persisted `startedAt` does NOT move on
    /// adjustment — the user is asking for more (or less) TOTAL rest from
    /// the original start point, not "+15 from now."
    public private(set) var targetSeconds: Int = 0

    /// The exercise label shown in the lock-screen notification body and
    /// the in-app overlay header. Cleared on `stop()`.
    public private(set) var currentExerciseName: String = ""

    // MARK: - Static contract

    /// Stable identifier for the pending local notification.
    ///
    /// The same-identifier replace-by-identifier reschedule pattern requires
    /// this constant to be STABLE across all calls (`schedule(...)` /
    /// `cancel(...)`). `UNUserNotificationCenter.add(request:)` with a
    /// duplicate identifier replaces the prior pending request atomically —
    /// see `RestTimerNotificationScheduler.addRequest` for the citation.
    ///
    /// This anchor is the entire reason ±15s mutations are safe; using a
    /// per-call UUID instead would create multiple pending alerts on rapid
    /// adjustment spam (RESEARCH §6 Pitfall 9).
    public static let notificationID = "rest-timer.scheduled"

    // MARK: - Injected collaborators

    /// Notification scheduling collaborator. Production uses
    /// `LiveNotificationScheduler` (UNUserNotificationCenter-backed); unit
    /// tests pass a recording stub that captures the schedule/cancel calls
    /// without triggering the OS permission prompt.
    private let scheduler: RestTimerNotificationScheduling

    /// ActivityKit Live Activity collaborator. Defaults to
    /// `NoopActivityController()` so plan 02-01's existing unit tests
    /// keep their hermetic shape (no ActivityKit side effects). Production
    /// call sites use `RestTimerEngine.makeProduction()` which wires the
    /// live `RestTimerActivityController` from plan 02-02.
    ///
    /// The engine owns three orthogonal concerns: notification scheduling
    /// (lock-screen alert), Live Activity (lock-screen card + Dynamic
    /// Island), and the Date-based countdown state. Each is independently
    /// swappable for tests.
    private let activityController: RestTimerActivityControlling

    /// Injectable wall-clock. `Date.now` in production; unit tests pass a
    /// closure returning a controlled `Date` to simulate elapsed time
    /// without sleeping. This is the seam that lets
    /// `dateMathSurvivesSimulatedBackground` exercise the 3-minute-lock
    /// scenario in microseconds.
    private let now: () -> Date

    public init(
        scheduler: RestTimerNotificationScheduling = LiveNotificationScheduler(),
        activityController: RestTimerActivityControlling = NoopActivityController(),
        now: @escaping () -> Date = { Date.now }
    ) {
        self.scheduler = scheduler
        self.activityController = activityController
        self.now = now
    }

    /// Production factory: wires the live `LiveNotificationScheduler`
    /// (plan 02-01) and the live `RestTimerActivityController` (plan 02-02)
    /// in a single call. Used by `SessionLoggerView` in plan 04-01.
    ///
    /// Kept separate from the default initializer so the default init stays
    /// hermetic — passing a `StubScheduler` is the canonical unit-test
    /// shape, and the Noop activity controller default keeps those tests
    /// free of ActivityKit imports.
    public static func makeProduction() -> RestTimerEngine {
        RestTimerEngine(
            scheduler: LiveNotificationScheduler(),
            activityController: RestTimerActivityController()
        )
    }

    // MARK: - Computed accessors

    /// Computed remaining time in seconds.
    ///
    /// Negative when the countdown has overrun zero (the user hasn't yet
    /// tapped the next set's weight field or hit Skip). The UI shows the
    /// overrun magnitude — "Rest complete · +10s" — until the next set is
    /// entered. Returns 0 when the timer is not running.
    public var remaining: TimeInterval {
        guard let startedAt else { return 0 }
        return Double(targetSeconds) - now().timeIntervalSince(startedAt)
    }

    /// Whether the timer is currently active. Cheap read used by the
    /// session logger to decide whether to render the rest overlay.
    public var isRunning: Bool { startedAt != nil }

    // MARK: - Mutating commands

    /// Start (or restart) the timer.
    ///
    /// Called from `SetRow.completeAction` on the set-complete checkmark
    /// tap (plan 04-01). Schedules a `UNUserNotification` for the lock-screen
    /// alert via the injected scheduler.
    ///
    /// Restart semantics: calling `start(...)` while the timer is running
    /// REPLACES the prior state (new `startedAt`, new target, new exercise
    /// name, fresh notification scheduling). The `restartReplacesPriorState`
    /// test pins this.
    public func start(seconds: Int, exerciseName: String) {
        self.startedAt = now()
        self.targetSeconds = max(1, seconds)
        self.currentExerciseName = exerciseName
        scheduler.schedule(
            in: targetSeconds,
            exerciseName: exerciseName,
            identifier: Self.notificationID
        )
        // Plan 02-02 wire: start the Live Activity in lockstep with the
        // notification scheduling. NoopActivityController by default makes
        // this a no-op in plan-02-01 unit tests.
        activityController.start(
            startedAt: self.startedAt!,
            targetSeconds: self.targetSeconds,
            exerciseName: exerciseName
        )
    }

    /// Mutate the target by ±N seconds.
    ///
    /// The persisted `startedAt` does NOT move — the user is asking for
    /// more (or less) total rest from the original start point, not from
    /// now. So if the user started a 180s timer 30s ago and taps "+15",
    /// the new target is 195s, the remaining is 165s (NOT 195s), and the
    /// notification is rescheduled to fire 165 seconds from now.
    ///
    /// Per RESEARCH §6 Pitfall 9: the Live Activity scheduler in plan 02-02
    /// debounces this for rate-limit reasons, but the notification scheduler
    /// is always called here (notification scheduling is cheap, idempotent,
    /// and the replace-by-identifier pattern guarantees only one pending
    /// request exists at any time).
    ///
    /// No-op when not running (callers like `SetRow.plusButtonAction` may
    /// fire while the engine is stopped if the user double-taps).
    public func adjust(deltaSeconds: Int) {
        guard isRunning, let startedAt else { return }
        let newTarget = max(0, targetSeconds + deltaSeconds)
        targetSeconds = newTarget

        // Reschedule the notification to fire at `startedAt + newTarget`,
        // computed as the delta from `now()` so the trigger interval is
        // correct regardless of how much time has elapsed since `start()`.
        // Clamp at >= 1s to keep `UNTimeIntervalNotificationTrigger` happy.
        let fireDate = startedAt.addingTimeInterval(Double(newTarget))
        let firesIn = max(1, Int(fireDate.timeIntervalSince(now())))
        scheduler.schedule(
            in: firesIn,
            exerciseName: currentExerciseName,
            identifier: Self.notificationID
        )
        // Plan 02-02 wire: push the new ContentState through the debounce.
        // startedAt does NOT move; only targetSeconds changes.
        activityController.update(
            startedAt: startedAt,
            targetSeconds: newTarget
        )
    }

    /// Stop the timer and cancel the pending lock-screen notification.
    ///
    /// Called from:
    ///   - `SetRow.weightField.onTapGesture` when the user taps the NEXT
    ///     set's weight field (auto-stop on next-set entry — SESS-04).
    ///   - The "Skip" button in the rest overlay.
    ///   - Session-end / session-discard flows (plan 04-01).
    ///
    /// Idempotent — safe to call when not running.
    public func stop() {
        startedAt = nil
        targetSeconds = 0
        currentExerciseName = ""
        scheduler.cancel(identifier: Self.notificationID)
        // Plan 02-02 wire: dismiss the Live Activity immediately.
        activityController.end()
    }
}
