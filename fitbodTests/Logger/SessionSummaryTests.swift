//
//  SessionSummaryTests.swift
//  fitbodTests
//
//  SessionSummary is the roll-up behind SessionDetailView (post-Finish
//  summary and history detail): totals, per-exercise best set, PRs.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionSummary", .serialized)
struct SessionSummaryTests {

    private let day: TimeInterval = 24 * 3600

    @Test("summary totals, best set and PRs against prior history")
    func summaryRollup() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let past = Date.now.addingTimeInterval(-7 * day)
        try LoggerFixtures.session(exercise: bench, startedAt: past, completedAt: past.addingTimeInterval(3600),
                                   sets: [(100, 5, true)], in: ctx)
        let start = Date.now.addingTimeInterval(-3600)
        let today = try LoggerFixtures.session(exercise: bench, startedAt: start, completedAt: .now,
                                               sets: [(100, 5, true), (110, 5, true), (120, 5, false)], in: ctx)
        today.totalDurationSeconds = 3600
        let warmup = SetEntry()
        ctx.insert(warmup)
        warmup.sessionExercise = today.exercises?.first
        warmup.isWarmup = true
        warmup.isComplete = true
        warmup.weight = 60
        warmup.reps = 5
        try ctx.save()

        let summary = SessionSummary.make(session: today, context: ctx)

        #expect(summary.durationSeconds == 3600)
        #expect(summary.workingSetCount == 2)
        #expect(summary.totalVolume == 100 * 5 + 110 * 5)
        let line = try #require(summary.exercises.first)
        #expect(line.name == "Bench")
        #expect(line.best?.weight == 110)
        #expect(line.prKinds.contains(.weight))
        #expect(summary.prExerciseCount == 1)
    }

    @Test("no PR when today only ties the prior best")
    func tieIsNotPR() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let past = Date.now.addingTimeInterval(-7 * day)
        try LoggerFixtures.session(exercise: bench, startedAt: past, completedAt: past.addingTimeInterval(3600),
                                   sets: [(100, 5, true)], in: ctx)
        let today = try LoggerFixtures.session(exercise: bench, startedAt: .now.addingTimeInterval(-600),
                                               completedAt: .now, sets: [(100, 5, true)], in: ctx)
        let summary = SessionSummary.make(session: today, context: ctx)
        #expect(summary.prExerciseCount == 0)
    }

    @Test("history PRs count one record per exercise and kind, like the summary")
    func prsBySessionCountsRecords() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let squat = LoggerFixtures.exercise("Squat", in: ctx)
        let past = Date.now.addingTimeInterval(-7 * day)
        let first = try LoggerFixtures.session(exercise: bench, startedAt: past, completedAt: past.addingTimeInterval(3600),
                                               sets: [(100, 5, true)], in: ctx)
        let start = Date.now.addingTimeInterval(-3600)
        let today = try LoggerFixtures.session(exercise: bench, startedAt: start, completedAt: .now,
                                               sets: [(110, 5, true)], in: ctx)
        // A second lift, logged for the first time today.
        let squatLine = SessionExercise()
        ctx.insert(squatLine)
        squatLine.session = today
        squatLine.exercise = squat
        squatLine.exerciseNameSnapshot = squat.name
        squatLine.orderIndex = 1
        let squatSet = SetEntry()
        ctx.insert(squatSet)
        squatSet.sessionExercise = squatLine
        squatSet.weight = 140
        squatSet.reps = 5
        squatSet.isComplete = true
        squatSet.completedAt = start.addingTimeInterval(600)
        try ctx.save()

        let prs = SessionSummary.prsBySession([today, first])

        // Bench beats last week on weight, volume and e1RM (the reps tie);
        // the squat's first log tops all four kinds.
        let todays = try #require(prs[today.id])
        #expect(todays.count == 3 + 4)
        #expect(todays.kinds == PRKind.allCases)
        // The badge count is the total the summary lists per exercise.
        let summary = SessionSummary.make(session: today, context: ctx)
        #expect(todays.count == summary.exercises.reduce(0) { $0 + $1.prKinds.count })
    }

    @Test("history PRs leave out ties and unfinished workouts")
    func prsBySessionSkipsTiesAndLiveWorkouts() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let past = Date.now.addingTimeInterval(-7 * day)
        let first = try LoggerFixtures.session(exercise: bench, startedAt: past, completedAt: past.addingTimeInterval(3600),
                                               sets: [(100, 5, true)], in: ctx)
        let tieStart = Date.now.addingTimeInterval(-2 * day)
        let tie = try LoggerFixtures.session(exercise: bench, startedAt: tieStart, completedAt: tieStart.addingTimeInterval(3600),
                                             sets: [(100, 5, true)], in: ctx)
        let live = try LoggerFixtures.session(exercise: bench, startedAt: .now.addingTimeInterval(-600),
                                              completedAt: nil, sets: [(120, 5, true)], in: ctx)

        let prs = SessionSummary.prsBySession([live, tie, first])

        #expect(prs[first.id]?.count == 4)   // a first log tops every kind
        #expect(prs[tie.id] == nil)
        #expect(prs[live.id] == nil)
    }
}
