//
//  InSessionPRStateTests.swift
//  fitbodTests
//
//  Wave-4 plan 06-07 — observability tests for InSessionPRState
//  (PROG-08 + CONTEXT D-14..D-16).
//
//  Three @Test functions:
//
//    1. emptyOnInit — fresh state has currentBanner == nil
//    2. multiPRCanonicalOrder — a set that hits multiple PR kinds
//       populates banner.kinds in PRKind.allCases order (weight →
//       reps → volume → e1RM)
//    3. nextSaveNoPRClearsBanner — a save with no PR hits clears
//       the prior banner (D-15 "next save with no PRs replaces
//       prior banner")
//
//  Each test acquires a fresh in-memory SchemaV6 ModelContainer via
//  InMemoryContainer.makeCurrent() so SetEntry rows can carry their
//  Session/SessionExercise/Exercise relationship chain into the
//  PRDetector kernel.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("InSessionPRState (PROG-08 + CONTEXT D-14..D-16)", .serialized)
struct InSessionPRStateTests {

    private func makeContext() throws -> ModelContext {
        ModelContext(try InMemoryContainer.makeCurrent())
    }

    // MARK: - 1. empty on init

    @Test("emptyOnInit — fresh state has nil banner + empty prTable")
    func emptyOnInit() {
        let state = InSessionPRState()
        #expect(state.currentBanner == nil)
        #expect(state.prTable.recordedSlotCount == 0)
    }

    // MARK: - 2. multi-PR canonical order

    @Test("multiPRCanonicalOrder — a 110×5 first set hits weight + reps + volume + e1RM in canonical order")
    func multiPRCanonicalOrder() throws {
        let ctx = try makeContext()
        let bench = Exercise(
            name: "Bench", canonicalName: "bench",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        ctx.insert(bench)
        let session = Session()
        session.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        session.intentRaw = Intent.strength.rawValue
        ctx.insert(session)
        let se = SessionExercise()
        se.session = session
        se.exercise = bench
        se.targetSets = 1
        ctx.insert(se)
        let set = SetEntry()
        set.sessionExercise = se
        set.weight = 110
        set.reps = 5
        set.rpe = 9.0
        set.isWarmup = false
        set.isComplete = true
        set.completedAt = session.startedAt
        ctx.insert(set)
        try ctx.save()

        let state = InSessionPRState()   // empty table → first save tops every slot
        state.observeSave(set: set)

        let banner = try #require(state.currentBanner)
        // PRKind.allCases canonical order is weight → reps → volume → e1RM
        #expect(banner.kinds == [.weight, .reps, .volume, .e1RM])
        #expect(banner.weight == 110)
        #expect(banner.reps == 5)
    }

    // MARK: - 3. next save without PR clears banner

    @Test("nextSaveNoPRClearsBanner — D-15 next-save-no-PR replaces prior banner")
    func nextSaveNoPRClearsBanner() throws {
        let ctx = try makeContext()
        let bench = Exercise(
            name: "Bench", canonicalName: "bench",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        ctx.insert(bench)
        let session = Session()
        session.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        session.intentRaw = Intent.strength.rawValue
        ctx.insert(session)
        let se = SessionExercise()
        se.session = session
        se.exercise = bench
        se.targetSets = 2
        ctx.insert(se)

        // First set: PR
        let firstSet = SetEntry()
        firstSet.sessionExercise = se
        firstSet.weight = 110
        firstSet.reps = 5
        firstSet.rpe = 9.0
        firstSet.isWarmup = false
        firstSet.isComplete = true
        firstSet.completedAt = session.startedAt
        ctx.insert(firstSet)

        // Second set: strictly worse than the first on every PR criterion
        let secondSet = SetEntry()
        secondSet.sessionExercise = se
        secondSet.weight = 80
        secondSet.reps = 5
        secondSet.rpe = 8.0
        secondSet.isWarmup = false
        secondSet.isComplete = true
        secondSet.completedAt = session.startedAt.addingTimeInterval(120)
        ctx.insert(secondSet)
        try ctx.save()

        let state = InSessionPRState()
        state.observeSave(set: firstSet)
        #expect(state.currentBanner != nil, "first set must populate banner")

        state.observeSave(set: secondSet)
        #expect(state.currentBanner == nil, "second non-PR save must clear banner")
    }
}
