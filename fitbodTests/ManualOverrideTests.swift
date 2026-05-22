//
//  ManualOverrideTests.swift
//  fitbodTests
//
//  RED scaffold — 4 @Test stubs for manual weight override behavior and
//  the minCalibrationSets setting. Replaced by plan 03-08 with real
//  assertions against the wasManualOverride flag and the next-session
//  progression logic.
//
//  Mirrors the SessionFactoryTests.swift fixture shape:
//    - @MainActor + @Suite(.serialized) over in-memory ModelContainer
//    - makeContext() builds Schema(SchemaV3.models) + FitbodSchemaMigrationPlan
//    - each @Test signature is () throws -> Void
//    - each body issues a single Issue.record(...)
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("ManualOverride", .serialized)
struct ManualOverrideTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - Scaffolds (replaced by plan 03-08)

    @Test("manualOverrideFlagSetWhenWeightDiverges")
    func manualOverrideFlagSetWhenWeightDiverges() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: SetEntry.wasManualOverride becomes true when actualWeight diverges from rounded prescribed weight by more than exercise.smallestIncrement")
    }

    @Test("manualOverrideFlagFalseWhenWeightMatchesPrescription")
    func manualOverrideFlagFalseWhenWeightMatchesPrescription() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: SetEntry.wasManualOverride stays false when actualWeight equals SessionExercise.prescribedWeight")
    }

    @Test("nextSessionReadsActualNotPrescribed")
    func nextSessionReadsActualNotPrescribed() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: PRES-07: progression next session reads SetEntry.actualWeight (the override) NOT SessionExercise.prescribedWeight (the original suggestion)")
    }

    @Test("userSettingsMinCalibrationSetsHonored")
    func userSettingsMinCalibrationSetsHonored() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: SET-07: changing UserSettings.minCalibrationSets from 10 to 20 keeps RPEAutoregStrategy in calibrating mode until 20 sets are logged")
    }
}
