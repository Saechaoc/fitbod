//
//  MuscleRegionPathsTests.swift
//  fitbodTests
//
//  Pins the slug-registry coverage of `MuscleRegionPaths.front` and
//  `.back`. Phase 5.1 plan 04 replaces anatomical bezier paths with
//  axis-aligned grid rectangles (GridRegion array). These tests pin the
//  REGISTRY shape independent of geometry.
//
//  TDD RED→GREEN: Written before the GridRegion-based implementation to
//  drive the rewrite. Coverage note: the 10×12 heatmap grid covers 14 of
//  the 17 free-exercise-db slugs directly. NECK is rendered as
//  "neck-decorative" (no zone binding). abductors + adductors are not on
//  the visible heatmap grid — they are intentionally excluded per
//  bru-screens/heatmap.jsx verbatim contract.
//

import Foundation
import SwiftUI
import Testing
@testable import fitbod

@Suite("MuscleRegionPaths")
struct MuscleRegionPathsTests {

    // MARK: - 1. Slug coverage — grid-visible slugs

    /// The 14 slugs that the 10×12 block-anatomy heatmap grid exposes.
    /// Neck is decorative (rendered as "neck-decorative"). Abductors and
    /// adductors are absent from bru-screens/heatmap.jsx — not rendered.
    private static let gridCoverableSlugs: Set<String> = [
        "chest", "shoulders", "biceps", "forearms", "abdominals",
        "quadriceps", "calves",
        "traps", "lats", "middle back", "lower back",
        "triceps", "glutes", "hamstrings",
    ]

    @Test("Combined front + back covers all grid-visible muscle slugs")
    func combinedRegistryCoversGridSlugs() {
        let frontSlugs = Set(MuscleRegionPaths.front.map(\.slug))
        let backSlugs = Set(MuscleRegionPaths.back.map(\.slug))
        let combined = frontSlugs.union(backSlugs)
        let nonDecorative = combined.filter { !$0.hasSuffix("-decorative") }
        let missing = Self.gridCoverableSlugs.subtracting(nonDecorative)
        #expect(missing.isEmpty, "Missing grid slugs: \(missing)")
    }

    @Test("No slug outside the expected set appears in the registry")
    func noUnexpectedSlugs() {
        let allowed = Self.gridCoverableSlugs.union(["neck-decorative"])
        for region in MuscleRegionPaths.front {
            #expect(allowed.contains(region.slug),
                "Unexpected front slug: '\(region.slug)'")
        }
        for region in MuscleRegionPaths.back {
            #expect(allowed.contains(region.slug),
                "Unexpected back slug: '\(region.slug)'")
        }
    }

    // MARK: - 2. Rect validity

    @Test("Every GridRegion has positive width and height")
    func everyRegionHasPositiveRect() {
        for region in MuscleRegionPaths.front {
            let r = region.rect()
            #expect(r.width > 0, "front region '\(region.displayLabel)' has zero width")
            #expect(r.height > 0, "front region '\(region.displayLabel)' has zero height")
        }
        for region in MuscleRegionPaths.back {
            let r = region.rect()
            #expect(r.width > 0, "back region '\(region.displayLabel)' has zero width")
            #expect(r.height > 0, "back region '\(region.displayLabel)' has zero height")
        }
    }

    // MARK: - 3. Symmetrical pairs

    @Test("Symmetrical paired regions both resolve to the same canonical slug")
    func symmetricalPairsSameSlug() {
        // Front pairs: CHEST L + CHEST R → "chest"
        let frontChest = MuscleRegionPaths.front.filter { $0.displayLabel.hasPrefix("CHEST") }
        #expect(frontChest.count == 2, "Expected 2 CHEST regions, got \(frontChest.count)")
        #expect(Set(frontChest.map(\.slug)) == ["chest"])

        // Front pairs: BICEP × 2 → "biceps"
        let frontBicep = MuscleRegionPaths.front.filter { $0.displayLabel == "BICEP" }
        #expect(frontBicep.count == 2, "Expected 2 BICEP regions, got \(frontBicep.count)")
        #expect(Set(frontBicep.map(\.slug)) == ["biceps"])

        // Front pairs: QUAD × 2 → "quadriceps"
        let frontQuad = MuscleRegionPaths.front.filter { $0.displayLabel == "QUAD" }
        #expect(frontQuad.count == 2, "Expected 2 QUAD regions, got \(frontQuad.count)")
        #expect(Set(frontQuad.map(\.slug)) == ["quadriceps"])

        // Back pairs: LAT × 2 → "lats"
        let backLat = MuscleRegionPaths.back.filter { $0.displayLabel == "LAT" }
        #expect(backLat.count == 2, "Expected 2 LAT regions, got \(backLat.count)")
        #expect(Set(backLat.map(\.slug)) == ["lats"])

        // Back pairs: HAM × 2 → "hamstrings"
        let backHam = MuscleRegionPaths.back.filter { $0.displayLabel == "HAM" }
        #expect(backHam.count == 2, "Expected 2 HAM regions, got \(backHam.count)")
        #expect(Set(backHam.map(\.slug)) == ["hamstrings"])

        // Back pairs: GLUTE × 2 → "glutes"
        let backGlute = MuscleRegionPaths.back.filter { $0.displayLabel == "GLUTE" }
        #expect(backGlute.count == 2, "Expected 2 GLUTE regions, got \(backGlute.count)")
        #expect(Set(backGlute.map(\.slug)) == ["glutes"])

        // Front: CALF × 2 → "calves"
        let frontCalf = MuscleRegionPaths.front.filter { $0.displayLabel == "CALF" }
        #expect(frontCalf.count == 2, "Expected 2 front CALF regions, got \(frontCalf.count)")
        #expect(Set(frontCalf.map(\.slug)) == ["calves"])

        // Back: CALF × 2 → "calves"
        let backCalf = MuscleRegionPaths.back.filter { $0.displayLabel == "CALF" }
        #expect(backCalf.count == 2, "Expected 2 back CALF regions, got \(backCalf.count)")
        #expect(Set(backCalf.map(\.slug)) == ["calves"])

        // Back pairs: TRI × 2 → "triceps"
        let backTri = MuscleRegionPaths.back.filter { $0.displayLabel == "TRI" }
        #expect(backTri.count == 2, "Expected 2 TRI regions, got \(backTri.count)")
        #expect(Set(backTri.map(\.slug)) == ["triceps"])
    }

    // MARK: - 4. Label content

    @Test("Front regions contain expected uppercase display labels from heatmap.jsx")
    func frontLabelsMatchHeatmapJSX() {
        let labels = Set(MuscleRegionPaths.front.map(\.displayLabel))
        // Expected front labels per bru-screens/heatmap.jsx lines 14–38
        let required: Set<String> = [
            "NECK", "DELT", "CHEST L", "CHEST R",
            "BICEP", "ABS L", "ABS R", "FORE", "QUAD", "CALF"
        ]
        for label in required {
            #expect(labels.contains(label), "Missing front label: '\(label)'")
        }
    }

    @Test("Back regions contain expected uppercase display labels from heatmap.jsx")
    func backLabelsMatchHeatmapJSX() {
        let labels = Set(MuscleRegionPaths.back.map(\.displayLabel))
        // Expected back labels per bru-screens/heatmap.jsx lines 40–66
        let required: Set<String> = [
            "NECK", "TRAPS", "R.DELT", "UPPER BACK",
            "LAT", "TRI", "LOWER BACK", "GLUTE", "HAM", "CALF"
        ]
        for label in required {
            #expect(labels.contains(label), "Missing back label: '\(label)'")
        }
    }
}
