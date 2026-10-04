//
//  WorkoutLogicTests.swift
//  fitbodTests
//
//  Milestone 1 — the rules behind the active-workout screen
//  (`WorkoutLogic.swift`), exercised against an in-memory container on the
//  current schema:
//
//    - set validation (reps required; weight required unless bodyweight)
//    - completing / adding / deleting sets persists immediately
//    - previous performance never reads the workout in progress
//    - finishing keeps only performed work; discarding deletes everything
//    - totals, recap deltas and the 1RM estimate
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WorkoutLogic (milestone 1)", .serialized)
struct WorkoutLogicTests {

    // MARK: - Fixture

    private struct Fixture {
        let context: ModelContext
        let routine: Routine
        let bench: Exercise
        let pullup: Exercise
    }

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeFixture() throws -> Fixture {
        let context = ModelContext(try InMemoryContainer.makeCurrent())
        let bench = Exercise.previewSample(name: "Barbell Bench Press", equipment: .barbell, mechanic: .compound, primaryMuscleSlugs: ["chest"])
        let pullup = Exercise.previewSample(name: "Pullups", equipment: .bodyweight, mechanic: .compound, primaryMuscleSlugs: ["lats"])
        context.insert(bench)
        context.insert(pullup)

        let routine = Routine()
        routine.name = "Upper A"
        context.insert(routine)
        for (index, exercise) in [bench, pullup].enumerated() {
            let line = RoutineExercise()
            line.routine = routine
            line.exercise = exercise
            line.orderIndex = index
            line.intentRaw = Intent.strength.rawValue
            line.targetSets = 3
            line.targetRepsLow = 5
            line.targetRepsHigh = 8
            line.prescribedRestSeconds = 150
            context.insert(line)
        }
        try context.save()
        return Fixture(context: context, routine: routine, bench: bench, pullup: pullup)
    }

    private func exercise(_ session: Session, named name: String) throws -> SessionExercise {
        try #require((session.exercises ?? []).first { $0.exercise?.name == name })
    }

    /// A finished session for `exercise` with the given completed sets.
    @discardableResult
    private func logPastSession(
        _ fx: Fixture,
        exercise: Exercise,
        daysAgo: Double,
        sets: [(Double, Int)]
    ) -> Session {
        let session = Session()
        session.startedAt = start.addingTimeInterval(-daysAgo * 86_400)
        session.completedAt = session.startedAt.addingTimeInterval(3_600)
        session.routineSnapshotName = "Upper A"
        fx.context.insert(session)
        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.intentRaw = Intent.strength.rawValue
        fx.context.insert(se)
        for (index, set) in sets.enumerated() {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = index
            entry.weight = set.0
            entry.reps = set.1
            entry.isComplete = true
            fx.context.insert(entry)
        }
        try? fx.context.save()
        return session
    }

    // MARK: - Validation

    @Test("reps are always required; weight only for loaded lifts")
    func validation() {
        let entry = SetEntry()
        #expect(WorkoutLogging.validate(entry, equipment: .barbell) == .missingReps)

        entry.reps = 5
        #expect(WorkoutLogging.validate(entry, equipment: .barbell) == .missingWeight)
        #expect(WorkoutLogging.validate(entry, equipment: .bodyweight) == .ok)

        entry.weight = -20 // assisted
        #expect(WorkoutLogging.validate(entry, equipment: .weightedBodyweight) == .ok)
        #expect(WorkoutLogging.validate(entry, equipment: .dumbbell) == .missingWeight)

        entry.weight = 185
        #expect(WorkoutLogging.validate(entry, equipment: .barbell) == .ok)

        #expect(SetValidation.missingReps.message(setLabel: "2") == "Enter reps to complete set 2.")
        #expect(SetValidation.missingWeight.message(setLabel: "W1") == "Enter a weight to complete set W1.")
        #expect(SetValidation.ok.message(setLabel: "1") == nil)
    }

    @Test("complete only marks valid sets, stamps the time and saves")
    func completeIsValidatedAndSaved() throws {
        let fx = try makeFixture()
        let session = try SessionFactory.start(routine: fx.routine, on: start, context: fx.context)
        let set = try #require(WorkoutLogging.workingSets(of: exercise(session, named: "Barbell Bench Press")).first)

        set.weight = 185
        #expect(WorkoutLogging.complete(set, equipment: .barbell, context: fx.context) == .missingReps)
        #expect(set.isComplete == false)

        set.reps = 5
        let doneAt = start.addingTimeInterval(240)
        #expect(WorkoutLogging.complete(set, equipment: .barbell, context: fx.context, now: doneAt) == .ok)
        #expect(set.isComplete)
        #expect(set.completedAt == doneAt)
        #expect(fx.context.hasChanges == false)

        WorkoutLogging.uncomplete(set, context: fx.context)
        #expect(set.isComplete == false)
        #expect(set.weight == 185 && set.reps == 5)
    }

    @Test("add set copies the last working weight; delete removes it")
    func addAndDeleteSets() throws {
        let fx = try makeFixture()
        let session = try SessionFactory.start(routine: fx.routine, on: start, context: fx.context)
        let bench = try exercise(session, named: "Barbell Bench Press")
        let working = WorkoutLogging.workingSets(of: bench)
        #expect(working.count == 3)
        working.last?.weight = 195

        let added = WorkoutLogging.addSet(to: bench, context: fx.context)
        #expect(added.weight == 195)
        #expect(added.reps == 0)
        #expect(added.isComplete == false)
        #expect(added.orderIndex == (working.map(\.orderIndex).max() ?? 0) + 1)
        #expect(WorkoutLogging.workingSets(of: bench).count == 4)

        WorkoutLogging.delete(added, context: fx.context)
        #expect(WorkoutLogging.workingSets(of: bench).count == 3)
    }

    // MARK: - Previous performance

    @Test("previous performance comes from the last earlier workout, never the one in progress")
    func previousExcludesCurrentWorkout() throws {
        let fx = try makeFixture()
        logPastSession(fx, exercise: fx.bench, daysAgo: 9, sets: [(175, 5), (175, 5)])
        logPastSession(fx, exercise: fx.bench, daysAgo: 4, sets: [(185, 5), (185, 5), (190, 4)])

        let session = try SessionFactory.start(routine: fx.routine, on: start, context: fx.context)
        let bench = try exercise(session, named: "Barbell Bench Press")
        let first = try #require(WorkoutLogging.workingSets(of: bench).first)
        first.weight = 200
        first.reps = 3
        WorkoutLogging.complete(first, equipment: .barbell, context: fx.context)

        let previous = try #require(PreviousPerformance.lookup(
            exerciseID: fx.bench.id,
            intentRaw: Intent.strength.rawValue,
            excludingSessionID: session.id,
            context: fx.context
        ))
        #expect(previous.lines.map(\.weight) == [185, 185, 190])
        #expect(previous.line(forSetIndex: 0) == PreviousPerformance.Line(weight: 185, reps: 5, rpe: nil))
        #expect(previous.line(forSetIndex: 3) == nil)
        #expect(previous.topLine?.weight == 190)

        // Without the exclusion the workout in progress would win — the
        // bug the old top-set query had once a set was committed.
        let unscoped = PreviousPerformance.lookup(
            exerciseID: fx.bench.id,
            intentRaw: Intent.strength.rawValue,
            excludingSessionID: nil,
            context: fx.context
        )
        #expect(unscoped?.lines.first?.weight == 200)

        // Different intent → nothing.
        #expect(PreviousPerformance.lookup(
            exerciseID: fx.bench.id,
            intentRaw: Intent.hypertrophy.rawValue,
            excludingSessionID: session.id,
            context: fx.context
        ) == nil)
    }

    // MARK: - Finish / discard

    @Test("finish keeps only performed work and stamps the duration")
    func finishPrunesUnperformedWork() throws {
        let fx = try makeFixture()
        let session = try SessionFactory.start(routine: fx.routine, on: start, context: fx.context)
        let bench = try exercise(session, named: "Barbell Bench Press")
        for set in WorkoutLogging.workingSets(of: bench).prefix(2) {
            set.weight = 185
            set.reps = 5
            WorkoutLogging.complete(set, equipment: .barbell, context: fx.context)
        }
        #expect(WorkoutFinisher.completedSetCount(in: session) == 2)
        #expect(WorkoutFinisher.unfinishedSetCount(in: session) == 4)

        let outcome = WorkoutFinisher.finish(session, context: fx.context, now: start.addingTimeInterval(3_725))
        #expect(outcome == WorkoutFinisher.Outcome(removedUnfinishedSets: 4, removedEmptyExercises: 1))
        #expect(session.completedAt == start.addingTimeInterval(3_725))
        #expect(session.totalDurationSeconds == 3_725)

        let remaining = try fx.context.fetch(FetchDescriptor<SessionExercise>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.exercise?.name == "Barbell Bench Press")
        let sets = try fx.context.fetch(FetchDescriptor<SetEntry>())
        #expect(sets.count == 2)
        #expect(sets.allSatisfy(\.isComplete))
        #expect(SessionFactory.active(in: fx.context) == nil)

        let stats = WorkoutStats.compute(for: session)
        #expect(stats.completedSets == 2)
        #expect(stats.totalReps == 10)
        #expect(stats.volume == 1_850)
        #expect(stats.durationSeconds == 3_725)
    }

    @Test("discard deletes the workout; the routine is untouched")
    func discardDeletesWorkout() throws {
        let fx = try makeFixture()
        let session = try SessionFactory.start(routine: fx.routine, on: start, context: fx.context)
        WorkoutFinisher.discard(session, context: fx.context)

        #expect(try fx.context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try fx.context.fetch(FetchDescriptor<SetEntry>()).isEmpty)
        #expect((fx.routine.exercises ?? []).count == 2)
    }

    @Test("an unplanned exercise is appended after the planned ones")
    func addExerciseAppends() throws {
        let fx = try makeFixture()
        let session = try SessionFactory.start(routine: fx.routine, on: start, context: fx.context)
        let curl = Exercise.previewSample(name: "Hammer Curls", equipment: .dumbbell, mechanic: .isolation)
        fx.context.insert(curl)

        let added = WorkoutLogging.addExercise(curl, to: session, context: fx.context)
        #expect(added.orderIndex == 2)
        #expect(added.intentRaw == Intent.hypertrophy.rawValue)
        #expect(added.prescribedRestSeconds == 90)
        #expect((added.sets ?? []).count == 3)
        #expect((fx.routine.exercises ?? []).count == 2)
    }

    // MARK: - Recap + 1RM

    @Test("recap delta compares best sets")
    func recapDelta() {
        typealias Line = PreviousPerformance.Line
        #expect(ExerciseRecap.delta(best: Line(weight: 185, reps: 5, rpe: nil), previousBest: nil) == .firstTime)
        #expect(ExerciseRecap.delta(best: Line(weight: 190, reps: 5, rpe: nil), previousBest: Line(weight: 185, reps: 5, rpe: nil)) == .heavier(5))
        #expect(ExerciseRecap.delta(best: Line(weight: 180, reps: 8, rpe: nil), previousBest: Line(weight: 185, reps: 5, rpe: nil)) == .lighter(5))
        #expect(ExerciseRecap.delta(best: Line(weight: 185, reps: 7, rpe: nil), previousBest: Line(weight: 185, reps: 5, rpe: nil)) == .moreReps(2))
        #expect(ExerciseRecap.delta(best: Line(weight: 185, reps: 4, rpe: nil), previousBest: Line(weight: 185, reps: 5, rpe: nil)) == .fewerReps(1))
        #expect(ExerciseRecap.delta(best: Line(weight: 185, reps: 5, rpe: nil), previousBest: Line(weight: 185, reps: 5, rpe: nil)) == .same)
    }

    @Test("summary recap reports the gain over the previous session")
    func recapAgainstHistory() throws {
        let fx = try makeFixture()
        logPastSession(fx, exercise: fx.bench, daysAgo: 4, sets: [(185, 5), (185, 5)])
        let session = try SessionFactory.start(routine: fx.routine, on: start, context: fx.context)
        let bench = try exercise(session, named: "Barbell Bench Press")
        let set = try #require(WorkoutLogging.workingSets(of: bench).first)
        set.weight = 190
        set.reps = 5
        WorkoutLogging.complete(set, equipment: .barbell, context: fx.context)
        WorkoutFinisher.finish(session, context: fx.context, now: start.addingTimeInterval(1_800))

        let recaps = ExerciseRecap.build(for: session, context: fx.context)
        #expect(recaps.count == 1)
        #expect(recaps.first?.delta == .heavier(5))
        #expect(recaps.first?.best == PreviousPerformance.Line(weight: 190, reps: 5, rpe: nil))
    }

    @Test("Epley estimate, capped at 12 reps")
    func oneRepMax() {
        #expect(OneRepMax.epley(weight: 100, reps: 1) == 100)
        #expect(abs((OneRepMax.epley(weight: 100, reps: 10) ?? 0) - 133.333) < 0.01)
        #expect(OneRepMax.epley(weight: 100, reps: 13) == nil)
        #expect(OneRepMax.epley(weight: 0, reps: 5) == nil)
    }
}
