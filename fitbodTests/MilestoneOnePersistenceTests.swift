import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("MilestoneOneDiskPersistence", .serialized)
struct MilestoneOnePersistenceTests {
    @Test("Bodyweight sets complete with zero added load and preserve previous reps")
    func bodyweightCompletionAndPreviousPerformance() throws {
        for equipment in [Equipment.bodyweight, .weightedBodyweight] {
            let context = try LoggerFixtures.makeContext()
            let exercise = LoggerFixtures.exercise("Push-Up", in: context)
            exercise.equipmentRaw = equipment.rawValue
            let workout = try LoggerFixtures.session(
                exercise: exercise, startedAt: .now, completedAt: nil,
                sets: [(0, 12, false)], in: context
            )
            let item = try #require(workout.exercises?.first)
            let entry = try #require(item.sets?.first)
            #expect(SessionSetActions.canComplete(entry))
            #expect(SessionSetActions.complete(entry, context: context))
            workout.completedAt = .now
            try context.save()
            let prior = PreviousMatchingIntent.fetchTopWorkingSet(
                exerciseID: exercise.id, intentRaw: workout.intentRaw, context: context
            )
            #expect(prior?.weight == 0)
            #expect(prior?.reps == 12)
            let summary = SessionSummary.make(session: workout, priorSets: [])
            #expect(summary.workingSetCount == 1)
            #expect(summary.totalVolume == 0)
        }
    }

    @Test("Loaded exercises reject empty, negative and non-finite weights")
    func invalidLoadedSetCompletion() throws {
        let context = try LoggerFixtures.makeContext()
        let exercise = LoggerFixtures.exercise("Bench", in: context)
        let workout = try LoggerFixtures.session(
            exercise: exercise, startedAt: .now, completedAt: nil,
            sets: [(0, 8, false)], in: context
        )
        let entry = try #require(workout.exercises?.first?.sets?.first)
        for weight in [0, -10, Double.nan, .infinity] {
            entry.weight = weight
            #expect(!SessionSetActions.canComplete(entry))
        }
        entry.weight = 80
        entry.reps = 0
        #expect(!SessionSetActions.canComplete(entry))
        entry.reps = 8
        #expect(SessionSetActions.canComplete(entry))
    }

    @Test("A workout survives store close/reopen and later template edits keep its snapshot")
    func persistedWorkoutJourney() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbod-m1-disk-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("workout.store")

        // Release the entire first container/context before reading the SQLite store.
        let sessionID = try autoreleasepool {
            let container = try FitbodModelContainer.make(storeURL: url)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let exercise = LoggerFixtures.exercise("Cambered Bar Bench Press", in: context)
            exercise.isCustom = true
            let template = try LoggerFixtures.template("Push A", exercises: [exercise], in: context)
            let workout = try SessionFactory.start(template: template, context: context)
            let loggedExercise = try #require(workout.exercises?.first)
            let firstSet = try #require(SessionSetActions.ordered(loggedExercise).first(where: { !$0.isWarmup }))
            firstSet.weight = 80
            firstSet.reps = 8
            #expect(SessionSetActions.complete(firstSet, context: context))
            let added = SessionSetActions.addSet(to: loggedExercise, context: context)
            added.weight = 82.5
            added.reps = 6
            try context.save()
            return workout.id
        }

        try autoreleasepool {
            let reopened = try FitbodModelContainer.make(storeURL: url)
            let context = ModelContext(reopened)
            context.autosaveEnabled = false
            let workout = try #require(try context.fetch(FetchDescriptor<Session>(
                predicate: #Predicate { $0.id == sessionID }
            )).first)
            #expect(workout.completedAt == nil)
            #expect(workout.routineSnapshotName == "Push A")
            let exercise = try #require(workout.exercises?.first)
            #expect(exercise.displayName == "Cambered Bar Bench Press")
            let sets = SessionSetActions.ordered(exercise).filter { !$0.isWarmup }
            #expect(sets.count == 4)
            #expect(sets.first?.isComplete == true)
            #expect(sets.first?.weight == 80)
            #expect(sets.first?.reps == 8)
            #expect(sets.last?.weight == 82.5)
            #expect(sets.last?.reps == 6)
            #expect(sets.last?.isComplete == false)

            // Finish and change all upstream authoring records before closing again.
            workout.completedAt = .now
            workout.template?.name = "Renamed session"
            let prescription = try #require(workout.template?.exercises?.first)
            prescription.targetSets = 5
            prescription.targetRepsLow = 12
            prescription.targetRepsHigh = 15
            prescription.prescribedRestSeconds = 45
            exercise.exercise?.name = "Renamed custom exercise"
            try context.save()
        }

        try autoreleasepool {
            let reopened = try FitbodModelContainer.make(storeURL: url)
            let context = ModelContext(reopened)
            let history = try context.fetch(FetchDescriptor<Session>(
                predicate: #Predicate { $0.completedAt != nil }
            ))
            #expect(history.count == 1)
            let workout = try #require(history.first)
            #expect(workout.id == sessionID)
            #expect(workout.templateName == "Push A")
            #expect(workout.routineSnapshotName == "Push A")
            let exercise = try #require(workout.exercises?.first)
            #expect(exercise.displayName == "Cambered Bar Bench Press")
            #expect(exercise.targetSets == 3)
            #expect(exercise.targetRepsLow == 5)
            #expect(exercise.targetRepsHigh == 8)
            #expect(exercise.prescribedRestSeconds == 180)
            let summary = SessionSummary.make(session: workout, priorSets: [])
            #expect(summary.exercises.first?.name == "Cambered Bar Bench Press")
            #expect(summary.workingSetCount == 1)
            #expect(summary.totalVolume == 640)
        }
    }
}
