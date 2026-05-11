//
//  CascadeRuleTests.swift
//  fitbodTests
//
//  Anchors LIB-05 ("editing/deleting a custom exercise must NOT delete
//  historical session rows") and pins the rest of the cascade-rule
//  matrix from CONTEXT.md Area 4 / ARCHITECTURE.md:
//
//    - Exercise → ExerciseMuscleStimulus: cascade (stimulus rows owned)
//    - Session → SessionExercise → SetEntry: cascade chain
//    - Routine → RoutineExercise: cascade
//    - Exercise → SessionExercise: NULLIFY (LIB-05) — deleting a library
//      entry must leave the SessionExercise row in place with
//      `exercise == nil`.
//
//  These rules are non-negotiable Day 1 because a future schema
//  change is not allowed to retroactively rewrite cascade semantics
//  on existing on-disk rows.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("CascadeRules")
struct CascadeRuleTests {

    // MARK: - Exercise → ExerciseMuscleStimulus (cascade)

    @Test("deleting an Exercise cascades into its ExerciseMuscleStimulus rows")
    func exerciseToMuscleStimulusCascades() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        ctx.insert(chest)

        let ex = Exercise.previewSample(
            name: "Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ctx.insert(ex)
        ctx.insert(ExerciseMuscleStimulus(
            exercise: ex,
            muscle: chest,
            role: "primary",
            weight: 1.0
        ))
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>()).count == 1)

        ctx.delete(ex)
        try ctx.save()

        // Cascade rule: deleting Exercise removes its owned stimulus rows.
        #expect(try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>()).isEmpty)
        // MuscleGroup itself is untouched.
        #expect(try ctx.fetch(FetchDescriptor<MuscleGroup>()).count == 1)
    }

    // MARK: - Exercise → SessionExercise (NULLIFY — LIB-05 anchor)

    @Test("deleting an Exercise NULLIFIES the linked SessionExercise.exercise (LIB-05)")
    func exerciseToSessionExerciseNullifies() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let session = Session()
        session.routineSnapshotName = "Test Session"
        session.startedAt = .now
        ctx.insert(session)

        let ex = Exercise.previewSample(
            name: "Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ctx.insert(ex)

        let se = SessionExercise()
        se.session = session
        se.exercise = ex
        se.orderIndex = 0
        ctx.insert(se)
        try ctx.save()

        // Sanity: forward reference wired.
        let preDelete = try ctx.fetch(FetchDescriptor<SessionExercise>())
        #expect(preDelete.count == 1)
        #expect(preDelete.first?.exercise != nil)

        // Delete the library entry. LIB-05: history row survives.
        ctx.delete(ex)
        try ctx.save()

        let postDelete = try ctx.fetch(FetchDescriptor<SessionExercise>())
        #expect(postDelete.count == 1, "SessionExercise must survive Exercise deletion")
        #expect(
            postDelete.first?.exercise == nil,
            "SessionExercise.exercise must be nullified (LIB-05)"
        )
        // Session itself untouched.
        #expect(try ctx.fetch(FetchDescriptor<Session>()).count == 1)
    }

    // MARK: - Session → SessionExercise → SetEntry (cascade chain)

    @Test("deleting a Session cascades into SessionExercise and SetEntry rows")
    func sessionCascadesToSetEntry() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let session = Session()
        session.routineSnapshotName = "Cascade Test"
        ctx.insert(session)

        let se = SessionExercise()
        se.session = session
        se.orderIndex = 0
        ctx.insert(se)

        let set1 = SetEntry()
        set1.sessionExercise = se
        set1.orderIndex = 0
        set1.weight = 135
        set1.reps = 5
        ctx.insert(set1)

        let set2 = SetEntry()
        set2.sessionExercise = se
        set2.orderIndex = 1
        set2.weight = 145
        set2.reps = 5
        ctx.insert(set2)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<SessionExercise>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<SetEntry>()).count == 2)

        ctx.delete(session)
        try ctx.save()

        // Full cascade chain: deleting Session removes SessionExercise
        // AND its SetEntry rows.
        #expect(try ctx.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<SessionExercise>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<SetEntry>()).isEmpty)
    }

    // MARK: - Routine → RoutineExercise (cascade)

    @Test("deleting a Routine cascades into its RoutineExercise rows")
    func routineCascadesToRoutineExercise() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let routine = Routine()
        routine.name = "Push Day"
        ctx.insert(routine)

        let re1 = RoutineExercise()
        re1.routine = routine
        re1.orderIndex = 0
        ctx.insert(re1)

        let re2 = RoutineExercise()
        re2.routine = routine
        re2.orderIndex = 1
        ctx.insert(re2)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<RoutineExercise>()).count == 2)

        ctx.delete(routine)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<Routine>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<RoutineExercise>()).isEmpty)
    }
}
