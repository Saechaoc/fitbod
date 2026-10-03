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
}
