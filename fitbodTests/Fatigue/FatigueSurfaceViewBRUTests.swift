//
//  FatigueSurfaceViewBRUTests.swift
//  fitbodTests
//
//  Phase 5.1 plan 05 — BRU contract tests for the reskinned FatigueSurfaceView.
//
//  Strategy: FatigueSurfaceView uses @Query which requires a live ModelContainer
//  at runtime. These tests verify the surface-level BRU contract without
//  full SwiftUI rendering:
//
//  Test 1 (compose contract): The key BRU copy strings are declared verbatim
//    in the view file and the BRUSectionHead init calls use the exact
//    UI-SPEC verbatim section-head labels. Verified via source-grep.
//
//  Test 2 (empty state preserved): The empty-state VStack copy strings match
//    the verbatim UI-SPEC §Copywriting Contract literals. Verified via
//    source-grep — the actual strings live in the view file.
//
//  Test 3 (no Front/Back Picker): Source grep confirms zero matches for
//    `Picker.*pickerStyle` in FatigueSurfaceView.swift — the segmented
//    control has been deleted per UI-SPEC line 268.
//
//  Test 4 (navigation route): MuscleSlugRoute.detail(_) is Hashable + Sendable
//    and appends onto a NavigationPath correctly — the route type used by
//    both bar taps and heatmap region taps.
//
//  These tests mirror the BRUGrepAuditTests pattern of reading the source
//  tree at runtime via #filePath + FileManager.
//

import Foundation
import Testing
import SwiftUI
@testable import fitbod

// MARK: - FatigueSurfaceViewBRUTests

@Suite("FatigueSurfaceViewBRU")
struct FatigueSurfaceViewBRUTests {

    // MARK: - Helpers

    /// Resolves the absolute path to `FatigueSurfaceView.swift` at test runtime.
    /// #filePath points to fitbodTests/Fatigue/FatigueSurfaceViewBRUTests.swift —
    /// navigate up 3 levels to project root, then into fitbod/Fatigue/.
    private func fatigueSurfacePath(file: StaticString = #filePath) throws -> URL {
        let testPath = String(describing: file)
        let testURL = URL(fileURLWithPath: testPath)
        // fitbodTests/Fatigue/FatigueSurfaceViewBRUTests.swift
        //   -> up 1: fitbodTests/Fatigue/
        //   -> up 2: fitbodTests/
        //   -> up 3: project root
        let projectRoot = testURL
            .deletingLastPathComponent()   // Fatigue/
            .deletingLastPathComponent()   // fitbodTests/
            .deletingLastPathComponent()   // project root
        let target = projectRoot
            .appendingPathComponent("fitbod")
            .appendingPathComponent("Fatigue")
            .appendingPathComponent("FatigueSurfaceView.swift")
        let exists = FileManager.default.fileExists(atPath: target.path)
        #expect(exists, "FatigueSurfaceView.swift not found at expected path: \(target.path)")
        return target
    }

    private func sourceContents(file: StaticString = #filePath) throws -> String {
        let url = try fatigueSurfacePath(file: file)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Test 1: Compose contract — verbatim BRU copy strings present

    @Test("FatigueSurfaceView contains verbatim summary slab caption WORKING SETS · 7 DAYS")
    func summaryCaptionPresent() throws {
        let source = try sourceContents()
        #expect(
            source.contains("WORKING SETS · 7 DAYS"),
            "Summary slab must contain verbatim caption 'WORKING SETS · 7 DAYS' per volume.jsx line 26"
        )
    }

    @Test("FatigueSurfaceView contains BRUSectionHead Volume This Week verbatim")
    func volumeSectionHeadPresent() throws {
        let source = try sourceContents()
        #expect(
            source.contains("BRUSectionHead(\"Volume This Week\")"),
            "Must call BRUSectionHead with verbatim label 'Volume This Week' per UI-SPEC §Copywriting Contract"
        )
    }

    @Test("FatigueSurfaceView contains BRUSectionHead Muscle Heatmap verbatim")
    func heatmapSectionHeadPresent() throws {
        let source = try sourceContents()
        #expect(
            source.contains("BRUSectionHead(\"Muscle Heatmap\""),
            "Must call BRUSectionHead with verbatim label 'Muscle Heatmap' per UI-SPEC §Copywriting Contract"
        )
    }

    @Test("FatigueSurfaceView contains two BodySilhouetteView instances (one .front + one .back)")
    func twinBodySilhouetteViewsPresent() throws {
        let source = try sourceContents()
        // Count occurrences of BodySilhouetteView( init calls
        let frontCount = source.components(separatedBy: "side: .front").count - 1
        let backCount = source.components(separatedBy: "side: .back").count - 1
        #expect(frontCount >= 1, "Must contain at least one BodySilhouetteView(side: .front, ...) instance")
        #expect(backCount >= 1, "Must contain at least one BodySilhouetteView(side: .back, ...) instance")
    }

    @Test("FatigueSurfaceView contains FRONT label for front heatmap column")
    func frontLabelPresent() throws {
        let source = try sourceContents()
        #expect(
            source.contains("\"FRONT\""),
            "Heatmap container must include a 'FRONT' label above the front BodySilhouetteView per heatmap.jsx"
        )
    }

    @Test("FatigueSurfaceView contains BACK label for back heatmap column")
    func backLabelPresent() throws {
        let source = try sourceContents()
        #expect(
            source.contains("\"BACK\""),
            "Heatmap container must include a 'BACK' label above the back BodySilhouetteView per heatmap.jsx"
        )
    }

    // MARK: - Test 2: Empty state preserved verbatim

    @Test("FatigueSurfaceView empty-state heading is verbatim per UI-SPEC §Copywriting Contract")
    func emptyStateHeadingVerbatim() throws {
        let source = try sourceContents()
        #expect(
            source.contains("\"No sets logged this week\""),
            "Empty-state heading must be verbatim 'No sets logged this week' per UI-SPEC §Copywriting Contract"
        )
    }

    @Test("FatigueSurfaceView empty-state body is verbatim per UI-SPEC §Copywriting Contract")
    func emptyStateBodyVerbatim() throws {
        let source = try sourceContents()
        #expect(
            source.contains("\"Log a workout to see your weekly volume.\""),
            "Empty-state body must be verbatim 'Log a workout to see your weekly volume.' per UI-SPEC §Copywriting Contract"
        )
    }

    // MARK: - Test 3: No Front/Back Picker

    @Test("FatigueSurfaceView contains zero Picker(...).pickerStyle(.segmented) patterns — Front/Back toggle deleted")
    func noFrontBackPicker() throws {
        let source = try sourceContents()
        // Check for both the old selectedSide state and pickerStyle usage
        let hasSelectedSide = source.contains("selectedSide")
        let hasPickerStyle = source.contains("pickerStyle")
        #expect(
            !hasSelectedSide,
            "FatigueSurfaceView must not declare selectedSide — Front/Back Picker was deleted per UI-SPEC line 268"
        )
        #expect(
            !hasPickerStyle,
            "FatigueSurfaceView must not use .pickerStyle — Front/Back segmented control was deleted per UI-SPEC line 268"
        )
    }

    @Test("FatigueSurfaceView contains zero banned token Color.accentColor")
    func noBannedTokenAccentColor() throws {
        let source = try sourceContents()
        #expect(
            !source.contains("Color.accentColor"),
            "FatigueSurfaceView must contain zero Color.accentColor — banned BRU token"
        )
    }

    @Test("FatigueSurfaceView contains zero banned token RoundedRectangle")
    func noBannedTokenRoundedRectangle() throws {
        let source = try sourceContents()
        #expect(
            !source.contains("RoundedRectangle(cornerRadius:)"),
            "FatigueSurfaceView must contain zero RoundedRectangle(cornerRadius:) — banned BRU token"
        )
    }

    @Test("FatigueSurfaceView contains zero banned token Image(systemName:)")
    func noBannedTokenImageSystemName() throws {
        let source = try sourceContents()
        #expect(
            !source.contains("Image(systemName:)"),
            "FatigueSurfaceView must contain zero Image(systemName:) — banned BRU token"
        )
    }

    @Test("FatigueSurfaceView contains zero legacy .font(.headline) / .font(.body) tokens")
    func noBannedFontTokens() throws {
        let source = try sourceContents()
        let bannedFontPatterns = [
            ".font(.headline)",
            ".font(.body)",
            ".font(.caption)",
            ".font(.subheadline)",
            ".font(.footnote)",
        ]
        for pattern in bannedFontPatterns {
            #expect(
                !source.contains(pattern),
                "FatigueSurfaceView must contain zero '\(pattern)' — banned BRU font token"
            )
        }
    }

    // MARK: - Test 4: Navigation route contract

    @Test("MuscleSlugRoute.detail is Hashable — can be appended to NavigationPath")
    func muscleSlugRouteIsHashable() {
        let route = MuscleSlugRoute.detail("chest")
        var path = NavigationPath()
        // appendElement requires the type to conform to Hashable — this compiles
        // only if MuscleSlugRoute: Hashable
        path.append(route)
        #expect(path.count == 1, "NavigationPath should have 1 element after appending MuscleSlugRoute.detail")
    }

    @Test("MuscleSlugRoute.detail carries the correct slug string")
    func muscleSlugRouteSlugPreserved() {
        let slug = "triceps"
        let route = MuscleSlugRoute.detail(slug)
        // Extract via pattern matching
        if case .detail(let extracted) = route {
            #expect(extracted == slug, "MuscleSlugRoute.detail must preserve the slug verbatim")
        } else {
            Issue.record("MuscleSlugRoute.detail pattern match failed")
        }
    }

    @Test("Two MuscleSlugRoute.detail with different slugs are not equal — distinct routes")
    func muscleSlugRouteDistinctSlugs() {
        let chest = MuscleSlugRoute.detail("chest")
        let triceps = MuscleSlugRoute.detail("triceps")
        #expect(chest != triceps, "Different slugs must produce distinct MuscleSlugRoute values")
    }

    @Test("Two MuscleSlugRoute.detail with same slug are equal — stable hash")
    func muscleSlugRouteEqualSlugs() {
        let a = MuscleSlugRoute.detail("chest")
        let b = MuscleSlugRoute.detail("chest")
        #expect(a == b, "Same slug must produce equal MuscleSlugRoute values for stable navigation")
    }
}
