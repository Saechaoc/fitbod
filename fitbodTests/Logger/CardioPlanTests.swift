//
//  CardioPlanTests.swift
//  fitbodTests
//
//  Cardio is one bout with a plan, and no sets or rest (RM-062, 2026-11-11):
//    - a workout start copies a routine row's plan and makes a cardio row
//      one bout, whatever sets the row stores;
//    - the plan's values are the bout's offers, before last time's;
//    - Done saves a treadmill's offered speed and incline, and a failed
//      save leaves the bout as typed;
//    - a swap to cardio keeps one pending row;
//    - a treadmill set reads its speed, incline and worked-out distance,
//      and a stair machine's level reads as its speed;
//    - a plan reads in one line, and a session's estimate, Today's session
//      list and History count its time and no sets;
//    - a finished workout's set totals leave its bouts out;
//    - so do a workout in progress's resume banner and slab and its Finish
//      sheet, and the discard and remove warnings name a bout as a bout;
//    - a cardio exercise's history and recent performance count bouts.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Cardio plan", .serialized)
struct CardioPlanTests {
    private let now = Date(timeIntervalSinceReferenceDate: 30 * 86_400)
    /// 3.5 mph in km/h, as a treadmill's speed is stored.
    private let mph35 = 3.5 * 1.609344

    private func cardio(_ name: String, tracking: Tracking, in ctx: ModelContext) -> Exercise {
        let exercise = Exercise.previewSample(name: name, equipment: .cardioMachine, mechanic: .compound)
        exercise.category = "cardio"
        exercise.trackingRaw = tracking.rawValue
        ctx.insert(exercise)
        return exercise
    }

    @Test("a workout start copies the plan and makes a cardio row one bout")
    func startCopiesPlanAndMakesOneBout() throws {
        let ctx = try LoggerFixtures.makeContext()
        let treadmill = cardio("Treadmill", tracking: .durationSpeedIncline, in: ctx)
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let template = try LoggerFixtures.template("Cardio", exercises: [treadmill, bench], sets: 3, in: ctx)
        let row = try #require(template.exercises?.first { $0.exercise?.id == treadmill.id })
        row.targetDurationSeconds = 1_800
        row.targetSpeedKmh = mph35
        row.targetIncline = 12
        try ctx.save()

        let workout = try SessionFactory.start(template: template, on: now, context: ctx)

        let logged = try #require(workout.exercises?.first { $0.exercise?.id == treadmill.id })
        #expect(logged.targetDurationSeconds == 1_800 && logged.targetSpeedKmh == mph35 && logged.targetIncline == 12)
        #expect(logged.targetLevel == nil)
        #expect(SessionSetActions.ordered(logged).filter { !$0.isWarmup }.count == 1)
        let lift = try #require(workout.exercises?.first { $0.exercise?.id == bench.id })
        #expect(SessionSetActions.ordered(lift).filter { !$0.isWarmup }.count == 3)
        // History names the cardio line's bouts, not sets.
        let lines = SessionSummary.make(session: workout, priorSets: []).exercises
        #expect(lines.map(\.name) == ["Treadmill", "Bench"] && lines.map(\.isCardio) == [true, false])
    }

    @Test("the plan's values are the bout's offers, before last time's")
    func planIsTheOffer() throws {
        let ctx = try LoggerFixtures.makeContext()
        let climber = cardio("Stair Climber", tracking: .durationStepSpeed, in: ctx)
        let last = try LoggerFixtures.session(
            exercise: climber, startedAt: now.addingTimeInterval(-86_400), completedAt: now.addingTimeInterval(-84_000),
            sets: [(0, 0, true)], in: ctx
        )
        let lastBout = try #require(last.exercises?.first?.sets?.first)
        lastBout.durationSeconds = 900
        lastBout.level = 6
        let today = try LoggerFixtures.session(
            exercise: climber, startedAt: now, completedAt: nil, sets: [(0, 0, false)], in: ctx
        )
        let current = try #require(today.exercises?.first)
        let bout = try #require(current.sets?.first)
        try ctx.save()
        func offer(prior: [SetEntry] = [lastBout]) -> WorkoutSetSuggestion? {
            WorkoutSetSuggestions(exercise: current, prior: prior).offers()[bout.id]
        }

        // No plan: last time's bout.
        #expect(offer() == WorkoutSetSuggestion(durationSeconds: 900, level: 6))
        // A planned time alone keeps last time's speed.
        current.targetDurationSeconds = 1_200
        #expect(offer() == WorkoutSetSuggestion(durationSeconds: 1_200, level: 6))
        current.targetLevel = 8
        #expect(offer() == WorkoutSetSuggestion(durationSeconds: 1_200, level: 8))
        // With no last time, the plan alone.
        #expect(offer(prior: []) == WorkoutSetSuggestion(durationSeconds: 1_200, level: 8))
        // Nothing planned and nothing logged: no offer.
        current.targetDurationSeconds = nil
        current.targetLevel = nil
        #expect(offer(prior: []) == nil)

        // A treadmill's plan offers its speed and incline.
        let treadmill = cardio("Treadmill", tracking: .durationSpeedIncline, in: ctx)
        let run = try LoggerFixtures.session(
            exercise: treadmill, startedAt: now, completedAt: nil, sets: [(0, 0, false)], in: ctx
        )
        let runLog = try #require(run.exercises?.first)
        runLog.targetDurationSeconds = 1_800
        runLog.targetSpeedKmh = mph35
        runLog.targetIncline = 12
        let runBout = try #require(runLog.sets?.first)
        #expect(WorkoutSetSuggestions(exercise: runLog, prior: []).offers()[runBout.id]
                == WorkoutSetSuggestion(durationSeconds: 1_800, speedKmh: mph35, incline: 12))
    }

    @Test("Done saves a treadmill's offered speed and incline; a failed save leaves the bout as typed")
    func completeTreadmillBout() throws {
        struct Failure: Error {}
        let ctx = try LoggerFixtures.makeContext()
        let treadmill = cardio("Treadmill", tracking: .durationSpeedIncline, in: ctx)
        let workout = try LoggerFixtures.session(
            exercise: treadmill, startedAt: now, completedAt: nil, sets: [(0, 0, false), (0, 0, false)], in: ctx
        )
        let bouts = SessionSetActions.ordered(try #require(workout.exercises?.first))
        let offer = WorkoutSetSuggestion(durationSeconds: 1_800, speedKmh: mph35, incline: 12)

        bouts[1].incline = 10
        #expect(throws: Failure.self) {
            try SessionSetActions.complete(bouts[1], suggestion: offer, context: ctx) { _ in throw Failure() }
        }
        #expect(!bouts[1].isComplete && bouts[1].durationSeconds == nil)
        #expect(bouts[1].speedKmh == nil && bouts[1].incline == 10)

        #expect(try SessionSetActions.complete(bouts[0], at: now, suggestion: offer, context: ctx))
        #expect(bouts[0].isComplete && bouts[0].durationSeconds == 1_800)
        #expect(bouts[0].speedKmh == mph35 && bouts[0].incline == 12)
    }

    @Test("a swap to cardio keeps one pending row, and the lift keeps its finished set")
    func swapToCardioKeepsOneBout() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let climber = cardio("Stair Climber", tracking: .durationStepSpeed, in: ctx)
        let workout = try LoggerFixtures.session(
            exercise: bench, startedAt: now, completedAt: nil,
            sets: [(100, 5, true), (0, 0, false), (0, 0, false)], in: ctx
        )
        let current = try #require(workout.exercises?.first)

        #expect(SwapExerciseSheet.swap(current, to: climber, context: ctx))

        let rows = SessionSetActions.ordered(current)
        #expect(rows.count == 1 && !rows[0].isComplete && rows[0].orderIndex == 0)
        let benchLog = try #require(workout.exercises?.first { $0.exercise?.id == bench.id })
        #expect(SessionSetActions.ordered(benchLog).map(\.weight) == [100])
    }

    @Test("a treadmill set reads its speed, incline and worked-out distance; a stair machine's level is its speed")
    func cardioText() {
        #expect(SetText.speed(mph35, unit: .lb) == "3.5")
        #expect(SetText.speed(mph35, unit: .kg) == "5.63")
        #expect(SetText.kmh(fromTyped: "3.5", unit: .lb, locale: Locale(identifier: "en_US")) == mph35)
        #expect(SetText.kmh(fromTyped: "8,5", unit: .kg, locale: Locale(identifier: "de_DE")) == 8.5)
        #expect(SetText.kmh(fromTyped: "fast", unit: .kg, locale: Locale(identifier: "en_US")) == nil)

        func text(distance: Double? = nil, level: Double? = nil, speed: Double? = nil, incline: Double? = nil,
                  seconds: Int = 1_800, tracking: Tracking? = nil, unit: WeightUnit = .lb, compact: Bool = false) -> String {
            SetText.result(
                weight: 0, reps: 0, durationSeconds: seconds, distanceMeters: distance, level: level,
                speedKmh: speed, incline: incline, tracking: tracking, unit: unit, compact: compact
            )
        }
        #expect(text(speed: mph35, incline: 12) == "30:00 · 3.5 mph · 12% incline · ~1.75 mi")
        #expect(text(speed: mph35, incline: 12, compact: true) == "30:00 3.5mph 12%")
        // A logged distance wins over the worked-out one.
        #expect(text(distance: 3_000, speed: mph35, unit: .kg) == "30:00 · 3 km · 5.63 km/h")
        #expect(text(level: 8, seconds: 1_200, tracking: .durationStepSpeed) == "20:00 · speed 8")
        #expect(text(level: 8, seconds: 1_200, tracking: .durationStepSpeed, compact: true) == "20:00 spd8")
        #expect(text(level: 8, seconds: 1_200, tracking: .durationLevel) == "20:00 · level 8")
        #expect(text(level: 8, seconds: 1_200) == "20:00 · level 8", "A set whose exercise is gone keeps the word level")
    }

    @Test("a plan reads in one line; a session's estimate and Today's list count its time and no sets")
    func planTextAndEstimate() throws {
        let ctx = try LoggerFixtures.makeContext()
        let treadmill = cardio("Treadmill", tracking: .durationSpeedIncline, in: ctx)
        let climber = cardio("Stair Climber", tracking: .durationStepSpeed, in: ctx)
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let template = try LoggerFixtures.template(
            "Mixed", exercises: [treadmill, climber, bench], sets: 3, rest: 120, in: ctx
        )
        let rows = (template.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        rows[0].targetDurationSeconds = 1_800
        rows[0].targetSpeedKmh = mph35
        rows[0].targetIncline = 12
        rows[1].targetDurationSeconds = 1_230
        rows[1].targetLevel = 8

        #expect(rows[0].planText(tracking: treadmill.tracking, unit: .lb) == "30 min · 3.5 mph · 12% incline")
        #expect(rows[1].planText(tracking: climber.tracking, unit: .lb) == "20:30 · speed 8")
        #expect(rows[2].planText(tracking: bench.tracking, unit: .lb) == nil)

        let summary = SessionTemplateSummary(template: template)
        #expect(summary.exerciseCount == 3)
        #expect(summary.workingSets == 3, "Cardio counts no sets")
        #expect(rows.map { $0.workingSetCount(phase: nil) } == [0, 0, 3])
        #expect(SessionSheet.summary(of: template, phase: nil) == "3 exercises · 3 sets")
        // 30:00 and 20:30 of cardio, then three sets of 2:00 rest and 0:40 work.
        let seconds = 1_800 + 1_230 + 3 * (120 + SessionTemplateSummary.workSecondsPerSet)
        #expect(summary.estimatedMinutes == Int((Double(seconds) / 60).rounded()))
    }

    @Test("a finished workout's set totals leave its cardio bouts out")
    func setTotalsLeaveOutBouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let climber = cardio("Stair Climber", tracking: .durationStepSpeed, in: ctx)
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let template = try LoggerFixtures.template("Mixed", exercises: [climber, bench], sets: 3, in: ctx)
        let workout = try SessionFactory.start(template: template, on: now, context: ctx)
        for log in workout.exercises ?? [] {
            for set in SessionSetActions.ordered(log) where !set.isWarmup {
                if log.exercise?.id == climber.id {
                    set.durationSeconds = 1_200
                    set.level = 8
                } else {
                    set.weight = 100
                    set.reps = 5
                }
                set.isComplete = true
                set.completedAt = now
            }
        }
        workout.completedAt = now.addingTimeInterval(3_600)
        try ctx.save()

        let summary = SessionSummary.make(session: workout, priorSets: [])
        #expect(summary.exercises.map(\.workingSets) == [1, 3], "The climber's line counts its one bout")
        #expect(summary.workingSetCount == 3)
        #expect(TodayWeek.workingSets(in: workout) == 3)
        #expect(SessionHistoryFormat.setCount(of: workout) == 3)
        #expect(DoneTodaySlab.caption(for: workout, prCount: 0) == "3 sets")
        #expect(workout.loggedSetCount == 4, "A bout still counts as logged work")

        // Cardio alone shows its time and no set count.
        let cardioDay = try LoggerFixtures.session(
            exercise: climber, startedAt: now, completedAt: now.addingTimeInterval(1_500), sets: [(0, 0, true)], in: ctx
        )
        cardioDay.totalDurationSeconds = 1_500
        #expect(DoneTodaySlab.caption(for: cardioDay, prCount: 0) == "25M")
        #expect(cardioDay.loggedSetCount == 1, "A workout of one bout is not empty")
    }

    @Test("a workout in progress counts its sets and no bouts on each surface; warnings name the bout")
    func inProgressCountsLeaveOutBouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let climber = cardio("Stair Climber", tracking: .durationStepSpeed, in: ctx)
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let template = try LoggerFixtures.template("Mixed", exercises: [climber, bench], sets: 3, in: ctx)
        let workout = try SessionFactory.start(template: template, on: now, context: ctx)
        let boutLog = try #require(workout.exercises?.first { $0.exercise?.id == climber.id })
        let liftLog = try #require(workout.exercises?.first { $0.exercise?.id == bench.id })
        func expectSurfaces(
            of session: Session, count: Int?, banner: String, slab: String?, finish: String, discard: String?,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(SessionHistoryFormat.inProgressSetCount(of: session) == count, sourceLocation: sourceLocation)
            #expect(ResumeWorkoutBanner.caption(for: session, elapsed: "5:00") == banner, sourceLocation: sourceLocation)
            #expect(ResumeWorkoutSlab.loggedCaption(for: session) == slab, sourceLocation: sourceLocation)
            #expect(SessionLoggerView.finishCaption(for: session, elapsed: "5:00") == finish, sourceLocation: sourceLocation)
            #expect(SessionHistoryFormat.discardWarning(for: session) == discard, sourceLocation: sourceLocation)
        }

        // Nothing logged: "0 sets" says why Finish offers Discard workout.
        expectSurfaces(
            of: workout, count: 0, banner: "5:00 · 0 sets", slab: "0 sets logged", finish: "0 sets logged · 5:00",
            discard: nil
        )

        // The bout alone shows no set count, yet the workout logged something.
        let bout = try #require(SessionSetActions.ordered(boutLog).first)
        bout.durationSeconds = 1_200
        bout.level = 8
        bout.isComplete = true
        expectSurfaces(
            of: workout, count: nil, banner: "5:00", slab: nil, finish: "5:00",
            discard: "1 logged bout will be deleted."
        )
        #expect(workout.loggedSetCount == 1, "Finish, not Discard workout, and a discard asks first")
        #expect(SessionLoggerView.removeWarning(for: boutLog) == "1 logged bout will be removed with it.")
        #expect(SessionLoggerView.removeWarning(for: liftLog) == "Nothing is logged for it yet.")

        // Two bench sets as well: the counts are the sets, and the warning names both.
        for set in SessionSetActions.ordered(liftLog).filter({ !$0.isWarmup }).prefix(2) {
            set.weight = 100
            set.reps = 5
            set.isComplete = true
        }
        expectSurfaces(
            of: workout, count: 2, banner: "5:00 · 2 sets", slab: "2 sets logged", finish: "2 sets logged · 5:00",
            discard: "2 logged sets and 1 bout will be deleted."
        )
        #expect(SessionLoggerView.removeWarning(for: liftLog) == "2 logged sets will be removed with it.")

        // Lifts alone read as before.
        let liftsOnly = try LoggerFixtures.session(
            exercise: bench, startedAt: now, completedAt: nil, sets: [(100, 5, true), (0, 0, false)], in: ctx
        )
        expectSurfaces(
            of: liftsOnly, count: 1, banner: "5:00 · 1 set", slab: "1 set logged", finish: "1 set logged · 5:00",
            discard: "1 logged set will be deleted."
        )
    }

    @Test("a cardio exercise's history and recent performance count bouts; a lift's count sets")
    func exerciseHistoryCountsBouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let climber = cardio("Stair Climber", tracking: .durationStepSpeed, in: ctx)
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let climb = try LoggerFixtures.session(
            exercise: climber, startedAt: now, completedAt: now.addingTimeInterval(1_500), sets: [(0, 0, true)], in: ctx
        )
        let bout = try #require(climb.exercises?.first?.sets?.first)
        bout.durationSeconds = 1_200
        bout.level = 8
        let lift = try LoggerFixtures.session(
            exercise: bench, startedAt: now, completedAt: now.addingTimeInterval(1_500),
            sets: [(100, 5, true), (100, 5, true)], in: ctx
        )
        func historyRows(_ workout: Session) -> [String] {
            let shown = ExerciseHistoryView.completedSets(from: workout.exercises ?? [], intent: nil)
            return ExerciseHistoryView.rows(from: shown, prSetIDs: []).map(\.countLabel)
        }

        #expect(ExerciseHistoryView.countLine(1, across: 1, of: climber) == "1 bout across 1 workout")
        #expect(historyRows(climb) == ["1 bout"])
        #expect(RecentPerformanceList.entries(from: climb.exercises ?? []).map(\.countLabel) == ["1 bout"])
        // Lifts read as before.
        #expect(ExerciseHistoryView.countLine(2, across: 1, of: bench) == "2 sets across 1 workout")
        #expect(historyRows(lift) == ["2 sets"])
        #expect(RecentPerformanceList.entries(from: lift.exercises ?? []).map(\.countLabel) == ["2 working sets"])
    }

    @Test("the routine editor's draft reads the plan from its row")
    func planRoundTripsThroughTheDraft() throws {
        let ctx = try LoggerFixtures.makeContext()
        let climber = cardio("Stair Climber", tracking: .durationStepSpeed, in: ctx)
        let template = try LoggerFixtures.template("Cardio", exercises: [climber], sets: 1, in: ctx)
        let row = try #require(template.exercises?.first)
        row.targetDurationSeconds = 1_200
        row.targetLevel = 8

        let draft = RoutineExerciseDraft(re: row)
        #expect(draft.targetDurationSeconds == 1_200 && draft.targetLevel == 8)
        #expect(draft.planText(tracking: climber.tracking, unit: .lb) == "20 min · speed 8")
        // Cardio alone has no sets to count.
        #expect(SessionTemplateSummary(template: template).line == "1 exercise · ~20 min")
        #expect(SessionSheet.summary(of: template, phase: nil) == "1 exercise")
    }
}
