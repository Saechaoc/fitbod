//
//  RollBackTests.swift
//  fitbodTests
//
//  A rolled-back change must not stay on screen. SwiftData (Xcode 26.5)
//  leaves loaded models showing the discarded values after
//  `ModelContext.rollback()` until they are fetched again.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("RollBack", .serialized)
struct RollBackTests {

    @Test("a rolled-back edit reads the saved value again")
    func rolledBackEditReadsSavedValue() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try ctx.save()

        bench.name = "Discarded"
        SessionSetActions.rollBack(ctx)

        #expect(bench.name == "Bench")
        #expect(!ctx.hasChanges)
    }

    @Test("a rolled-back delete leaves the model readable and saved")
    func rolledBackDeleteKeepsModel() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        try ctx.save()

        ctx.delete(bench)
        SessionSetActions.rollBack(ctx)

        #expect(!bench.isDeleted)
        #expect(bench.name == "Bench")
        #expect(try ctx.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }

    @Test("a rolled-back insert is gone")
    func rolledBackInsertIsGone() throws {
        let ctx = try LoggerFixtures.makeContext()
        _ = LoggerFixtures.exercise("Bench", in: ctx)
        try ctx.save()

        _ = LoggerFixtures.exercise("Discarded", in: ctx)
        SessionSetActions.rollBack(ctx)

        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).map(\.name) == ["Bench"])
    }
}
