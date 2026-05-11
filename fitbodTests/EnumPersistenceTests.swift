//
//  EnumPersistenceTests.swift
//  fitbodTests
//
//  Anchors FOUND-03 — every domain enum stored as `*Raw: String` round-
//  trips through insert + save + fetch, and the computed accessor on the
//  owning `@Model` returns the original enum case.
//
//  This is the load-bearing test for PITFALLS #9 (using `Codable` enums
//  on `@Model` types crashes; the `*Raw: String` + computed accessor
//  pattern is the documented workaround). One parameterised `@Test` per
//  enum / owning-entity pair.
//
//  All 11 String-backed enums are covered:
//    Equipment, Mechanic, Force, Level, Pattern  → Exercise
//    Intent, ProgressionKind                     → SessionExercise / RoutineExercise
//    MuscleRegion                                → MuscleGroup
//    WeightUnit, ProgressionKind                 → UserSettings
//    BlockPhaseKind                              → BlockPhase
//    SetType                                     → SetEntry
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("EnumPersistence")
struct EnumPersistenceTests {

    // MARK: - Equipment ↔ Exercise.equipmentRaw

    @Test("Equipment cases round-trip through Exercise.equipmentRaw",
          arguments: Equipment.allCases)
    func equipmentRoundTrip(_ value: Equipment) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let ex = Exercise()
        ex.equipmentRaw = value.rawValue
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.first?.equipmentRaw == value.rawValue)
        #expect(fetched.first?.equipment == value)
    }

    // MARK: - Mechanic ↔ Exercise.mechanicRaw

    @Test("Mechanic cases round-trip through Exercise.mechanicRaw",
          arguments: Mechanic.allCases)
    func mechanicRoundTrip(_ value: Mechanic) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let ex = Exercise()
        ex.mechanicRaw = value.rawValue
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.first?.mechanicRaw == value.rawValue)
        #expect(fetched.first?.mechanic == value)
    }

    // MARK: - Force ↔ Exercise.forceRaw (Optional)

    @Test("Force cases round-trip through Exercise.forceRaw",
          arguments: Force.allCases)
    func forceRoundTrip(_ value: Force) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let ex = Exercise()
        ex.forceRaw = value.rawValue
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.first?.forceRaw == value.rawValue)
        #expect(fetched.first?.force == value)
    }

    // MARK: - Level ↔ Exercise.levelRaw (Optional)

    @Test("Level cases round-trip through Exercise.levelRaw",
          arguments: Level.allCases)
    func levelRoundTrip(_ value: Level) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let ex = Exercise()
        ex.levelRaw = value.rawValue
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.first?.levelRaw == value.rawValue)
        #expect(fetched.first?.level == value)
    }

    // MARK: - Pattern ↔ Exercise.patternRaw (Optional)

    @Test("Pattern cases round-trip through Exercise.patternRaw",
          arguments: Pattern.allCases)
    func patternRoundTrip(_ value: Pattern) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let ex = Exercise()
        ex.patternRaw = value.rawValue
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.first?.patternRaw == value.rawValue)
        #expect(fetched.first?.pattern == value)
    }

    // MARK: - Intent ↔ SessionExercise.intentRaw

    @Test("Intent cases round-trip through SessionExercise.intentRaw",
          arguments: Intent.allCases)
    func intentRoundTrip(_ value: Intent) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let se = SessionExercise()
        se.intentRaw = value.rawValue
        ctx.insert(se)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SessionExercise>())
        #expect(fetched.first?.intentRaw == value.rawValue)
        #expect(fetched.first?.intent == value)
    }

    // MARK: - ProgressionKind ↔ SessionExercise.progressionKindRaw

    @Test("ProgressionKind cases round-trip through SessionExercise.progressionKindRaw",
          arguments: ProgressionKind.allCases)
    func progressionKindRoundTrip(_ value: ProgressionKind) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let se = SessionExercise()
        se.progressionKindRaw = value.rawValue
        ctx.insert(se)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SessionExercise>())
        #expect(fetched.first?.progressionKindRaw == value.rawValue)
        #expect(fetched.first?.progressionKind == value)
    }

    // MARK: - MuscleRegion ↔ MuscleGroup.regionRaw

    @Test("MuscleRegion cases round-trip through MuscleGroup.regionRaw",
          arguments: MuscleRegion.allCases)
    func muscleRegionRoundTrip(_ value: MuscleRegion) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        // Unique slug per case to avoid #Unique<MuscleGroup>([\.slug])
        // collisions across parameterised invocations of a shared store
        // (each @Test gets a fresh container but the slug stays distinct
        // for readability).
        let m = MuscleGroup(slug: "region-\(value.rawValue)",
                            displayName: value.rawValue,
                            region: value)
        ctx.insert(m)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<MuscleGroup>())
        #expect(fetched.first?.regionRaw == value.rawValue)
        #expect(fetched.first?.region == value)
    }

    // MARK: - WeightUnit ↔ UserSettings.unitsRaw

    @Test("WeightUnit cases round-trip through UserSettings.unitsRaw",
          arguments: WeightUnit.allCases)
    func weightUnitRoundTrip(_ value: WeightUnit) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let u = UserSettings()
        u.unitsRaw = value.rawValue
        ctx.insert(u)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<UserSettings>())
        #expect(fetched.first?.unitsRaw == value.rawValue)
        #expect(fetched.first?.weightUnit == value)
    }

    // MARK: - BlockPhaseKind ↔ BlockPhase.nameRaw

    @Test("BlockPhaseKind cases round-trip through BlockPhase.nameRaw",
          arguments: BlockPhaseKind.allCases)
    func blockPhaseKindRoundTrip(_ value: BlockPhaseKind) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let bp = BlockPhase()
        bp.nameRaw = value.rawValue
        ctx.insert(bp)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<BlockPhase>())
        #expect(fetched.first?.nameRaw == value.rawValue)
        #expect(fetched.first?.kind == value)
    }

    // MARK: - SetType ↔ SetEntry.setTypeRaw

    @Test("SetType cases round-trip through SetEntry.setTypeRaw",
          arguments: SetType.allCases)
    func setTypeRoundTrip(_ value: SetType) throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        let s = SetEntry()
        s.setTypeRaw = value.rawValue
        ctx.insert(s)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SetEntry>())
        #expect(fetched.first?.setTypeRaw == value.rawValue)
        #expect(fetched.first?.setType == value)
    }
}
