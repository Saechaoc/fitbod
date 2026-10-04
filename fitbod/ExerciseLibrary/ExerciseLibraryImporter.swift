//
//  ExerciseLibraryImporter.swift
//  fitbod
//
//  Plan 01-PLAN-02-02 — the load-bearing one-time seed pipeline for the
//  built-in exercise library. Authored as a model-actor so the work
//  (decoding ~1.0 MB of JSON, filtering, and inserting ~702 `Exercise`
//  rows + 17 `MuscleGroup` rows + ~2200 `ExerciseMuscleStimulus` rows)
//  runs off the main thread (PITFALLS.md #6 — never block the main
//  thread on 800+ inserts).
//
//  ## Idempotency
//
//  `UserDefaults["exercise_seed_version"]` stores the integer stamp from
//  the most-recently-applied seed. The bundled `SEED_VERSION.txt` is the
//  source of truth (currently `1`); `seedIfNeeded()` short-circuits when
//  stored ≥ bundled. Future dataset bumps increment `SEED_VERSION.txt`
//  and the next launch performs a fresh seed.
//
//  ## Performance bar
//
//  Cold-launch target: < 2.0 s on iPhone 16 sim (Phase 1 success
//  criterion 1). 100-row batched saves keep SQLite transactions
//  small without paying per-row save overhead.
//
//  ## Critical invariants (RESEARCH PITFALLS)
//
//  - **Pitfall #6** — the model-actor macro synthesizes its own executor +
//    context, so the seed never blocks the main thread. The macro is the
//    non-negotiable piece; do not refactor to a plain `Task { @MainActor in ... }`.
//  - **Pitfall #7 (relationship-link)** — `Exercise` is `modelContext.insert(...)`'d
//    FIRST, then the `ExerciseMuscleStimulus` join rows reference it.
//    Inserting the join row before the parent silently drops the link.
//  - **Pitfall #3 (denormalized filter field)** — `Exercise.primaryMuscleSlugsJoined`
//    is populated as `"|chest|triceps|"` at seed time. The Wave-3 muscle
//    filter predicate uses `.contains("|<slug>|")` against this indexed
//    field; predicates traversing the `[ExerciseMuscleStimulus]`
//    relationship are not allowed by SwiftData's NSPredicate translator.
//  - **Pitfall #11 (autosave race)** — the model-actor macro synthesizes
//    a dedicated context separate from the main context. SQLite WAL mode
//    handles concurrent readers + serialized writers. No explicit
//    `autosaveEnabled = false` is needed; we trust the actor isolation.
//
//  ## Observability
//
//  Logs three lines via `Logger(subsystem: "com.fitbod.app", category: "seed")`:
//  start, filter count, completion (with elapsed seconds). Watch in
//  Console.app filtered by subsystem during first-launch profiling.
//

import Foundation
import OSLog
import SwiftData

/// One-shot seed importer. Construct with the shared `ModelContainer`
/// (typically from `fitbodApp.container`), then `await importer.seedIfNeeded()`
/// inside `RootView.task { ... }` — the wire-up lives in plan 03-01.
@ModelActor
public actor ExerciseLibraryImporter {

    // MARK: - Constants

    /// `UserDefaults` key storing the most-recently-applied seed version.
    public static let seedVersionKey = "exercise_seed_version"

    /// Default stimulus weight for a primary-muscle contributor
    /// (CONTEXT.md Area 1 — seed defaults; hand-curation deferred to Phase 5).
    static let primaryWeight: Double = 1.0

    /// Default stimulus weight for a secondary-muscle contributor.
    static let secondaryWeight: Double = 0.5

    /// Batch size for context-save calls. 100 rows keeps each SQLite
    /// transaction small while avoiding per-row save overhead.
    static let batchSize = 100

    /// Structured logging handle (Console.app filterable subsystem).
    private static let log = Logger(subsystem: "com.fitbod.app", category: "seed")

    // MARK: - Bundled seed version helper

    /// Reads `SEED_VERSION.txt` from the app bundle and returns its
    /// integer value (whitespace-trimmed). Throws if the file is
    /// missing or unreadable.
    public static func bundledSeedVersion(bundle: Bundle = .main) throws -> Int {
        guard let url = bundle.url(forResource: "SEED_VERSION", withExtension: "txt") else {
            throw SeedError.bundledResourceMissing(name: "SEED_VERSION.txt")
        }
        let raw = try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(raw) ?? 0
    }

    // MARK: - Public entry point

    /// Idempotent seed entry point.
    ///
    /// 1. Reads `UserDefaults[seedVersionKey]` and bundled `SEED_VERSION.txt`.
    /// 2. If stored ≥ bundled, returns immediately (no work).
    /// 3. Otherwise loads `exercises.json`, filters to strength
    ///    categories, upserts the 17 `MuscleGroup` rows and the filtered
    ///    exercises (matched by `externalID`; stimulus join rows rebuilt)
    ///    in 100-row batches, and seeds the `UserSettings` singleton if
    ///    absent. Existing rows are updated in place — never deleted — so
    ///    routines, history, volume targets and custom exercises survive a
    ///    library refresh.
    /// 4. On success stamps `UserDefaults[seedVersionKey] = bundled`.
    /// 5. On mid-import failure rolls back unsaved inserts and
    ///    rethrows; the next call's step 3 cleanup makes retry safe
    ///    even if some batches did reach disk before the failure
    ///    (review WR-01).
    ///
    /// - Parameter bundle: Override for the resource bundle. Production
    ///   callers always pass `.main`; tests use a parameterised bundle
    ///   for hermetic resource resolution if desired (currently all tests
    ///   read from `Bundle.main` since the test target runs in the host
    ///   app bundle).
    /// - Throws: `SeedError` on missing bundled resources, decode failure,
    ///   or unrecoverable persistence errors.
    public func seedIfNeeded(bundle: Bundle = .main) async throws {
        let bundled = try Self.bundledSeedVersion(bundle: bundle)
        let stored = UserDefaults.standard.integer(forKey: Self.seedVersionKey)
        guard stored < bundled else {
            Self.log.debug("Seed up to date (stored=\(stored), bundled=\(bundled)) — skipping")
            return
        }
        Self.log.info("Seeding library from version \(stored) → \(bundled)")
        let start = Date()

        // MARK: 0. Index what is already stored (upsert — never wipe)
        //
        // A re-seed (bundled SEED_VERSION bumped) or a retry after a failed
        // partial seed updates built-in rows in place, matched by
        // `externalID` (exercises) and `slug` (muscles), and inserts only
        // what is new. Nothing is deleted: routines and logged workouts
        // point at built-in exercises, muscles own the user's volume
        // targets, and custom exercises (`externalID == nil`) are never
        // touched. Upserting also removes the unique-constraint collision a
        // partial seed used to cause on retry (review WR-01) without the
        // old wipe, which destroyed those references (milestone 1).
        var exercisesByExternalID: [String: Exercise] = [:]
        for exercise in try modelContext.fetch(FetchDescriptor<Exercise>()) {
            if let externalID = exercise.externalID {
                exercisesByExternalID[externalID] = exercise
            }
        }
        var musclesBySlug: [String: MuscleGroup] = [:]
        for muscle in try modelContext.fetch(FetchDescriptor<MuscleGroup>()) {
            musclesBySlug[muscle.slug] = muscle
        }

        // MARK: 1. Load + decode + filter
        guard let url = bundle.url(forResource: "exercises", withExtension: "json") else {
            throw SeedError.bundledResourceMissing(name: "exercises.json")
        }
        let data = try Data(contentsOf: url)
        let allDTOs: [ExerciseDTO]
        do {
            allDTOs = try JSONDecoder().decode([ExerciseDTO].self, from: data)
        } catch {
            throw SeedError.decodeFailed(underlying: error)
        }
        let dtos = allDTOs.filter { EquipmentMapper.shouldImport(category: $0.category) }
        Self.log.info("Filtered \(allDTOs.count) → \(dtos.count) strength exercises")

        // Wrap the remaining steps so a mid-batch failure rolls back
        // unsaved inserts (review WR-01). The MARK: 0 cleanup above
        // covers the on-disk partial-state case across launches; this
        // catches the in-flight context-state case within a single run.
        do {
            // MARK: 2. Upsert canonical MuscleGroup rows
            //
            // Single source of truth: `MuscleRegionMap.allSlugs` — the 17
            // canonical slugs. Iterating `allSlugs` (not `dtos`) means every
            // canonical slug gets a row even if no dataset entry references
            // it yet, which keeps the muscle-volume-target wiring in Phase 5
            // stable across future dataset refreshes.
            for slug in MuscleRegionMap.allSlugs {
                if let existing = musclesBySlug[slug] {
                    existing.displayName = MuscleRegionMap.displayName(for: slug)
                    existing.regionRaw = MuscleRegionMap.region(for: slug).rawValue
                    continue
                }
                let mg = MuscleGroup(
                    slug: slug,
                    displayName: MuscleRegionMap.displayName(for: slug),
                    region: MuscleRegionMap.region(for: slug)
                )
                modelContext.insert(mg)
                musclesBySlug[slug] = mg
            }
            // No save here — the muscle rows ride along with the first
            // exercise batch's save. Inserting them up-front (before any
            // exercise) is enough for the stimulus join rows below to bind
            // to a real parent reference per Pitfall #7.

            // MARK: 3. Insert Exercise rows + stimulus rows in 100-row batches
            var batchCount = 0
            for dto in dtos {
                let canonicalName = dto.name
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)

                // Pitfall #3 — denormalize primary-muscle slugs into a
                // pipe-delimited field so the muscle-filter predicate in
                // Wave 3 can use `.contains("|chest|")` against the
                // `#Index<Exercise>([\.primaryMuscleSlugsJoined])` index.
                let joined = dto.primaryMuscles.isEmpty
                    ? ""
                    : "|" + dto.primaryMuscles.joined(separator: "|") + "|"

                let exercise: Exercise
                if let existing = exercisesByExternalID[dto.id] {
                    // Refresh catalog fields in place; the row keeps its id,
                    // so routines and history keep pointing at it. User
                    // tweaks (increment, bar weight, unit) are left alone.
                    exercise = existing
                    exercise.name = dto.name
                    exercise.canonicalName = canonicalName
                    exercise.equipmentRaw = EquipmentMapper.map(dto.equipment).rawValue
                    exercise.mechanicRaw = dto.mechanic ?? Mechanic.compound.rawValue
                    exercise.forceRaw = dto.force
                    exercise.levelRaw = dto.level
                    exercise.category = dto.category
                    exercise.instructions = dto.instructions
                    exercise.imagePaths = dto.images
                    exercise.primaryMuscleSlugsJoined = joined
                    // Stimulus rows are rebuilt from the dataset below.
                    for stimulus in exercise.muscleStimuli ?? [] {
                        modelContext.delete(stimulus)
                    }
                } else {
                    exercise = Exercise(
                        externalID: dto.id,
                        name: dto.name,
                        canonicalName: canonicalName,
                        equipmentRaw: EquipmentMapper.map(dto.equipment).rawValue,
                        mechanicRaw: dto.mechanic ?? Mechanic.compound.rawValue,
                        forceRaw: dto.force,
                        levelRaw: dto.level,
                        category: dto.category,
                        instructions: dto.instructions,
                        imagePaths: dto.images,
                        isCustom: false,
                        primaryMuscleSlugsJoined: joined
                    )
                    // Pitfall #7 — insert FIRST, then the join rows reference it.
                    // SwiftData drops relationship links silently if the parent
                    // isn't yet inserted into the context.
                    modelContext.insert(exercise)
                    exercisesByExternalID[dto.id] = exercise
                }

                // Stimulus rows: 1.0 primary / 0.5 secondary (CONTEXT.md Area 1).
                // Unknown slugs (i.e., slugs not in `MuscleRegionMap.allSlugs`)
                // are skipped with a debug log — a future dataset bump that
                // adds a new slug would surface here.
                for slug in dto.primaryMuscles {
                    guard let mg = musclesBySlug[slug] else {
                        Self.log.debug("Unknown primary muscle slug '\(slug)' on \(dto.id) — skipping stimulus row")
                        continue
                    }
                    let stim = ExerciseMuscleStimulus(
                        exercise: exercise,
                        muscle: mg,
                        role: "primary",
                        weight: Self.primaryWeight
                    )
                    modelContext.insert(stim)
                }
                for slug in dto.secondaryMuscles {
                    guard let mg = musclesBySlug[slug] else {
                        Self.log.debug("Unknown secondary muscle slug '\(slug)' on \(dto.id) — skipping stimulus row")
                        continue
                    }
                    let stim = ExerciseMuscleStimulus(
                        exercise: exercise,
                        muscle: mg,
                        role: "secondary",
                        weight: Self.secondaryWeight
                    )
                    modelContext.insert(stim)
                }

                batchCount += 1
                if batchCount >= Self.batchSize {
                    try modelContext.save()
                    batchCount = 0
                }
            }
            // Flush the trailing partial batch.
            if batchCount > 0 {
                try modelContext.save()
            }

            // MARK: 4. Seed UserSettings singleton if absent
            //
            // The Settings tab in Wave 3 queries `[UserSettings]` and reads
            // `.first`. Inserting the default row here means the Settings
            // view never has to handle an empty-store state.
            let settingsCount = try modelContext.fetchCount(FetchDescriptor<UserSettings>())
            if settingsCount == 0 {
                modelContext.insert(UserSettings.default())
                try modelContext.save()
            }

            // MARK: 5. Stamp the version stamp
            UserDefaults.standard.set(bundled, forKey: Self.seedVersionKey)
            let elapsed = Date().timeIntervalSince(start)
            Self.log.info("Seed complete in \(elapsed, format: .fixed(precision: 3))s — \(dtos.count) exercises, \(musclesBySlug.count) muscles")
        } catch {
            // Mid-import failure (e.g. disk full mid-batch). Roll back
            // unsaved inserts so the context state matches disk before
            // rethrowing. The next `seedIfNeeded()` call (after the
            // user retries / app relaunches) re-enters MARK: 0 and
            // upserts over any rows that DID make it to disk before the
            // failure, so retry succeeds cleanly (review WR-01).
            modelContext.rollback()
            Self.log.error("Seed failed mid-import — rolling back: \(error.localizedDescription)")
            throw error
        }
    }
}
