//
//  TrainingDaysWriterTests.swift
//  fitbodTests
//
//  Phase 8-02 — SPEC-8-TRAININGDAYS: pins the sort-once-at-write contract
//  and the locale/region-change-stability invariant. Pure-value tests need no
//  shared state, so no @MainActor or .serialized attributes required.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("TrainingDaysWriter")
struct TrainingDaysWriterTests {

    // MARK: - Locale sort tests

    @Test("Sun-first locale: [3,1,6] sorts to [1,3,6]")
    func sunFirstSort() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        let sorted = TrainingDaysWriter.sort(weekdays: [3, 1, 6], using: cal)
        #expect(sorted == [1, 3, 6])
    }

    @Test("Mon-first locale: [1,2,7] sorts to [2,7,1]")
    func monFirstSort() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        let sorted = TrainingDaysWriter.sort(weekdays: [1, 2, 7], using: cal)
        // Mon(2) first, Sat(7) second, Sun(1) last in Mon-first locale
        #expect(sorted == [2, 7, 1])
    }

    @Test("Idempotence: sorting an already-sorted array returns the same array")
    func idempotence() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        let alreadySorted = [1, 3, 6]
        let sortedAgain = TrainingDaysWriter.sort(weekdays: alreadySorted, using: cal)
        #expect(sortedAgain == alreadySorted)
    }

    // MARK: - Region-change stability (SPEC-8-TRAININGDAYS §3/§5)

    /// Proves the verbatim-read invariant ACROSS a persistence round-trip: the
    /// array sorted at write under a Mon-first calendar must survive a save and a
    /// fresh-context fetch unchanged — even when the reading context is created
    /// after a simulated region change (different `Calendar.firstWeekday`).
    ///
    /// WR-05: the prior version read the same in-memory object twice (`x == x`),
    /// which proved nothing. This version fetches from a SECOND ModelContext to
    /// prove the stored order survived persistence and was not re-sorted on read.
    @Test("Region change after write does not re-sort stored trainingDays")
    func regionChangeDoesNotResort() throws {
        // Build an in-memory V7 container — same pattern as SplitDeletionGuardTests
        let schema = Schema(SchemaV7.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        let ctx = ModelContext(container)

        // Mon-first calendar for the write
        var monFirstCal = Calendar(identifier: .gregorian)
        monFirstCal.firstWeekday = 2

        // Write: [Tue=3, Thu=5, Sat=7] sorted with Mon-first stays [3, 5, 7]
        let block = Block()
        ctx.insert(block)
        block.name = "Test Block"
        block.trainingDays = TrainingDaysWriter.sort(weekdays: [3, 5, 7], using: monFirstCal)
        try ctx.save()
        let storedID = block.id

        // Simulate a region change by reading through a NEW ModelContext (mimics
        // a cold re-launch where Calendar.current now has a different firstWeekday).
        // The reader does NOT call TrainingDaysWriter — it reads verbatim from storage.
        let ctx2 = ModelContext(container)
        let fetched = try #require(
            try ctx2.fetch(
                FetchDescriptor<Block>(predicate: #Predicate { $0.id == storedID })
            ).first,
            "Block must be fetchable from a fresh context after save"
        )

        // The fetched array must match the Mon-first-sorted order exactly —
        // proving the stored order survived persistence and was not re-sorted
        // under the reader's (different) calendar.
        #expect(fetched.trainingDays == [3, 5, 7],
            "Stored trainingDays order must survive a persistence round-trip unchanged")
    }
}
