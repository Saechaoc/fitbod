//
//  SessionFactoryPhase3Tests.swift
//  fitbodTests
//
//  Phase 3 integration tests for SessionFactory.start(...). Replaced plan
//  03-08's Issue.record placeholders with concrete assertions covering:
//
//    1. prescribedWeightSetOnSessionExercise — PRES-01
//    2. warmupSetEntriesInsertedForFirstQualifyingCompound — WARM-01
//    3. workingSetsShiftAfterWarmupInsertion — working sets offset
//    4. secondQualifyingCompoundDoesNotGetWarmup — WARM-01 single-ramp
//    5. warmupSkippedWhenWarmupConfigDisabled — WARM-03
//
//  Each test builds its own in-memory ModelContainer via Schema(SchemaV3.models)
//  + FitbodSchemaMigrationPlan (mirroring SessionFactoryTests.swift).
//
//  Fixture helpers build minimal Routine + RoutineExercise graphs and seed
//  a PlateInventory row so prescribe() has plate math available without
//  falling back to the transient default path.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionFactoryPhase3", .serialized)
struct SessionFactoryPhase3Tests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Seeds a standard kg barbell PlateInventory into the context so the
    /// strategy prescribe() call has plate math available. Returns the
    /// inserted inventory.
    @discardableResult
    private func seedBarbellInventory(ctx: ModelContext) throws -> PlateInventory {
        let inv = PlateInventory()
        inv.equipmentKind = .barbell
        inv.barWeight = 20.0
        inv.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)
        ctx.insert(inv)
        try ctx.save()
        return inv
    }

    /// Builds a routine with a single barbell compound exercise using double
    /// progression. Appropriate for prescribedWeight and warmup tests.
    @discardableResult
    private func makeCompoundRoutine(ctx: ModelContext) throws -> (Routine, Exercise) {
        let ex = Exercise.previewSample(
            name: "Bench Press",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ex.smallestIncrement = 2.5
        ex.barWeightOverride = nil    // use inventory bar weight (20 kg)
        ctx.insert(ex)

        let routine = Routine()
        routine.name = "Push Day"
        ctx.insert(routine)

        let re = RoutineExercise()
        re.routine = routine
        re.exercise = ex
        re.orderIndex = 0
        re.intentRaw = Intent.strength.rawValue
        re.targetSets = 3
        re.targetRepsLow = 5
        re.targetRepsHigh = 5
        re.targetRPE = nil              // double progression doesn't use RPE
        re.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(re)

        try ctx.save()
        return (routine, ex)
    }

    // MARK: - 1. prescribedWeightSetOnSessionExercise (PRES-01)

    @Test("prescribedWeightSetOnSessionExercise")
    func prescribedWeightSetOnSessionExercise() throws {
        let ctx = try makeContext()
        try seedBarbellInventory(ctx: ctx)
        let (routine, _) = try makeCompoundRoutine(ctx: ctx)

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)

        // After start, every SessionExercise must have a non-nil prescribedWeight.
        // On the first-ever session (no history), DoubleProgressionStrategy returns
        // weight 0 — still non-nil (it's an Optional<Double> assigned from the result).
        let exercises = session.exercises ?? []
        #expect(!exercises.isEmpty)
        for se in exercises {
            // prescribedWeight is set (may be 0 for first session, but is non-nil)
            #expect(se.prescribedWeight != nil, "SessionExercise.prescribedWeight should be non-nil after start()")
        }
    }

    // MARK: - 2. warmupSetEntriesInsertedForFirstQualifyingCompound (WARM-01)

    @Test("warmupSetEntriesInsertedForFirstQualifyingCompound")
    func warmupSetEntriesInsertedForFirstQualifyingCompound() throws {
        let ctx = try makeContext()
        let inv = try seedBarbellInventory(ctx: ctx)

        // Seed a prior session so prescribedWeight > 0 and the warmup
        // threshold (1.5 × barWeight = 30 kg) is exceeded.
        let ex = Exercise.previewSample(
            name: "Squat",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["quads"]
        )
        ex.smallestIncrement = 2.5
        ctx.insert(ex)

        let routine = Routine()
        routine.name = "Leg Day"
        ctx.insert(routine)

        let re = RoutineExercise()
        re.routine = routine
        re.exercise = ex
        re.orderIndex = 0
        re.intentRaw = Intent.strength.rawValue
        re.targetSets = 3
        re.targetRepsLow = 5
        re.targetRepsHigh = 5
        re.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(re)

        // Seed a prior completed session so lastSessionWeight > barWeight × 1.5.
        let priorSession = Session()
        priorSession.startedAt = Date(timeIntervalSinceNow: -86400)
        priorSession.completedAt = Date(timeIntervalSinceNow: -83600)
        ctx.insert(priorSession)

        let priorSE = SessionExercise()
        priorSE.session = priorSession
        priorSE.exercise = ex
        priorSE.intentRaw = Intent.strength.rawValue
        priorSE.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(priorSE)

        // Prior working set at 100 kg — well above 1.5 × 20 = 30 kg threshold.
        let priorSet = SetEntry()
        priorSet.sessionExercise = priorSE
        priorSet.orderIndex = 0
        priorSet.weight = 100.0
        priorSet.reps = 5
        priorSet.isWarmup = false
        priorSet.isComplete = true
        priorSet.setTypeRaw = SetType.working.rawValue
        priorSet.completedAt = Date(timeIntervalSinceNow: -83600)
        ctx.insert(priorSet)

        try ctx.save()

        // Mark prior session completed before starting a new one.
        // (active session guard checks completedAt == nil)
        // Already set above.

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        let ses = session.exercises ?? []
        #expect(ses.count == 1)

        let se = ses[0]
        let allSets = (se.sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let warmupSets = allSets.filter { $0.isWarmup }
        let workingSets = allSets.filter { !$0.isWarmup }

        // Should have 4 warmup sets (barbell 4-step ramp: 40/60/75/90%)
        #expect(warmupSets.count == 4, "Expected 4 warmup sets; got \(warmupSets.count)")

        // All warmup sets must have isWarmup = true and isComplete = false.
        for (i, ws) in warmupSets.enumerated() {
            #expect(ws.isWarmup == true)
            #expect(ws.isComplete == false)
            #expect(ws.orderIndex == i, "Warmup set \(i) should have orderIndex \(i), got \(ws.orderIndex)")
        }

        // Working sets must be present.
        #expect(workingSets.count == 3)

        // Inventory is used for the `inv` reference; just ensure it's accessible.
        _ = inv
    }

    // MARK: - 3. workingSetsShiftAfterWarmupInsertion

    @Test("workingSetsShiftAfterWarmupInsertion")
    func workingSetsShiftAfterWarmupInsertion() throws {
        let ctx = try makeContext()
        try seedBarbellInventory(ctx: ctx)

        let ex = Exercise.previewSample(
            name: "Deadlift",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["back"]
        )
        ex.smallestIncrement = 2.5
        ctx.insert(ex)

        let routine = Routine()
        routine.name = "Pull Day"
        ctx.insert(routine)

        let re = RoutineExercise()
        re.routine = routine
        re.exercise = ex
        re.orderIndex = 0
        re.intentRaw = Intent.strength.rawValue
        re.targetSets = 3
        re.targetRepsLow = 5
        re.targetRepsHigh = 5
        re.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(re)

        // Seed prior session for warmup threshold.
        let priorSession = Session()
        priorSession.startedAt = Date(timeIntervalSinceNow: -86400)
        priorSession.completedAt = Date(timeIntervalSinceNow: -83600)
        ctx.insert(priorSession)
        let priorSE = SessionExercise()
        priorSE.session = priorSession
        priorSE.exercise = ex
        priorSE.intentRaw = Intent.strength.rawValue
        priorSE.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(priorSE)
        let priorSet = SetEntry()
        priorSet.sessionExercise = priorSE
        priorSet.orderIndex = 0
        priorSet.weight = 120.0
        priorSet.reps = 5
        priorSet.isWarmup = false
        priorSet.isComplete = true
        priorSet.setTypeRaw = SetType.working.rawValue
        priorSet.completedAt = Date(timeIntervalSinceNow: -83600)
        ctx.insert(priorSet)
        try ctx.save()

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        let se = (session.exercises ?? [])[0]
        let allSets = (se.sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
        let warmupSets = allSets.filter { $0.isWarmup }
        let workingSets = allSets.filter { !$0.isWarmup }

        let warmupCount = warmupSets.count
        #expect(warmupCount == 4, "Expected 4 warmup sets for barbell compound")

        // Working set orderIndices must all be >= warmupCount.
        for ws in workingSets {
            #expect(ws.orderIndex >= warmupCount,
                "Working set orderIndex \(ws.orderIndex) should be >= warmupCount \(warmupCount)")
        }

        // Verify working sets start exactly at warmupCount.
        let workingIndices = workingSets.map { $0.orderIndex }.sorted()
        let expectedIndices = (warmupCount..<(warmupCount + 3)).map { $0 }
        #expect(workingIndices == expectedIndices,
            "Working set indices \(workingIndices) should equal \(expectedIndices)")
    }

    // MARK: - 4. secondQualifyingCompoundDoesNotGetWarmup (WARM-01)

    @Test("secondQualifyingCompoundDoesNotGetWarmup")
    func secondQualifyingCompoundDoesNotGetWarmup() throws {
        let ctx = try makeContext()
        try seedBarbellInventory(ctx: ctx)

        // Two barbell compound exercises in a single routine.
        let ex1 = Exercise.previewSample(
            name: "Bench Press",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ex1.smallestIncrement = 2.5
        ctx.insert(ex1)

        let ex2 = Exercise.previewSample(
            name: "Overhead Press",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["shoulders"]
        )
        ex2.smallestIncrement = 2.5
        ctx.insert(ex2)

        let routine = Routine()
        routine.name = "Push Day"
        ctx.insert(routine)

        let re1 = RoutineExercise()
        re1.routine = routine
        re1.exercise = ex1
        re1.orderIndex = 0
        re1.intentRaw = Intent.strength.rawValue
        re1.targetSets = 3
        re1.targetRepsLow = 5
        re1.targetRepsHigh = 5
        re1.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(re1)

        let re2 = RoutineExercise()
        re2.routine = routine
        re2.exercise = ex2
        re2.orderIndex = 1
        re2.intentRaw = Intent.strength.rawValue
        re2.targetSets = 3
        re2.targetRepsLow = 5
        re2.targetRepsHigh = 5
        re2.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(re2)

        // Seed prior sessions for both exercises so warmup threshold is exceeded.
        func seedPriorSet(for exercise: Exercise, weight: Double) throws {
            let priorSession = Session()
            priorSession.startedAt = Date(timeIntervalSinceNow: -86400)
            priorSession.completedAt = Date(timeIntervalSinceNow: -83600)
            ctx.insert(priorSession)
            let priorSE = SessionExercise()
            priorSE.session = priorSession
            priorSE.exercise = exercise
            priorSE.intentRaw = Intent.strength.rawValue
            priorSE.progressionKindRaw = ProgressionKind.double.rawValue
            ctx.insert(priorSE)
            let priorSet = SetEntry()
            priorSet.sessionExercise = priorSE
            priorSet.orderIndex = 0
            priorSet.weight = weight
            priorSet.reps = 5
            priorSet.isWarmup = false
            priorSet.isComplete = true
            priorSet.setTypeRaw = SetType.working.rawValue
            priorSet.completedAt = Date(timeIntervalSinceNow: -83600)
            ctx.insert(priorSet)
        }

        try seedPriorSet(for: ex1, weight: 100.0)
        try seedPriorSet(for: ex2, weight: 80.0)
        try ctx.save()

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        let exercises = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        #expect(exercises.count == 2)

        let se1 = exercises[0]
        let se2 = exercises[1]

        let warmup1 = (se1.sets ?? []).filter { $0.isWarmup }
        let warmup2 = (se2.sets ?? []).filter { $0.isWarmup }

        // First compound gets warmup ramp.
        #expect(!warmup1.isEmpty, "First compound should get a warmup ramp")
        // Second compound must NOT get a ramp — only the first qualifying
        // compound per session receives one.
        #expect(warmup2.isEmpty, "Second compound must not get a warmup ramp; only the first qualifies")
    }

    // MARK: - 5. warmupSkippedWhenWarmupConfigDisabled (WARM-03)

    @Test("warmupSkippedWhenWarmupConfigDisabled")
    func warmupSkippedWhenWarmupConfigDisabled() throws {
        let ctx = try makeContext()
        try seedBarbellInventory(ctx: ctx)

        let ex = Exercise.previewSample(
            name: "Bench Press",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"]
        )
        ex.smallestIncrement = 2.5
        ctx.insert(ex)

        let routine = Routine()
        routine.name = "Push Day"
        ctx.insert(routine)

        let re = RoutineExercise()
        re.routine = routine
        re.exercise = ex
        re.orderIndex = 0
        re.intentRaw = Intent.strength.rawValue
        re.targetSets = 3
        re.targetRepsLow = 5
        re.targetRepsHigh = 5
        re.progressionKindRaw = ProgressionKind.double.rawValue
        // WARM-03: explicitly disable warm-up for this exercise.
        re.warmupOverride = WarmupConfig(enabled: false)
        ctx.insert(re)

        // Seed prior session so prescribedWeight > barWeight threshold.
        let priorSession = Session()
        priorSession.startedAt = Date(timeIntervalSinceNow: -86400)
        priorSession.completedAt = Date(timeIntervalSinceNow: -83600)
        ctx.insert(priorSession)
        let priorSE = SessionExercise()
        priorSE.session = priorSession
        priorSE.exercise = ex
        priorSE.intentRaw = Intent.strength.rawValue
        priorSE.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(priorSE)
        let priorSet = SetEntry()
        priorSet.sessionExercise = priorSE
        priorSet.orderIndex = 0
        priorSet.weight = 100.0
        priorSet.reps = 5
        priorSet.isWarmup = false
        priorSet.isComplete = true
        priorSet.setTypeRaw = SetType.working.rawValue
        priorSet.completedAt = Date(timeIntervalSinceNow: -83600)
        ctx.insert(priorSet)
        try ctx.save()

        let session = try SessionFactory.start(routine: routine, on: .now, context: ctx)
        let se = (session.exercises ?? [])[0]
        let warmupSets = (se.sets ?? []).filter { $0.isWarmup }

        #expect(warmupSets.isEmpty,
            "warmupOverride.enabled = false must suppress the ramp; got \(warmupSets.count) warmup sets")
    }
}
