//
//  ExerciseStoreAndDemoDataTests.swift
//  fitbodTests
//
//  Milestone 1:
//    - `ExerciseStore.delete` (custom exercise delete): logged workouts keep
//      their sets with the exercise reference cleared, routines drop the
//      line and renumber, the delete confirmation's usage counts are right.
//    - `DemoData` (opt-in `-seed-demo-history`): builds finished history
//      from whatever library exists and never runs twice or over real data.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("ExerciseStore + DemoData (milestone 1)", .serialized)
struct ExerciseStoreAndDemoDataTests {

    @Test("deleting a custom exercise keeps history, removes routine lines, renumbers")
    func deleteCustomExercise() throws {
        let context = ModelContext(try InMemoryContainer.makeCurrent())
        let custom = Exercise.previewSample(name: "Zercher Good Morning", equipment: .barbell, mechanic: .compound, isCustom: true)
        let squat = Exercise.previewSample(name: "Barbell Squat", equipment: .barbell, mechanic: .compound)
        let curl = Exercise.previewSample(name: "Lying Leg Curls", equipment: .machine, mechanic: .isolation)
        [custom, squat, curl].forEach { context.insert($0) }

        let routine = Routine()
        routine.name = "Lower A"
        context.insert(routine)
        for (index, exercise) in [squat, custom, curl].enumerated() {
            let line = RoutineExercise()
            line.routine = routine
            line.exercise = exercise
            line.orderIndex = index
            context.insert(line)
        }

        let session = Session()
        session.routineSnapshotName = "Lower A"
        session.completedAt = .now
        context.insert(session)
        let logged = SessionExercise()
        logged.session = session
        logged.exercise = custom
        context.insert(logged)
        let set = SetEntry()
        set.sessionExercise = logged
        set.weight = 135
        set.reps = 8
        set.isComplete = true
        context.insert(set)
        try context.save()

        #expect(ExerciseStore.usage(of: custom, context: context) == ExerciseStore.Usage(loggedSessions: 1, routines: 1))

        ExerciseStore.delete(custom, context: context)

        let lines = try context.fetch(FetchDescriptor<RoutineExercise>(sortBy: [SortDescriptor(\.orderIndex)]))
        #expect(lines.map { $0.exercise?.name } == ["Barbell Squat", "Lying Leg Curls"])
        #expect(lines.map(\.orderIndex) == [0, 1])

        let history = try context.fetch(FetchDescriptor<SessionExercise>())
        #expect(history.count == 1)
        #expect(history.first?.exercise == nil)
        #expect(try context.fetch(FetchDescriptor<SetEntry>()).first?.weight == 135)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 2)
    }

    @Test("demo history: finished workouts with climbing weights, seeded once")
    func demoDataSeedsOnce() throws {
        let context = ModelContext(PreviewModelContainer.make())
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(DemoData.seedIfNeeded(in: context, now: now))

        // The preview fixture only has bench + row, so only the upper
        // routine resolves — and only those two lines.
        let routines = try context.fetch(FetchDescriptor<Routine>())
        #expect(routines.map(\.name) == [DemoData.upper.name])
        #expect((routines.first?.exercises ?? []).count == 2)

        let sessions = try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)]))
        #expect(sessions.count == 6)
        #expect(sessions.allSatisfy { $0.completedAt != nil && ($0.totalDurationSeconds ?? 0) > 0 })
        #expect(sessions.allSatisfy { $0.startedAt < now })
        #expect(try context.fetch(FetchDescriptor<SetEntry>()).allSatisfy { $0.isComplete })

        let benchWeights = sessions.compactMap { session in
            (session.exercises ?? []).first { $0.exercise?.name == "Barbell Bench Press" }
                .flatMap { WorkoutLogging.workingSets(of: $0).first?.weight }
        }
        #expect(benchWeights.first == 205)
        #expect(benchWeights.last == 215)

        // Never twice, never over existing data.
        #expect(DemoData.seedIfNeeded(in: context, now: now) == false)
        #expect(try context.fetch(FetchDescriptor<Session>()).count == 6)
    }

    @Test("demo history needs a library")
    func demoDataWithoutLibrary() throws {
        let context = ModelContext(try InMemoryContainer.makeCurrent())
        #expect(DemoData.seedIfNeeded(in: context) == false)
        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
    }
}
