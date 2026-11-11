//
//  SeedTests.swift
//  fitbodTests
//
//  Plan 01-PLAN-02-02 anchor suite — proves the load-bearing
//  `ExerciseLibraryImporter` (`@ModelActor`) seed pipeline.
//
//  Ten Swift Testing functions cover:
//   1. `strengthOnlyCount` — at least 600 strength exercises after seed
//      (typical: ~702 per the vendored snapshot).
//   2. `muscleGroupCount` — exactly 19 canonical MuscleGroup rows.
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
//  10. `curationRetagsBodyweightMoves` - the seed applies `curation.json`
//      (RM-022). `ExerciseCatalogTests` checks the file itself.
//  11. `cardioAddsNoMuscleVolume` - a cardio row imports under its curated
//      name with no muscle, so its sets add no muscle volume (RM-062).
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

    /// The externalIDs a complete seed holds: every entry of the bundled
    /// catalog.
    private static func bundledIDs() throws -> Set<String> {
        Set(try ExerciseCatalog.bundled().map(\.id))
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

    @Test("the seed applies curation.json's equipment and tracking")
    func curationRetagsBodyweightMoves() async throws {
        let container = try InMemoryContainer.makeEmpty()
        try await ExerciseLibraryImporter(modelContainer: container).seedIfNeeded(defaults: defaults)
        let context = ModelContext(container)
        func seeded(_ externalID: String) throws -> Exercise {
            try #require(try context.fetch(FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.externalID == externalID }
            )).first)
        }
        let dip = try seeded("Parallel_Bar_Dip")
        #expect(dip.equipment == .bodyweight)
        #expect(SessionSetActions.isValidSet(weight: 0, reps: 10, tracking: dip.tracking))

        // Seed 5: holds and carries are timed, a carry keeps its load, the
        // band-assisted pull-up takes assistance, and Smith and EZ-bar rows
        // have their own equipment.
        let plank = try seeded("Plank")
        #expect(plank.tracking == .duration)
        #expect(plank.timedValues.isEmpty)
        #expect(try seeded("Farmers_Walk").timedValues == [.weight])
        #expect(try seeded("Band_Assisted_Pull-Up").tracking == .assistedReps)
        #expect(try seeded("Smith_Machine_Squat").equipment == .smithMachine)
        #expect(try seeded("EZ-Bar_Curl").equipment == .ezBar)
        #expect(try seeded("Bodyweight_Flyes").equipment == .bodyweight)
        // A row curation does not list keeps the tracking its equipment implies.
        let bench = try seeded("Barbell_Bench_Press_-_Medium_Grip")
        #expect(bench.trackingRaw == nil)
        #expect(bench.tracking == .weightReps)
    }

    @Test("a cardio row imports under its curated name with no muscle, and its sets add no muscle volume")
    @MainActor // LoggerFixtures, which builds the workouts, is main-actor isolated.
    func cardioAddsNoMuscleVolume() async throws {
        let container = try InMemoryContainer.makeEmpty()
        try await ExerciseLibraryImporter(modelContainer: container).seedIfNeeded(defaults: defaults)
        let ctx = ModelContext(container)
        func seeded(_ externalID: String) throws -> Exercise {
            try #require(try ctx.fetch(FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.externalID == externalID }
            )).first)
        }
        let climber = try seeded("Stairmaster")
        #expect(climber.name == "Stair Climber" && climber.canonicalName == "stair climber")
        #expect(climber.equipment == .cardioMachine && climber.isCardio)
        // Seed 10: a stair machine's console number is its speed, stored as a level.
        #expect(climber.tracking == .durationStepSpeed && climber.timedValues == [.level])
        #expect(try seeded("Step_Mill").tracking == .durationStepSpeed)
        #expect(try seeded("Elliptical_Trainer").tracking == .durationLevel)
        #expect(climber.aliasesJoined.split(separator: "|").contains("stairmaster"))
        // Upstream lists quadriceps for it, which would count as leg volume.
        #expect(climber.primaryMuscleSlugsJoined.isEmpty)
        #expect((climber.muscleStimuli ?? []).isEmpty)
        // Seed 10: a treadmill records its speed and incline (RM-062).
        #expect(try seeded("Walking_Treadmill").timedValues == [.speed, .incline])
        #expect(try seeded("Running_Treadmill").timedValues == [.speed, .incline])
        #expect(try seeded("Rowing_Stationary").timedValues == [.distance])
        #expect(try seeded("Rope_Jumping").timedValues.isEmpty, "Jump Rope logs a time alone")
        // Cardio that curation does not import stays out, as stretching does.
        #expect(try ctx.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { $0.externalID == "Skating" })) == 0)

        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let cardio = try LoggerFixtures.session(
            exercise: climber, startedAt: start, completedAt: start.addingTimeInterval(1_500),
            sets: [(0, 0, true)], in: ctx
        )
        let set = try #require(cardio.exercises?.first?.sets?.first)
        set.durationSeconds = 1_200
        set.level = 8
        try ctx.save()
        #expect(set.countsAsWork && set.hasResult, "the cardio set is a logged working set")
        let weekStart = start.addingTimeInterval(-24 * 3_600)
        #expect(
            FatigueModel.weeklyVolumes(weekStart: weekStart, in: ctx).values
                .allSatisfy { $0.directSets == 0 && $0.indirectSets == 0 },
            "cardio must add no muscle volume"
        )
        // The same week counts a bench press set, so the window is the right one.
        try LoggerFixtures.session(
            exercise: try seeded("Barbell_Bench_Press_-_Medium_Grip"), startedAt: start,
            completedAt: start.addingTimeInterval(1_500), sets: [(100, 5, true)], in: ctx
        )
        #expect(FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: weekStart, in: ctx).directSets == 1)
    }

    // MARK: - Test 2: MuscleGroup count

    @Test("Seed creates exactly 19 canonical MuscleGroup rows")
    func muscleGroupCount() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

        let ctx = ModelContext(container)
        let muscles = try ctx.fetch(FetchDescriptor<MuscleGroup>())
        #expect(
            muscles.count == 19,
            "The app tracks 19 muscles; got \(muscles.count)"
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

    @Test("Stimulus rows: primary=1.0, secondary 0.25 or 0.5, at least 1 per exercise")
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
            secondary.allSatisfy { [0.25, 0.5].contains($0.weight) },
            "A secondary stimulus row gets 0.5 or 0.25 of a set (muscles.json, RM-065)"
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
        #expect(try after.fetchCount(FetchDescriptor<MuscleGroup>()) == 19)

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

    @Test("A re-seed gives a logged exercise with no name snapshot the name it shows, before any rename")
    @MainActor // LoggerFixtures is main-actor isolated.
    func reseedKeepsLoggedNames() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

        let ctx = ModelContext(container)
        let benchExternalID = "Barbell_Bench_Press_-_Medium_Grip"
        let bench = try #require(try ctx.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.externalID == benchExternalID }
        )).first)
        let startedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let workout = try LoggerFixtures.session(
            exercise: bench, startedAt: startedAt, completedAt: startedAt.addingTimeInterval(3_600),
            sets: [(100, 5, true)], in: ctx
        )
        // Logged before name snapshots existed (2026-10-02), under a name
        // the catalog has changed since, so the re-seed renames the bench.
        let logged = try #require(workout.exercises?.first)
        logged.exerciseNameSnapshot = ""
        let catalogName = bench.name
        let shownName = "Bench Press (an older catalog name)"
        bench.name = shownName
        try ctx.save()
        let loggedID = logged.id

        defaults.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
        try await importer.seedIfNeeded(defaults: defaults)

        let after = ModelContext(container)
        let reread = try #require(try after.fetch(FetchDescriptor<SessionExercise>(
            predicate: #Predicate { $0.id == loggedID }
        )).first)
        #expect(reread.exerciseNameSnapshot == shownName)
        #expect(reread.exercise?.name == catalogName, "the re-seed must have renamed the bench")
    }

    @Test("A row curation hides stays listed while a logged workout or a routine uses it")
    @MainActor // LoggerFixtures is main-actor isolated.
    func hiddenRowsInUseStayListed() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

        func seeded(_ externalID: String, in context: ModelContext) throws -> Exercise {
            try #require(try context.fetch(FetchDescriptor<Exercise>(
                predicate: #Predicate { $0.externalID == externalID }
            )).first)
        }
        let ctx = ModelContext(container)
        let logged = try seeded("Barbell_Shoulder_Press", in: ctx)
        let planned = try seeded("Running_Treadmill", in: ctx)
        let unused = try seeded("Car_Deadlift", in: ctx)
        #expect(logged.isHidden && planned.isHidden && unused.isHidden)

        // Picked before a seed hid them.
        let startedAt = Date(timeIntervalSince1970: 1_790_000_000)
        _ = try LoggerFixtures.session(
            exercise: logged, startedAt: startedAt, completedAt: startedAt.addingTimeInterval(3_600),
            sets: [(60, 8, true)], in: ctx
        )
        let routine = SessionTemplate()
        ctx.insert(routine)
        let item = SessionExerciseTemplate()
        ctx.insert(item)
        item.sessionTemplate = routine
        item.exercise = planned
        try ctx.save()

        defaults.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
        try await importer.seedIfNeeded(defaults: defaults)

        let after = ModelContext(container)
        #expect(try seeded("Barbell_Shoulder_Press", in: after).isHidden == false, "a logged exercise stays listed")
        #expect(try seeded("Running_Treadmill", in: after).isHidden == false, "a planned exercise stays listed")
        #expect(try seeded("Car_Deadlift", in: after).isHidden)
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
        let datasetIDs = try Self.bundledIDs()

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

    // MARK: - Muscle credits and the three delts (RM-065)

    /// The rows an exercise has after a seed, as credits, in slug order.
    private static func credits(of externalID: String, in ctx: ModelContext) throws -> [MuscleCredit] {
        try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>(
            predicate: #Predicate { $0.exercise?.externalID == externalID }
        ))
        .map { MuscleCredit(slug: $0.muscle?.slug ?? "", role: $0.role, weight: $0.weight) }
        .sorted { $0.slug < $1.slug }
    }

    private static func muscle(_ slug: String, in ctx: ModelContext) throws -> MuscleGroup {
        try #require(try ctx.fetch(FetchDescriptor<MuscleGroup>(predicate: #Predicate { $0.slug == slug })).first)
    }

    /// Seed 7's store: upstream's one shoulders muscle with a volume target,
    /// an upright row crediting it, and a hack squat with upstream's calves
    /// row and an older glutes weight. Reads back by link query only.
    @Test("A re-seed makes catalog stimulus rows match their muscle credits and deletes the shoulders muscle")
    func reseedMatchesMuscleCredits() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

        let ctx = ModelContext(container)
        func exercise(_ externalID: String) throws -> Exercise {
            try #require(try ctx.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.externalID == externalID })).first)
        }
        let shoulders = MuscleGroup(slug: "shoulders", displayName: "Shoulders", region: .upper)
        ctx.insert(shoulders)
        let target = MuscleVolumeTarget()
        ctx.insert(target)
        target.muscle = shoulders
        let upright = try exercise("Upright_Barbell_Row")
        for stimulus in upright.muscleStimuli ?? [] { ctx.delete(stimulus) }
        ctx.insert(ExerciseMuscleStimulus(exercise: upright, muscle: shoulders, role: "primary", weight: 1))
        ctx.insert(ExerciseMuscleStimulus(exercise: upright, muscle: try Self.muscle("traps", in: ctx), role: "secondary", weight: 0.5))
        upright.primaryMuscleSlugsJoined = "|shoulders|"
        let hack = try exercise("Hack_Squat")
        ctx.insert(ExerciseMuscleStimulus(exercise: hack, muscle: try Self.muscle("calves", in: ctx), role: "secondary", weight: 0.5))
        try #require(hack.muscleStimuli?.first { $0.muscle?.slug == "glutes" }).weight = 0.4
        try ctx.save()

        defaults.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
        try await importer.seedIfNeeded(defaults: defaults)

        let after = ModelContext(container)
        let catalog = Dictionary(uniqueKeysWithValues: try ExerciseCatalog.bundled().map { ($0.id, $0) })
        for id in ["Upright_Barbell_Row", "Hack_Squat"] {
            let expected = try #require(catalog[id]).muscles.sorted { $0.slug < $1.slug }
            #expect(try Self.credits(of: id, in: after) == expected, "\(id) must have exactly its muscle credits")
        }
        let uprightAfter = try #require(try after.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.externalID == "Upright_Barbell_Row" }
        )).first)
        #expect(uprightAfter.primaryMuscleSlugsJoined == "|side delts|traps|")
        #expect(try after.fetchCount(FetchDescriptor<MuscleGroup>(predicate: #Predicate { $0.slug == "shoulders" })) == 0)
        #expect(try after.fetchCount(FetchDescriptor<MuscleVolumeTarget>()) == 0, "the shoulders target goes with its muscle")
        #expect(try after.fetchCount(FetchDescriptor<MuscleGroup>()) == MuscleRegionMap.allSlugs.count)
    }

    @Test("A non-catalog exercise's shoulders credit moves to the delt its family credits most, or to the front delts")
    func customShouldersCreditMovesToADelt() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)

        let ctx = ModelContext(container)
        let shoulders = MuscleGroup(slug: "shoulders", displayName: "Shoulders", region: .upper)
        ctx.insert(shoulders)
        func custom(_ name: String, family: String?, joined: String) -> Exercise {
            let exercise = Exercise(
                name: name, canonicalName: name.lowercased(), equipmentRaw: Equipment.machine.rawValue,
                mechanicRaw: Mechanic.isolation.rawValue, isCustom: true, primaryMuscleSlugsJoined: joined
            )
            exercise.familyName = family
            ctx.insert(exercise)
            return exercise
        }
        // A machine in the Lateral Raise family: its shoulders credit is primary.
        let raise = custom("Arsenal Lateral", family: "Lateral Raise", joined: "|shoulders|")
        ctx.insert(ExerciseMuscleStimulus(exercise: raise, muscle: shoulders, role: "primary", weight: 1))
        // No family, already crediting the front delts less than shoulders.
        let press = custom("Odd Press", family: nil, joined: "|chest|")
        ctx.insert(ExerciseMuscleStimulus(exercise: press, muscle: try Self.muscle("chest", in: ctx), role: "primary", weight: 1))
        ctx.insert(ExerciseMuscleStimulus(exercise: press, muscle: shoulders, role: "secondary", weight: 0.5))
        ctx.insert(ExerciseMuscleStimulus(exercise: press, muscle: try Self.muscle("front delts", in: ctx), role: "secondary", weight: 0.25))
        // A row a newer dataset dropped keeps its credit too, on its family's delt.
        let dropped = custom("Dropped Fly", family: "Rear Delt Fly", joined: "|shoulders|")
        dropped.externalID = "Dropped_Rear_Fly"
        dropped.isCustom = false
        ctx.insert(ExerciseMuscleStimulus(exercise: dropped, muscle: shoulders, role: "primary", weight: 1))
        try ctx.save()
        let raiseID = raise.id, pressID = press.id, droppedID = dropped.id

        defaults.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
        try await importer.seedIfNeeded(defaults: defaults)

        let after = ModelContext(container)
        func credits(_ id: UUID) throws -> [MuscleCredit] {
            try after.fetch(FetchDescriptor<ExerciseMuscleStimulus>(predicate: #Predicate { $0.exercise?.id == id }))
                .map { MuscleCredit(slug: $0.muscle?.slug ?? "", role: $0.role, weight: $0.weight) }
                .sorted { $0.slug < $1.slug }
        }
        func joined(_ id: UUID) throws -> String? {
            try after.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })).first?.primaryMuscleSlugsJoined
        }
        #expect(try credits(raiseID) == [MuscleCredit(slug: "side delts", role: "primary", weight: 1)])
        #expect(try joined(raiseID) == "|side delts|")
        #expect(try credits(pressID) == [
            MuscleCredit(slug: "chest", role: "primary", weight: 1),
            MuscleCredit(slug: "front delts", role: "secondary", weight: 0.5),
        ])
        #expect(try joined(pressID) == "|chest|")
        #expect(try credits(droppedID) == [MuscleCredit(slug: "rear delts", role: "primary", weight: 1)])
        #expect(try joined(droppedID) == "|rear delts|")
        #expect(try after.fetchCount(FetchDescriptor<MuscleGroup>(predicate: #Predicate { $0.slug == "shoulders" })) == 0)
    }

    /// RootView keeps the tabs away while this is true, because a seed
    /// deletes rows the tabs read (RM-065).
    @Test("A seed is pending until the importer has seeded the bundled catalog")
    func seedIsPendingUntilSeeded() async throws {
        #expect(ExerciseLibraryImporter.seedIsPending(defaults: defaults))
        let importer = ExerciseLibraryImporter(modelContainer: try InMemoryContainer.makeEmpty())
        try await importer.seedIfNeeded(defaults: defaults)
        #expect(!ExerciseLibraryImporter.seedIsPending(defaults: defaults))
    }
}
