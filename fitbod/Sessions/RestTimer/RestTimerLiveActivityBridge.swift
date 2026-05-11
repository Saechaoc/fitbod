//
//  RestTimerLiveActivityBridge.swift
//  fitbod
//
//  The thin glue layer between `RestTimerEngine` (plan 02-01) and the
//  `RestTimerActivityController` (this plan, 02-02). The engine's contract
//  is unchanged by Live Activity work — the bridge observes engine
//  transitions and forwards them to the controller.
//
//  Wiring (deferred to plan 02-03):
//
//    let bridge = RestTimerLiveActivityBridge()
//    let engine = RestTimerEngine(
//        scheduler: LiveNotificationScheduler(),
//        activityDelegate: bridge   // 02-03 adds this seam
//    )
//
//  Why a separate bridge instead of folding the controller into the
//  engine: the engine ships in plan 02-01 with a closed surface (notification
//  scheduling + Date math only). The Live Activity is a strictly additive
//  side-channel — the engine functions correctly even when the activity
//  fails to start (simulator / pre-Pro / user-disabled). Keeping the bridge
//  separate matches the silent-fallback contract from RESEARCH §6 Pitfall 3.
//
//  The bridge is observable / @MainActor and erases the iOS 16.1
//  availability gate of `RestTimerActivityController` (the project's
//  iOS 18.0 floor makes the gate always-true, but the typechecker still
//  requires the attribute on direct references to `Activity<...>`).
//

import Foundation

/// Bridges `RestTimerEngine` lifecycle transitions to the
/// `RestTimerActivityController`. The bridge holds the controller as a
/// `RestTimerActivityControlling` (the protocol type) so tests can inject
/// `NoopActivityController`.
///
/// The protocol-based shape also lets the engine's plan-02-03 integration
/// point be a single property of type `RestTimerActivityControlling?` —
/// nil disables the Live Activity entirely (the silent-fallback path).
@MainActor
public final class RestTimerLiveActivityBridge {

    /// Underlying controller. Defaults to the live `RestTimerActivityController`
    /// on iOS 16.1+ (always true at runtime given the project's 18.0
    /// deployment floor) and a `NoopActivityController` otherwise.
    private let controller: RestTimerActivityControlling

    /// Production initializer — picks the iOS 16.1+ live controller when
    /// available, the no-op otherwise.
    public init() {
        if #available(iOS 16.1, *) {
            self.controller = RestTimerActivityController()
        } else {
            self.controller = NoopActivityController()
        }
    }

    /// Test / preview seam — inject any conforming controller.
    public init(controller: RestTimerActivityControlling) {
        self.controller = controller
    }

    /// Forward the engine's `start(...)` to the activity controller.
    /// Called from `RestTimerEngine.start(...)` (wired in plan 02-03).
    public func engineDidStart(
        startedAt: Date,
        targetSeconds: Int,
        exerciseName: String
    ) {
        controller.start(
            startedAt: startedAt,
            targetSeconds: targetSeconds,
            exerciseName: exerciseName
        )
    }

    /// Forward the engine's `adjust(...)` to the activity controller as a
    /// debounced update (RESEARCH §6 Pitfall 9). The `startedAt` does NOT
    /// move on ±15s adjustment — only `targetSeconds` changes — but the
    /// bridge forwards both so the controller's ContentState is the
    /// single source of truth for the widget.
    public func engineDidAdjust(
        startedAt: Date,
        targetSeconds: Int
    ) {
        controller.update(
            startedAt: startedAt,
            targetSeconds: targetSeconds
        )
    }

    /// Forward the engine's `stop()` to the activity controller. Dismisses
    /// the Live Activity immediately. Idempotent.
    public func engineDidStop() {
        controller.end()
    }
}

extension RestTimerLiveActivityBridge: RestTimerActivityControlling {
    /// `RestTimerActivityControlling` conformance so the bridge itself
    /// can be the single value the engine holds (plan 02-03 will declare
    /// `private let activityDelegate: RestTimerActivityControlling?` on
    /// the engine and assign the bridge there). This avoids requiring the
    /// engine to know about both types.
    public func start(startedAt: Date, targetSeconds: Int, exerciseName: String) {
        engineDidStart(
            startedAt: startedAt,
            targetSeconds: targetSeconds,
            exerciseName: exerciseName
        )
    }

    public func update(startedAt: Date, targetSeconds: Int) {
        engineDidAdjust(startedAt: startedAt, targetSeconds: targetSeconds)
    }

    public func end() {
        engineDidStop()
    }
}
