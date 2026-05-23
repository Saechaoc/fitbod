//
//  MuscleRegionPathsTests.swift
//  fitbodTests
//
//  Pins the slug-registry coverage of `MuscleRegionPaths.front` and
//  `.back`. Wave 0 ships stub Rectangle paths; Wave 3 (plan 05)
//  replaces them with anatomically-correct beziers. These tests pin
//  the REGISTRY shape independent of geometry — they stay GREEN even
//  after Wave 3's geometry refresh as long as every slug stays present.
//

import Foundation
import SwiftUI
import Testing
@testable import fitbod

@Suite("MuscleRegionPaths")
struct MuscleRegionPathsTests {

    // MARK: - 1. Front-view registry

    @Test("Front registry contains all front-visible muscle slugs")
    func frontContainsExpectedSlugs() {
        let expected: Set<String> = [
            "chest", "shoulders", "biceps", "forearms",
            "abdominals", "quadriceps", "calves",
            "neck", "abductors", "adductors",
        ]
        let actual = Set(MuscleRegionPaths.front.keys)
        #expect(expected.isSubset(of: actual))
    }

    // MARK: - 2. Back-view registry

    @Test("Back registry contains all back-visible muscle slugs")
    func backContainsExpectedSlugs() {
        let expected: Set<String> = [
            "traps", "lats", "middle back", "lower back",
            "shoulders", "triceps", "glutes", "hamstrings", "calves",
        ]
        let actual = Set(MuscleRegionPaths.back.keys)
        #expect(expected.isSubset(of: actual))
    }

    // MARK: - 3. Combined registry covers all 17 muscle slugs

    @Test("Combined front ∪ back covers every free-exercise-db muscle slug")
    func combinedRegistryCoversAllSeventeenMuscleSlugs() {
        let combined = Set(MuscleRegionPaths.front.keys)
            .union(MuscleRegionPaths.back.keys)
        let expected = Set(MuscleRegionMap.allSlugs)
        #expect(combined == expected)
    }

    // MARK: - 4. No empty paths

    @Test("No empty Paths — every entry has a non-null boundingRect")
    func noEmptyPaths() {
        for (slug, path) in MuscleRegionPaths.front {
            let r = path.boundingRect
            #expect(r.width > 0, "front path for \(slug) has zero width")
            #expect(r.height > 0, "front path for \(slug) has zero height")
        }
        for (slug, path) in MuscleRegionPaths.back {
            let r = path.boundingRect
            #expect(r.width > 0, "back path for \(slug) has zero width")
            #expect(r.height > 0, "back path for \(slug) has zero height")
        }
    }
}
