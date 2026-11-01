//
//  SeedTests.swift
//  fitbodTests
//
//  Plan 01-PLAN-02-02 anchor suite — proves the load-bearing
//  `ExerciseLibraryImporter` (`@ModelActor`) seed pipeline.
//
//  Nine Swift Testing functions cover:
//   1. `strengthOnlyCount` — at least 600 strength exercises after seed
//      (typical: ~702 per the vendored snapshot).
//   2. `muscleGroupCount` — exactly 17 canonical MuscleGroup rows.
//   3. `idempotent` — second call does not duplicate rows.
//   4. `userSettingsSeeded` — UserSettings singleton with weightUnit == .lb.
//   5. `stimulusWeightingDefaults` — primary=1.0, secondary=0.5.
//   6. `denormalizedMuscleField` — `primaryMuscleSlugsJoined` populated
//      with `|slug|` format for ≥95% of seeded exercises.
//   7. `coldLaunchUnder2s` — performance budget; soft cap at 5s for CI
//      headroom, production target <2s (FOUND-05).
//   8. `reseedKeepsLifterData` — a re-seed updates the catalog in place
//      and keeps everything the lifter made or logged (T128, F296).
//   9. `partialSeedResumes` — a seed that stopped partway resumes without
//      duplicating what reached disk (review WR-01).
//
//  ## Test isolation
//
//  Each test:
//    - keeps the seed-version stamp in its own `UserDefaults` suite
//      (`defaults`), never in `UserDefaults.standard`: the hosted tests
//      share that with the app on the phone, and clearing the phone's stamp
//      made the app's next launch re-seed over the store UI tests left
//      (F296).
//    - builds a fresh in-memory `ModelContainer` via
//      `InMemoryContainer.makeEmpty()` so seed counts are exact.
//    - reads the bundled `exercises.json` from `Bundle.main` (the test
//      target runs inside the `fitbod` host app bundle, so
//      auto-discovered resources resolve cleanly).
//
//  Swift Testing creates a new `SeedTests` instance per `@Test`, with a
//  new stamp suite that `deinit` removes, so tests share nothing mutable
//  and the suite needs no `.serialized`.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("ExerciseLibraryImporter")
final class SeedTests {

    // MARK: - Helpers

    private let defaultsSuiteName = "SeedTests.\(UUID().uuidString)"

    /// Where this test's seed-version stamp lives. A fresh suite starts with
    /// no stamp, so the first `seedIfNeeded` performs work.
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    /// The externalIDs a complete seed holds: every strength-category entry
    /// in the bundled dataset.
    private static func bundledStrengthIDs() throws -> Set<String> {
        let url = try #require(Bundle.main.url(forResource: "exercises", withExtension: "json"))
        let dtos = try JSONDecoder().decode([ExerciseDTO].self, from: Data(contentsOf: url))
        return Set(dtos.filter { EquipmentMapper.shouldImport(category: $0.category) }.map(\.id))
    }

    // MARK: - Test 1: strength-only count

    @Test("Seed inserts at least 600 strength exercises (LIB-01 / FOUND-05)")
    func strengthOnlyCount() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

        let ctx = ModelContext(container)
        let count = try ctx.fetchCount(FetchDescriptor<Exercise>())
        #expect(
            count >= 600,
            "Strength-filtered seed should yield ≥600 exercises (typical: ~702); got \(count)"
        )
    }

    // MARK: - Test 2: MuscleGroup count

    @Test("Seed creates exactly 17 canonical MuscleGroup rows")
    func muscleGroupCount() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

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
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)

        try await importer.seedIfNeeded(defaults: defaults)
        let ctx1 = ModelContext(container)
        let firstExerciseCount = try ctx1.fetchCount(FetchDescriptor<Exercise>())
        let firstMuscleCount = try ctx1.fetchCount(FetchDescriptor<MuscleGroup>())
        let firstStimulusCount = try ctx1.fetchCount(FetchDescriptor<ExerciseMuscleStimulus>())

        // Second call: should short-circuit because UserDefaults stamp
        // now matches bundled SEED_VERSION.
        try await importer.seedIfNeeded(defaults: defaults)
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
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

        let ctx = ModelContext(container)
        let settings = try ctx.fetch(FetchDescriptor<UserSettings>())
        #expect(settings.count == 1, "Exactly one UserSettings row; got \(settings.count)")
        #expect(settings.first?.weightUnit == .lb, "Default weightUnit is .lb (SET-01)")
    }

    // MARK: - Test 5: stimulus weighting defaults

    @Test("Stimulus rows: primary=1.0, secondary=0.5, at least 1 per exercise")
    func stimulusWeightingDefaults() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

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
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

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

        // Spot-check a known chest-primary row. Some bench press variants,
        // such as the powerlifting seed row, are intentionally triceps-primary.
        if let bench = exercises.first(where: { $0.externalID == "Barbell_Bench_Press_-_Medium_Grip" }) {
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
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)

        let start = Date()
        try await importer.seedIfNeeded(defaults: defaults)
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

    // MARK: - Test 8: a re-seed keeps the lifter's data (T128, F296)

    /// Seeds, adds what the lifter makes and logs, clears the stamp and seeds
    /// again. Reads everything back by id or by link query, never through a
    /// relationship: reading a link to a row the seed deleted crashes the
    /// host app instead of failing the test.
    @Test("A re-seed keeps custom exercises, logged and planned links, edited weights and targets, and exercise settings")
    @MainActor // LoggerFixtures, which builds the session and the workout, is main-actor isolated.
    func reseedKeepsLifterData() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

        let ctx = ModelContext(container)
        let benchExternalID = "Barbell_Bench_Press_-_Medium_Grip"
        let bench = try #require(try ctx.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.externalID == benchExternalID }
        )).first)
        let benchChest = try #require(bench.muscleStimuli?.first { $0.muscle?.slug == "chest" })
        let chest = try #require(benchChest.muscle)

        // The bench press's own settings and a stimulus weight the lifter edited.
        bench.unitOverride = .kg
        bench.smallestIncrement = 1.25
        bench.barWeightOverride = 15
        bench.plateauWindowOverride = 4
        bench.plateauToleranceOverride = 0.02
        benchChest.weight = 0.8
        benchChest.userEditedWeight = true
        // A field the dataset supplies, as an older dataset wrote it.
        let datasetInstructions = bench.instructions
        bench.instructions = ["An older dataset's step"]

        // A volume target the lifter edited.
        let target = MuscleVolumeTarget()
        ctx.insert(target)
        target.muscle = chest
        target.mv = 5
        target.mev = 9
        target.mav = 15
        target.mrv = 21
        target.userEdited = true

        // A custom exercise with its own stimulus row.
        let custom = LoggerFixtures.exercise("Cambered Bar Bench", in: ctx)
        custom.isCustom = true
        let customChest = ExerciseMuscleStimulus()
        ctx.insert(customChest)
        customChest.exercise = custom
        customChest.muscle = chest
        customChest.weight = 0.9

        // A seeded exercise the bundled dataset no longer lists.
        let retired = Exercise(
            externalID: "T128_Retired_Lift",
            name: "Retired Lift",
            canonicalName: "retired lift",
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
        ctx.insert(retired)

        // A session that plans both exercises, and a finished workout that
        // logged the bench press.
        _ = try LoggerFixtures.template("Push A", exercises: [bench, custom], in: ctx)
        let startedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let workout = try LoggerFixtures.session(
            exercise: bench, startedAt: startedAt, completedAt: startedAt.addingTimeInterval(3_600),
            sets: [(100, 5, true)], in: ctx
        )
        try ctx.save()

        let benchID = bench.id, chestID = chest.id, benchChestID = benchChest.id, targetID = target.id
        let customID = custom.id, customChestID = customChest.id, retiredID = retired.id, workoutID = workout.id
        let seededCount = try ctx.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom }))
        let stimulusCount = try ctx.fetchCount(FetchDescriptor<ExerciseMuscleStimulus>())

        defaults.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
        try await importer.seedIfNeeded(defaults: defaults)

        let after = ModelContext(container)
        #expect(
            try after.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom })) == seededCount,
            "The re-seed must neither add nor remove seeded exercises"
        )
        #expect(
            try after.fetchCount(FetchDescriptor<ExerciseMuscleStimulus>()) == stimulusCount,
            "The re-seed must neither add nor remove stimulus rows"
        )
        #expect(try after.fetchCount(FetchDescriptor<MuscleGroup>()) == 17)

        // The bench press is the same row: its settings kept, its dataset fields refreshed.
        let benchAfter = try after.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == benchID })).first
        #expect(benchAfter != nil, "The re-seed must update the bench press in place, not replace it")
        #expect(benchAfter?.unitOverride == .kg)
        #expect(benchAfter?.smallestIncrement == 1.25)
        #expect(benchAfter?.barWeightOverride == 15)
        #expect(benchAfter?.plateauWindowOverride == 4)
        #expect(benchAfter?.plateauToleranceOverride == 0.02)
        #expect(benchAfter?.instructions == datasetInstructions, "The re-seed must refresh what the dataset supplies")

        // The edited stimulus weight is still the bench press's chest row.
        let benchChestAfter = try after.fetch(FetchDescriptor<ExerciseMuscleStimulus>(
            predicate: #Predicate { $0.exercise?.id == benchID && $0.muscle?.id == chestID }
        ))
        #expect(benchChestAfter.map(\.id) == [benchChestID])
        #expect(benchChestAfter.first?.weight == 0.8)
        #expect(benchChestAfter.first?.userEditedWeight == true)

        // The edited volume target is still the chest's.
        let chestTargets = try after.fetch(FetchDescriptor<MuscleVolumeTarget>(
            predicate: #Predicate { $0.muscle?.id == chestID }
        ))
        #expect(chestTargets.map(\.id) == [targetID])
        #expect(chestTargets.first.map { [$0.mv, $0.mev, $0.mav, $0.mrv] } == [5, 9, 15, 21])
        #expect(chestTargets.first?.userEdited == true)

        // The custom exercise and its own stimulus row.
        let customAfter = try after.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == customID })).first
        #expect(customAfter?.name == "Cambered Bar Bench")
        #expect(customAfter?.isCustom == true)
        let customChestAfter = try after.fetch(FetchDescriptor<ExerciseMuscleStimulus>(
            predicate: #Predicate { $0.exercise?.id == customID && $0.muscle?.id == chestID }
        ))
        #expect(customChestAfter.map(\.id) == [customChestID])
        #expect(customChestAfter.first?.weight == 0.9)

        // The seeded exercise the dataset no longer lists stays as it was.
        let retiredAfter = try after.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == retiredID })).first
        #expect(retiredAfter?.name == "Retired Lift")
        #expect(retiredAfter?.externalID == "T128_Retired_Lift")

        // The finished workout and the session still point at the same rows.
        let logged = try after.fetch(FetchDescriptor<SessionExercise>(
            predicate: #Predicate { $0.exercise?.id == benchID }
        ))
        #expect(logged.map { $0.session?.id } == [workoutID], "The finished workout must still log the bench press")
        #expect(
            try after.fetchCount(FetchDescriptor<SessionExerciseTemplate>(
                predicate: #Predicate { $0.exercise?.id == benchID }
            )) == 1,
            "The session must still plan the bench press"
        )
        #expect(
            try after.fetchCount(FetchDescriptor<SessionExerciseTemplate>(
                predicate: #Predicate { $0.exercise?.id == customID }
            )) == 1,
            "The session must still plan the custom exercise"
        )
    }

    // MARK: - Test 9: a seed that stopped partway resumes (review WR-01)

    @Test("A seed that stopped partway resumes: what reached disk stays, the rest is inserted once")
    func partialSeedResumes() async throws {
        let container = try InMemoryContainer.makeEmpty()

        // What a seed that failed after its first save leaves: one muscle,
        // one exercise with one of its stimulus rows, and no stamp.
        let ctx = ModelContext(container)
        let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
        ctx.insert(chest)
        let bench = Exercise(
            externalID: "Barbell_Bench_Press_-_Medium_Grip",
            name: "Barbell Bench Press - Medium Grip",
            canonicalName: "barbell bench press - medium grip",
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue,
            primaryMuscleSlugsJoined: "|chest|"
        )
        ctx.insert(bench)
        let benchChest = ExerciseMuscleStimulus()
        ctx.insert(benchChest)
        benchChest.exercise = bench
        benchChest.muscle = chest
        try ctx.save()
        let benchID = bench.id, chestID = chest.id, benchChestID = benchChest.id
        let datasetIDs = try Self.bundledStrengthIDs()

        try await ExerciseLibraryImporter(modelContainer: container).seedIfNeeded(defaults: defaults)

        let after = ModelContext(container)
        let externalIDs = try after.fetch(FetchDescriptor<Exercise>()).compactMap(\.externalID)
        #expect(externalIDs.count == Set(externalIDs).count, "No exercise may be inserted twice")
        #expect(Set(externalIDs) == datasetIDs, "The resumed seed must hold the whole dataset")
        let muscles = try after.fetch(FetchDescriptor<MuscleGroup>())
        #expect(muscles.map(\.slug).sorted() == MuscleRegionMap.allSlugs.sorted(), "Every muscle exactly once")
        #expect(muscles.first { $0.slug == "chest" }?.id == chestID, "The muscle that reached disk stays")
        #expect(
            try after.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == benchID })) == 1,
            "The exercise that reached disk stays"
        )

        // The bench press keeps its chest row and gains the rows the failed
        // seed never wrote.
        let benchStimuli = try after.fetch(FetchDescriptor<ExerciseMuscleStimulus>(
            predicate: #Predicate { $0.exercise?.id == benchID }
        ))
        #expect(benchStimuli.filter { $0.muscle?.slug == "chest" }.map(\.id) == [benchChestID])
        #expect(benchStimuli.count > 1, "The rows the failed seed never wrote must be inserted")
        #expect(
            defaults.integer(forKey: ExerciseLibraryImporter.seedVersionKey)
                == (try ExerciseLibraryImporter.bundledSeedVersion())
        )
    }
}
