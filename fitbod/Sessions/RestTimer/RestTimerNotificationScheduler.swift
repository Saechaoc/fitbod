//
//  RestTimerNotificationScheduler.swift
//  fitbod
//
//  The lock-screen notification half of the rest timer subsystem. Wraps
//  `UNUserNotificationCenter` behind a protocol (`RestTimerNotificationScheduling`)
//  so `RestTimerEngine` can be unit-tested without triggering the OS
//  permission prompt or hitting the real notification center in CI.
//
//  This file is the load-bearing mitigation for PITFALLS-doc #4 (the rest
//  timer drifting/stopping when the phone locks — the #1 user-visible
//  failure mode of a workout tracker). The pattern is:
//
//    1. Schedule a single `UNTimeIntervalNotificationTrigger` with a STABLE
//       identifier (`RestTimerEngine.notificationID`) at start time.
//    2. On ±15s adjustment, call `schedule(...)` again with the SAME
//       identifier — `UNUserNotificationCenter.add(request)` with a duplicate
//       identifier REPLACES the prior request atomically (RESEARCH §6 Pattern 2
//       + UNNotificationRequest docs). No cancel-then-add race window.
//    3. On stop / skip / auto-stop-on-next-set, call `cancel(identifier:)` →
//       `removePendingNotificationRequests(withIdentifiers:)`.
//
//  Permission policy (CONTEXT.md Area 4): request on FIRST session start,
//  NOT at app launch. The first invocation of `schedule(...)` triggers
//  `requestAuthorization(options:)`; subsequent invocations skip the prompt.
//  Denied state silently fails — the in-app overlay still works (UI-SPEC
//  § Error states "silent fallback").
//
//  Title / body copy is UI-SPEC verbatim:
//    - title: "Rest complete"
//    - body:  "{exerciseName} — next set ready."
//
//  No ActivityKit / Live Activity wiring lives here — that's plan 02-02's
//  responsibility. This file's surface is unchanged by Live Activity work.
//

import Foundation
import UserNotifications

/// Abstraction over `UNUserNotificationCenter` for testability.
///
/// The production implementation is `LiveNotificationScheduler`; unit tests
/// use a stub (`StubScheduler` in `RestTimerEngineTests`) that records the
/// `schedule` / `cancel` calls without touching the real notification center.
@MainActor
public protocol RestTimerNotificationScheduling {
    /// Schedule (or reschedule) the rest-complete lock-screen notification.
    /// Repeated calls with the same `identifier` REPLACE the prior pending
    /// request — this is the documented atomic-reschedule pattern that the
    /// ±15s buttons rely on.
    func schedule(in seconds: Int, exerciseName: String, identifier: String)

    /// Cancel the pending notification (called on stop / skip / auto-stop).
    func cancel(identifier: String)
}

/// Production implementation — talks to `UNUserNotificationCenter.current()`.
///
/// First call to `schedule(...)` triggers the permission prompt
/// (CONTEXT.md Area 4: "request on first session start"). Subsequent calls
/// skip the prompt; denied state silently fails (the in-app overlay still
/// works per UI-SPEC § Error states).
@MainActor
public final class LiveNotificationScheduler: RestTimerNotificationScheduling {
    public init() {}

    public func schedule(in seconds: Int, exerciseName: String, identifier: String) {
        // Defer to a Task so we can call the async permission API without
        // making the protocol method async (the engine's call sites stay
        // synchronous — fire-and-forget is the right shape here since the
        // notification scheduling is a side effect of UI mutations).
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.addRequest(
                    in: seconds,
                    exerciseName: exerciseName,
                    identifier: identifier,
                    center: center
                )
            case .notDetermined:
                // First-time prompt — CONTEXT.md Area 4 mandates this lives
                // at first session start, NOT at app launch.
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
                if granted {
                    self.addRequest(
                        in: seconds,
                        exerciseName: exerciseName,
                        identifier: identifier,
                        center: center
                    )
                }
            case .denied:
                // Silent fallback per UI-SPEC § Error states. The consuming
                // view (plan 04-01's SessionLoggerView) MAY surface a banner
                // explaining the in-app overlay is the only feedback channel;
                // the scheduler itself is UI-free.
                return
            @unknown default:
                return
            }
        }
    }

    public func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }

    /// Internal: construct + submit the `UNNotificationRequest`. Same-identifier
    /// `add(request:)` is the documented atomic-replace pattern.
    private func addRequest(
        in seconds: Int,
        exerciseName: String,
        identifier: String,
        center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"                              // UI-SPEC verbatim
        content.body = "\(exerciseName) — next set ready."           // UI-SPEC verbatim
        content.sound = .default

        // Non-repeating `UNTimeIntervalNotificationTrigger` has no 60-second
        // minimum (the 60s floor applies only to `repeats: true` triggers per
        // Apple docs). Rest timers commonly run 60–180s but warm-up rests
        // can be 30s. Clamp at >= 1s defensively to avoid the trap of
        // passing a non-positive interval. [RESEARCH Assumption A3]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, TimeInterval(seconds)),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        Task {
            // `add(request:)` with an existing identifier replaces the prior
            // request atomically — the ±15s reschedule pattern. The throw is
            // logged-but-ignored: if the notification can't be scheduled the
            // in-app overlay still works.
            try? await center.add(request)
        }
    }
}
