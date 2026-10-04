//
//  WorkoutPersistenceTests.swift
//  fitbodTests
//
//  Milestone 1 — the two data guarantees of the workout journey:
//
//    1. Workouts are snapshots. Renaming a routine, changing its
//       prescription, removing its exercises or deleting it never rewrites
//       a logged workout.
//    2. Data survives relaunch. An in-progress workout (typed values,
//       completed sets) and a finished one are read back intact by a
//       brand-new ModelContainer opened on the same on-disk store — the
//       same thing the app does on every launch. (The XCUITest journey
//       covers the UI half: terminate, relaunch, the workout reopens.)
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WorkoutPersistence (milestone 1)", .serialized)
struct WorkoutPersistenceTests {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Inserts a two-exercise routine and returns it.
    @discardableResult
    private func insertRoutine(into context: ModelContext) throws -> Routine {
        let squat = Exercise.previewSample(name: "Barbell Squat", equipment: .barbell, mechanic: .compound, primaryMuscleSlugs: ["quadriceps"])
        let curl = Exercise.previewSample(name: "Lying Leg Curls", equipment: .machine, mechanic: .isolation, primaryMuscleSlugs: ["hamstrings"])
        context.insert(squat)
        context.insert(curl)
        let routine = Routine()
        routine.name = "Lower A"
        context.insert(routine)
        for (index, exercise) in [squat, curl].enumerated() {
            let line = RoutineExercise()
            line.routine = routine
            line.exercise = exercise
            line.orderIndex = index
            line.intentRaw = (index == 0 ? Intent.strength : Intent.hypertrophy).rawValue
            line.targetSets = 3
            line.targetRepsLow = index == 0 ? 4 : 10
            line.targetRepsHigh = index == 0 ? 6 : 12
            line.targetRPE = index == 0 ? 8 : nil
            line.prescribedRestSeconds = index == 0 ? 210 : 90
            context.insert(line)
        }
        try context.save()
        return routine
    }

    // MARK: - Snapshots

    @Test("editing or deleting the routine never rewrites a logged workout")
    func routineEditsNeverRewriteHistory() throws {
        let context = ModelContext(try InMemoryContainer.makeCurrent())
        let routine = try insertRoutine(into: context)

        let session = try SessionFactory.start(routine: routine, on: start, context: context)
        let squat = try #require((session.exercises ?? []).first { $0.orderIndex == 0 })
        for set in WorkoutLogging.workingSets(of: squat) {
            set.weight = 275
            set.reps = 5
            WorkoutLogging.complete(set, equipment: .barbell, context: context)
        }
        WorkoutFinisher.finish(session, context: context, now: start.addingTimeInterval(3_000))

        // Edit everything about the routine.
        routine.name = "Lower B — Deadlift"
        for line in routine.exercises ?? [] {
            line.targetSets = 5
            line.targetRepsLow = 1
            line.targetRepsHigh = 3
            line.prescribedRestSeconds = 300
            line.intentRaw = Intent.power.rawValue
        }
        if let curlLine = (routine.exercises ?? []).first(where: { $0.orderIndex == 1 }) {
            context.delete(curlLine)
        }
        try context.save()

        #expect(session.routineSnapshotName == "Lower A")
        #expect(session.sourceRoutineID == routine.id)
        #expect(squat.targetSets == 3)
        #expect(squat.targetRepsLow == 4)
        #expect(squat.targetRepsHigh == 6)
        #expect(squat.targetRPE == 8)
        #expect(squat.prescribedRestSeconds == 210)
        #expect(squat.intentRaw == Intent.strength.rawValue)
        #expect(WorkoutLogging.workingSets(of: squat).map(\.weight) == [275, 275, 275])

        // Deleting the routine keeps the workout in History.
        RoutineStore.delete(routine, context: context)
        let finished = try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.completedAt != nil }))
        #expect(finished.count == 1)
        #expect(finished.first?.routineSnapshotName == "Lower A")
        #expect(try context.fetch(FetchDescriptor<SetEntry>()).count == 3)
    }

    // MARK: - Relaunch

    /// Opens the production schema + migration plan on an on-disk store,
    /// exactly like `fitbodApp.init()`.
    private func openStore(at url: URL) throws -> ModelContainer {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, migrationPlan: FitbodSchemaMigrationPlan.self, configurations: config)
    }

    private func makeStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbod-relaunch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("default.store")
    }

    /// First "launch": start a workout, complete one set, type into the
    /// next without completing it. Returns the session id.
    private func firstLaunch(storeURL: URL) throws -> UUID {
        let container = try openStore(at: storeURL)
        let context = ModelContext(container)
        let routine = try insertRoutine(into: context)
        let session = try SessionFactory.start(routine: routine, on: start, context: context)
        let squat = try #require((session.exercises ?? []).first { $0.orderIndex == 0 })
        let sets = WorkoutLogging.workingSets(of: squat)
        sets[0].weight = 275
        sets[0].reps = 5
        sets[0].rpe = 8
        WorkoutLogging.complete(sets[0], equipment: .barbell, context: context, now: start.addingTimeInterval(300))
        sets[1].weight = 280          // typed, not completed
        try context.save()
        return session.id
    }

    @Test("an in-progress workout reopens intact from disk, then finishes and stays in history")
    func workoutSurvivesRelaunch() throws {
        let storeURL = try makeStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let sessionID = try firstLaunch(storeURL: storeURL)

        // Second launch: a brand-new container on the same file.
        let relaunched = try openStore(at: storeURL)
        let context = ModelContext(relaunched)
        let active = try #require(SessionFactory.active(in: context))
        #expect(active.id == sessionID)
        #expect(active.routineSnapshotName == "Lower A")
        let squat = try #require((active.exercises ?? []).first { $0.orderIndex == 0 })
        let sets = WorkoutLogging.workingSets(of: squat)
        #expect(sets.count == 3)
        #expect(sets[0].isComplete)
        #expect(sets[0].weight == 275 && sets[0].reps == 5 && sets[0].rpe == 8)
        #expect(sets[0].completedAt == start.addingTimeInterval(300))
        #expect(sets[1].isComplete == false)
        #expect(sets[1].weight == 280)

        // Finish on the second launch.
        sets[1].reps = 4
        WorkoutLogging.complete(sets[1], equipment: .barbell, context: context)
        WorkoutFinisher.finish(active, context: context, now: start.addingTimeInterval(3_600))

        // Third launch: History reads the finished workout.
        let third = ModelContext(try openStore(at: storeURL))
        #expect(SessionFactory.active(in: third) == nil)
        let history = try third.fetch(FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        ))
        #expect(history.count == 1)
        #expect(history.first?.id == sessionID)
        let finished = try #require(history.first)
        let stats = WorkoutStats.compute(for: finished)
        #expect(stats.completedSets == 2)
        #expect(stats.volume == 275 * 5 + 280 * 4)
    }
}
