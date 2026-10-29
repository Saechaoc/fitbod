//
//  LoggedSetCountTests.swift
//  fitbodTests
//
//  Review item 2, decision 5: "logged sets" means completed working sets.
//  Warm-ups never count, whether completed or skipped. `Session.loggedSetCount`
//  drives the logger header, the Finish check, the Today resume slab and the
//  Program resume banner.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("LoggedSetCount")
struct LoggedSetCountTests {

    /// Held by the suite so the models stay attached for the whole test.
    private let ctx: ModelContext

    init() throws {
        ctx = ModelContext(try InMemoryContainer.makeCurrent())
    }

    /// One session whose exercises hold sets of the given (isWarmup, isComplete) kinds.
    private func makeSession(_ exercises: [[(isWarmup: Bool, isComplete: Bool)]]) throws -> Session {
        let session = Session()
        ctx.insert(session)
        for kinds in exercises {
            let se = SessionExercise()
            ctx.insert(se)
            se.session = session
            for (index, kind) in kinds.enumerated() {
                let set = SetEntry()
                ctx.insert(set)
                set.orderIndex = index
                set.isWarmup = kind.isWarmup
                set.isComplete = kind.isComplete
                set.sessionExercise = se
            }
        }
        try ctx.save()
        return session
    }

    @Test("Counts completed working sets across exercises; warm-ups and planned sets never count")
    func countsCompletedWorkingSetsOnly() throws {
        let session = try makeSession([
            // Skipped warm-ups are complete but must not count.
            [(true, true), (true, true), (false, true), (false, false)],
            [(true, false), (false, true), (false, true)],
        ])
        #expect(session.loggedSetCount == 3)
    }

    @Test("Skipped warm-ups alone log nothing")
    func skippedWarmupsLogNothing() throws {
        let session = try makeSession([[(true, true), (true, true), (true, true), (true, true), (false, false)]])
        #expect(session.loggedSetCount == 0)
    }

    @Test("A session without exercises logs nothing")
    func emptySessionLogsNothing() throws {
        #expect(try makeSession([]).loggedSetCount == 0)
    }
}
