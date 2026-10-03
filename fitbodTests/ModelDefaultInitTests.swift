//
//  ModelDefaultInitTests.swift
//  fitbodTests
//
//  Every @Model type default-inits, inserts, saves and fetches (FOUND-02).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("ModelDefaultInit")
struct ModelDefaultInitTests {

    // MARK: - FOUND-01 — container builds with versioned schema + migration plan

    // MARK: - exercise round-trip — proves insert + save + fetch path

    @Test("Exercise round-trips through insert + save + fetch")
    func exerciseRoundTrip() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let ex = Exercise.previewSample(
            name: "Test Lift",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Lift")
        #expect(fetched.first?.equipment == .barbell)
        #expect(fetched.first?.primaryMuscleSlugsJoined == "|chest|")
    }

    // MARK: - FOUND-02 — every entity instantiable + saveable via no-arg init

    @Test("Exercise default-inits and saves")
    func exerciseDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let ex = Exercise()
        ctx.insert(ex)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    @Test("MuscleGroup default-inits and saves")
    func muscleGroupDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let m = MuscleGroup()
        // slug uniqueness requires a non-empty value to be set before
        // a second row would clash; the no-arg default is "" and is
        // legal for a single row.
        ctx.insert(m)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<MuscleGroup>()).count == 1)
    }

    @Test("ExerciseMuscleStimulus default-inits and saves")
    func stimulusDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let s = ExerciseMuscleStimulus()
        ctx.insert(s)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>()).count == 1)
    }

    @Test("SessionTemplate default-inits and saves")
    func routineDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let r = SessionTemplate()
        ctx.insert(r)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<SessionTemplate>()).count == 1)
    }

    @Test("SessionExerciseTemplate default-inits and saves")
    func routineExerciseDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let re = SessionExerciseTemplate()
        ctx.insert(re)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<SessionExerciseTemplate>()).count == 1)
    }

    @Test("Session default-inits and saves")
    func sessionDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let s = Session()
        ctx.insert(s)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<Session>()).count == 1)
    }

    @Test("SessionExercise default-inits and saves")
    func sessionExerciseDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let se = SessionExercise()
        ctx.insert(se)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<SessionExercise>()).count == 1)
    }

    @Test("SetEntry default-inits and saves")
    func setEntryDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let s = SetEntry()
        ctx.insert(s)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<SetEntry>()).count == 1)
    }

    @Test("Block default-inits and saves")
    func blockDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let b = Block()
        ctx.insert(b)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<Block>()).count == 1)
    }

    @Test("BlockPhase default-inits and saves")
    func blockPhaseDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let bp = BlockPhase()
        ctx.insert(bp)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<BlockPhase>()).count == 1)
    }

    @Test("UserSettings default-inits and saves")
    func userSettingsDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let u = UserSettings()
        ctx.insert(u)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<UserSettings>()).count == 1)
    }

    @Test("MuscleVolumeTarget default-inits and saves")
    func muscleVolumeTargetDefaults() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let mvt = MuscleVolumeTarget()
        ctx.insert(mvt)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<MuscleVolumeTarget>()).count == 1)
    }
}
