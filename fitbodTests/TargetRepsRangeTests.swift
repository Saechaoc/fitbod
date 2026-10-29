//
//  TargetRepsRangeTests.swift
//  fitbodTests
//
//  Review item 5: target reps are steppers whose ranges come from
//  `RoutineExerciseDraft`. The low end stops at the high end and the high
//  end stops at the low end, so stepping can never make low exceed high.
//

import Testing
@testable import fitbod

@MainActor
@Suite("TargetRepsRange")
struct TargetRepsRangeTests {

    private func draft(low: Int, high: Int) -> RoutineExerciseDraft {
        let draft = RoutineExerciseDraft()
        draft.targetRepsLow = low
        draft.targetRepsHigh = high
        return draft
    }

    @Test("Each end stops at the other, and follows it as it moves")
    func endsStopAtEachOther() {
        let d = draft(low: 4, high: 6)
        #expect(d.targetRepsLowRange == 1...6)
        #expect(d.targetRepsHighRange == 4...RoutineExerciseDraft.maxTargetReps)

        d.targetRepsHigh = 8
        #expect(d.targetRepsLowRange.upperBound == 8)
        d.targetRepsLow = 7
        #expect(d.targetRepsHighRange.lowerBound == 7)
    }

    @Test("Equal ends cannot step past each other", arguments: [1, 6, RoutineExerciseDraft.maxTargetReps])
    func equalEndsCannotCross(reps: Int) {
        let d = draft(low: reps, high: reps)
        #expect(!d.targetRepsLowRange.contains(reps + 1), "Low must not step above high")
        #expect(!d.targetRepsHighRange.contains(reps - 1), "High must not step below low")
    }

    /// Ranges with lowerBound > upperBound trap, so values typed before the
    /// steppers (0, 68, low above high) must still give valid ranges.
    @Test("Out-of-range stored values give valid ranges to step back from",
          arguments: [(0, 0), (16, 12), (6, 68), (99, 99)])
    func corruptValuesGiveValidRanges(low: Int, high: Int) {
        let d = draft(low: low, high: high)
        let limit = 1...RoutineExerciseDraft.maxTargetReps
        #expect(limit.contains(d.targetRepsLowRange.lowerBound) && limit.contains(d.targetRepsLowRange.upperBound))
        #expect(limit.contains(d.targetRepsHighRange.lowerBound) && limit.contains(d.targetRepsHighRange.upperBound))
    }
}
