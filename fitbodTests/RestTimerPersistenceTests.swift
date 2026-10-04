//
//  RestTimerPersistenceTests.swift
//  fitbodTests
//
//  Milestone 1 — the rest timer survives backgrounding, eviction and a full
//  relaunch because it is persisted as an absolute moment
//  (`startedAt + targetSeconds`) and every reading is derived from the
//  clock, never from a ticking counter.
//
//  "Relaunch" is simulated by building a second engine over the same store
//  with a later clock — exactly what `RestTimerEngine.makeProduction()`
//  does at launch (`UserDefaultsRestTimerStore` + `restore()`).
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("RestTimerPersistence (milestone 1)")
struct RestTimerPersistenceTests {

    /// Mutable test clock.
    final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeEngine(store: RestTimerPersisting, clock: Clock) -> RestTimerEngine {
        RestTimerEngine(
            scheduler: NoopNotificationScheduler(),
            store: store,
            now: { clock.now }
        )
    }

    @Test("start persists the absolute deadline; a relaunched engine shows the same remaining time")
    func restoreAfterRelaunch() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let sessionID = UUID()

        let first = makeEngine(store: store, clock: clock)
        first.start(seconds: 180, exerciseName: "Barbell Squat", sessionID: sessionID)
        #expect(store.snapshot?.deadline == t0.addingTimeInterval(180))
        #expect(store.snapshot?.sessionID == sessionID)

        // App killed; relaunched 70 s later.
        clock.now = t0.addingTimeInterval(70)
        let second = makeEngine(store: store, clock: clock)
        #expect(second.isRunning == false)
        second.restore()
        #expect(second.isRunning)
        #expect(second.remaining == 110)
        #expect(second.deadline == t0.addingTimeInterval(180))
        #expect(second.currentExerciseName == "Barbell Squat")
        #expect(second.sessionID == sessionID)
    }

    @Test("time keeps running while the app is away — restore past the deadline shows overtime, not a reset")
    func backgroundingDoesNotReset() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        makeEngine(store: store, clock: clock).start(seconds: 90, exerciseName: "Bench", sessionID: nil)

        clock.now = t0.addingTimeInterval(90 + 25)
        let engine = makeEngine(store: store, clock: clock)
        engine.restore()
        #expect(engine.isRunning)
        #expect(engine.isOvertime)
        #expect(engine.remaining == -25)
        #expect(engine.progress == 1)
        #expect(RestTimerText.clock(engine.remaining) == "+0:25")
    }

    @Test("a timer that ended long ago is dropped on restore")
    func staleTimerIsDiscarded() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        makeEngine(store: store, clock: clock).start(seconds: 120, exerciseName: "Row", sessionID: nil)

        clock.now = t0.addingTimeInterval(120 + 16 * 60)
        let engine = makeEngine(store: store, clock: clock)
        engine.restore()
        #expect(engine.isRunning == false)
        #expect(store.snapshot == nil)
    }

    @Test("±15 s and presets persist and keep the original start")
    func adjustmentsPersist() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let engine = makeEngine(store: store, clock: clock)
        engine.start(seconds: 180, exerciseName: "Bench", sessionID: nil)

        clock.now = t0.addingTimeInterval(30)
        engine.adjust(deltaSeconds: 15)
        #expect(store.snapshot?.targetSeconds == 195)
        #expect(store.snapshot?.startedAt == t0)
        #expect(engine.remaining == 165)

        engine.setTarget(seconds: 120)
        #expect(store.snapshot?.targetSeconds == 120)
        #expect(engine.remaining == 90)

        // Relaunch sees the adjusted target.
        let relaunched = makeEngine(store: store, clock: clock)
        relaunched.restore()
        #expect(relaunched.targetSeconds == 120)
        #expect(relaunched.remaining == 90)
    }

    @Test("stop clears the persisted timer")
    func stopClearsSnapshot() {
        let store = InMemoryRestTimerStore()
        let engine = makeEngine(store: store, clock: Clock(t0))
        engine.start(seconds: 60, exerciseName: "Curl", sessionID: UUID())
        #expect(store.snapshot != nil)
        engine.stop()
        #expect(store.snapshot == nil)
        #expect(engine.sessionID == nil)
    }

    @Test("stop(ifBelongsTo:) only stops the workout's own timer")
    func stopIfBelongsTo() {
        let store = InMemoryRestTimerStore()
        let engine = makeEngine(store: store, clock: Clock(t0))
        let mine = UUID()
        engine.start(seconds: 60, exerciseName: "Curl", sessionID: mine)

        engine.stop(ifBelongsTo: UUID())
        #expect(engine.isRunning)

        engine.stop(ifBelongsTo: mine)
        #expect(engine.isRunning == false)
        #expect(store.snapshot == nil)
    }

    @Test("UserDefaults store round-trips the snapshot and clears it")
    func userDefaultsStoreRoundTrip() throws {
        let suite = "fitbod.tests.rest-timer.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserDefaultsRestTimerStore(defaults: defaults)
        #expect(store.load() == nil)

        let snapshot = RestTimerSnapshot(startedAt: t0, targetSeconds: 150, exerciseName: "Weighted Pull Ups", sessionID: UUID())
        store.save(snapshot)
        // A second store over the same defaults (i.e. after relaunch).
        #expect(UserDefaultsRestTimerStore(defaults: defaults).load() == snapshot)

        store.save(nil)
        #expect(store.load() == nil)
        #expect(defaults.data(forKey: UserDefaultsRestTimerStore.key) == nil)
    }
}
