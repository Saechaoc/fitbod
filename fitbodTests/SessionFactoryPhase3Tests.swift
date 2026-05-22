//
//  SessionFactoryPhase3Tests.swift
//  fitbodTests
//
//  RED scaffold — 5 @Test stubs for Phase 3 SessionFactory behavior:
//  prescribedWeight on SessionExercise and warm-up SetEntry rows.
//  Replaced by plan 03-08 with real assertions once the Phase 3 hooks
//  are added to SessionFactory.
//
//  Mirrors SessionFactoryTests.swift verbatim: same imports, same
//  @MainActor + .serialized + makeContext() shape, but uses
//  Schema(SchemaV3.models) instead of SchemaV2.
//
//  Each @Test signature is () throws -> Void. Each body issues a single
//  Issue.record(...) — DO NOT call SessionFactory.start here; the Phase 3
//  hooks don't exist yet (plan 03-08 adds them).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SessionFactoryPhase3", .serialized)
struct SessionFactoryPhase3Tests {

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

    @Test("prescribedWeightSetOnSessionExercise")
    func prescribedWeightSetOnSessionExercise() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: PRES-01: after SessionFactory.start(...), every SessionExercise has non-nil prescribedWeight")
    }

    @Test("warmupSetEntriesInsertedForFirstQualifyingCompound")
    func warmupSetEntriesInsertedForFirstQualifyingCompound() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: WARM-01: first SessionExercise with mechanic==.compound AND equipment==.barbell gets 4 warmup SetEntry rows (isWarmup==true) with orderIndex 0-3")
    }

    @Test("workingSetsShiftAfterWarmupInsertion")
    func workingSetsShiftAfterWarmupInsertion() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: Working SetEntry rows have orderIndex >= warmup count (start at 4 when 4 warmups are inserted)")
    }

    @Test("secondQualifyingCompoundDoesNotGetWarmup")
    func secondQualifyingCompoundDoesNotGetWarmup() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: WARM-01: only the FIRST qualifying compound receives ramp; second one gets working sets only")
    }

    @Test("warmupSkippedWhenWarmupConfigDisabled")
    func warmupSkippedWhenWarmupConfigDisabled() throws {
        Issue.record("PENDING IMPL — replaced by plan 03-08: WARM-03: RoutineExercise.warmupOverride = WarmupConfig(enabled: false) suppresses ramp on that exercise")
    }
}
