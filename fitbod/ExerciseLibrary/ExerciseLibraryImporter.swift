//
//  ExerciseLibraryImporter.swift
//  fitbod
//
//  Plan 01-PLAN-02-02 — the load-bearing one-time seed pipeline for the
//  built-in exercise library. Authored as a model-actor so the work
//  (decoding ~1.0 MB of JSON, resolving it through `ExerciseCatalog`, and
//  inserting ~840 `Exercise` rows + 19 `MuscleGroup` rows + ~2300
//  `ExerciseMuscleStimulus` rows)
//  runs off the main thread (PITFALLS.md #6 — never block the main
//  thread on 800+ inserts).
//
//  ## Idempotency
//
//  `UserDefaults["exercise_seed_version"]` stores the integer stamp from
//  the most-recently-applied seed. The bundled `SEED_VERSION.txt` is the
//  source of truth; `seedIfNeeded()` short-circuits when stored ≥ bundled.
//  Future dataset bumps increment `SEED_VERSION.txt` and the next launch
//  re-seeds in place (see below).
//
//  ## Re-seeding in place (T128, F296)
//
//  A seed into a store that already holds the library finds each seeded
//  exercise by `externalID` and each muscle by `slug`, updates the fields
//  the dataset supplies, and inserts what is missing. Custom exercises, the
//  exercise links of logged workouts and sessions, edited volume targets,
//  an exercise's own settings, and seeded exercises a newer dataset dropped
//  all stay.
//  A catalog exercise's stimulus rows follow its muscle credits exactly
//  (`muscles.json`, RM-065): a row for a muscle it no longer credits is
//  deleted, unless the lifter edited its weight. The retired "shoulders"
//  muscle is deleted with its volume target, after the rows of exercises
//  outside the catalog move to a delt. Deletes are safe because `RootView` shows the
//  library splash, and no tab, while a seed runs: a view holding a deleted
//  model would crash on its next read.
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

    /// True when the bundled catalog is newer than the one the store holds,
    /// so the next `seedIfNeeded` writes. `RootView` keeps the tabs away
    /// until it has run.
    public static func seedIsPending(bundle: Bundle = .main, defaults: UserDefaults = .standard) -> Bool {
        defaults.integer(forKey: seedVersionKey) < ((try? bundledSeedVersion(bundle: bundle)) ?? 0)
    }

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
    /// 1. Reads `defaults[seedVersionKey]` and bundled `SEED_VERSION.txt`.
    /// 2. If stored ≥ bundled, returns immediately (no work).
    /// 3. Otherwise resolves the bundled catalog (`ExerciseCatalog`),
    ///    upserts the `MuscleGroup` rows by `slug`, upserts the catalog's
    ///    exercises by `externalID` with their stimulus rows in 100-row
    ///    batches, and seeds the `UserSettings` singleton if absent. Only
    ///    stimulus rows and the retired "shoulders" muscle are deleted (see
    ///    "Re-seeding in place" above).
    /// 4. On success stamps `defaults[seedVersionKey] = bundled`.
    /// 5. On mid-import failure rolls back unsaved changes and rethrows.
    ///    The next call finds the batches that did reach disk by
    ///    `externalID` and `slug` and inserts only the rest, so a retry
    ///    never collides with the `#Unique` rules (review WR-01).
    ///
    /// - Parameters:
    ///   - bundle: Override for the resource bundle. Production callers
    ///     always pass `.main`; tests use a parameterised bundle for
    ///     hermetic resource resolution if desired (currently all tests
    ///     read from `Bundle.main` since the test target runs in the host
    ///     app bundle).
    ///   - defaults: Where the seed-version stamp lives. Production callers
    ///     use `.standard`; tests pass their own suite, because the hosted
    ///     tests share `.standard` with the app on the phone (F296).
    /// - Throws: `SeedError` on missing bundled resources, decode failure,
    ///   or unrecoverable persistence errors.
    public func seedIfNeeded(bundle: Bundle = .main, defaults: UserDefaults = .standard) async throws {
        let bundled = try Self.bundledSeedVersion(bundle: bundle)
        let stored = defaults.integer(forKey: Self.seedVersionKey)
        guard stored < bundled else {
            Self.log.debug("Seed up to date (stored=\(stored), bundled=\(bundled)) — skipping")
            return
        }
        Self.log.info("Seeding library from version \(stored) → \(bundled)")
        let start = Date()

        // MARK: 1. Resolve the bundled catalog
        let entries = try ExerciseCatalog.bundled(in: bundle)
        Self.log.info("Catalog resolved, exercise count \(entries.count)")

        // Wrap the remaining steps so a mid-batch failure rolls back
        // unsaved changes (review WR-01). Batches that already reached
        // disk are matched by externalID and slug on the next run, so the
        // retry never inserts them twice.
        do {
            // MARK: 2. Upsert canonical MuscleGroup rows by slug
            //
            // Single source of truth: `MuscleRegionMap.allSlugs` — the
            // canonical slugs. Iterating `allSlugs` (not `entries`) means every
            // canonical slug gets a row even if no dataset entry references
            // it yet, which keeps the muscle-volume-target wiring in Phase 5
            // stable across future dataset refreshes. An existing row keeps
            // its identity, so its volume targets and stimulus rows stay.
            var musclesBySlug: [String: MuscleGroup] = [:]
            for muscle in try modelContext.fetch(FetchDescriptor<MuscleGroup>()) where musclesBySlug[muscle.slug] == nil {
                musclesBySlug[muscle.slug] = muscle
            }
            for slug in MuscleRegionMap.allSlugs {
                let displayName = MuscleRegionMap.displayName(for: slug)
                let region = MuscleRegionMap.region(for: slug)
                if let muscle = musclesBySlug[slug] {
                    // Write only what differs: an equal assignment still
                    // marks the row changed and re-renders its views.
                    if muscle.displayName != displayName { muscle.displayName = displayName }
                    if muscle.regionRaw != region.rawValue { muscle.regionRaw = region.rawValue }
                } else {
                    let mg = MuscleGroup(slug: slug, displayName: displayName, region: region)
                    modelContext.insert(mg)
                    musclesBySlug[slug] = mg
                }
            }
            // No save here — the muscle rows ride along with the first
            // exercise batch's save. Inserting them up-front (before any
            // exercise) is enough for the stimulus join rows below to bind
            // to a real parent reference per Pitfall #7.

            // MARK: 2b. Retire the one "shoulders" muscle (RM-065)
            //
            // Step 4 gives catalog exercises their delts. The shoulders
            // credit of an exercise outside the catalog, a custom one or a
            // row a newer dataset dropped, moves to the delt its family
            // credits most, or to the front delts; the muscle itself goes
            // once the exercises are saved.
            let retired = musclesBySlug[MuscleRegionMap.retiredShouldersSlug]
            if let retired {
                let familyDelts = Self.familyDelts(entries)
                let catalogIDs = Set(entries.map(\.id))
                for stimulus in retired.stimuli ?? [] {
                    guard let exercise = stimulus.exercise,
                          !(exercise.externalID.map(catalogIDs.contains) ?? false) else { continue }
                    let slug = exercise.familyName.flatMap { familyDelts[$0] } ?? "front delts"
                    Self.move(stimulus, of: exercise, to: slug, muscle: musclesBySlug[slug], in: modelContext)
                }
            }

            // MARK: 3. Find the exercises an earlier seed inserted
            //
            // By externalID. Custom exercises have none, so the seed never
            // matches or touches them.
            var exercisesByExternalID: [String: Exercise] = [:]
            let seeded = FetchDescriptor<Exercise>(predicate: #Predicate { $0.externalID != nil })
            for exercise in try modelContext.fetch(seeded) {
                guard let externalID = exercise.externalID, exercisesByExternalID[externalID] == nil else { continue }
                exercisesByExternalID[externalID] = exercise
            }
            // Their stimulus rows, from one fetch rather than one
            // relationship fault per exercise.
            var stimuliByExercise: [PersistentIdentifier: [ExerciseMuscleStimulus]] = [:]
            if !exercisesByExternalID.isEmpty {
                for stimulus in try modelContext.fetch(FetchDescriptor<ExerciseMuscleStimulus>()) {
                    guard let exercise = stimulus.exercise, exercise.externalID != nil else { continue }
                    stimuliByExercise[exercise.persistentModelID, default: []].append(stimulus)
                }
            }

            // MARK: 3b. Exercises in use
            //
            // A workout logged before name snapshots existed (2026-10-02)
            // shows its exercise's live name. It gets that name now, before
            // step 4 writes a curated rename, so History keeps the name the
            // lifter logged. A row a logged workout or a routine uses stays
            // listed when curation hides it, so it can still be picked
            // (RM-022).
            var inUse = Set<PersistentIdentifier>()
            for logged in try modelContext.fetch(FetchDescriptor<SessionExercise>()) {
                guard let exercise = logged.exercise else { continue }
                inUse.insert(exercise.persistentModelID)
                if logged.exerciseNameSnapshot.isEmpty, !exercise.name.isEmpty {
                    logged.exerciseNameSnapshot = exercise.name
                }
            }
            for planned in try modelContext.fetch(FetchDescriptor<SessionExerciseTemplate>()) {
                if let exercise = planned.exercise { inUse.insert(exercise.persistentModelID) }
            }

            // MARK: 4. Upsert Exercise rows + their stimulus rows in 100-row batches
            var batchCount = 0
            var insertedCount = 0
            var updatedCount = 0
            for entry in entries {
                // The curated name, so a renamed row is found by its new name.
                let canonicalName = entry.name
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)

                // Pitfall #3 — denormalize primary-muscle slugs into a
                // pipe-delimited field so the muscle-filter predicate in
                // Wave 3 can use `.contains("|chest|")` against the
                // `#Index<Exercise>([\.primaryMuscleSlugsJoined])` index.
                let joined = entry.primaryMuscles.isEmpty
                    ? ""
                    : "|" + entry.primaryMuscles.joined(separator: "|") + "|"

                let exercise: Exercise
                // The stimulus rows this exercise had before this seed.
                let stimuli: [ExerciseMuscleStimulus]
                if let existing = exercisesByExternalID[entry.id] {
                    exercise = existing
                    stimuli = stimuliByExercise[existing.persistentModelID] ?? []
                    let isHidden = entry.isHidden && !inUse.contains(existing.persistentModelID)
                    if refresh(
                        existing, from: entry, canonicalName: canonicalName,
                        primaryMuscleSlugsJoined: joined, isHidden: isHidden
                    ) {
                        updatedCount += 1
                    }
                } else {
                    exercise = Exercise(
                        externalID: entry.id,
                        name: entry.name,
                        canonicalName: canonicalName,
                        equipmentRaw: entry.equipmentRaw,
                        mechanicRaw: entry.mechanicRaw,
                        forceRaw: entry.forceRaw,
                        levelRaw: entry.levelRaw,
                        category: entry.category,
                        instructions: entry.instructions,
                        imagePaths: entry.imagePaths,
                        isCustom: false,
                        primaryMuscleSlugsJoined: joined
                    )
                    exercise.trackingRaw = entry.trackingRaw
                    exercise.aliasesJoined = entry.aliasesJoined
                    exercise.familyName = entry.familyName
                    exercise.variantLabel = entry.variantLabel
                    exercise.brand = entry.brand
                    exercise.loadingRaw = entry.loadingRaw
                    exercise.isHidden = entry.isHidden
                    // Pitfall #7 — insert FIRST, then the join rows reference it.
                    // SwiftData drops relationship links silently if the parent
                    // isn't yet inserted into the context.
                    modelContext.insert(exercise)
                    exercisesByExternalID[entry.id] = exercise
                    stimuli = []
                    insertedCount += 1
                }
                syncStimuli(stimuli, of: exercise, to: entry, musclesBySlug: musclesBySlug)

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

            // MARK: 4b. Delete the retired muscle and its volume target
            if let retired {
                modelContext.delete(retired)
                try modelContext.save()
            }

            // MARK: 5. Seed UserSettings singleton if absent
            //
            // The Settings tab in Wave 3 queries `[UserSettings]` and reads
            // `.first`. Inserting the default row here means the Settings
            // view never has to handle an empty-store state.
            let settingsCount = try modelContext.fetchCount(FetchDescriptor<UserSettings>())
            if settingsCount == 0 {
                modelContext.insert(UserSettings.default())
                try modelContext.save()
            }

            // MARK: 6. Stamp the version stamp
            defaults.set(bundled, forKey: Self.seedVersionKey)
            let elapsed = Date().timeIntervalSince(start)
            Self.log.info("Seed complete in \(elapsed, format: .fixed(precision: 3))s — \(BRUCountLabel.text(entries.count, "exercise"), privacy: .public) (\(insertedCount) new, \(updatedCount) updated), \(musclesBySlug.count) muscles")
        } catch {
            // Mid-import failure (e.g. disk full mid-batch). Roll back
            // unsaved changes so the context state matches disk before
            // rethrowing. The next `seedIfNeeded()` call (after the
            // user retries / app relaunches) finds the rows that DID make
            // it to disk by externalID and slug and inserts only the rest,
            // so retry succeeds cleanly (review WR-01).
            SessionSetActions.rollBack(modelContext)
            Self.log.error("Seed failed mid-import — rolling back: \(error.localizedDescription)")
            throw error
        }
    }

    /// Writes the fields the catalog supplies onto an exercise an earlier
    /// seed inserted, and reports whether any changed. Only what differs is
    /// written, because an equal assignment still marks the row changed and
    /// re-renders every view that reads it. The exercise's identity and the
    /// lifter's settings (unit override, increment, bar weight, plateau
    /// overrides) are not catalog fields, so they stay as they are. Tracking,
    /// aliases, family, variant, brand, loading and hiding come from
    /// curation alone, so a row curation stops listing goes back to the
    /// derived tracking and loses the rest. `isHidden` is curation's choice
    /// unless the row is in use.
    private func refresh(
        _ exercise: Exercise,
        from entry: CatalogEntry,
        canonicalName: String,
        primaryMuscleSlugsJoined joined: String,
        isHidden: Bool
    ) -> Bool {
        var changed = false
        func write<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Exercise, Value>, _ value: Value) {
            guard exercise[keyPath: keyPath] != value else { return }
            exercise[keyPath: keyPath] = value
            changed = true
        }
        write(\.name, entry.name)
        write(\.canonicalName, canonicalName)
        write(\.equipmentRaw, entry.equipmentRaw)
        write(\.trackingRaw, entry.trackingRaw)
        write(\.aliasesJoined, entry.aliasesJoined)
        write(\.familyName, entry.familyName)
        write(\.variantLabel, entry.variantLabel)
        write(\.brand, entry.brand)
        write(\.loadingRaw, entry.loadingRaw)
        write(\.isHidden, isHidden)
        write(\.mechanicRaw, entry.mechanicRaw)
        write(\.forceRaw, entry.forceRaw)
        write(\.levelRaw, entry.levelRaw)
        write(\.category, entry.category)
        write(\.instructions, entry.instructions)
        write(\.imagePaths, entry.imagePaths)
        write(\.primaryMuscleSlugsJoined, joined)
        return changed
    }

    /// Makes a catalog exercise's stimulus rows match the entry's muscle
    /// credits: a row keeps its identity and takes the credit's role and
    /// weight, a credited muscle with no row gets one, and a row for a muscle
    /// the entry no longer credits, or a second row for one muscle, is
    /// deleted. A row whose weight the lifter edited stays as it is. Only
    /// what differs is written, as in `refresh`.
    private func syncStimuli(
        _ stimuli: [ExerciseMuscleStimulus],
        of exercise: Exercise,
        to entry: CatalogEntry,
        musclesBySlug: [String: MuscleGroup]
    ) {
        var covered = Set<String>()
        for stimulus in stimuli {
            guard let slug = stimulus.muscle?.slug else { continue }
            if stimulus.userEditedWeight {
                covered.insert(slug)
            } else if let credit = entry.muscles.first(where: { $0.slug == slug }), covered.insert(slug).inserted {
                if stimulus.role != credit.role { stimulus.role = credit.role }
                if stimulus.weight != credit.weight { stimulus.weight = credit.weight }
            } else {
                modelContext.delete(stimulus)
            }
        }
        for credit in entry.muscles where !covered.contains(credit.slug) {
            guard let muscle = musclesBySlug[credit.slug] else {
                Self.log.debug("Unknown muscle slug '\(credit.slug)' on \(entry.id): skipping stimulus row")
                continue
            }
            modelContext.insert(ExerciseMuscleStimulus(
                exercise: exercise, muscle: muscle, role: credit.role, weight: credit.weight
            ))
        }
    }

    /// For each family, the delt its catalog rows credit most, primary
    /// before secondary and then front, side, rear.
    static func familyDelts(_ entries: [CatalogEntry]) -> [String: String] {
        let order = ["front delts": 0, "side delts": 1, "rear delts": 2]
        var best: [String: (credit: MuscleCredit, rank: Int)] = [:]
        for entry in entries {
            guard let family = entry.familyName else { continue }
            for credit in entry.muscles {
                guard let rank = order[credit.slug] else { continue }
                if let current = best[family],
                   current.credit.weight > credit.weight
                    || (current.credit.weight == credit.weight && current.rank <= rank) {
                    continue
                }
                best[family] = (credit, rank)
            }
        }
        return best.mapValues(\.credit.slug)
    }

    /// Moves a non-catalog exercise's retired shoulders credit to `slug`. When the
    /// exercise already credits that delt, the stronger of the two credits
    /// stays on its row and the shoulders row goes. The exercise's primary
    /// muscle list follows.
    static func move(
        _ stimulus: ExerciseMuscleStimulus,
        of exercise: Exercise,
        to slug: String,
        muscle: MuscleGroup?,
        in context: ModelContext
    ) {
        guard let muscle else { return }
        let retiredToken = "|\(MuscleRegionMap.retiredShouldersSlug)|"
        if let existing = (exercise.muscleStimuli ?? []).first(where: { $0.muscle?.slug == slug }) {
            if stimulus.role == "primary" { existing.role = "primary" }
            existing.weight = max(existing.weight, stimulus.weight)
            context.delete(stimulus)
        } else {
            stimulus.muscle = muscle
        }
        let joined = exercise.primaryMuscleSlugsJoined
        guard joined.contains(retiredToken) else { return }
        let replaced = joined.contains("|\(slug)|")
            ? joined.replacingOccurrences(of: retiredToken, with: "|")
            : joined.replacingOccurrences(of: retiredToken, with: "|\(slug)|")
        exercise.primaryMuscleSlugsJoined = replaced == "|" ? "" : replaced
    }
}
