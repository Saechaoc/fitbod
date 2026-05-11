//
//  FilterStatePredicateTests.swift
//  fitbodTests
//
//  Plan 01-PLAN-03-02 anchor suite — proves the `FilterState` filter
//  pipeline (`swiftDataPredicate(with:)` at SwiftData +
//  `applyPostFetchFilters(to:)` post-fetch) composes correctly over the
//  full matrix of facet + search combinations.
//
//  Pipeline note: search lives in `swiftDataPredicate(with:)` (pushed down to
//  SwiftData). Facets live in `applyPostFetchFilters(to:)` because guarded
//  multi-facet matching pushes `#Predicate` past Swift's type-checker budget
//  and is fragile for SwiftData SQL translation. See FilterState.swift header
//  for the full rationale.
//
//  Nine Swift Testing functions cover:
//   1. `emptyFilterAll` — empty state returns every row
//   2. `searchBench` — case- + diacritic-insensitive substring search
//      (pushed down via `swiftDataPredicate(with:)`)
//   3. `swiftDataPredicateAppliesSearch` — proves search constrains the
//      SwiftData fetch before post-fetch filtering
//   4. `equipmentFilter` — equipment facet, single-value selection
//   5. `mechanicFilter` — mechanic facet (single-select)
//   6. `muscleFilterDenormalized` — muscle facet through the
//      denormalized `|slug|` post-fetch path (PITFALLS #3)
//   7. `multiFacetAND` — AND-across-facets (equipment + mechanic)
//   8. `multiSelectWithinFacet` — OR-within-facet (muscle selecting two
//      slugs returns the union)
//   9. `facetSelectionDoesNotConstrainSwiftDataFetch` — proves facets stay
//      out of the SwiftData predicate
//
//  ## Fixture
//
//  Each test builds an in-memory `ModelContainer` via
//  `InMemoryContainer.makeEmpty()`, inserts four hand-crafted exercises
//  spanning equipment / mechanic / muscle variety, saves, then runs the
//  predicate via `FetchDescriptor` and counts the resulting rows.
//
//  The fixture order matters for stable `name`-based assertions:
//   - "Barbell Bench Press" — barbell, compound, primary muscle: chest
//   - "Dumbbell Curl"      — dumbbell, isolation, primary muscle: biceps
//   - "Cable Lat Pulldown" — cable, compound, primary muscle: lats
//   - "Squat"              — barbell, compound, primary muscle: quadriceps
//
//  ## Test isolation
//
//  Swift Testing's `struct` suite is re-instantiated per `@Test`, so each
//  `@Test` builds its own container. The suite is `.serialized` because
//  SwiftData-backed tests in this project otherwise run concurrently inside
//  the app-hosted test process and can trap before individual assertions run.
//  No `UserDefaults` reset needed here — the importer is not invoked by the
//  fixture.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("FilterState.swiftDataPredicate(with:) + applyPostFetchFilters(to:)", .serialized)
struct FilterStatePredicateTests {

    // MARK: - Pipeline helper

    /// Runs the full filter pipeline: `swiftDataPredicate(with:)` at the
    /// SwiftData fetch boundary, then `applyPostFetchFilters(to:)` over the
    /// fetched rows. Mirrors what `FilteredExerciseList` does in production.
    private static func evaluate(
        _ state: FilterState,
        search: String,
        in ctx: ModelContext
    ) throws -> [Exercise] {
        let fetched = try ctx.fetch(FetchDescriptor<Exercise>(
            predicate: state.swiftDataPredicate(with: search)
        ))
        return state.applyPostFetchFilters(to: fetched)
    }

    // MARK: - Fixture

    /// Inserts the four-exercise fixture into a fresh in-memory container
    /// and returns the container + a fresh `ModelContext` for fetching.
    private static func makeFixture() throws -> (ModelContainer, ModelContext) {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)
        ctx.insert(makeExercise(
            name: "Barbell Bench Press",
            equipment: "barbell",
            mechanic: "compound",
            primary: ["chest"]
        ))
        ctx.insert(makeExercise(
            name: "Dumbbell Curl",
            equipment: "dumbbell",
            mechanic: "isolation",
            primary: ["biceps"]
        ))
        ctx.insert(makeExercise(
            name: "Cable Lat Pulldown",
            equipment: "cable",
            mechanic: "compound",
            primary: ["lats"]
        ))
        ctx.insert(makeExercise(
            name: "Squat",
            equipment: "barbell",
            mechanic: "compound",
            primary: ["quadriceps"]
        ))
        try ctx.save()
        return (container, ctx)
    }

    /// Builds a single Exercise with `canonicalName` and
    /// `primaryMuscleSlugsJoined` populated to match the importer's
    /// wire format (`"|chest|"` etc.). This is the same convention
    /// `Exercise.previewSample` applies, restated here so the test
    /// reads top-to-bottom without bouncing into the preview helper.
    private static func makeExercise(
        name: String,
        equipment: String,
        mechanic: String,
        primary: [String]
    ) -> Exercise {
        let canonical = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        let joined = primary.isEmpty
            ? ""
            : "|" + primary.joined(separator: "|") + "|"
        return Exercise(
            name: name,
            canonicalName: canonical,
            equipmentRaw: equipment,
            mechanicRaw: mechanic,
            category: "strength",
            isCustom: false,
            primaryMuscleSlugsJoined: joined
        )
    }

    // MARK: - Test 1: empty filter

    @Test("Empty filter returns every exercise")
    func emptyFilterAll() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        let result = try Self.evaluate(state, search: "", in: ctx)
        #expect(result.count == 4, "Empty filter should match all 4 fixture rows; got \(result.count)")
    }

    // MARK: - Test 2: search

    @Test("Search 'bench' returns only Bench Press")
    func searchBench() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        let result = try Self.evaluate(state, search: "bench", in: ctx)
        #expect(result.count == 1, "Search 'bench' should match exactly 1 row; got \(result.count)")
        #expect(result.first?.name == "Barbell Bench Press")
    }

    @Test("SwiftData predicate applies search before post-fetch muscle filtering")
    func swiftDataPredicateAppliesSearch() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        let fetched = try ctx.fetch(FetchDescriptor<Exercise>(
            predicate: state.swiftDataPredicate(with: "bench")
        ))
        #expect(fetched.map(\.name) == ["Barbell Bench Press"])
    }

    // MARK: - Test 3: equipment facet

    @Test("Equipment=dumbbell returns Dumbbell Curl only")
    func equipmentFilter() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        state.selectedEquipmentRaw = ["dumbbell"]
        let result = try Self.evaluate(state, search: "", in: ctx)
        #expect(result.count == 1, "Equipment=dumbbell should match exactly 1 row; got \(result.count)")
        #expect(result.first?.name == "Dumbbell Curl")
    }

    // MARK: - Test 4: mechanic facet

    @Test("Mechanic=isolation returns Dumbbell Curl only")
    func mechanicFilter() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        state.selectedMechanicRaw = "isolation"
        let result = try Self.evaluate(state, search: "", in: ctx)
        #expect(result.count == 1, "Mechanic=isolation should match exactly 1 row; got \(result.count)")
        #expect(result.first?.name == "Dumbbell Curl")
    }

    // MARK: - Test 5: muscle facet (denormalized — PITFALLS #3)

    @Test("Muscle=chest returns Bench Press only (denormalized slug match)")
    func muscleFilterDenormalized() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        state.selectedMuscleSlugs = ["chest"]
        let result = try Self.evaluate(state, search: "", in: ctx)
        #expect(
            result.count == 1,
            "Muscle=chest should match exactly 1 row via |chest| denormalised match; got \(result.count)"
        )
        #expect(result.first?.name == "Barbell Bench Press")
    }

    // MARK: - Test 6: multi-facet AND

    @Test("Equipment=barbell AND Mechanic=compound returns Bench + Squat")
    func multiFacetAND() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        state.selectedEquipmentRaw = ["barbell"]
        state.selectedMechanicRaw = "compound"
        let result = try Self.evaluate(state, search: "", in: ctx)
        #expect(
            result.count == 2,
            "barbell + compound AND should match exactly 2 rows (Bench + Squat); got \(result.count)"
        )
        let names = Set(result.map(\.name))
        #expect(names == Set(["Barbell Bench Press", "Squat"]))
    }

    // MARK: - Test 7: multi-select OR within facet

    @Test("Multi-select within muscle facet ORs: chest+biceps → 2 rows")
    func multiSelectWithinFacet() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        state.selectedMuscleSlugs = ["chest", "biceps"]
        let result = try Self.evaluate(state, search: "", in: ctx)
        #expect(
            result.count == 2,
            "muscle=[chest, biceps] OR should match exactly 2 rows (Bench + Curl); got \(result.count)"
        )
        let names = Set(result.map(\.name))
        #expect(names == Set(["Barbell Bench Press", "Dumbbell Curl"]))
    }

    // MARK: - Test 9: facets stay post-fetch

    @Test("Facet selections do not constrain the SwiftData fetch")
    func facetSelectionDoesNotConstrainSwiftDataFetch() throws {
        let (_, ctx) = try Self.makeFixture()
        let state = FilterState()
        state.selectedEquipmentRaw = ["barbell"]
        state.selectedMuscleSlugs = ["chest"]
        let fetched = try ctx.fetch(FetchDescriptor<Exercise>(
            predicate: state.swiftDataPredicate(with: "")
        ))
        let filtered = state.applyPostFetchFilters(to: fetched)

        #expect(fetched.count == 4, "Facets should not be pushed into the SwiftData predicate")
        #expect(filtered.map(\.name) == ["Barbell Bench Press"])
    }
}
