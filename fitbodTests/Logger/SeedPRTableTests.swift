//
//  SeedPRTableAndSummaryTests.swift
//  fitbodTests
//
//  Regression: SessionFactory.seedPRTable used a multi-level optional
//  chain inside #Predicate, which throws NSInvalidArgumentException at
//  fetch time and crashed SessionLoggerView on every open. These tests
//  run it against a real in-memory container with logged sets.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SeedPRTable", .serialized)
struct SeedPRTableTests {

    private let day: TimeInterval = 24 * 3600

    @Test("seedPRTable fetches history for the session's exercises without crashing")
    func seedPRTableAgainstRealStore() async throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let squat = LoggerFixtures.exercise("Squat", in: ctx)
        let past = Date.now.addingTimeInterval(-7 * day)
        try LoggerFixtures.session(exercise: bench, startedAt: past, completedAt: past.addingTimeInterval(3600),
                                   sets: [(100, 5, true), (105, 3, true), (200, 1, false)], in: ctx)
        try LoggerFixtures.session(exercise: squat, startedAt: past, completedAt: past.addingTimeInterval(3600),
                                   sets: [(150, 5, true)], in: ctx)
        let current = try LoggerFixtures.session(exercise: bench, startedAt: .now, completedAt: nil,
                                                 sets: [(0, 0, false)], in: ctx)

        let table = await SessionFactory.seedPRTable(for: current, context: ctx)

        // Bench only (squat is not in this session); the incomplete 200 is ignored.
        let weightPR = table.record(exerciseID: bench.id, intent: .strength, kind: .weight, bucket: .strength)
        #expect(weightPR?.weight == 105)
        #expect(table.record(exerciseID: squat.id, intent: .strength, kind: .weight, bucket: .strength) == nil)
    }
}
