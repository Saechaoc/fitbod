//
//  IndexedQueryTests.swift
//  fitbodTests
//
//  Plan 01-PLAN-03-02 — at-scale query timing assertions for the two
//  hot predicate paths in `ExerciseLibraryView`:
//
//    1. `canonicalName.contains(...)` — the search path
//    2. `primaryMuscleSlugsJoined.contains(...)` — the denormalised
//       muscle filter (PITFALLS #3)
//
//  ## Why test timing rather than EXPLAIN
//
//  We cannot introspect the SQLite query plan from a Swift Testing
//  suite. The next-best signal is wall-clock — a regression that
//  removes the `#Index<Exercise>` declaration on either field would
//  surface as a 5-10× slowdown over the ~702-exercise seeded corpus.
//
//  ## Budgets
//
//  Production target is `<50ms` per RESEARCH § Pattern 4 / FOUND-04 on
//  iPhone 16-class hardware. The plan caps at `<200ms` (the soft cap
//  for CI headroom) — first-launch SQLite warmup can bloat the
//  wall-clock on a cold runner. Tighten once CI cold-launch profiling
//  is consistent.
//
//  ## Test setup
//
//  Each test builds a fresh in-memory container and runs `seedIfNeeded()`
//  to populate the full ~702-exercise corpus, with the seed-version stamp
//  in the test's own `UserDefaults` suite (`defaults`), never in
//  `UserDefaults.standard`, which the hosted tests share with the app on
//  the phone (F296). The seed itself is exercised by `SeedTests`; these
//  tests assume it works and only measure post-seed query time.
//
//  Swift Testing creates a new instance per test, with a new stamp suite
//  that `deinit` removes, so tests share nothing mutable and the suite
//  needs no `.serialized`.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("Indexed queries on Exercise")
final class IndexedQueryTests {

    // MARK: - Helpers

    private let defaultsSuiteName = "IndexedQueryTests.\(UUID().uuidString)"

    /// Where this test's seed-version stamp lives. A fresh suite starts with
    /// no stamp, so `seedIfNeeded` performs work.
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    /// Builds a fully-seeded in-memory container ready for query
    /// profiling. Returns the container so callers can derive their
    /// own `ModelContext` for fetching.
    private func makeSeededContainer() async throws -> ModelContainer {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: defaults)
        return container
    }

    // MARK: - Test 1: canonicalName.contains stays fast

    @Test(
        "canonicalName.contains query stays under 200ms at seeded scale",
        .timeLimit(.minutes(1))
    )
    func canonicalNameContainsFast() async throws {
        let container = try await makeSeededContainer()
        let ctx = ModelContext(container)

        // Capture-by-value: needle must be a local let so the
        // #Predicate macro encodes it as a literal (PITFALLS #12).
        let needle = "bench"
        let pred = #Predicate<Exercise> { ex in
            ex.canonicalName.contains(needle)
        }
        let start = Date()
        let results = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
        let elapsed = Date().timeIntervalSince(start)

        #expect(
            results.count > 0,
            "Seeded library should contain at least one 'bench' exercise; got \(results.count)"
        )
        #expect(
            elapsed < 0.20,
            "canonicalName.contains over ~702 rows took \(elapsed)s — production target <0.05s with #Index, soft cap 0.20s for CI"
        )
    }

    // MARK: - Test 2: primaryMuscleSlugsJoined.contains stays fast

    @Test(
        "primaryMuscleSlugsJoined.contains query stays under 200ms at seeded scale",
        .timeLimit(.minutes(1))
    )
    func muscleJoinedFast() async throws {
        let container = try await makeSeededContainer()
        let ctx = ModelContext(container)

        // Same capture-by-value pattern as Test 1.
        let needle = "|chest|"
        let pred = #Predicate<Exercise> { ex in
            ex.primaryMuscleSlugsJoined.contains(needle)
        }
        let start = Date()
        let results = try ctx.fetch(FetchDescriptor<Exercise>(predicate: pred))
        let elapsed = Date().timeIntervalSince(start)

        #expect(
            results.count > 0,
            "Some seeded exercises should have chest as a primary muscle; got \(results.count)"
        )
        #expect(
            elapsed < 0.20,
            "primaryMuscleSlugsJoined.contains over ~702 rows took \(elapsed)s — production target <0.05s with #Index, soft cap 0.20s for CI"
        )
    }
}
