//
//  MuscleVolumeTargetSeederTests.swift
//  fitbodTests
//
//  Pins MuscleVolumeTargetSeeder semantics per RESEARCH §7.3 +
//  Threat T-05-02:
//    1. Seeds 17 rows on an empty context (one per free-exercise-db
//       muscle slug seeded by Phase 1).
//    2. User-edited rows (userEdited == true) preserved verbatim
//       across re-seed — VOL-03 anchor.
//    3. Non-user-edited rows are overwritten to the current canonical
//       RP values.
//    4. Idempotent across multiple runs.
//    5. Defense-in-depth: RP landmark data is pre-validated monotonic
//       (T-05-02 mitigation — the seeder cannot introduce a
//       non-monotonic row because it writes whole tuples).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("MuscleVolumeTargetSeeder", .serialized)
struct MuscleVolumeTargetSeederTests {

    // MARK: - Helpers

    /// Insert all 17 MuscleGroup rows (matches MuscleRegionMap.allSlugs).
    @discardableResult
    private func seedAllMuscles(_ ctx: ModelContext) throws -> [String: MuscleGroup] {
        var byslug: [String: MuscleGroup] = [:]
        for slug in MuscleRegionMap.allSlugs {
            let m = MuscleGroup(
                slug: slug,
                displayName: MuscleRegionMap.displayName(for: slug),
                region: MuscleRegionMap.region(for: slug)
            )
            ctx.insert(m)
            byslug[slug] = m
        }
        try ctx.save()
        return byslug
    }

    // MARK: - 1. Seeds 17 rows on empty context

    @Test("Seeder writes 17 MuscleVolumeTarget rows from RP landmarks on an empty context")
    func seedsSeventeenRowsOnEmptyContext() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedAllMuscles(ctx)

        MuscleVolumeTargetSeeder.seedIfNeeded(in: ctx)

        let count = (try? ctx.fetchCount(FetchDescriptor<MuscleVolumeTarget>())) ?? 0
        #expect(count == 17)

        // Spot-check a few canonical slugs.
        for (slug, _) in muscles {
            let landmark = RPVolumeLandmarks.landmark(for: slug)
            let descriptor = FetchDescriptor<MuscleVolumeTarget>(
                predicate: #Predicate<MuscleVolumeTarget> { $0.muscle?.slug == slug }
            )
            let row = try #require((try? ctx.fetch(descriptor))?.first, "missing target row for \(slug)")
            #expect(row.mv == landmark.mv)
            #expect(row.mev == landmark.mev)
            #expect(row.mav == landmark.mav)
            #expect(row.mrv == landmark.mrv)
            #expect(row.userEdited == false)
        }
    }

    // MARK: - 2. Preserves user-edited row

    @Test("User-edited row is preserved verbatim across re-seed (VOL-03)")
    func preservesUserEditedRowAcrossReSeed() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedAllMuscles(ctx)
        // Pre-seed a user-edited chest target with mev=10 (custom).
        let edited = MuscleVolumeTarget()
        edited.muscle = muscles["chest"]
        edited.mv = 6
        edited.mev = 10           // custom — different from RP default 8
        edited.mav = 16
        edited.mrv = 22
        edited.userEdited = true
        ctx.insert(edited)
        try ctx.save()

        MuscleVolumeTargetSeeder.seedIfNeeded(in: ctx)

        let descriptor = FetchDescriptor<MuscleVolumeTarget>(
            predicate: #Predicate<MuscleVolumeTarget> { $0.muscle?.slug == "chest" }
        )
        let row = try #require((try? ctx.fetch(descriptor))?.first)
        #expect(row.mev == 10, "user-edited mev clobbered: got \(row.mev)")
        #expect(row.userEdited == true)
    }

    // MARK: - 3. Overwrites non-edited rows

    @Test("Non-user-edited rows are overwritten with current RP defaults")
    func overwritesNonEditedRowsWithCurrentRPDefaults() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        let muscles = try seedAllMuscles(ctx)
        // Pre-seed a stale chest target with mev=99 (not user-edited).
        let stale = MuscleVolumeTarget()
        stale.muscle = muscles["chest"]
        stale.mv = 6
        stale.mev = 99           // stale; should be overwritten
        stale.mav = 16
        stale.mrv = 22
        stale.userEdited = false
        ctx.insert(stale)
        try ctx.save()

        MuscleVolumeTargetSeeder.seedIfNeeded(in: ctx)

        let descriptor = FetchDescriptor<MuscleVolumeTarget>(
            predicate: #Predicate<MuscleVolumeTarget> { $0.muscle?.slug == "chest" }
        )
        let row = try #require((try? ctx.fetch(descriptor))?.first)
        // RP default for chest mev is 8.
        let landmark = RPVolumeLandmarks.landmark(for: "chest")
        #expect(row.mev == landmark.mev)
    }

    // MARK: - 4. Idempotent across multiple runs

    @Test("Re-running the seeder does not change row counts or values")
    func idempotentAcrossMultipleRuns() throws {
        let ctx = try FatigueTestFixtures.makeContext()
        _ = try seedAllMuscles(ctx)

        MuscleVolumeTargetSeeder.seedIfNeeded(in: ctx)
        let after1 = (try? ctx.fetchCount(FetchDescriptor<MuscleVolumeTarget>())) ?? 0
        MuscleVolumeTargetSeeder.seedIfNeeded(in: ctx)
        let after2 = (try? ctx.fetchCount(FetchDescriptor<MuscleVolumeTarget>())) ?? 0
        MuscleVolumeTargetSeeder.seedIfNeeded(in: ctx)
        let after3 = (try? ctx.fetchCount(FetchDescriptor<MuscleVolumeTarget>())) ?? 0

        #expect(after1 == 17)
        #expect(after2 == 17)
        #expect(after3 == 17)
    }

    // MARK: - 5. All RP landmarks are monotonic (T-05-02 defense-in-depth)

    @Test("All RP landmarks satisfy MV ≤ MEV < MAV < MRV (T-05-02 defense-in-depth)")
    func allRPLandmarksAreMonotonic() {
        for (slug, landmark) in RPVolumeLandmarks.landmarks {
            #expect(landmark.mv <= landmark.mev, "slug \(slug): MV > MEV")
            #expect(landmark.mev < landmark.mav, "slug \(slug): MEV ≥ MAV")
            #expect(landmark.mav < landmark.mrv, "slug \(slug): MAV ≥ MRV")
        }
    }
}
