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
//  surface as a 5-10× slowdown over the ~675-exercise seeded corpus.
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
//  Each test resets the UserDefaults seed stamp and builds a fresh
//  in-memory container, then runs `seedIfNeeded()` to populate the full
//  ~675-exercise corpus. The seed itself is exercised by `SeedTests`;
//  these tests assume it works and only measure post-seed query time.
//
//  ## Why `.serialized`
//
//  Same reason as `SeedTests`: `UserDefaults.standard` is process-wide,
//  and parallel `@Test` execution can race the importer's seed-version
//  stamp, causing one test's `seedIfNeeded()` to short-circuit on the
//  stamp another test just wrote. `.serialized` forces sequential
//  execution within this suite (review WR-02).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("Indexed queries on Exercise", .serialized)
struct IndexedQueryTests {

    // MARK: - Helpers

    /// Removes the seed-version stamp from `UserDefaults` so a fresh
    /// `seedIfNeeded()` call actually performs work rather than
    /// short-circuiting.
    private static func resetStamp() {
        UserDefaults.standard.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
    }

    /// Builds a fully-seeded in-memory container ready for query
    /// profiling. Returns the container so callers can derive their
    /// own `ModelContext` for fetching.
    private static func makeSeededContainer() async throws -> ModelContainer {
        Self.resetStamp()
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded()
        return container
    }

    // MARK: - Test 1: canonicalName.contains stays fast

    @Test(
        "canonicalName.contains query stays under 200ms at seeded scale",
        .timeLimit(.minutes(1))
    )
    func canonicalNameContainsFast() async throws {
        let container = try await Self.makeSeededContainer()
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
            "canonicalName.contains over ~675 rows took \(elapsed)s — production target <0.05s with #Index, soft cap 0.20s for CI"
        )
    }

    // MARK: - Test 2: primaryMuscleSlugsJoined.contains stays fast

    @Test(
        "primaryMuscleSlugsJoined.contains query stays under 200ms at seeded scale",
        .timeLimit(.minutes(1))
    )
    func muscleJoinedFast() async throws {
        let container = try await Self.makeSeededContainer()
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
            "primaryMuscleSlugsJoined.contains over ~675 rows took \(elapsed)s — production target <0.05s with #Index, soft cap 0.20s for CI"
        )
    }
}
