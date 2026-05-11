//
//  RestTimerEngineTests.swift
//  fitbodTests
//
//  Ten test functions covering the Date-based rest timer engine
//  (PITFALLS-doc #4 / SESS-04 — the load-bearing Phase 2 user-visible
//  invariant). Each test uses the `StubScheduler` recording double and
//  an injected synthetic clock closure to exercise the engine without
//  triggering the OS permission prompt or sleeping.
//
//  Test matrix:
//    1. notRunningInitially                              — default state
//    2. startSetsStartedAtAndTarget                       — start mutates all three fields + Date math at t+30 and t+200
//    3. startSchedulesNotificationOnce                    — single schedule call on start
//    4. plus15IncreasesTargetAndReschedulesFromOriginalStart
//                                                          — +15 mutates targetSeconds; startedAt does NOT move;
//                                                            notification rescheduled for (targetSeconds - elapsed)
//    5. minus15DecreasesTarget                            — -15 symmetrically
//    6. adjustClampsTargetAtZero                          — negative target prevented
//    7. adjustNoopWhenNotRunning                          — no-op when timer not running
//    8. stopCancelsAndResets                              — cancel notification + zero state
//    9. dateMathSurvivesSimulatedBackground               — 3-minute simulated lock; remaining is correct
//   10. restartReplacesPriorState                         — second start(...) replaces prior state cleanly
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("RestTimerEngine", .serialized)
struct RestTimerEngineTests {

    // MARK: - Test doubles

    /// Recording stub used by every test in this suite. Captures every
    /// `schedule(...)` / `cancel(...)` invocation so assertions can verify
    /// the engine's notification side effects without touching the real
    /// `UNUserNotificationCenter`.
    final class StubScheduler: RestTimerNotificationScheduling {
        var scheduleCalls: [(seconds: Int, name: String, id: String)] = []
        var cancelCalls: [String] = []

        func schedule(in seconds: Int, exerciseName: String, identifier: String) {
            scheduleCalls.append((seconds, exerciseName, identifier))
        }

        func cancel(identifier: String) {
            cancelCalls.append(identifier)
        }
    }

    // MARK: - Tests

    @Test("notRunningInitially")
    func notRunningInitially() {
        let engine = RestTimerEngine(scheduler: StubScheduler())

        #expect(engine.isRunning == false)
        #expect(engine.startedAt == nil)
        #expect(engine.targetSeconds == 0)
        #expect(engine.currentExerciseName == "")
        #expect(engine.remaining == 0)
    }

    @Test("startSetsStartedAtAndTarget")
    func startSetsStartedAtAndTarget() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var clock = t0
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { clock })

        engine.start(seconds: 180, exerciseName: "Bench Press")

        #expect(engine.isRunning == true)
        #expect(engine.startedAt == t0)
        #expect(engine.targetSeconds == 180)
        #expect(engine.currentExerciseName == "Bench Press")
        #expect(engine.remaining == 180)

        // After 30 seconds elapse, remaining should be 150.
        clock = t0.addingTimeInterval(30)
        #expect(engine.remaining == 150)

        // After 200 seconds (overrun), remaining goes negative.
        clock = t0.addingTimeInterval(200)
        #expect(engine.remaining == -20)
    }

    @Test("startSchedulesNotificationOnce")
    func startSchedulesNotificationOnce() {
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { Date(timeIntervalSince1970: 1_000) })

        engine.start(seconds: 180, exerciseName: "Bench")

        #expect(stub.scheduleCalls.count == 1)
        #expect(stub.scheduleCalls[0].seconds == 180)
        #expect(stub.scheduleCalls[0].name == "Bench")
        #expect(stub.scheduleCalls[0].id == RestTimerEngine.notificationID)
        #expect(stub.cancelCalls.isEmpty)
    }

    @Test("plus15IncreasesTargetAndReschedulesFromOriginalStart")
    func plus15IncreasesTargetAndReschedulesFromOriginalStart() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var clock = t0
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { clock })

        engine.start(seconds: 180, exerciseName: "Squat")
        clock = t0.addingTimeInterval(30)   // 30s elapsed; 150 remaining
        engine.adjust(deltaSeconds: 15)

        // targetSeconds += 15; startedAt does NOT move.
        #expect(engine.targetSeconds == 195)
        #expect(engine.startedAt == t0)

        // remaining = 195 - 30 = 165 (NOT 195 — the start point is fixed).
        #expect(engine.remaining == 165)

        // Notification rescheduled to fire in (195 - 30) = 165s.
        #expect(stub.scheduleCalls.count == 2)
        #expect(stub.scheduleCalls[1].seconds == 165)
        #expect(stub.scheduleCalls[1].name == "Squat")
        #expect(stub.scheduleCalls[1].id == RestTimerEngine.notificationID)
    }

    @Test("minus15DecreasesTarget")
    func minus15DecreasesTarget() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var clock = t0
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { clock })

        engine.start(seconds: 90, exerciseName: "Curl")
        clock = t0.addingTimeInterval(10)  // 10s elapsed
        engine.adjust(deltaSeconds: -15)

        #expect(engine.targetSeconds == 75)
        #expect(engine.startedAt == t0)
        // remaining = 75 - 10 = 65
        #expect(engine.remaining == 65)

        // Reschedule fires in (75 - 10) = 65s.
        #expect(stub.scheduleCalls.count == 2)
        #expect(stub.scheduleCalls[1].seconds == 65)
    }

    @Test("adjustClampsTargetAtZero")
    func adjustClampsTargetAtZero() {
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { Date(timeIntervalSince1970: 1_000) })

        engine.start(seconds: 10, exerciseName: "Curl")
        engine.adjust(deltaSeconds: -30)

        #expect(engine.targetSeconds == 0)
    }

    @Test("adjustNoopWhenNotRunning")
    func adjustNoopWhenNotRunning() {
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { Date.now })

        // Engine never started — adjust must be a no-op.
        engine.adjust(deltaSeconds: 30)

        #expect(engine.isRunning == false)
        #expect(engine.targetSeconds == 0)
        #expect(stub.scheduleCalls.isEmpty)
        #expect(stub.cancelCalls.isEmpty)
    }

    @Test("stopCancelsAndResets")
    func stopCancelsAndResets() {
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { Date.now })

        engine.start(seconds: 120, exerciseName: "Row")
        engine.stop()

        #expect(engine.isRunning == false)
        #expect(engine.startedAt == nil)
        #expect(engine.targetSeconds == 0)
        #expect(engine.currentExerciseName == "")
        #expect(engine.remaining == 0)
        #expect(stub.cancelCalls == [RestTimerEngine.notificationID])
    }

    @Test("dateMathSurvivesSimulatedBackground")
    func dateMathSurvivesSimulatedBackground() {
        // The headline test for PITFALLS-doc #4 / SESS-04. Simulates the
        // "user locks phone, waits 3 minutes" scenario by mutating the
        // injected clock without sleeping. If remaining returns the wrong
        // number here, the engine has implicitly relied on a foreground
        // timer somewhere — the entire pitfall.
        let t0 = Date(timeIntervalSince1970: 1_000)
        var clock = t0
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { clock })

        engine.start(seconds: 180, exerciseName: "Bench")

        // Simulate lock + 3-minute wait. The engine's `startedAt` is fixed
        // at t0; advancing the clock to t0 + 180 → remaining = 0.
        clock = t0.addingTimeInterval(180)
        #expect(engine.remaining == 0)

        // Wait an additional 10 seconds (overrun state — user hasn't
        // tapped the next set's weight field yet).
        clock = t0.addingTimeInterval(190)
        #expect(engine.remaining == -10)

        // 5 more minutes of overrun — still computes correctly from Date math.
        clock = t0.addingTimeInterval(490)
        #expect(engine.remaining == -310)
    }

    @Test("restartReplacesPriorState")
    func restartReplacesPriorState() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var clock = t0
        let stub = StubScheduler()
        let engine = RestTimerEngine(scheduler: stub, now: { clock })

        engine.start(seconds: 120, exerciseName: "Bench")
        clock = t0.addingTimeInterval(60)
        engine.start(seconds: 180, exerciseName: "Squat")  // new set, new exercise

        #expect(engine.startedAt == t0.addingTimeInterval(60))
        #expect(engine.targetSeconds == 180)
        #expect(engine.currentExerciseName == "Squat")
        #expect(engine.remaining == 180)

        // Two schedule calls — one per start. The second uses the SAME
        // identifier as the first, so the OS-side replace-by-identifier
        // pattern keeps only one pending notification.
        #expect(stub.scheduleCalls.count == 2)
        #expect(stub.scheduleCalls[0].name == "Bench")
        #expect(stub.scheduleCalls[1].name == "Squat")
        #expect(stub.scheduleCalls[0].id == RestTimerEngine.notificationID)
        #expect(stub.scheduleCalls[1].id == RestTimerEngine.notificationID)
    }
}
