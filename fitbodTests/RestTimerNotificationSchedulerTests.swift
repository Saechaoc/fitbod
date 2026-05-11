//
//  RestTimerNotificationSchedulerTests.swift
//  fitbodTests
//
//  Three test functions covering the contract surface of the
//  notification scheduler. The production scheduler
//  (`LiveNotificationScheduler`) talks to `UNUserNotificationCenter` which
//  can't be hermetically tested without environment mocking — these tests
//  verify (a) the stable-identifier constant the replace-by-identifier
//  pattern relies on, (b) the protocol-conformance of the live scheduler,
//  and (c) the >= 1s clamp that protects `UNTimeIntervalNotificationTrigger`
//  from a trap when callers pass zero.
//
//  End-to-end lock-screen delivery is deferred to manual on-device
//  verification (see PLAN.md § Manual verification).
//

import Foundation
import UserNotifications
import Testing
@testable import fitbod

@MainActor
@Suite("RestTimerNotificationScheduler", .serialized)
struct RestTimerNotificationSchedulerTests {

    @Test("notificationIDConstantIsStable")
    func notificationIDConstantIsStable() {
        // The same-identifier replace-by-identifier pattern requires
        // `RestTimerEngine.notificationID` to be a STABLE non-empty
        // constant. This test pins the contract — if a future refactor
        // accidentally rotates the identifier to per-call UUIDs, the
        // ±15s reschedule pattern would pile up multiple pending alerts
        // on the lock screen (RESEARCH §6 Pitfall 9). This test fails
        // fast.
        #expect(RestTimerEngine.notificationID == "rest-timer.scheduled")
        #expect(!RestTimerEngine.notificationID.isEmpty)
    }

    @Test("liveSchedulerConformsToProtocol")
    func liveSchedulerConformsToProtocol() {
        // Smoke: instantiation succeeds; the protocol surface compiles
        // against the production type. The cast through the existential
        // proves `LiveNotificationScheduler` is an honest conformance of
        // `RestTimerNotificationScheduling` (i.e., the engine's injection
        // point accepts it without ceremony).
        let scheduler: any RestTimerNotificationScheduling = LiveNotificationScheduler()
        scheduler.cancel(identifier: "test-only-conformance")
    }

    @Test("liveSchedulerScheduleAccepts1SecondMinimum")
    func liveSchedulerScheduleAccepts1SecondMinimum() {
        // `UNTimeIntervalNotificationTrigger(timeInterval:repeats:false)`
        // traps if the interval is <= 0. The scheduler clamps at >= 1s
        // defensively. Test by passing 0 — the call must not crash.
        //
        // We can't assert anything about what was scheduled (the real
        // `UNUserNotificationCenter` is the only sink), but a non-crashing
        // call proves the clamp guard is in place.
        let scheduler = LiveNotificationScheduler()
        scheduler.schedule(in: 0, exerciseName: "X", identifier: "test-clamp")
    }
}
