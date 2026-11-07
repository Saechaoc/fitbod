//
//  SessionEditServiceTests.swift
//  fitbodTests
//
//  History corrections: a moved workout moves whole and joins the block
//  running at its new start, one save applies all its set changes, and a
//  refused edit changes nothing.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionEditService", .serialized)
struct SessionEditServiceTests {
    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSinceReferenceDate: 30 * 86_400)

    private func finishedWorkout(on start: Date, in ctx: ModelContext) throws -> Session {
        try LoggerFixtures.session(
            exercise: LoggerFixtures.exercise("Bench", in: ctx),
            startedAt: start,
            completedAt: start.addingTimeInterval(3_600),
            sets: [(100, 5, true), (100, 5, true), (100, 5, true)],
            in: ctx
        )
    }

    private func block(from start: Date, to end: Date?, in ctx: ModelContext) -> Block {
        let block = Block()
        ctx.insert(block)
        block.startDate = start
        block.endDate = end
        block.isActive = end == nil
        return block
    }

    @Test("a moved workout moves whole and joins the block running at its new start")
    func moveShiftsWorkoutAndReassignsBlock() throws {
        let ctx = try LoggerFixtures.makeContext()
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let ended = block(from: base, to: base.addingTimeInterval(10 * day), in: ctx)
        let running = block(from: base.addingTimeInterval(10 * day), to: nil, in: ctx)
        // Saved as ready and never started: every block has a start date,
        // but one that never ran holds no workouts.
        let ready = block(from: base.addingTimeInterval(3 * day), to: nil, in: ctx)
        ready.isActive = false
        let workout = try finishedWorkout(on: base.addingTimeInterval(12 * day), in: ctx)
        workout.block = running
        let exercise = try #require(workout.exercises?.first)
        exercise.prescribedWeight = 100
        try ctx.save()
        let setTimes = SessionSetActions.ordered(exercise).map(\.completedAt)

        try SessionEditService.save(WorkoutEdit(startedAt: base.addingTimeInterval(5 * day)), to: workout, now: now, context: ctx)

        #expect(workout.startedAt == base.addingTimeInterval(5 * day))
        #expect(workout.completedAt == base.addingTimeInterval(5 * day + 3_600))
        #expect(SessionSetActions.ordered(exercise).map(\.completedAt) == setTimes.map { $0.addingTimeInterval(-7 * day) })
        #expect(workout.block?.id == ended.id)
        #expect(exercise.prescribedWeight == 100)
    }

    @Test("a move that would end after now throws and changes nothing")
    func moveIntoFutureThrows() throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-2 * day)
        let workout = try finishedWorkout(on: start, in: ctx)

        #expect(throws: SessionEditError.endsInFuture) {
            try SessionEditService.save(WorkoutEdit(startedAt: now.addingTimeInterval(-60)), to: workout, now: now, context: ctx)
        }
        #expect(workout.startedAt == start)
    }

    @Test("set changes, additions and deletions save together, in order")
    func setChangesApplyTogether() throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        let exercise = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(exercise)
        let lastLogged = sets[2].completedAt

        var edit = WorkoutEdit(startedAt: start)
        edit.changed[sets[0].id] = .init(weight: 102.5, reps: 5, rpe: 8)
        // A deleted set's leftover change is not checked: it is going away.
        edit.changed[sets[1].id] = .init(weight: 100, reps: 0, rpe: nil)
        edit.deleted = [sets[1].id]
        edit.added[exercise.id] = [.init(weight: 100, reps: 4, rpe: 9)]
        try SessionEditService.save(edit, to: workout, now: now, context: ctx)

        let saved = SessionSetActions.ordered(exercise)
        #expect(saved.map(\.weight) == [102.5, 100, 100])
        #expect(saved.map(\.reps) == [5, 5, 4])
        #expect(saved.map(\.orderIndex) == [0, 1, 2])
        let added = try #require(saved.last)
        let finishedAt = try #require(workout.completedAt)
        #expect(added.isComplete && added.rpe == 9)
        #expect(added.completedAt > lastLogged && added.completedAt <= finishedAt)
    }

    @Test("an invalid set throws and saves none of the edit")
    func invalidSetChangesNothing() throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        let sets = SessionSetActions.ordered(try #require(workout.exercises?.first))

        var edit = WorkoutEdit(startedAt: start.addingTimeInterval(-day))
        edit.changed[sets[0].id] = .init(weight: 110, reps: 5, rpe: nil)
        edit.changed[sets[1].id] = .init(weight: 100, reps: 0, rpe: nil)

        #expect(throws: SessionEditError.invalidSet) {
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        }
        #expect(workout.startedAt == start)
        #expect(sets[0].weight == 100)
    }

    @Test("unsupported weights are rejected before any correction is written", arguments: [
        10_000_000_000_000_000_000.0, Double(Int.max), Double.greatestFiniteMagnitude,
        Double.infinity, Double.nan
    ])
    func unsupportedWeightChangesNothing(weight: Double) throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        let sets = SessionSetActions.ordered(try #require(workout.exercises?.first))
        var edit = WorkoutEdit(startedAt: start.addingTimeInterval(-day))
        edit.changed[sets[0].id] = .init(weight: 110, reps: 5, rpe: 8)
        edit.changed[sets[1].id] = .init(weight: weight, reps: 5, rpe: nil)

        #expect(throws: SessionEditError.invalidSet) {
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        }
        #expect(workout.startedAt == start)
        #expect(sets.map(\.weight) == [100, 100, 100])
        #expect(sets[0].rpe == nil)
    }

    @Test("unsupported reps and set volume are rejected atomically", arguments: [
        WorkoutEdit.Values(weight: 1, reps: Int.max, rpe: nil),
        WorkoutEdit.Values(weight: 1_000_000_000_000_000_000, reps: 10, rpe: nil)
    ])
    func unsupportedSetVolumeChangesNothing(values: WorkoutEdit.Values) throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        let set = try #require(workout.exercises?.first?.sets?.first)
        var edit = WorkoutEdit(startedAt: start)
        edit.changed[set.id] = values

        #expect(throws: SessionEditError.invalidSet) {
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        }
        #expect(set.weight == 100 && set.reps == 5)
    }

    @Test("proposed exercise and workout totals must remain representable", arguments: [false, true])
    func unsupportedTotalsChangeNothing(acrossExercises: Bool) throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        let exercise = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(exercise)
        var edit = WorkoutEdit(startedAt: start)
        edit.changed[sets[0].id] = .init(weight: 6_000_000_000_000_000_000, reps: 1, rpe: nil)
        if acrossExercises {
            let second = SessionExercise()
            ctx.insert(second)
            second.session = workout
            second.exercise = LoggerFixtures.exercise("Press", in: ctx)
            try ctx.save()
            edit.added[second.id] = [.init(weight: 6_000_000_000_000_000_000, reps: 1, rpe: nil)]
        } else {
            edit.changed[sets[1].id] = .init(weight: 6_000_000_000_000_000_000, reps: 1, rpe: nil)
        }

        #expect(throws: SessionEditError.invalidSet) {
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
        }
        #expect(sets.map(\.weight) == [100, 100, 100])
        #expect((workout.exercises ?? []).flatMap { $0.sets ?? [] }.count == 3)
    }

    @Test("correction weight text round-trips in its visible locale", arguments: ["en_US", "de_DE", "ar_SA"])
    func localizedWeightRoundTrips(identifier: String) {
        let locale = Locale(identifier: identifier)
        for weight in [0.0, 7.5, 112.5, 1_234.75] {
            let text = WorkoutCorrectionInput.weightText(weight, locale: locale)
            #expect(WorkoutCorrectionInput.weight(text, locale: locale) == weight)
        }
        #expect(WorkoutCorrectionInput.weight("7,5", locale: Locale(identifier: "de_DE")) == 7.5)
        #expect(WorkoutCorrectionInput.weightText(7.5, locale: Locale(identifier: "de_DE")) == "7,5")
    }

    @Test("correction parsing rejects the entire malformed number, not just its suffix")
    func malformedWeightIsInvalid() {
        for identifier in ["en_US", "de_DE"] {
            let locale = Locale(identifier: identifier)
            for text in ["", " ", "7.5x", "7,5x", "1,2.3", "1.2,3", "nan", "NaN", "inf", "1e3", "-1", " 7", "7 ", "10000000000000000000"] {
                #expect(WorkoutCorrectionInput.weight(text, locale: locale) == nil)
            }
        }
        #expect(WorkoutCorrectionInput.weight("7,5", locale: Locale(identifier: "en_US")) == nil)
        #expect(WorkoutCorrectionInput.weight("7.5", locale: Locale(identifier: "de_DE")) == nil)
    }

    @Test("reps require a whole supported positive integer")
    func correctionRepsAreValidated() {
        #expect(WorkoutCorrectionInput.reps("7") == 7)
        for text in ["", "0", "-1", "7.5", "7,5", "7x", " 7", String(Int.max), "10000000000000000000"] {
            #expect(WorkoutCorrectionInput.reps(text) == nil)
        }
    }

    @Test("a localized correction and explicit bodyweight zero keep their numeric value")
    func localizedAndZeroWeightsSave() throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        let exercise = try #require(workout.exercises?.first)
        exercise.exercise?.equipmentRaw = Equipment.bodyweight.rawValue
        let sets = SessionSetActions.ordered(exercise)
        var edit = WorkoutEdit(startedAt: start)
        let weight = try #require(WorkoutCorrectionInput.weight("7,5", locale: Locale(identifier: "de_DE")))
        edit.changed[sets[0].id] = .init(weight: weight, reps: 5, rpe: 8)
        edit.changed[sets[1].id] = .init(weight: 0, reps: 7, rpe: nil)

        try SessionEditService.save(edit, to: workout, now: now, context: ctx)

        #expect(sets[0].weight == 7.5)
        #expect(sets[1].weight == 0 && sets[1].reps == 7)
    }

    @Test("unsupported volumes render without trapping")
    func unsupportedVolumeLabels() {
        for volume in [Double.nan, .infinity, -.infinity, -1, 1e19, Double(Int.max), .greatestFiniteMagnitude] {
            #expect(SessionHistoryFormat.roundedVolume(volume) == "—")
            #expect(SessionHistoryFormat.setsLine(count: 3, volume: volume, unit: .lb) == "3 sets · — lb")
            #expect(SessionHistoryFormat.compactTonnage(volume) == "—")
        }
        let belowBoundary = Double(Int.max).nextDown
        #expect(SessionHistoryFormat.roundedVolume(belowBoundary) != "—")
        #expect(WorkoutCorrectionInput.isSupported(belowBoundary))
    }

    @Test("ordinary volume rounding, grouping, zero omission and compact labels stay unchanged")
    func ordinaryVolumeLabels() {
        let locale = Locale(identifier: "en_US")
        #expect(SessionHistoryFormat.roundedVolume(1_500.4, locale: locale) == "1,500")
        #expect(SessionHistoryFormat.roundedVolume(1_500.5, locale: locale) == "1,501")
        #expect(SessionHistoryFormat.setsLine(count: 1, volume: 0, unit: .kg) == "1 set")
        #expect(SessionHistoryFormat.compactTonnage(4_610.4) == 4_610.formatted(.number.grouping(.automatic)))
        #expect(SessionHistoryFormat.compactTonnage(71_200) == 71.2.formatted(.number.precision(.fractionLength(1))) + "k")
    }

    @Test("an edit draft starts unchanged and saves its edits as one")
    func draftSavesItsEdits() throws {
        let ctx = try LoggerFixtures.makeContext()
        let start = now.addingTimeInterval(-day)
        let workout = try finishedWorkout(on: start, in: ctx)
        var draft = WorkoutEditDraft(session: workout)
        #expect(!draft.hasChanges)
        let exerciseID = try #require(draft.exercises.first?.id)
        let rows = try #require(draft.exercises.first?.rows)

        draft.exercises[0].rows[0].values.weight = 105
        draft.deleteRow(rows[1].id, from: exerciseID)
        draft.addSet(to: exerciseID)
        draft.startedAt = start.addingTimeInterval(-day)
        #expect(draft.hasChanges)
        try SessionEditService.save(draft.edit, to: workout, now: now, context: ctx)

        let saved = SessionSetActions.ordered(try #require(workout.exercises?.first))
        #expect(saved.map(\.weight) == [105, 100, 100])
        #expect(workout.startedAt == start.addingTimeInterval(-day))
    }

    @Test("a set typed Warm-up stays out of the edit draft, as it does the summary")
    func draftLeavesOutTypedWarmups() throws {
        let ctx = try LoggerFixtures.makeContext()
        let workout = try finishedWorkout(on: now.addingTimeInterval(-day), in: ctx)
        let exercise = try #require(workout.exercises?.first)
        let sets = SessionSetActions.ordered(exercise)
        sets[0].setTypeRaw = SetType.warmup.rawValue

        let rows = try #require(WorkoutEditDraft(session: workout).exercises.first?.rows)
        #expect(rows.map(\.id) == sets.dropFirst().map(\.id))
        #expect(SessionSummary.make(session: workout, priorSets: []).exercises.first?.workingSets == rows.count)
    }

    @Test("a correction survives closing and reopening the store")
    func correctionSurvivesReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitbod-edit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("edit.store")
        let start = now.addingTimeInterval(-3 * day)

        let (workoutID, setID) = try autoreleasepool {
            let ctx = ModelContext(try FitbodModelContainer.make(storeURL: url))
            ctx.autosaveEnabled = false
            let workout = try finishedWorkout(on: start, in: ctx)
            let exercise = try #require(workout.exercises?.first)
            let first = try #require(SessionSetActions.ordered(exercise).first)
            var edit = WorkoutEdit(startedAt: start.addingTimeInterval(-day))
            edit.changed[first.id] = .init(weight: 105, reps: 6, rpe: 8.5)
            try SessionEditService.save(edit, to: workout, now: now, context: ctx)
            return (workout.id, first.id)
        }

        try autoreleasepool {
            let ctx = ModelContext(try FitbodModelContainer.make(storeURL: url))
            let workout = try #require(try ctx.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == workoutID })).first)
            let set = try #require(try ctx.fetch(FetchDescriptor<SetEntry>(predicate: #Predicate { $0.id == setID })).first)
            #expect(workout.startedAt == start.addingTimeInterval(-day))
            #expect(set.weight == 105 && set.reps == 6 && set.rpe == 8.5)
        }
    }
}
