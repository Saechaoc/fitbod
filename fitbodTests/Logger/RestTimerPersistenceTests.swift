//
//  RestTimerPersistenceTests.swift
//  fitbodTests
//
//  The rest timer is persisted as a deadline keyed by session id. These
//  tests simulate an app relaunch by building a FRESH engine over the SAME
//  store with the clock moved forward, and check that the countdown, the
//  pending notification and the Live Activity all follow the stored
//  deadline.
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("RestTimerPersistence", .serialized)
struct RestTimerPersistenceTests {

    final class RecordingScheduler: RestTimerNotificationScheduling {
        var scheduled: [Int] = []
        var cancelled = 0
        func schedule(in seconds: Int, exerciseName: String, identifier: String) { scheduled.append(seconds) }
        func cancel(identifier: String) { cancelled += 1 }
    }

    final class RecordingActivity: RestTimerActivityControlling {
        var starts = 0
        var resumes: [(Date, Int)] = []
        var updates: [Int] = []
        var ends = 0
        func start(startedAt: Date, targetSeconds: Int, exerciseName: String) { starts += 1 }
        func update(startedAt: Date, targetSeconds: Int) { updates.append(targetSeconds) }
        func end() { ends += 1 }
        func resume(startedAt: Date, targetSeconds: Int, exerciseName: String) {
            resumes.append((startedAt, targetSeconds))
        }
    }

    final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private let sessionID = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func engine(
        store: RestTimerStore,
        clock: Clock,
        scheduler: RecordingScheduler? = nil,
        activity: RecordingActivity? = nil
    ) -> RestTimerEngine {
        RestTimerEngine(
            scheduler: scheduler ?? RecordingScheduler(),
            activityController: activity ?? RecordingActivity(),
            store: store,
            now: { clock.now }
        )
    }

    @Test("start persists the absolute deadline for the session")
    func startPersistsDeadline() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let e = engine(store: store, clock: clock)
        e.bind(sessionID: sessionID)
        e.start(seconds: 180, exerciseName: "Bench")

        let snap = store.load(sessionID: sessionID)
        #expect(snap?.endsAt == t0.addingTimeInterval(180))
        #expect(snap?.targetSeconds == 180)
        #expect(snap?.exerciseName == "Bench")
    }

    @Test("relaunch mid-rest resumes from the remaining time and re-arms side effects")
    func relaunchMidRestResumes() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let first = engine(store: store, clock: clock)
        first.bind(sessionID: sessionID)
        first.start(seconds: 180, exerciseName: "Bench")

        // App killed; relaunched 70 seconds later.
        clock.now = t0.addingTimeInterval(70)
        let scheduler = RecordingScheduler()
        let activity = RecordingActivity()
        let second = engine(store: store, clock: clock, scheduler: scheduler, activity: activity)
        second.bind(sessionID: sessionID)

        #expect(second.isRunning)
        #expect(!second.isFinished)
        #expect(second.remaining == 110)
        #expect(second.currentExerciseName == "Bench")
        #expect(scheduler.scheduled == [110])
        #expect(activity.resumes.count == 1)
        #expect(activity.resumes.first?.1 == 180)
        #expect(store.load(sessionID: sessionID) != nil)
    }

    @Test("relaunch after the deadline shows finished and clears everything")
    func relaunchAfterDeadlineFinishesAndClears() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let first = engine(store: store, clock: clock)
        first.bind(sessionID: sessionID)
        first.start(seconds: 90, exerciseName: "Row")

        clock.now = t0.addingTimeInterval(300)
        let scheduler = RecordingScheduler()
        let activity = RecordingActivity()
        let second = engine(store: store, clock: clock, scheduler: scheduler, activity: activity)
        second.bind(sessionID: sessionID)

        #expect(second.isRunning)
        #expect(second.isFinished)
        #expect(store.load(sessionID: sessionID) == nil)
        #expect(scheduler.cancelled == 1)
        #expect(scheduler.scheduled.isEmpty)
        #expect(activity.ends == 1)

        // A second foreground restore must not wipe the finished display.
        second.restore()
        #expect(second.isFinished)
    }

    @Test("adjust moves the stored deadline; a fresh engine sees the new one")
    func adjustMovesStoredDeadline() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let e = engine(store: store, clock: clock)
        e.bind(sessionID: sessionID)
        e.start(seconds: 120, exerciseName: "Squat")
        clock.now = t0.addingTimeInterval(20)
        e.adjust(deltaSeconds: 15)
        e.adjust(deltaSeconds: 15)
        e.adjust(deltaSeconds: -15)

        #expect(store.load(sessionID: sessionID)?.endsAt == t0.addingTimeInterval(135))

        clock.now = t0.addingTimeInterval(100)
        let relaunched = engine(store: store, clock: clock)
        relaunched.bind(sessionID: sessionID)
        #expect(relaunched.remaining == 35)
        #expect(relaunched.targetSeconds == 135)
    }

    @Test("adjust below elapsed time cancels the alert instead of firing in 1s")
    func adjustIntoThePastCancels() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let scheduler = RecordingScheduler()
        let e = engine(store: store, clock: clock, scheduler: scheduler)
        e.bind(sessionID: sessionID)
        e.start(seconds: 60, exerciseName: "Curl")
        clock.now = t0.addingTimeInterval(50)
        e.adjust(deltaSeconds: -15)

        #expect(e.isFinished)
        #expect(scheduler.scheduled == [60])
        #expect(scheduler.cancelled == 1)
    }

    @Test("skip clears the stored deadline so a relaunch shows nothing")
    func skipClears() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let e = engine(store: store, clock: clock)
        e.bind(sessionID: sessionID)
        e.start(seconds: 120, exerciseName: "Press")
        e.stop()

        #expect(store.load(sessionID: sessionID) == nil)
        let relaunched = engine(store: store, clock: clock)
        relaunched.bind(sessionID: sessionID)
        #expect(!relaunched.isRunning)
    }

    @Test("restore while already in sync does not reschedule")
    func restoreIsIdempotent() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let scheduler = RecordingScheduler()
        let activity = RecordingActivity()
        let e = engine(store: store, clock: clock, scheduler: scheduler, activity: activity)
        e.bind(sessionID: sessionID)
        e.start(seconds: 120, exerciseName: "Press")
        clock.now = t0.addingTimeInterval(30)
        e.restore()
        e.restore()

        #expect(scheduler.scheduled == [120])
        #expect(activity.resumes.isEmpty)
        #expect(e.remaining == 90)
    }

    @Test("timers are keyed by session id")
    func keyedBySession() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let e = engine(store: store, clock: clock)
        e.bind(sessionID: sessionID)
        e.start(seconds: 120, exerciseName: "Press")

        let other = engine(store: store, clock: clock)
        other.bind(sessionID: UUID())
        #expect(!other.isRunning)
    }

    @Test("clearPersisted removes the deadline and tears down side effects")
    func clearPersistedFromOutsideLogger() {
        let store = InMemoryRestTimerStore()
        let clock = Clock(t0)
        let e = engine(store: store, clock: clock)
        e.bind(sessionID: sessionID)
        e.start(seconds: 120, exerciseName: "Press")

        let scheduler = RecordingScheduler()
        let activity = RecordingActivity()
        RestTimerEngine.clearPersisted(
            sessionID: sessionID,
            store: store,
            scheduler: scheduler,
            activityController: activity
        )
        #expect(store.load(sessionID: sessionID) == nil)
        #expect(scheduler.cancelled == 1)
        #expect(activity.ends == 1)
    }

    @Test("UserDefaults store round-trips a snapshot")
    func userDefaultsRoundTrip() throws {
        let suite = "RestTimerPersistenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsRestTimerStore(defaults: defaults)
        let snap = RestTimerSnapshot(
            startedAt: t0,
            endsAt: t0.addingTimeInterval(150),
            targetSeconds: 150,
            exerciseName: "Bench"
        )
        store.save(snap, sessionID: sessionID)

        let reopened = UserDefaultsRestTimerStore(defaults: defaults)
        #expect(reopened.load(sessionID: sessionID) == snap)
        reopened.clear(sessionID: sessionID)
        #expect(store.load(sessionID: sessionID) == nil)
    }
}
