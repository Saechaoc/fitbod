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
import SwiftUI
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

    // MARK: - Test 4: not-trained edge (total == 0) → "NOT TRAINED" in muted

    @Test("not-trained edge (total == 0) renders a readable muted NOT TRAINED chip and count")
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
                "isNotTrained must be true when totalSetsRounded == 0")
        // bruFaint is a fill: as text on the paper row it can't be read.
        #expect(bar.chipColor == .bruMuted, "NOT TRAINED chip outlines in bruMuted, as in the reference")
        #expect(bar.chipShouldFill == false)
        #expect(bar.countColor == .bruMuted, "the 0 count must stay readable")
    }

    // MARK: - Test 5: set count color per zone

    @Test("set count reads in muted under MEV, ink when productive, signal text near and over MRV",
          arguments: [(5, Color.bruMuted), (15, Color.bruInk), (21, Color.bruSignalText), (24, Color.bruSignalText)])
    func countColorFollowsZone(sets: Int, expected: Color) {
        let bar = MuscleVolumeBar(
            muscle: makeMusclePure(),
            target: makeTarget(mev: 8, mav: 18, mrv: 22),
            total: WeightedSetTotal(directSets: Double(sets), indirectSets: 0),
            delta: WeekOverWeekDelta(currentWeekTotal: Double(sets), previousWeekTotal: Double(sets))
        )
        #expect(bar.countColor == expected, "\(sets) sets is \(bar.zone)")
    }

    // MARK: - Test 6: shared axis

    private func makeBar(sets: Int, mrv: Int = 22, axisSets: Int? = nil) -> MuscleVolumeBar {
        let target = makeTarget(mev: 8, mav: 18, mrv: mrv)
        let total = WeightedSetTotal(directSets: Double(sets), indirectSets: 0)
        let delta = WeekOverWeekDelta(currentWeekTotal: Double(sets), previousWeekTotal: Double(sets))
        if let axisSets {
            return MuscleVolumeBar(muscle: makeMusclePure(), target: target, total: total,
                                   delta: delta, axisSets: axisSets)
        }
        return MuscleVolumeBar(muscle: makeMusclePure(), target: target, total: total, delta: delta)
    }

    @Test("the track spans the reference's 25 sets by default, so MRV 22 sits inside it")
    func axisDefaultsToTwentyFiveSets() {
        let bar = makeBar(sets: 16)
        #expect(MuscleVolumeBar.minimumAxisSets == 25)
        #expect(bar.axisMax == 25)
        #expect(bar.fillFraction == 16.0 / 25.0)
    }

    @Test("volume past MRV still grows the fill, up to the end of the track")
    func fillShowsVolumePastMRV() {
        #expect(makeBar(sets: 24).fillFraction > makeBar(sets: 22).fillFraction)
        #expect(makeBar(sets: 40).fillFraction == 1)
        #expect(makeBar(sets: 0).fillFraction == 0)
    }

    @Test("a row uses the shared axis, stretched only if its own MRV runs past it")
    func axisFollowsSharedValueAndMRV() {
        #expect(makeBar(sets: 10, axisSets: 30).axisMax == 30)
        #expect(makeBar(sets: 10, mrv: 32).axisMax == 32)
        #expect(makeBar(sets: 10, mrv: 32, axisSets: 30).axisMax == 32)
    }
}
