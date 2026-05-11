//
//  PrescriptionDefaultsTests.swift
//  fitbodTests
//
//  Truth-table coverage for `PrescriptionDefaults.apply(to:from:)`
//  (ROUTINE-09 + CONTEXT.md Area 1). Four `@Test` functions:
//
//    1. compoundBarbellStrength — Bench Press (compound + barbell) →
//       strength intent + 4-6 reps + 180s rest
//    2. compoundDumbbellHypertrophy — DB Press (compound + dumbbell) →
//       hypertrophy intent + 8-12 reps + 180s rest
//    3. isolationHypertrophy — Curl (isolation + dumbbell) →
//       hypertrophy intent + 8-12 reps + 90s rest
//    4. restMatchesMechanic — sweep every Mechanic / Equipment
//       combination and verify the rest-time rule holds
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("PrescriptionDefaults (ROUTINE-09 + CONTEXT.md Area 1)")
struct PrescriptionDefaultsTests {

    @Test("compoundBarbellStrength — Bench Press → strength + 4-6 reps + 180s rest")
    func compoundBarbellStrength() {
        let bench = Exercise(
            name: "Barbell Bench Press",
            canonicalName: "barbell bench press",
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
        let draft = RoutineExerciseDraft()
        PrescriptionDefaults.apply(to: draft, from: bench)
        #expect(draft.intent == .strength)
        #expect(draft.targetRepsLow == 4)
        #expect(draft.targetRepsHigh == 6)
        #expect(draft.targetRPE == 8.0)
        #expect(draft.prescribedRestSeconds == 180)
        #expect(draft.progressionKind == .double)
    }

    @Test("compoundDumbbellHypertrophy — DB Press → hypertrophy + 8-12 reps + 180s rest")
    func compoundDumbbellHypertrophy() {
        let dbPress = Exercise(
            name: "Dumbbell Press",
            canonicalName: "dumbbell press",
            equipmentRaw: Equipment.dumbbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
        let draft = RoutineExerciseDraft()
        PrescriptionDefaults.apply(to: draft, from: dbPress)
        // Compound non-barbell → hypertrophy default
        #expect(draft.intent == .hypertrophy)
        #expect(draft.targetRepsLow == 8)
        #expect(draft.targetRepsHigh == 12)
        // Still compound, so 180s rest
        #expect(draft.prescribedRestSeconds == 180)
    }

    @Test("isolationHypertrophy — Curl → hypertrophy + 8-12 reps + 90s rest")
    func isolationHypertrophy() {
        let curl = Exercise(
            name: "Dumbbell Curl",
            canonicalName: "dumbbell curl",
            equipmentRaw: Equipment.dumbbell.rawValue,
            mechanicRaw: Mechanic.isolation.rawValue
        )
        let draft = RoutineExerciseDraft()
        PrescriptionDefaults.apply(to: draft, from: curl)
        #expect(draft.intent == .hypertrophy)
        #expect(draft.targetRepsLow == 8)
        #expect(draft.targetRepsHigh == 12)
        #expect(draft.prescribedRestSeconds == 90)
    }

    @Test("restMatchesMechanic — sweep — every compound → 180s, every isolation → 90s")
    func restMatchesMechanic() {
        for equipment in Equipment.allCases {
            for mechanic in Mechanic.allCases {
                let ex = Exercise(
                    name: "Sweep \(equipment.rawValue) \(mechanic.rawValue)",
                    canonicalName: "sweep",
                    equipmentRaw: equipment.rawValue,
                    mechanicRaw: mechanic.rawValue
                )
                let draft = RoutineExerciseDraft()
                PrescriptionDefaults.apply(to: draft, from: ex)
                if mechanic == .compound {
                    #expect(
                        draft.prescribedRestSeconds == 180,
                        "compound + \(equipment.rawValue) → 180s rest, got \(draft.prescribedRestSeconds)"
                    )
                } else {
                    #expect(
                        draft.prescribedRestSeconds == 90,
                        "isolation + \(equipment.rawValue) → 90s rest, got \(draft.prescribedRestSeconds)"
                    )
                }
            }
        }
    }
}
