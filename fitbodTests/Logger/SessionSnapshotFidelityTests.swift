//
//  SessionSnapshotFidelityTests.swift
//  fitbodTests
//
//  A logged session is frozen at log time: renaming or editing the
//  template, or renaming the catalog exercise, afterwards must not change
//  the session's names, targets or sets.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionSnapshotFidelity", .serialized)
struct SessionSnapshotFidelityTests {

    @Test("start writes template edge, template name and exercise name snapshots")
    func startWritesSnapshots() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Barbell Bench Press", in: ctx)
        let template = try LoggerFixtures.template("Push A", exercises: [bench], in: ctx)

        let session = try SessionFactory.start(template: template, context: ctx)

        #expect(session.template?.id == template.id)
        #expect(session.templateName == "Push A")
        #expect(session.routineSnapshotName == "Push A")
        let se = try #require(session.exercises?.first)
        #expect(se.exerciseNameSnapshot == "Barbell Bench Press")
        #expect(se.displayName == "Barbell Bench Press")
    }

    @Test("editing template and exercise after logging leaves the session unchanged")
    func editsAfterLoggingDoNotLeak() throws {
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Barbell Bench Press", in: ctx)
        let template = try LoggerFixtures.template(
            "Push A", exercises: [bench], sets: 3, repsLow: 5, repsHigh: 8, rest: 180, in: ctx
        )
        let session = try SessionFactory.start(template: template, context: ctx)
        let se = try #require(session.exercises?.first)
        let working = SessionSetActions.ordered(se).filter { !$0.isWarmup }
        working[0].weight = 100
        working[0].reps = 6
        SessionSetActions.complete(working[0], context: ctx)
        let setIDs = Set((se.sets ?? []).map(\.id))

        // Edit everything upstream after the fact.
        template.name = "Push Day (renamed)"
        let row = try #require(template.exercises?.first)
        row.targetSets = 5
        row.targetRepsLow = 10
        row.targetRepsHigh = 15
        row.prescribedRestSeconds = 60
        bench.name = "Bench (renamed)"
        try ctx.save()

        // Re-read through a fresh context.
        let reader = ModelContext(ctx.container)
        let sid = session.id
        let reread = try #require(try reader.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == sid })).first)
        let rse = try #require(reread.exercises?.first)

        #expect(reread.templateName == "Push A")
        #expect(reread.routineSnapshotName == "Push A")
        #expect(rse.exerciseNameSnapshot == "Barbell Bench Press")
        #expect(rse.displayName == "Barbell Bench Press")
        #expect(rse.targetSets == 3)
        #expect(rse.targetRepsLow == 5)
        #expect(rse.targetRepsHigh == 8)
        #expect(rse.prescribedRestSeconds == 180)
        #expect(Set((rse.sets ?? []).map(\.id)) == setIDs)
        let logged = (rse.sets ?? []).filter(\.isComplete)
        #expect(logged.count == 1)
        #expect(logged.first?.weight == 100)
        #expect(logged.first?.reps == 6)

        // The summary reads the snapshot too.
        let summary = SessionSummary.make(session: reread, priorSets: [])
        #expect(summary.exercises.first?.name == "Barbell Bench Press")
    }

    @Test("pre-snapshot rows fall back to the live exercise name")
    func emptySnapshotFallsBack() throws {
        let ctx = try LoggerFixtures.makeContext()
        let ex = LoggerFixtures.exercise("Row", in: ctx)
        let se = SessionExercise()
        ctx.insert(se)
        se.exercise = ex
        #expect(se.exerciseNameSnapshot == "")
        #expect(se.displayName == "Row")
    }

    @Test("swap writes the new exercise name snapshot")
    func swapWritesSnapshot() throws {
        // SwapExerciseSheet mutates exercise + snapshot together; mirror it.
        let ctx = try LoggerFixtures.makeContext()
        let bench = LoggerFixtures.exercise("Bench", in: ctx)
        let incline = LoggerFixtures.exercise("Incline Bench", in: ctx)
        let template = try LoggerFixtures.template("Push A", exercises: [bench], in: ctx)
        let session = try SessionFactory.start(template: template, context: ctx)
        let se = try #require(session.exercises?.first)
        se.exercise = incline
        se.exerciseNameSnapshot = incline.name
        incline.name = "Incline (renamed)"
        #expect(se.displayName == "Incline Bench")
    }
}
