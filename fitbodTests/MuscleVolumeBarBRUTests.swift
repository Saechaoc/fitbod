// MuscleVolumeBarBRUTests.swift
// fitbodTests
//
// Phase 05.1-01 Task 2 — TDD RED suite for the BRU-reskinned MuscleVolumeBar.
//
// Strategy:
//   Tests assert the public/internal computed properties that encode the
//   BRU chip contract (chipLabel, chipColor identity, chipShouldFill) and
//   the accessibility label verbatim. These properties are exposed as
//   `internal` on MuscleVolumeBar for testability.
//
//   The tests use the pure-value path (no SwiftUI rendering) — they
//   construct a MuscleVolumeBar and call its computed properties directly.
//   This is the same pattern used by BRUCorePrimitivesTests (which tests
//   BRUButton.Size.minHeight without rendering).
//
// These tests are GREEN once Task 2 GREEN implementation ships.

import Foundation
import Testing
@testable import fitbod

// MARK: - MuscleVolumeBarBRUTests

@Suite("MuscleVolumeBarBRU")
struct MuscleVolumeBarBRUTests {

    // MARK: - Helpers

    /// Build a minimal MuscleGroup without SwiftData.
    private func makeMusclePure(slug: String = "chest", displayName: String = "Chest") -> MuscleGroup {
        let m = MuscleGroup()
        m.slug = slug
        m.displayName = displayName
        return m
    }

    /// Build a minimal MuscleVolumeTarget without SwiftData.
    private func makeTarget(mev: Int = 8, mav: Int = 18, mrv: Int = 22) -> MuscleVolumeTarget {
        let t = MuscleVolumeTarget()
        t.mev = mev
        t.mav = mav
        t.mrv = mrv
        t.mv = 4
        return t
    }

    // MARK: - Test 1: productive zone + headroom ≥ 2 → "ADD A SET"

    @Test("productive zone with (mav − total) ≥ 2 renders chip label ADD A SET")
    func productiveHeadroomChipIsAddASet() {
        // mav=18, total=15 → headroom = 18 - 15 = 3 ≥ 2 → ADD A SET
        let bar = MuscleVolumeBar(
            muscle: makeMusclePure(),
            target: makeTarget(mev: 8, mav: 18, mrv: 22),
            total: WeightedSetTotal(directSets: 15, indirectSets: 0),
            delta: WeekOverWeekDelta(currentWeekTotal: 15, previousWeekTotal: 12)
        )
        #expect(bar.chipLabel == "ADD A SET",
                "productive zone with ≥2 sets of headroom to MAV must chip ADD A SET per UI-SPEC §Copy overlay")
    }

    // MARK: - Test 2: belowMEV zone → "UNDER MEV" filled bruAmber

    @Test("belowMEV zone renders chip label UNDER MEV with fill=true")
    func belowMEVChipIsUnderMEVFilled() {
        // total=5, mev=8 → belowMEV
        let bar = MuscleVolumeBar(
            muscle: makeMusclePure(),
            target: makeTarget(mev: 8, mav: 18, mrv: 22),
            total: WeightedSetTotal(directSets: 5, indirectSets: 0),
            delta: WeekOverWeekDelta(currentWeekTotal: 5, previousWeekTotal: 7)
        )
        #expect(bar.chipLabel == "UNDER MEV",
                "belowMEV zone must chip UNDER MEV per UI-SPEC §Copy overlay")
        #expect(bar.chipShouldFill == true,
                "belowMEV chip must be filled (bruAmber filled) per UI-SPEC §Copy overlay")
    }

    // MARK: - Test 3: accessibility label still reads D-06 verbatim sentence

    @Test("accessibilityDescription for belowMEV still reads D-06 verbatim zone.verb")
    func belowMEVAccessibilityLabelUsesVerbatimVerb() {
        // The visible chip shows "UNDER MEV" but the accessibility label
        // must use the D-06 verbatim sentence per UI-SPEC §Copy overlay table.
        let bar = MuscleVolumeBar(
            muscle: makeMusclePure(displayName: "Chest"),
            target: makeTarget(mev: 8, mav: 18, mrv: 22),
            total: WeightedSetTotal(directSets: 5, indirectSets: 0),
            delta: WeekOverWeekDelta(currentWeekTotal: 5, previousWeekTotal: 7)
        )
        let expected = "Chest: 5 sets this week, Below MEV — add volume. -2 vs last week."
        #expect(bar.accessibilityDescription == expected,
                "accessibilityDescription must preserve D-06 verbatim zone.verb sentence per UI-SPEC §Accessibility Contract")
    }

    // MARK: - Test 4: not-trained edge (total == 0) → "NOT TRAINED", opacity 0.5

    @Test("not-trained edge (total == 0) renders chip NOT TRAINED and isNotTrained flag true")
    func notTrainedEdgeChipIsNotTrained() {
        let bar = MuscleVolumeBar(
            muscle: makeMusclePure(),
            target: makeTarget(mev: 8, mav: 18, mrv: 22),
            total: WeightedSetTotal(directSets: 0, indirectSets: 0),
            delta: WeekOverWeekDelta(currentWeekTotal: 0, previousWeekTotal: 0)
        )
        #expect(bar.chipLabel == "NOT TRAINED",
                "totalSetsRounded == 0 must render NOT TRAINED chip per UI-SPEC §Copy overlay")
        #expect(bar.isNotTrained == true,
                "isNotTrained must be true when totalSetsRounded == 0 so the view applies opacity 0.5")
    }
}
