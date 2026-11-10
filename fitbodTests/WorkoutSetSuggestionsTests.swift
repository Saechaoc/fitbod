import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Workout set suggestions")
struct WorkoutSetSuggestionsTests {
    @Test("An empty workout uses completed sets and saves offers only on completion")
    func emptyWorkout() throws {
        let ctx = try LoggerFixtures.makeContext()
        let lift = LoggerFixtures.exercise("Bench", in: ctx)
        guard case .started(let workout) = WorkoutStarter.startEmpty(context: ctx) else {
            Issue.record("The empty workout did not start")
            return
        }
        AddUnplannedExerciseButton.append(exercise: lift, to: workout, context: ctx)
        let log = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(log)
        let first = sets[0]
        let second = sets[1]
        #expect(offers(log)[first.id] == WorkoutSetSuggestion())
        #expect(!SessionSetActions.canComplete(first, suggestion: offers(log)[first.id] ?? .init()))

        first.weight = 70
        first.reps = 10
        first.rpe = 8
        #expect(offers(log)[second.id] == WorkoutSetSuggestion(), "A draft is not performance")
        #expect(try SessionSetActions.complete(first, context: ctx))
        #expect(offers(log)[second.id] == WorkoutSetSuggestion(weight: 70, reps: 10))
        #expect(second.weight == 0 && second.reps == 0 && second.rpe == nil)

        second.reps = 8
        let offer = try #require(offers(log)[second.id])
        #expect(try SessionSetActions.complete(second, suggestion: offer, context: ctx))
        #expect(second.weight == 70 && second.reps == 8 && second.rpe == nil)
        #expect(offers(log)[sets[2].id] == WorkoutSetSuggestion(weight: 70, reps: 8))
    }

    @Test("An empty workout reuses the corresponding sets from matching-intent history")
    func previousWorkoutScheme() throws {
        let ctx = try LoggerFixtures.makeContext()
        let lift = LoggerFixtures.exercise("Bench", in: ctx)
        let now = Date.now
        try LoggerFixtures.session(
            exercise: lift, startedAt: now - 7200, completedAt: now - 6000,
            sets: [(100, 9, true), (90, 10, true)], in: ctx
        )
        let other = try LoggerFixtures.session(
            exercise: lift, startedAt: now - 3600, completedAt: now - 1800,
            sets: [(140, 6, true)], in: ctx
        )
        other.intentRaw = Intent.hypertrophy.rawValue
        try ctx.save()
        guard case .started(let workout) = WorkoutStarter.startEmpty(context: ctx, now: now) else {
            Issue.record("The empty workout did not start")
            return
        }
        AddUnplannedExerciseButton.append(exercise: lift, to: workout, context: ctx)
        let log = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(log)
        let prescription = SessionFactory.prescription(
            for: lift, targetRepsLow: 8, targetRepsHigh: 12, targetRPE: nil,
            in: workout, strategy: DoubleProgressionStrategy(), userSettings: nil, context: ctx
        )
        let suggestions = offers(log, prior: prescription.previousWorkingSets)
        #expect(suggestions[sets[0].id] == WorkoutSetSuggestion(weight: 100, reps: 9))
        #expect(suggestions[sets[1].id] == WorkoutSetSuggestion(weight: 90, reps: 10))
        #expect(suggestions[sets[2].id] == WorkoutSetSuggestion(weight: 90, reps: 10))
    }

    @Test("Double progression adds a rep at the same load, holds at high effort, and resets after a load increase")
    func progressionUsesTheProgramRange() throws {
        let ctx = try LoggerFixtures.makeContext()
        let lift = LoggerFixtures.exercise("Bench", in: ctx)
        let last = try LoggerFixtures.session(
            exercise: lift, startedAt: .now - 7200, completedAt: .now - 3600,
            sets: [(100, 8, true)], in: ctx
        )
        let prior = try #require(last.exercises?.first?.sets?.first)
        let template = try LoggerFixtures.template(
            "Push", exercises: [lift], sets: 2, repsLow: 6, repsHigh: 10, rest: 120, in: ctx
        )
        let workout = try SessionFactory.start(template: template, context: ctx)
        let log = try #require(workout.exercises?.first)
        let first = try #require(SessionSetActions.ordered(log).first(where: { !$0.isWarmup }))

        #expect(offers(log, prior: [prior])[first.id] == WorkoutSetSuggestion(weight: 100, reps: 9))
        prior.rpe = 10
        #expect(offers(log, prior: [prior])[first.id]?.reps == 8)
        log.prescribedWeight = 105
        #expect(offers(log, prior: [prior])[first.id] == WorkoutSetSuggestion(weight: 105, reps: 6))

        workout.progressionKindRaw = ProgressionKind.rpe.rawValue
        #expect(offers(log, prior: [prior])[first.id] == WorkoutSetSuggestion(weight: 105, reps: 10))
        first.weight = 102.5
        #expect(offers(log, prior: [prior])[first.id]?.reps == 10)
        workout.progressionKindRaw = ProgressionKind.hybrid.rawValue
        #expect(offers(log, prior: [prior])[first.id]?.reps == 10)
        first.weight = 0
        log.prescribedWeight = nil
        #expect(offers(log)[first.id]?.reps == 10)
        first.weight = 95
        first.reps = 4
        #expect(try SessionSetActions.complete(first, context: ctx))
        let second = try #require(SessionSetActions.ordered(log).last)
        #expect(offers(log, prior: [prior])[second.id] == WorkoutSetSuggestion(weight: 95, reps: 4))
    }

    @Test("Programmed block targets survive a different current set and leave typed inputs alone")
    func blockPlanTakesPriority() throws {
        let ctx = try LoggerFixtures.makeContext()
        let lift = LoggerFixtures.exercise("Bench", in: ctx)
        let workout = try LoggerFixtures.session(
            exercise: lift, startedAt: .now, completedAt: nil,
            sets: [(100, 7, true), (0, 0, false)], in: ctx
        )
        let block = Block()
        ctx.insert(block)
        workout.block = block
        workout.sourceRoutineID = UUID()
        workout.progressionKindRaw = ProgressionKind.block.rawValue
        let log = try #require(workout.exercises?.first)
        log.prescribedWeight = 120
        log.targetRepsLow = 6
        log.targetRepsHigh = 8
        let second = SessionSetActions.ordered(log)[1]
        #expect(offers(log)[second.id] == WorkoutSetSuggestion(weight: 120, reps: 6))
        second.weight = 105
        second.reps = 9
        let suggestion = try #require(offers(log)[second.id])
        #expect(suggestion.weight(for: second) == 105)
        #expect(suggestion.reps(for: second) == 9)
    }

    @Test("Warm-ups and special sets do not become working set offers")
    func ordinaryWorkingEvidence() throws {
        let ctx = try LoggerFixtures.makeContext()
        let lift = LoggerFixtures.exercise("Bench", in: ctx)
        let workout = try LoggerFixtures.session(
            exercise: lift, startedAt: .now, completedAt: nil,
            sets: [(100, 6, true), (40, 12, true), (50, 10, true), (0, 0, false)], in: ctx
        )
        let log = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(log)
        sets[1].setTypeRaw = SetType.drop.rawValue
        sets[2].setTypeRaw = SetType.warmup.rawValue
        #expect(offers(log)[sets[3].id] == WorkoutSetSuggestion(weight: 100, reps: 6))
    }

    @Test("Reopening a logged bodyweight set keeps its zero added load")
    func zeroAddedLoadSurvivesUndo() throws {
        let ctx = try LoggerFixtures.makeContext()
        let lift = LoggerFixtures.exercise("Dip", in: ctx)
        lift.equipmentRaw = Equipment.weightedBodyweight.rawValue
        let workout = try LoggerFixtures.session(
            exercise: lift, startedAt: .now, completedAt: nil,
            sets: [(0, 8, true)], in: ctx
        )
        let set = try #require(workout.exercises?.first?.sets?.first)
        SessionSetActions.uncomplete(set, context: ctx)
        #expect(!set.isComplete)
        #expect(WorkoutSetSuggestion(weight: 10, reps: 6).weight(for: set) == 0)
        #expect(set.reps == 8)
    }

    private func offers(_ exercise: SessionExercise, prior: [SetEntry] = []) -> [UUID: WorkoutSetSuggestion] {
        WorkoutSetSuggestions(exercise: exercise, prior: prior).offers()
    }
}
