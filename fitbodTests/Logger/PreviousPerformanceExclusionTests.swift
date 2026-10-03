//
//  PreviousPerformanceExclusionTests.swift
//  fitbodTests
//
//  "Previous" means the most recent FINISHED session other than the one
//  being logged. The in-progress session and abandoned (never finished)
//  sessions must never feed the PREVIOUS column or the weight hint.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("PreviousPerformanceExclusion", .serialized)
struct PreviousPerformanceExclusionTests {

    private let day: TimeInterval = 24 * 3600

    @Test("the current in-progress session is excluded")
    func excludesCurrentSession() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        let start = Date.now.addingTimeInterval(-7 * day)
        try LoggerFixtures.session(exercise: ex, startedAt: start, completedAt: start.addingTimeInterval(3600),
                                   sets: [(90, 5, true)], in: ctx)
        let current = try LoggerFixtures.session(exercise: ex, startedAt: .now, completedAt: nil,
                                                 sets: [(120, 5, true)], in: ctx)

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id, intentRaw: Intent.strength.rawValue, context: ctx,
            excludingSessionID: current.id
        )
        #expect(hit?.weight == 90)

        // Even without the explicit id, an unfinished session never counts.
        let hitNoID = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
        #expect(hitNoID?.weight == 90)
    }

    @Test("abandoned unfinished sessions are excluded even when newer")
    func excludesAbandoned() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        let old = Date.now.addingTimeInterval(-10 * day)
        try LoggerFixtures.session(exercise: ex, startedAt: old, completedAt: old.addingTimeInterval(3600),
                                   sets: [(80, 8, true)], in: ctx)
        let abandoned = Date.now.addingTimeInterval(-2 * day)
        try LoggerFixtures.session(exercise: ex, startedAt: abandoned, completedAt: nil,
                                   sets: [(140, 3, true)], in: ctx)

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
        #expect(hit?.weight == 80)
        #expect(hit?.reps == 8)
    }

    @Test("most recent finished session wins")
    func mostRecentFinishedFirst() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        let older = Date.now.addingTimeInterval(-14 * day)
        let newer = Date.now.addingTimeInterval(-3 * day)
        try LoggerFixtures.session(exercise: ex, startedAt: older, completedAt: older.addingTimeInterval(3600),
                                   sets: [(110, 3, true)], in: ctx)
        try LoggerFixtures.session(exercise: ex, startedAt: newer, completedAt: newer.addingTimeInterval(3600),
                                   sets: [(95, 6, true)], in: ctx)

        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id, intentRaw: Intent.strength.rawValue, context: ctx
        )
        #expect(hit?.weight == 95)
        #expect(hit?.sessionStartedAt == newer)
    }

    @Test("only an in-progress session → no previous")
    func onlyCurrentGivesNil() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Bench", in: ctx)
        let current = try LoggerFixtures.session(exercise: ex, startedAt: .now, completedAt: nil,
                                                 sets: [(100, 5, true)], in: ctx)
        let hit = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id, intentRaw: Intent.strength.rawValue, context: ctx,
            excludingSessionID: current.id
        )
        #expect(hit == nil)
    }
}
