//
//  EnumTests.swift
//  fitbodTests
//
//  Compile-time / case-count sanity checks for every domain enum.
//  Locks the case-set Day 1 so an accidental case rename in a future
//  phase trips a test, not a silent rawValue-mismatch in production.
//
//  LIB-06 anchor: Equipment must have exactly 9 cases (the 7 from the
//  requirement + `kettlebell` + `other` per RESEARCH Open Q #4). Every
//  other enum's case count is pinned for the same reason — the rawValue
//  strings end up persisted as on-disk SQLite cells, so a rename is a
//  data migration, not a refactor.
//

import Foundation
import Testing
@testable import fitbod

@Suite("Enums")
struct EnumTests {

    // MARK: - Intent (5 cases)

    @Test("Intent has exactly 5 cases")
    func intentHasFiveCases() {
        #expect(Intent.allCases.count == 5)
        #expect(Set(Intent.allCases.map(\.rawValue)) == [
            "strength", "hypertrophy", "power", "endurance", "technique",
        ])
    }

    // MARK: - ProgressionKind (4 cases)

    @Test("ProgressionKind has exactly 4 cases")
    func progressionKindHasFourCases() {
        #expect(ProgressionKind.allCases.count == 4)
        #expect(Set(ProgressionKind.allCases.map(\.rawValue)) == [
            "rpe", "double", "block", "hybrid",
        ])
    }

    // MARK: - Equipment (9 cases) — LIB-06 anchor

    @Test("Equipment has exactly 9 cases (LIB-06)")
    func equipmentHasNineCases() {
        #expect(Equipment.allCases.count == 9)
        #expect(Set(Equipment.allCases.map(\.rawValue)) == [
            "barbell",
            "dumbbell",
            "machine",
            "cable",
            "bands",
            "bodyweight",
            "weighted_bodyweight",
            "kettlebell",
            "other",
        ])
    }

    // MARK: - Mechanic (2 cases)

    @Test("Mechanic has exactly 2 cases")
    func mechanicHasTwoCases() {
        #expect(Mechanic.allCases.count == 2)
        #expect(Set(Mechanic.allCases.map(\.rawValue)) == ["compound", "isolation"])
    }

    // MARK: - Force (3 cases)

    @Test("Force has exactly 3 cases")
    func forceHasThreeCases() {
        #expect(Force.allCases.count == 3)
        #expect(Set(Force.allCases.map(\.rawValue)) == ["push", "pull", "static"])
    }

    // MARK: - Level (3 cases)

    @Test("Level has exactly 3 cases")
    func levelHasThreeCases() {
        #expect(Level.allCases.count == 3)
        #expect(Set(Level.allCases.map(\.rawValue)) == [
            "beginner", "intermediate", "expert",
        ])
    }

    // MARK: - Pattern (9 cases)

    @Test("Pattern has exactly 9 cases")
    func patternHasNineCases() {
        #expect(Pattern.allCases.count == 9)
        #expect(Set(Pattern.allCases.map(\.rawValue)) == [
            "horizontal_push", "vertical_push",
            "horizontal_pull", "vertical_pull",
            "squat", "hinge", "lunge", "carry", "core",
        ])
    }

    // MARK: - MuscleRegion (3 cases)

    @Test("MuscleRegion has exactly 3 cases")
    func muscleRegionHasThreeCases() {
        #expect(MuscleRegion.allCases.count == 3)
        #expect(Set(MuscleRegion.allCases.map(\.rawValue)) == ["upper", "lower", "core"])
    }

    // MARK: - WeightUnit (2 cases)

    @Test("WeightUnit has exactly 2 cases")
    func weightUnitHasTwoCases() {
        #expect(WeightUnit.allCases.count == 2)
        #expect(Set(WeightUnit.allCases.map(\.rawValue)) == ["lb", "kg"])
    }

    // MARK: - BlockPhaseKind (4 cases)

    @Test("BlockPhaseKind has exactly 4 cases")
    func blockPhaseKindHasFourCases() {
        #expect(BlockPhaseKind.allCases.count == 4)
        #expect(Set(BlockPhaseKind.allCases.map(\.rawValue)) == [
            "accumulation", "intensification", "realization", "deload",
        ])
    }

    // MARK: - SetType (5 cases)

    @Test("SetType has exactly 5 cases")
    func setTypeHasFiveCases() {
        #expect(SetType.allCases.count == 5)
        #expect(Set(SetType.allCases.map(\.rawValue)) == [
            "warmup", "working", "drop", "failure", "rest_pause",
        ])
    }

    // MARK: - Default values are members of their enum

    @Test("Every enum's static `default` is one of its cases")
    func defaultsAreMembers() {
        #expect(Intent.allCases.contains(Intent.default))
        #expect(ProgressionKind.allCases.contains(ProgressionKind.default))
        #expect(Equipment.allCases.contains(Equipment.default))
        #expect(Mechanic.allCases.contains(Mechanic.default))
        #expect(MuscleRegion.allCases.contains(MuscleRegion.default))
        #expect(WeightUnit.allCases.contains(WeightUnit.default))
        #expect(BlockPhaseKind.allCases.contains(BlockPhaseKind.default))
        #expect(SetType.allCases.contains(SetType.default))
    }
}
