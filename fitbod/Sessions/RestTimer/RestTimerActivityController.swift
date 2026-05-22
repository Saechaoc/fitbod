//
//  RestTimerActivityController.swift
//  fitbod
//
//  Main-app side of the ActivityKit Live Activity for the rest timer.
//  Owns the `Activity<RestTimerAttributes>` reference, debounces updates,
//  and silently falls back when the host system can't run Live Activities
//  (simulator / pre-Pro iPhone / user-disabled in Settings).
//
//  Lifecycle:
//    - `start(...)` — calls `Activity<RestTimerAttributes>.request(...)`
//      wrapped in do/catch. On failure (RESEARCH §6 Pitfall 3), the
//      `activity` ref stays nil and the in-app overlay (plan 02-03) is the
//      only feedback channel.
//    - `update(...)` — coalesces back-to-back calls via a 200ms-default
//      debounce window. Apple rate-limits Live Activity updates (RESEARCH
//      §6 Pitfall 9); spamming ±15s buttons must not trip the limiter.
//    - `end()` — dismisses the activity immediately (`.immediate` policy)
//      and cancels any pending debounce task.
//
//  Test seam: `RestTimerActivityControlling` protocol + `NoopActivityController`
//  let `RestTimerEngine` (plan 02-03) be unit-tested without touching the
//  real ActivityKit framework. The bridge (`RestTimerLiveActivityBridge`)
//  is the concrete delegate that owns a `RestTimerActivityController` and
//  wires it into `RestTimerEngine`.
//

import Foundation
@preconcurrency import ActivityKit

/// Abstraction over ActivityKit for unit-testability and for the silent-
/// fallback contract (RESEARCH §6 Pitfall 3). `RestTimerEngine` in plan
/// 02-03 will hold a delegate of this shape and call through it on every
/// start / adjust / stop transition.
@MainActor
public protocol RestTimerActivityControlling {
    /// Start a new Live Activity. Idempotent — if one is already running,
    /// `end()` is called first.
    func start(startedAt: Date, targetSeconds: Int, exerciseName: String)

    /// Push a state update to the running Live Activity. Coalesces with
    /// the next call within the debounce window (default 200ms).
    func update(startedAt: Date, targetSeconds: Int)

    /// Dismiss the running Live Activity immediately. Idempotent.
    func end()
}

/// Production implementation. Owns a single `Activity<RestTimerAttributes>`
/// reference at most. Every Apple-facing call is wrapped in
/// silent-fallback try/catch (RESEARCH §6 Pitfall 3).
@available(iOS 16.1, *)
@MainActor
public final class RestTimerActivityController: RestTimerActivityControlling {

    /// The running activity, when one was successfully started.
    /// `nil` on simulator / pre-Pro / user-disabled / Apple-rate-limited.
    private var activity: Activity<RestTimerAttributes>?

    /// Debounce window for `update(...)` to respect ActivityKit's
    /// documented rate limits (RESEARCH §6 Pitfall 9). Spam ±15s
    /// coalesces into a single update after the window.
    private let debounceMillis: Int

    /// Pending debounce task — cancelled if a new update arrives.
    private var debounceTask: Task<Void, Never>?

    public init(debounceMillis: Int = 200) {
        self.debounceMillis = debounceMillis
    }

    public func start(startedAt: Date, targetSeconds: Int, exerciseName: String) {
        // RESEARCH §6 Pitfall 3 — guard with areActivitiesEnabled and
        // silently fall back on any failure.
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else { return }

        // If an activity is already running (defensive — engine should
        // call end() first), end the prior one before requesting a new one.
        if activity != nil {
            end()
        }

        let attributes = RestTimerAttributes(
            sessionStartedAt: startedAt,
            exerciseName: exerciseName
        )
        let state = RestTimerAttributes.ContentState(
            startedAt: startedAt,
            targetSeconds: targetSeconds
        )
        let content = ActivityContent(
            state: state,
            staleDate: startedAt.addingTimeInterval(Double(targetSeconds + 30))
        )
        do {
            activity = try Activity<RestTimerAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil   // local-only updates; no APNs
            )
        } catch {
            // Simulator / denial / capability mismatch — silent fallback.
            activity = nil
        }
    }

    public func update(startedAt: Date, targetSeconds: Int) {
        // Cancel any in-flight debounce; schedule the latest mutation.
        debounceTask?.cancel()
        let snapshotActivity = activity
        let millis = debounceMillis
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(millis))
            guard !Task.isCancelled else { return }
            guard self != nil, let activity = snapshotActivity else { return }
            let state = RestTimerAttributes.ContentState(
                startedAt: startedAt,
                targetSeconds: targetSeconds
            )
            let content = ActivityContent(
                state: state,
                staleDate: startedAt.addingTimeInterval(Double(targetSeconds + 30))
            )
            await activity.update(content)
        }
    }

    public func end() {
        debounceTask?.cancel()
        debounceTask = nil
        guard let activity else { return }
        let startedAt = activity.content.state.startedAt
        self.activity = nil
        Task { @MainActor in
            let final = RestTimerAttributes.ContentState(
                startedAt: startedAt,
                targetSeconds: 0   // signal "stopped"
            )
            await activity.end(
                ActivityContent(state: final, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }
}

/// No-op controller for unit tests + previews + simulator fallback.
/// `RestTimerEngine` in plan 02-03 will accept this in its initializer
/// so tests can run without touching ActivityKit.
@MainActor
public final class NoopActivityController: RestTimerActivityControlling {
    public init() {}
    public func start(startedAt: Date, targetSeconds: Int, exerciseName: String) {}
    public func update(startedAt: Date, targetSeconds: Int) {}
    public func end() {}
}
