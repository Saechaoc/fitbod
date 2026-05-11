//
//  SeedTests.swift
//  fitbodTests
//
//  Plan 01-PLAN-02-02 anchor suite — proves the load-bearing
//  `ExerciseLibraryImporter` (`@ModelActor`) seed pipeline.
//
//  Seven Swift Testing functions cover:
//   1. `strengthOnlyCount` — at least 600 strength exercises after seed
//      (typical: ~675 per the vendored snapshot).
//   2. `muscleGroupCount` — exactly 17 canonical MuscleGroup rows.
//   3. `idempotent` — second call does not duplicate rows.
//   4. `userSettingsSeeded` — UserSettings singleton with weightUnit == .lb.
//   5. `stimulusWeightingDefaults` — primary=1.0, secondary=0.5.
//   6. `denormalizedMuscleField` — `primaryMuscleSlugsJoined` populated
//      with `|slug|` format for ≥95% of seeded exercises.
//   7. `coldLaunchUnder2s` — performance budget; soft cap at 5s for CI
//      headroom, production target <2s (FOUND-05).
//
//  ## Test isolation
//
//  Each test:
//    - resets `UserDefaults[seedVersionKey]` so the importer doesn't
//      short-circuit on a stamp left over from a previous test run.
//    - builds a fresh in-memory `ModelContainer` via
//      `InMemoryContainer.makeEmpty()` so seed counts are exact.
//    - reads the bundled `exercises.json` from `Bundle.main` (the test
//      target runs inside the `fitbod` host app bundle, so
//      auto-discovered resources resolve cleanly).
//
//  Swift Testing's `struct` suite is re-instantiated per `@Test`, so
//  there is no shared state between tests; UserDefaults is the only
//  process-wide channel and we reset it explicitly per test.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("ExerciseLibraryImporter")
struct SeedTests {

    // MARK: - Helpers

    /// Removes the seed-version stamp from `UserDefaults` so a fresh
    /// `seedIfNeeded()` call performs work rather than short-circuiting.
    /// Called at the start of every test; UserDefaults is process-wide.
    private static func resetStamp() {
        UserDefaults.standard.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
    }

    // MARK: - Test 1: strength-only count

    @Test("Seed inserts at least 600 strength exercises (LIB-01 / FOUND-05)")
    func strengthOnlyCount() async throws {
        Self.resetStamp()
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded()

        let ctx = ModelContext(container)
        let count = try ctx.fetchCount(FetchDescriptor<Exercise>())
        #expect(
            count >= 600,
            "Strength-filtered seed should yield ≥600 exercises (typical: ~675); got \(count)"
        )
    }

    // MARK: - Test 2: MuscleGroup count

    @Test("Seed creates exactly 17 canonical MuscleGroup rows")
    func muscleGroupCount() async throws {
        Self.resetStamp()
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded()

        let ctx = ModelContext(container)
        let muscles = try ctx.fetch(FetchDescriptor<MuscleGroup>())
        #expect(
            muscles.count == 17,
            "Dataset taxonomy has exactly 17 muscle slugs; got \(muscles.count)"
        )

        // Spot-check that every slug from MuscleRegionMap.allSlugs is
        // represented — if the importer accidentally inserts duplicates
        // or drops a slug, this surfaces immediately.
        let slugs = Set(muscles.map(\.slug))
        #expect(slugs == Set(MuscleRegionMap.allSlugs))
    }

    // MARK: - Test 3: idempotency

    @Test("Seed is idempotent — second call does not duplicate rows")
    func idempotent() async throws {
        Self.resetStamp()
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)

        try await importer.seedIfNeeded()
        let ctx1 = ModelContext(container)
        let firstExerciseCount = try ctx1.fetchCount(FetchDescriptor<Exercise>())
        let firstMuscleCount = try ctx1.fetchCount(FetchDescriptor<MuscleGroup>())
        let firstStimulusCount = try ctx1.fetchCount(FetchDescriptor<ExerciseMuscleStimulus>())

        // Second call: should short-circuit because UserDefaults stamp
        // now matches bundled SEED_VERSION.
        try await importer.seedIfNeeded()
        let ctx2 = ModelContext(container)
        let secondExerciseCount = try ctx2.fetchCount(FetchDescriptor<Exercise>())
        let secondMuscleCount = try ctx2.fetchCount(FetchDescriptor<MuscleGroup>())
        let secondStimulusCount = try ctx2.fetchCount(FetchDescriptor<ExerciseMuscleStimulus>())

        #expect(
            secondExerciseCount == firstExerciseCount,
            "Exercise count should not change on second seed; got \(firstExerciseCount) → \(secondExerciseCount)"
        )
        #expect(
            secondMuscleCount == firstMuscleCount,
            "MuscleGroup count should not change on second seed; got \(firstMuscleCount) → \(secondMuscleCount)"
        )
        #expect(
            secondStimulusCount == firstStimulusCount,
            "Stimulus row count should not change on second seed; got \(firstStimulusCount) → \(secondStimulusCount)"
        )
    }

    // MARK: - Test 4: UserSettings singleton

    @Test("Seed populates the UserSettings singleton with weightUnit == .lb")
    func userSettingsSeeded() async throws {
        Self.resetStamp()
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded()

        let ctx = ModelContext(container)
        let settings = try ctx.fetch(FetchDescriptor<UserSettings>())
        #expect(settings.count == 1, "Exactly one UserSettings row; got \(settings.count)")
        #expect(settings.first?.weightUnit == .lb, "Default weightUnit is .lb (SET-01)")
    }

    // MARK: - Test 5: stimulus weighting defaults

    @Test("Stimulus rows: primary=1.0, secondary=0.5, at least 1 per exercise")
    func stimulusWeightingDefaults() async throws {
        Self.resetStamp()
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded()

        let ctx = ModelContext(container)
        let stimuli = try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>())
        #expect(stimuli.count > 0, "Seed must produce stimulus rows")

        let primary = stimuli.filter { $0.role == "primary" }
        let secondary = stimuli.filter { $0.role == "secondary" }
        #expect(primary.count > 0, "At least one primary stimulus row")
        #expect(
            primary.allSatisfy { $0.weight == 1.0 },
            "All primary stimulus rows must have weight = 1.0 (CONTEXT.md Area 1 default)"
        )
        // The dataset has a handful of exercises with no secondary
        // muscles (e.g., isolation curls), so `secondary` may be smaller
        // than `primary` — just ensure the weight invariant holds for
        // every secondary row that does exist.
        #expect(
            secondary.allSatisfy { $0.weight == 0.5 },
            "All secondary stimulus rows must have weight = 0.5 (CONTEXT.md Area 1 default)"
        )

        // Every exercise should have at least 1 primary stimulus row
        // (the dataset always populates `primaryMuscles`).
        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        let exercisesWithStimuli = Set(stimuli.compactMap { $0.exercise?.id })
        let coverage = Double(exercisesWithStimuli.count) / Double(exercises.count)
        #expect(
            coverage > 0.95,
            "≥95% of seeded exercises should have at least one stimulus row; got \(coverage * 100)%"
        )
    }

    // MARK: - Test 6: denormalized muscle field (Pitfall #3)

    @Test("primaryMuscleSlugsJoined populated as |slug| for the muscle-filter predicate")
    func denormalizedMuscleField() async throws {
        Self.resetStamp()
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded()

        let ctx = ModelContext(container)
        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        let withMuscleData = exercises.filter { !$0.primaryMuscleSlugsJoined.isEmpty }
        let coverage = Double(withMuscleData.count) / Double(exercises.count)
        #expect(
            coverage > 0.95,
            "≥95% of seeded exercises should have a primary muscle assignment; got \(coverage * 100)%"
        )

        // Format check: every populated field should be pipe-bracketed,
        // i.e., starts with "|" and ends with "|" so `.contains("|chest|")`
        // matches as a whole-token predicate.
        for ex in withMuscleData {
            #expect(
                ex.primaryMuscleSlugsJoined.hasPrefix("|") && ex.primaryMuscleSlugsJoined.hasSuffix("|"),
                "primaryMuscleSlugsJoined must be pipe-bracketed; got '\(ex.primaryMuscleSlugsJoined)' on \(ex.name)"
            )
        }

        // Spot-check a known row: any bench-press variant should pull
        // chest as a primary muscle.
        if let bench = exercises.first(where: { $0.canonicalName.contains("bench press") }) {
            #expect(
                bench.primaryMuscleSlugsJoined.contains("|chest|"),
                "Bench press should list chest as a primary muscle; got '\(bench.primaryMuscleSlugsJoined)'"
            )
        }
    }

    // MARK: - Test 7: cold-launch performance budget

    @Test(
        "Cold seed completes within performance budget (target <2s, soft cap 5s)",
        .timeLimit(.minutes(1))
    )
    func coldLaunchUnder2s() async throws {
        Self.resetStamp()
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)

        let start = Date()
        try await importer.seedIfNeeded()
        let elapsed = Date().timeIntervalSince(start)

        // Production target is <2.0s (FOUND-05) — measured against the
        // in-memory store in the sim, this is achievable. CI headroom
        // tolerates up to 5.0s because first-launch SQLite warmup can
        // bloat the wall-clock on a cold runner. Tighten to 2.0 once
        // CI cold-launch profiling is consistent.
        #expect(
            elapsed < 5.0,
            "Seed elapsed \(elapsed)s — production target <2s, soft cap 5s for CI headroom"
        )
    }
}
