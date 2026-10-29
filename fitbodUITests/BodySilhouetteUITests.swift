//
//  BodySilhouetteUITests.swift
//  fitbodUITests
//
//  Phase 5 VOL-05: the Muscle Heatmap section renders on Today with the
//  front and back silhouettes side by side. UI-SPEC line 268 removed the
//  Front/Back segmented picker, so both sides show at once.
//
//  Tap-to-navigate-into-PerMuscleDetailView is exercised in
//  PerMuscleDetailUITests via the volume-bar tap path (the bar's
//  accessibility tree is more stable than the per-region Path
//  hit-test geometry across simulator runs).
//

import XCTest

final class BodySilhouetteUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHeatmapSectionRendersOnTodayTab() throws {
        // Today shows the heatmap only once the week has volume.
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        UITestNavigation.reveal(app.staticTexts["Muscle Heatmap"], in: app)
    }

    @MainActor
    func testFrontAndBackRenderSideBySide() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let front = app.staticTexts["FRONT"]
        let back = app.staticTexts["BACK"]
        UITestNavigation.reveal(back, in: app)
        XCTAssertTrue(front.isHittable)
        XCTAssertLessThan(front.frame.maxX, back.frame.minX)
        XCTAssertEqual(front.frame.midY, back.frame.midY, accuracy: 1)
        XCTAssertEqual(app.segmentedControls.count, 0)
    }
}
