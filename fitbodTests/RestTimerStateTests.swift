import Foundation
import Observation
import Testing
@testable import fitbod

@MainActor
@Suite("Rest timer state", .serialized)
struct RestTimerStateTests {
    @Test("A nonpositive rest starts at one second", arguments: [0, -30])
    func startClampsToOneSecond(seconds: Int) {
        let start = Date(timeIntervalSince1970: 1_000)
        let scheduler = RestTimerEngineTests.StubScheduler()
        let engine = RestTimerEngine(scheduler: scheduler, now: { start })

        engine.start(seconds: seconds, exerciseName: "Bench")

        #expect(engine.startedAt == start)
        #expect(engine.targetSeconds == 1)
        #expect(engine.currentExerciseName == "Bench")
        #expect(engine.endsAt == start.addingTimeInterval(1))
        #expect(engine.remaining == 1)
        #expect(!engine.isFinished)
        #expect(scheduler.scheduleCalls.map(\.seconds) == [1])
    }

    @Test("Restore derives duration from the deadline and preserves scheduling precision")
    func restoreUsesDeadlineInsteadOfStoredDuration() throws {
        let suite = "RestTimerStateTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsRestTimerStore(defaults: defaults)
        let sessionID = UUID()
        let start = Date(timeIntervalSince1970: 1_000)
        let snapshot = RestTimerSnapshot(
            startedAt: start, endsAt: start.addingTimeInterval(120.4),
            targetSeconds: 999, exerciseName: "Squat"
        )
        store.save(snapshot, sessionID: sessionID)
        let scheduler = RestTimerEngineTests.StubScheduler()
        let activity = RestTimerPersistenceTests.RecordingActivity()
        let engine = RestTimerEngine(
            scheduler: scheduler, activityController: activity, store: store,
            now: { start.addingTimeInterval(10.1) }
        )

        engine.bind(sessionID: sessionID)

        #expect(engine.startedAt == start)
        #expect(engine.targetSeconds == 120)
        #expect(engine.currentExerciseName == "Squat")
        #expect(engine.endsAt == start.addingTimeInterval(120))
        #expect(abs(engine.remaining - 109.9) < 0.001)
        #expect(scheduler.scheduleCalls.map(\.seconds) == [111])
        #expect(activity.resumes.first?.0 == start)
        #expect(activity.resumes.first?.1 == 120)
        #expect(store.load(sessionID: sessionID) == snapshot)

        engine.adjust(deltaSeconds: 15)

        #expect(store.load(sessionID: sessionID) == RestTimerSnapshot(
            startedAt: start, endsAt: start.addingTimeInterval(135),
            targetSeconds: 135, exerciseName: "Squat"
        ))
    }

    @Test("Public timer fields remain observable")
    func publicFieldsTrackChanges() async {
        let engine = RestTimerEngine(scheduler: RestTimerEngineTests.StubScheduler())

        await confirmation(expectedCount: 3) { changed in
            withObservationTracking { _ = engine.startedAt } onChange: { changed() }
            engine.start(seconds: 120, exerciseName: "Bench")

            withObservationTracking { _ = engine.targetSeconds } onChange: { changed() }
            engine.adjust(deltaSeconds: 15)

            withObservationTracking { _ = engine.currentExerciseName } onChange: { changed() }
            engine.stop()
        }
    }
}
