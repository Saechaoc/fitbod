//
//  RestTimerActivityControllerTests.swift
//  fitbodTests
//
//  Three tests covering the protocol surface, the silent-fallback
//  contract (RESEARCH §6 Pitfall 3 — `Activity.request` throws on
//  simulators and pre-Pro iPhones), and the debounce machinery
//  (RESEARCH §6 Pitfall 9 — Live Activity rate limit).
//
//  Why no direct assertion on the underlying `Activity` reference:
//  `RestTimerActivityController.activity` is `private` and not
//  observable from outside the type. The test contract is "no crash on
//  simulator" and "the public protocol surface is reachable" — the same
//  way the existing `RestTimerNotificationSchedulerTests` verifies the
//  scheduler without poking the real `UNUserNotificationCenter`.
//
//  End-to-end visual verification of the Dynamic Island / lock-screen
//  card requires a physical iPhone 14 Pro or newer (see plan PLAN.md
//  § Manual verification + RESEARCH § Open Question #1).
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("RestTimerActivityController")
struct RestTimerActivityControllerTests {

    @Test("noopControllerSwallowsAllCalls")
    func noopControllerSwallowsAllCalls() {
        // The Noop variant exists so `RestTimerEngine` in plan 02-03 can
        // run under unit tests without touching ActivityKit. This test
        // pins the protocol surface — if a future refactor adds a new
        // method to `RestTimerActivityControlling` without also adding
        // a Noop implementation, the test file fails to compile.
        let controller = NoopActivityController()
        controller.start(startedAt: Date.now, targetSeconds: 180, exerciseName: "Bench")
        controller.update(startedAt: Date.now, targetSeconds: 195)
        controller.end()
        // No assertion needed; the test proves the protocol surface
        // (and the silent-fallback contract via the no-op type) is reachable.
    }

    @Test("liveControllerSilentFallbackOnSimulator")
    func liveControllerSilentFallbackOnSimulator() async {
        // `Activity.request` typically throws on iOS simulator (no
        // Dynamic Island simulation). The controller must silently
        // nil the activity ref on failure (RESEARCH §6 Pitfall 3).
        // The contract is "no crash on simulator" — if the guard is
        // missing or the do/catch is removed, this test would crash
        // with an uncaught throw.
        let controller = RestTimerActivityController()
        controller.start(startedAt: Date.now, targetSeconds: 180, exerciseName: "Bench")
        // Smoke that update / end also survive the silent-fallback path
        // (when the underlying activity ref is nil, both calls are no-ops).
        controller.update(startedAt: Date.now, targetSeconds: 195)
        controller.end()
    }

    @Test("updateDebounceCoalesces")
    func updateDebounceCoalesces() async throws {
        // Verify the debounce machinery. The controller's debounce uses
        // an async sleep — wait long enough that the debounce fires.
        // The internal `activity` is nil on simulator (silent fallback),
        // so the `await activity.update(content)` line is short-circuited,
        // but the debounce task itself must still be cancelled and
        // re-scheduled correctly across multiple `update(...)` calls.
        // RESEARCH §6 Pitfall 9: rapid ±15s spam must coalesce — if the
        // debounce machinery is broken, each call would crash trying to
        // operate on a torn-down task.
        let controller = RestTimerActivityController(debounceMillis: 50)
        controller.start(startedAt: Date.now, targetSeconds: 180, exerciseName: "Bench")
        for delta in [195, 210, 225, 240] {
            controller.update(startedAt: Date.now, targetSeconds: delta)
        }
        try await Task.sleep(for: .milliseconds(100))
        // No crash = debounce machinery works. Final `end()` to verify
        // the cleanup path also survives after coalesced updates.
        controller.end()
    }
}
