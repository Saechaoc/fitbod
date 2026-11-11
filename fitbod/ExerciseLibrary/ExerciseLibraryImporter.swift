//
//  ExerciseLibraryImporter.swift
//  fitbod
//
//  Plan 01-PLAN-02-02 — the load-bearing one-time seed pipeline for the
//  built-in exercise library. Authored as a model-actor so the work
//  (decoding ~1.0 MB of JSON, resolving it through `ExerciseCatalog`, and
//  inserting ~710 `Exercise` rows + 17 `MuscleGroup` rows + ~2200
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
//  the dataset supplies, and inserts only what is missing. It deletes
//  nothing: custom exercises, the exercise links of logged workouts and
//  sessions, edited stimulus weights and volume targets, an exercise's own
//  settings, and seeded exercises a newer dataset dropped all stay. The
//  app runs the seed while Today and Progress already show these models,
//  so a delete would invalidate instances the views hold and crash them.
//  After an exercise's first seed its stimulus rows belong to
//  `StimulusWeightSeeder` and the lifter, so a re-seed adds rows only for
//  muscles the exercise has none for. A dataset that moves a muscle between
//  primary and secondary, or drops it, therefore leaves the existing row as
//  it is while `primaryMuscleSlugsJoined` follows the dataset; the bump that
//  makes such a change must handle it.
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
    /// 1. Reads `defaults[seedVersionKey]` and bundled `SEED_VERSION.txt`.
    /// 2. If stored ≥ bundled, returns immediately (no work).
    /// 3. Otherwise resolves the bundled catalog (`ExerciseCatalog`),
    ///    upserts the 17 `MuscleGroup` rows by `slug`, upserts the
    ///    catalog's exercises by `externalID` with any missing stimulus
    ///    join rows in 100-row batches, and seeds the `UserSettings`
    ///    singleton if absent. Nothing is deleted (see "Re-seeding in
    ///    place" above).
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
            // Single source of truth: `MuscleRegionMap.allSlugs` — the 17
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
            // The muscles each of them already has a stimulus row for, from
            // one fetch rather than one relationship fault per exercise.
            var stimulatedSlugs: [PersistentIdentifier: Set<String>] = [:]
            if !exercisesByExternalID.isEmpty {
                for stimulus in try modelContext.fetch(FetchDescriptor<ExerciseMuscleStimulus>()) {
                    guard let exercise = stimulus.exercise, let slug = stimulus.muscle?.slug else { continue }
                    stimulatedSlugs[exercise.persistentModelID, default: []].insert(slug)
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

            // MARK: 4. Upsert Exercise rows + missing stimulus rows in 100-row batches
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
                // Muscles this exercise had a stimulus row for before this seed.
                let stimulated: Set<String>
                if let existing = exercisesByExternalID[entry.id] {
                    exercise = existing
                    stimulated = stimulatedSlugs[existing.persistentModelID] ?? []
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
                    stimulated = []
                    insertedCount += 1
                }

                // Stimulus rows: 1.0 primary / 0.5 secondary (CONTEXT.md Area 1),
                // only for muscles the exercise had no row for before this
                // seed: an existing row's role and weight belong to
                // `StimulusWeightSeeder` and the lifter.
                // Unknown slugs (i.e., slugs not in `MuscleRegionMap.allSlugs`)
                // are skipped with a debug log — a future dataset bump that
                // adds a new slug would surface here.
                for slug in entry.primaryMuscles where !stimulated.contains(slug) {
                    guard let mg = musclesBySlug[slug] else {
                        Self.log.debug("Unknown primary muscle slug '\(slug)' on \(entry.id): skipping stimulus row")
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
                for slug in entry.secondaryMuscles where !stimulated.contains(slug) {
                    guard let mg = musclesBySlug[slug] else {
                        Self.log.debug("Unknown secondary muscle slug '\(slug)' on \(entry.id): skipping stimulus row")
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
}
