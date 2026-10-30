//
//  StimulusWeightSeederTests.swift
//  fitbodTests
//
//  Pins StimulusWeightSeeder semantics per RESEARCH §6.3 + Threat
//  T-05-01:
//    1. All 57 curated rows write on first launch (the entire
//       StimulusWeightTable.overrides dictionary is consumed).
//    2. User-edited rows (userEditedWeight == true) are preserved
//       verbatim across re-seeds — VOL-01 anchor.
//    3. Non-curated exercises are untouched (rows outside the
//       overrides dictionary keep whatever values Phase 1's seeder
//       wrote).
//    4. Idempotent across multiple runs — no row count growth + no
//       value drift.
//    5. T-05-01 clamp: weights outside [0, 1] are pinned in range
//       (tested directly via clampedWeight helper).
//    6. Find-or-update semantics, NOT delete-and-recreate — existing
//       row identity preserved.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("StimulusWeightSeeder", .serialized)
struct StimulusWeightSeederTests {

    // MARK: - Helpers

    /// Insert all 17 free-exercise-db muscle slugs into the context so
    /// the seeder can resolve muscle lookups for every curated triple.
    @discardableResult
    private func seedAllMuscles(_ ctx: ModelContext) throws -> [String: MuscleGroup] {
        var byslug: [String: MuscleGroup] = [:]
        for slug in MuscleRegionMap.allSlugs {
            let m = MuscleGroup(slug: slug, displayName: MuscleRegionMap.displayName(for: slug), region: MuscleRegionMap.region(for: slug))
            ctx.insert(m)
            byslug[slug] = m
        }
        try ctx.save()
        return byslug
    }

    /// Insert one Exercise per canonical name in
    /// `StimulusWeightTable.overrides`. Caller is responsible for
    /// pre-seeding the muscles via `seedAllMuscles` first.
    @discardableResult
    private func seedCuratedExercises(_ ctx: ModelContext) throws -> [String: Exercise] {
        var byname: [String: Exercise] = [:]
        for (canonicalName, _) in StimulusWeightTable.overrides {
            let ex = Exercise()
            ex.canonicalName = canonicalName
            ex.name = canonicalName.capitalized
            ctx.insert(ex)
            byname[canonicalName] = ex
        }
        try ctx.save()
        return byname
    }

    // MARK: - 1. All 57 curated lifts write on first launch

    @Test("Seeder writes the full curated table onto matching Exercise rows")
    func seederWritesAllCuratedRows() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        _ = try seedAllMuscles(ctx)
        let exercises = try seedCuratedExercises(ctx)

        StimulusWeightSeeder.seedIfNeeded(in: ctx)

        // For each curated key, assert that the Exercise has a stimulus
        // row matching each (muscleSlug, role, weight) triple.
        for (canonicalName, triples) in StimulusWeightTable.overrides {
            let ex = try #require(exercises[canonicalName])
            let stims = ex.muscleStimuli ?? []
            for triple in triples {
                let match = stims.first { $0.muscle?.slug == triple.muscleSlug }
                let row = try #require(match, "missing stimulus for \(canonicalName) → \(triple.muscleSlug)")
                #expect(row.role == triple.role, "wrong role for \(canonicalName) → \(triple.muscleSlug)")
                #expect(abs(row.weight - triple.weight) < 0.001, "wrong weight for \(canonicalName) → \(triple.muscleSlug): got \(row.weight) expected \(triple.weight)")
            }
        }
    }

    // MARK: - 2. User-edited rows are preserved

    @Test("Rows with userEditedWeight=true are preserved verbatim across seed")
    func userEditedRowsArePreservedAcrossReSeed() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedAllMuscles(ctx)
        let bench = Exercise()
        bench.canonicalName = "barbell bench press"
        bench.name = "Barbell Bench Press"
        ctx.insert(bench)

        // Pre-seed a user-edited chest stimulus at 0.75.
        let edited = ExerciseMuscleStimulus()
        edited.role = "primary"
        edited.weight = 0.75
        edited.userEditedWeight = true
        edited.muscle = muscles["chest"]
        edited.exercise = bench
        ctx.insert(edited)
        try ctx.save()

        StimulusWeightSeeder.seedIfNeeded(in: ctx)

        let stims = bench.muscleStimuli ?? []
        let chestStim = try #require(stims.first { $0.muscle?.slug == "chest" })
        #expect(abs(chestStim.weight - 0.75) < 0.001, "user-edited weight clobbered: got \(chestStim.weight)")
        #expect(chestStim.userEditedWeight == true)
    }

    // MARK: - 3. Non-curated exercises are untouched

    @Test("Exercises outside the curated table are not modified")
    func nonCuratedExercisesAreUntouched() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedAllMuscles(ctx)
        let chopper = Exercise()
        chopper.canonicalName = "cable woodchopper"
        chopper.name = "Cable Woodchopper"
        ctx.insert(chopper)

        let stim = ExerciseMuscleStimulus()
        stim.role = "primary"
        stim.weight = 0.42
        stim.muscle = muscles["abdominals"]
        stim.exercise = chopper
        ctx.insert(stim)
        try ctx.save()

        StimulusWeightSeeder.seedIfNeeded(in: ctx)

        let stims = chopper.muscleStimuli ?? []
        let row = try #require(stims.first { $0.muscle?.slug == "abdominals" })
        #expect(abs(row.weight - 0.42) < 0.001)
    }

    // MARK: - 4. Idempotency across re-runs

    @Test("Re-running the seeder does not change row counts or values")
    func idempotentAcrossMultipleRuns() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        _ = try seedAllMuscles(ctx)
        _ = try seedCuratedExercises(ctx)

        StimulusWeightSeeder.seedIfNeeded(in: ctx)
        let countAfterFirst = (try? ctx.fetchCount(FetchDescriptor<ExerciseMuscleStimulus>())) ?? 0

        StimulusWeightSeeder.seedIfNeeded(in: ctx)
        let countAfterSecond = (try? ctx.fetchCount(FetchDescriptor<ExerciseMuscleStimulus>())) ?? 0

        StimulusWeightSeeder.seedIfNeeded(in: ctx)
        let countAfterThird = (try? ctx.fetchCount(FetchDescriptor<ExerciseMuscleStimulus>())) ?? 0

        #expect(countAfterFirst == countAfterSecond)
        #expect(countAfterSecond == countAfterThird)
    }

    @Test("A re-run with nothing to change saves no rows")
    func rerunWithNothingToChangeSavesNoRows() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        _ = try seedAllMuscles(ctx)
        _ = try seedCuratedExercises(ctx)
        StimulusWeightSeeder.seedIfNeeded(in: ctx)

        let saved = SavedRowCount()
        let observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: ctx, queue: nil
        ) { note in
            saved.updated += (note.userInfo?[ModelContext.NotificationKey.updatedIdentifiers.rawValue]
                as? [PersistentIdentifier])?.count ?? 0
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        StimulusWeightSeeder.seedIfNeeded(in: ctx)
        #expect(saved.updated == 0)
    }

    // MARK: - 5. T-05-01 clamp

    @Test("clampedWeight pins weights outside [0,1] (T-05-01)")
    func t0501ClampOutOfRangeWeights() {
        #expect(abs(StimulusWeightSeeder.clampedWeight(1.5) - 1.0) < 0.001)
        #expect(abs(StimulusWeightSeeder.clampedWeight(2.0) - 1.0) < 0.001)
        #expect(abs(StimulusWeightSeeder.clampedWeight(-0.1) - 0.0) < 0.001)
        #expect(abs(StimulusWeightSeeder.clampedWeight(-100.0) - 0.0) < 0.001)
        // In-range values pass through unchanged.
        #expect(abs(StimulusWeightSeeder.clampedWeight(0.0) - 0.0) < 0.001)
        #expect(abs(StimulusWeightSeeder.clampedWeight(0.5) - 0.5) < 0.001)
        #expect(abs(StimulusWeightSeeder.clampedWeight(1.0) - 1.0) < 0.001)
    }

    // MARK: - 6. Find-or-update preserves row identity

    @Test("Find-or-update semantics: existing stimulus rows are updated in place, not duplicated")
    func seederDoesNotInsertDuplicateStimulusRows() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedAllMuscles(ctx)
        let bench = Exercise()
        bench.canonicalName = "barbell bench press"
        bench.name = "Barbell Bench Press"
        ctx.insert(bench)

        // Pre-seed 3 stimulus rows for chest / shoulders / triceps
        // (matching the curated triples, but with bogus weights — the
        // seeder should overwrite them since userEditedWeight=false).
        for slug in ["chest", "shoulders", "triceps"] {
            let s = ExerciseMuscleStimulus()
            s.role = "primary"   // wrong on purpose for shoulders/triceps
            s.weight = 0.1
            s.muscle = muscles[slug]
            s.exercise = bench
            ctx.insert(s)
        }
        try ctx.save()

        StimulusWeightSeeder.seedIfNeeded(in: ctx)

        let stims = bench.muscleStimuli ?? []
        // Still exactly 3 rows (no duplicates inserted).
        #expect(stims.count == 3)
        // Weights overwritten to curated values.
        let chest = try #require(stims.first { $0.muscle?.slug == "chest" })
        #expect(abs(chest.weight - 1.0) < 0.001)
        #expect(chest.role == "primary")
        let shoulders = try #require(stims.first { $0.muscle?.slug == "shoulders" })
        #expect(abs(shoulders.weight - 0.5) < 0.001)
        #expect(shoulders.role == "secondary")
    }
}
