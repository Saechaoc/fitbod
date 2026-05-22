//
//  WarmupConfigTests.swift
//  fitbodTests
//
//  Four @Test functions covering WarmupConfig (a pure value type) and
//  the RoutineExercise.warmupOverride computed accessor shipped by
//  plan 03-01 (Phase 3 schema scaffold):
//
//    1. codableRoundTripPreservesEnabledAndSkipNextSession — JSON encode
//       then decode preserves both Bool fields exactly.
//    2. defaultsAreEnabledTrueSkipFalse — the memberwise init default
//       values match the RESEARCH spec.
//    3. routineExerciseWarmupOverrideNilByDefault — a fresh RoutineExercise
//       has nil warmupOverrideData AND nil warmupOverride.
//    4. routineExerciseWarmupOverrideSetGetRoundTrip — setting warmupOverride
//       writes warmupOverrideData; re-reading warmupOverride decodes it back.
//
//  Tests 1 + 2 are pure value-type (no ModelContext needed).
//  Tests 3 + 4 require a V3 ModelContext to insert the @Model.
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("WarmupConfig", .serialized)
struct WarmupConfigTests {

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

    // MARK: - 1. Codable round-trip

    @Test("codableRoundTripPreservesEnabledAndSkipNextSession — encode/decode is lossless")
    func codableRoundTripPreservesEnabledAndSkipNextSession() throws {
        let original = WarmupConfig(enabled: false, skipNextSession: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WarmupConfig.self, from: data)
        #expect(decoded == original)
        #expect(decoded.enabled == false)
        #expect(decoded.skipNextSession == true)
    }

    // MARK: - 2. Default values

    @Test("defaultsAreEnabledTrueSkipFalse — WarmupConfig() carries correct defaults")
    func defaultsAreEnabledTrueSkipFalse() {
        let config = WarmupConfig()
        #expect(config.enabled == true)
        #expect(config.skipNextSession == false)
    }

    // MARK: - 3. RoutineExercise.warmupOverride is nil by default

    @Test("routineExerciseWarmupOverrideNilByDefault — fresh RoutineExercise has nil override")
    func routineExerciseWarmupOverrideNilByDefault() throws {
        let ctx = try makeContext()
        let re = RoutineExercise()
        ctx.insert(re)
        try ctx.save()

        // The raw Data field must be nil (not set).
        #expect(re.warmupOverrideData == nil)

        // The computed accessor must return nil when the Data field is nil.
        #expect(re.warmupOverride == nil)
    }

    // MARK: - 4. RoutineExercise.warmupOverride get/set round-trip

    @Test("routineExerciseWarmupOverrideSetGetRoundTrip — set encodes Data; get decodes back")
    func routineExerciseWarmupOverrideSetGetRoundTrip() throws {
        let ctx = try makeContext()
        let re = RoutineExercise()
        ctx.insert(re)

        let config = WarmupConfig(enabled: false, skipNextSession: true)
        re.warmupOverride = config

        // After setting, the raw Data field must be non-nil.
        #expect(re.warmupOverrideData != nil)

        // The computed getter must decode back to the same value.
        let decoded = try #require(re.warmupOverride)
        #expect(decoded == config)
        #expect(decoded.enabled == false)
        #expect(decoded.skipNextSession == true)
    }
}
