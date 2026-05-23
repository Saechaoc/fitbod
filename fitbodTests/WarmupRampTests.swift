//
//  WarmupRampTests.swift
//  fitbodTests
//
//  5 @Test functions for WarmupRamp — turned GREEN by plan 03-05.
//
//  Tests that require shouldGenerate() use a V3 in-memory ModelContext to
//  construct SessionExercise + Exercise pairs (@MainActor + .serialized per
//  the project SwiftData test convention). Tests that only call generate()
//  are pure-function and need no context.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WarmupRamp", .serialized)
struct WarmupRampTests {

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

    /// Builds an in-memory SessionExercise linked to a minimal Exercise.
    private func makeSessionExercise(
        ctx: ModelContext,
        equipment: Equipment,
        mechanic: Mechanic
    ) -> SessionExercise {
        let ex = Exercise.previewSample(
            name: "Test Exercise",
            equipment: equipment,
            mechanic: mechanic
        )
        ctx.insert(ex)

        let se = SessionExercise()
        se.exercise = ex
        ctx.insert(se)
        return se
    }

    // Standard kg barbell plate set.
    private let standardPlates: [(weight: Double, countPerSide: Int)] = [
        (weight: 20.0, countPerSide: 4),
        (weight: 10.0, countPerSide: 4),
        (weight: 5.0, countPerSide: 4),
        (weight: 2.5, countPerSide: 4),
        (weight: 1.25, countPerSide: 4)
    ]
    private let barWeight: Double = 20.0

    // MARK: - 1. Barbell compound at sufficient weight generates 4 sets

    @Test("barbellCompoundAtTopGenerates4Sets")
    func barbellCompoundAtTopGenerates4Sets() throws {
        // generate() is pure — no ModelContext needed.
        let top = 100.0
        let entries = WarmupRamp.generate(
            top: top,
            bar: barWeight,
            plates: standardPlates,
            isUnilateral: false  // barbell
        )

        #expect(entries.count == 4)

        // Reps sequence must be [5, 3, 2, 1].
        let repsSequence = entries.map(\.reps)
        #expect(repsSequence == [5, 3, 2, 1])

        // Each weight must be <= the corresponding percentage of top.
        let pcts = [0.40, 0.60, 0.75, 0.90]
        for (entry, pct) in zip(entries, pcts) {
            #expect(entry.weight <= pct * top,
                "\(entry.weight) should be <= \(pct * top) for \(Int(pct * 100))% ramp step")
        }

        // All entries must be marked as warmup sets.
        for entry in entries {
            #expect(entry.isWarmup == true)
            #expect(entry.setTypeRaw == "warmup")
            #expect(entry.isComplete == false)
        }

        // Order indices must be 0, 1, 2, 3.
        #expect(entries.map(\.orderIndex) == [0, 1, 2, 3])
    }

    // MARK: - 2. Dumbbell halves to 2 sets

    @Test("dumbbellHalvesTo2Sets")
    func dumbbellHalvesTo2Sets() throws {
        let top = 40.0  // 40 kg dumbbell
        let entries = WarmupRamp.generate(
            top: top,
            bar: 0,                 // dumbbells have no bar component
            plates: standardPlates,
            isUnilateral: true      // dumbbell → 2-set ramp
        )

        #expect(entries.count == 2)

        // Reps sequence must be [3, 1] for dumbbell ramp.
        #expect(entries.map(\.reps) == [3, 1])

        // Weights must be <= 60% and 90% of top respectively.
        #expect(entries[0].weight <= 0.60 * top)
        #expect(entries[1].weight <= 0.90 * top)

        for entry in entries {
            #expect(entry.isWarmup == true)
        }
    }

    // MARK: - 3. Light weight skips ramp (shouldGenerate returns false)

    @Test("lightWeightSkipsRamp")
    func lightWeightSkipsRamp() throws {
        let ctx = try makeContext()
        // Barbell compound — but top weight < 1.5 × barWeight (30 < 1.5 × 20 = 30)
        // Exactly 30 means top == 1.5 * bar, which passes (>=). Use 29 to fail.
        let se = makeSessionExercise(ctx: ctx, equipment: .barbell, mechanic: .compound)

        let result = WarmupRamp.shouldGenerate(
            for: se,
            deloadActive: false,
            topWorkingWeight: 25.0,     // 25 < 1.5 × 20 = 30 → skip
            barWeight: barWeight,
            warmupConfig: nil
        )

        #expect(result == false)
    }

    // MARK: - 4. Bodyweight equipment skips ramp

    @Test("bodyweightSkipsRamp")
    func bodyweightSkipsRamp() throws {
        let ctx = try makeContext()
        // Bodyweight equipment → shouldGenerate returns false regardless of weight.
        let se = makeSessionExercise(ctx: ctx, equipment: .bodyweight, mechanic: .compound)

        let result = WarmupRamp.shouldGenerate(
            for: se,
            deloadActive: false,
            topWorkingWeight: 100.0,    // weight is irrelevant — bodyweight always skips
            barWeight: barWeight,
            warmupConfig: nil
        )

        #expect(result == false)
    }

    // MARK: - 5. Deload active skips ramp even on qualifying compound

    @Test("deloadActiveSkipsRamp")
    func deloadActiveSkipsRamp() throws {
        let ctx = try makeContext()
        // Fully qualifying barbell compound with sufficient weight — but deload active.
        let se = makeSessionExercise(ctx: ctx, equipment: .barbell, mechanic: .compound)

        let result = WarmupRamp.shouldGenerate(
            for: se,
            deloadActive: true,         // deload → skip regardless of everything else
            topWorkingWeight: 100.0,
            barWeight: barWeight,
            warmupConfig: nil
        )

        #expect(result == false)
    }
}
