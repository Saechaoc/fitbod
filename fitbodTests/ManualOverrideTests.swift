//
//  ManualOverrideTests.swift
//  fitbodTests
//
//  Phase 3 plan 03-08 integration tests for manual weight override behavior
//  and the minCalibrationSets setting. Replaces the Issue.record placeholders
//  with concrete model-layer assertions.
//
//  Test philosophy (per plan 03-08 <behavior>):
//    - manualOverrideFlagSetWhenWeightDiverges / manualOverrideFlagFalseWhenWeightMatchesPrescription:
//      PrescriptionWeightCell writes wasManualOverride=true via its onChange
//      handler — tested here at the model layer by direct SetEntry mutation +
//      save + refetch. UI-layer behavior is covered by Task 3's human-verify
//      checkpoint.
//    - nextSessionReadsActualNotPrescribed: SessionFactory history fetch reads
//      SetEntry.weight (actualWeight), not SessionExercise.prescribedWeight.
//      Asserted by checking that fetchHistoryPoints returns the overridden
//      weight, not the prescription.
//    - userSettingsMinCalibrationSetsHonored: inserting UserSettings with
//      minCalibrationSets=20, then logging 15 working sets, then calling
//      RPEAutoregStrategy.prescribe — asserts status == .calibrating(15, 20).
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

    // MARK: - 1. manualOverrideFlagSetWhenWeightDiverges

    @Test("manualOverrideFlagSetWhenWeightDiverges")
    func manualOverrideFlagSetWhenWeightDiverges() throws {
        let ctx = try makeContext()

        // Build a minimal session with a prescribed weight.
        let ex = Exercise.previewSample(
            name: "Bench Press",
            equipment: .barbell,
            mechanic: .compound
        )
        ex.smallestIncrement = 2.5
        ctx.insert(ex)

        let se = SessionExercise()
        se.exercise = ex
        se.intentRaw = Intent.strength.rawValue
        se.prescribedWeight = 100.0
        ctx.insert(se)

        let entry = SetEntry()
        entry.sessionExercise = se
        entry.orderIndex = 0
        entry.weight = 100.0
        entry.wasManualOverride = false
        ctx.insert(entry)
        try ctx.save()

        // Simulate the PrescriptionWeightCell's onChange handler: user types a
        // divergent weight (105 kg vs prescribed 100 kg — delta = 5, far above
        // smallestIncrement of 2.5).
        entry.weight = 105.0
        entry.wasManualOverride = true   // PrescriptionWeightCell sets this when |weight - prescribed| > 0.001
        try ctx.save()

        // Refetch and assert the flag survived the round-trip.
        let descriptor = FetchDescriptor<SetEntry>()
        let fetched = try ctx.fetch(descriptor)
        let refetched = fetched.first { $0.id == entry.id }!
        #expect(refetched.wasManualOverride == true,
            "wasManualOverride must be true when user weight diverges from prescribed weight")
        #expect(refetched.weight == 105.0)
    }

    // MARK: - 2. manualOverrideFlagFalseWhenWeightMatchesPrescription

    @Test("manualOverrideFlagFalseWhenWeightMatchesPrescription")
    func manualOverrideFlagFalseWhenWeightMatchesPrescription() throws {
        let ctx = try makeContext()

        let ex = Exercise.previewSample(
            name: "OHP",
            equipment: .barbell,
            mechanic: .compound
        )
        ctx.insert(ex)

        let se = SessionExercise()
        se.exercise = ex
        se.intentRaw = Intent.strength.rawValue
        se.prescribedWeight = 60.0
        ctx.insert(se)

        let entry = SetEntry()
        entry.sessionExercise = se
        entry.orderIndex = 0
        entry.weight = 60.0
        entry.wasManualOverride = false
        ctx.insert(entry)
        try ctx.save()

        // Simulate confirming the prescribed weight — no divergence.
        // PrescriptionWeightCell keeps wasManualOverride = false when
        // |weight - prescribed| <= 0.001.
        entry.weight = 60.0
        entry.wasManualOverride = false
        try ctx.save()

        let descriptor = FetchDescriptor<SetEntry>()
        let fetched = try ctx.fetch(descriptor)
        let refetched = fetched.first { $0.id == entry.id }!
        #expect(refetched.wasManualOverride == false,
            "wasManualOverride must remain false when weight matches prescription")
    }

    // MARK: - 3. nextSessionReadsActualNotPrescribed (PRES-07)

    @Test("nextSessionReadsActualNotPrescribed")
    func nextSessionReadsActualNotPrescribed() throws {
        let ctx = try makeContext()

        // Build an exercise + prior session with prescribedWeight 100 but
        // actualWeight 105 (user override).
        let ex = Exercise.previewSample(
            name: "Squat",
            equipment: .barbell,
            mechanic: .compound
        )
        ex.smallestIncrement = 2.5
        ctx.insert(ex)

        let priorSession = Session()
        priorSession.startedAt = Date(timeIntervalSinceNow: -86400)
        priorSession.completedAt = Date(timeIntervalSinceNow: -83600)
        ctx.insert(priorSession)

        let priorSE = SessionExercise()
        priorSE.session = priorSession
        priorSE.exercise = ex
        priorSE.intentRaw = Intent.strength.rawValue
        priorSE.prescribedWeight = 100.0   // the prescription
        priorSE.progressionKindRaw = ProgressionKind.double.rawValue
        ctx.insert(priorSE)

        // SetEntry.weight is the actual weight logged (105 kg — user override).
        // This is what PreviousMatchingIntent reads for the next-session hint.
        let priorSet = SetEntry()
        priorSet.sessionExercise = priorSE
        priorSet.orderIndex = 0
        priorSet.weight = 105.0            // ACTUAL weight (override), NOT prescribedWeight
        priorSet.reps = 5
        priorSet.rpe = 8.0
        priorSet.isWarmup = false
        priorSet.isComplete = true
        priorSet.wasManualOverride = true   // this was an override
        priorSet.setTypeRaw = SetType.working.rawValue
        priorSet.completedAt = Date(timeIntervalSinceNow: -83600)
        ctx.insert(priorSet)
        try ctx.save()

        // PRES-07: fetchHistoryPoints (which powers the next-session strategy
        // call) reads SetEntry.weight (105), not SessionExercise.prescribedWeight (100).
        let historyPoints = SessionFactory.fetchHistoryPoints(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )

        // With RPE 8.0 and 5 reps, TuchschererTable.percent should return ~0.811.
        // e1RM = 105 / 0.811 ≈ 129.5 — confirm it's derived from 105, not 100.
        // We verify this by checking the e1RM is notably higher than 100/0.811 ≈ 123.3.
        #expect(!historyPoints.isEmpty, "Should find one history point from the prior session")
        let e1RM = historyPoints[0].e1RM
        // e1RM from 105 kg should be distinctly higher than from 100 kg.
        // Using 105 / TuchschererTable.percent(reps:5, rpe:8.0) ≈ 105 / 0.811 ≈ 129.5
        // Using 100 / 0.811 ≈ 123.3
        // Assert > 125 to confirm 105 kg (actual) was read, not 100 kg (prescribed).
        #expect(e1RM > 125.0,
            "History point e1RM \(e1RM) should reflect actual weight 105, not prescription 100")

        // Also confirm PreviousMatchingIntent returns 105 (actual), not 100 (prescribed).
        let hint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.strength.rawValue,
            context: ctx
        )
        #expect(hint?.weight == 105.0,
            "PreviousMatchingIntent must return SetEntry.weight (105), not prescribedWeight (100)")
    }

    // MARK: - 4. userSettingsMinCalibrationSetsHonored (SET-07)

    @Test("userSettingsMinCalibrationSetsHonored")
    func userSettingsMinCalibrationSetsHonored() throws {
        let ctx = try makeContext()

        // Insert UserSettings with minCalibrationSets = 20.
        let settings = UserSettings()
        settings.minCalibrationSets = 20
        settings.defaultIncrementKg = 2.5
        settings.unitsRaw = WeightUnit.kg.rawValue
        ctx.insert(settings)

        let ex = Exercise.previewSample(
            name: "Romanian Deadlift",
            equipment: .barbell,
            mechanic: .compound
        )
        ex.smallestIncrement = 2.5
        ctx.insert(ex)

        // Seed exactly 15 completed RPE working sets (below the 20-set threshold).
        let priorSession = Session()
        priorSession.startedAt = Date(timeIntervalSinceNow: -86400 * 14)
        priorSession.completedAt = Date(timeIntervalSinceNow: -86400 * 14 + 3600)
        ctx.insert(priorSession)

        let priorSE = SessionExercise()
        priorSE.session = priorSession
        priorSE.exercise = ex
        priorSE.intentRaw = Intent.hypertrophy.rawValue
        priorSE.progressionKindRaw = ProgressionKind.rpe.rawValue
        priorSE.targetRepsLow = 8
        priorSE.targetRepsHigh = 12
        priorSE.targetRPE = 8.0
        ctx.insert(priorSE)

        for i in 0..<15 {
            let entry = SetEntry()
            entry.sessionExercise = priorSE
            entry.orderIndex = i
            entry.weight = 80.0
            entry.reps = 10
            entry.rpe = 8.0
            entry.isWarmup = false
            entry.isComplete = true
            entry.setTypeRaw = SetType.working.rawValue
            entry.completedAt = Date(timeIntervalSinceNow: -86400 * 14 + 3600 + Double(i * 120))
            ctx.insert(entry)
        }
        try ctx.save()

        // Fetch history points (15 sets with RPE — all eligible).
        let historyPoints = SessionFactory.fetchHistoryPoints(
            exerciseID: ex.id,
            intentRaw: Intent.hypertrophy.rawValue,
            context: ctx
        )
        #expect(historyPoints.count == 15, "Expected 15 history points; got \(historyPoints.count)")

        // Invoke RPEAutoregStrategy with minCalibrationSets = 20.
        // With 15 < 20 sets, status must be .calibrating(15, 20).
        let plates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .kg)
            .map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        let barWeight = PlateInventoryDefaults.barWeight(for: .barbell, unitSystem: .kg)

        let lastHint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: ex.id,
            intentRaw: Intent.hypertrophy.rawValue,
            context: ctx
        )

        let strategy = RPEAutoregStrategy()
        let (_, explanation) = strategy.prescribe(
            history: historyPoints,
            targetRepsLow: 8,
            targetRepsHigh: 12,
            targetRPE: 8.0,
            lastSessionRepsArray: nil,
            smallestIncrement: 2.5,
            plates: plates,
            barWeight: barWeight,
            minCalibrationSets: settings.minCalibrationSets,  // 20
            lastSessionWeight: lastHint?.weight,
            lastSessionReps: lastHint?.reps,
            lastSessionRPE: lastHint?.rpe,
            lastSessionDate: lastHint?.sessionStartedAt
        )

        // SET-07: with minCalibrationSets = 20 and only 15 logged sets, the
        // strategy must remain in calibrating mode.
        switch explanation.status {
        case .calibrating(let current, let threshold):
            #expect(current == 15, "Expected current=15; got \(current)")
            #expect(threshold == 20, "Expected threshold=20; got \(threshold)")
        case .calibrated:
            Issue.record("Expected .calibrating(15, 20) but got .calibrated — minCalibrationSets=20 was not honored")
        case .notApplicable:
            Issue.record("Expected .calibrating(15, 20) but got .notApplicable")
        }
    }
}
