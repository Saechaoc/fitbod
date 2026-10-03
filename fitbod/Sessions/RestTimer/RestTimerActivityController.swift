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

    /// Re-attach to a rest period restored from persistence (app relaunch
    /// or logger re-open). The live controller adopts a still-running
    /// activity for the same exercise instead of stacking a duplicate.
    func resume(startedAt: Date, targetSeconds: Int, exerciseName: String)
}

extension RestTimerActivityControlling {
    /// Default: a restore is just a fresh start.
    public func resume(startedAt: Date, targetSeconds: Int, exerciseName: String) {
        start(startedAt: startedAt, targetSeconds: targetSeconds, exerciseName: exerciseName)
    }
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

        // End whatever is showing first: the activity this controller owns
        // AND any orphan left by a previous process (the app was killed
        // mid-rest), so a new rest never stacks a second card.
        end()

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

    public func resume(startedAt: Date, targetSeconds: Int, exerciseName: String) {
        // After a relaunch `activity` is nil but the system may still be
        // showing the card from the previous process. Adopt it when it
        // belongs to the same rest period; otherwise start fresh.
        if activity == nil,
           let orphan = Activity<RestTimerAttributes>.activities.first(where: {
               $0.activityState == .active && $0.attributes.exerciseName == exerciseName
           }) {
            activity = orphan
            update(startedAt: startedAt, targetSeconds: targetSeconds)
            return
        }
        if activity != nil {
            update(startedAt: startedAt, targetSeconds: targetSeconds)
            return
        }
        start(startedAt: startedAt, targetSeconds: targetSeconds, exerciseName: exerciseName)
    }

    public func end() {
        debounceTask?.cancel()
        debounceTask = nil
        let owned = activity
        self.activity = nil
        // Owned activity plus any orphan from a previous process.
        var toEnd = Activity<RestTimerAttributes>.activities
        if let owned, !toEnd.contains(where: { $0.id == owned.id }) {
            toEnd.append(owned)
        }
        for activity in toEnd {
            let startedAt = activity.content.state.startedAt
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
