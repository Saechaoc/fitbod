//
//  Phase5FieldDefaultsTests.swift
//  fitbodTests
//
//  Round-trip defaults for the Phase 5 fields on the live baseline schema.
//  The V5 -> V6 migration tests were removed when schema history was reset (2026-10-02).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("Phase5FieldDefaults", .serialized)
struct Phase5FieldDefaultsTests {

    // MARK: - Helpers

    /// Fresh in-memory ModelContext from the production factory (baseline schema).
    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    // MARK: - 3. migrateV5toV6 is custom (not lightweight)

    // MARK: - 4. V6 entity count equals V5 entity count (nested-substitution invariant)

    // MARK: - 5. UserSettings Phase 5 fields round-trip

    @Test("UserSettings carries Phase 5 fields with correct defaults")
    func userSettingsPhase5FieldsRoundTrip() throws {
        let ctx = try makeContext()
        let s = UserSettings.default()
        ctx.insert(s)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<UserSettings>())
        let row = try #require(fetched.first)
        #expect(row.frequencyHitMinSets == 2)
        #expect(row.deloadAdvisoryDismissedWeekStart == nil)
        #expect(row.weeklyRecapShownForWeekStart == nil)
        // D-12: new default is 0.02 (bumped from 0.005).
        #expect(abs(row.plateauTolerance - 0.02) < 1e-9)
    }

    // MARK: - 6. Exercise Phase 5 fields round-trip

    @Test("Exercise carries Phase 5 plateau override fields defaulting to nil")
    func exercisePhase5FieldsRoundTrip() throws {
        let ctx = try makeContext()
        let ex = Exercise()
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        let row = try #require(fetched.first)
        #expect(row.plateauWindowOverride == nil)
        #expect(row.plateauToleranceOverride == nil)
    }

    // MARK: - 7. ExerciseMuscleStimulus userEditedWeight round-trips

    @Test("ExerciseMuscleStimulus.userEditedWeight defaults to false")
    func exerciseMuscleStimulusUserEditedRoundTrip() throws {
        let ctx = try makeContext()
        let s = ExerciseMuscleStimulus()
        ctx.insert(s)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>())
        let row = try #require(fetched.first)
        #expect(row.userEditedWeight == false)
    }

    // MARK: - 8. MuscleVolumeTarget userEdited round-trips

    @Test("MuscleVolumeTarget.userEdited defaults to false")
    func muscleVolumeTargetUserEditedRoundTrip() throws {
        let ctx = try makeContext()
        let mvt = MuscleVolumeTarget()
        ctx.insert(mvt)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<MuscleVolumeTarget>())
        let row = try #require(fetched.first)
        #expect(row.userEdited == false)
    }
}
