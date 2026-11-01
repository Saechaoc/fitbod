// SetRowsIgnoreOverridesTests.swift
//
// Ticket T110, finding F223. The session editor's set list showed an
// exercise's per-set overrides in place of its own prescription, and hid
// the other sets, though the logger builds every working set from the
// exercise's prescription and never applies an override.

import Foundation
import Testing
@testable import fitbod

@MainActor
struct SetRowsIgnoreOverridesTests {

    @Test("The set list shows the exercise's own prescription for every set, even with a stored override on set 1")
    func rowsIgnoreStoredOverrides() {
        let exercise = RoutineExerciseDraft()
        exercise.targetSets = 3
        exercise.targetRepsLow = 8
        exercise.targetRepsHigh = 12
        exercise.targetRPE = 8
        let override = exercise.appendOverride(setIndex: 0)
        override.targetRepsLow = 5
        override.targetRepsHigh = 5
        override.targetRPE = 9

        let expected = (1...3).map { SetRowsContainer.Row(setNumber: $0, reps: 8, rpe: 8) }
        #expect(SetRowsContainer.rows(for: exercise) == expected)
        // The stored override stays as it was.
        #expect(exercise.setOverrides.count == 1)
        #expect(exercise.setOverrides.first?.targetRepsLow == 5)
        #expect(exercise.setOverrides.first?.targetRPE == 9)
    }
}
