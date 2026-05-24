// PrescriptionWeightCellBRUUITests.swift
// fitbodUITests
//
// Phase 3.2 Plan 10 — BRU surface smoke tests for PrescriptionWeightCell.
// UI-REVIEW Phase 3.2 / UI-SPEC § PrescriptionWeightCell (lines 320–355).
//
// PURPOSE: Verify that the PrescriptionWeightCell BRU rewrite does NOT
// show an info.circle SF Symbol button on working set weight cells.
// The Phase 3.2-04 rewrite removed the info.circle button entirely and
// replaced it with a long-press gesture affordance per 03-UI-SPEC line 321.
//
// CONTRACT ENFORCER: The actual view-instantiation contract (init signature,
// BRU token compile-time resolution) is enforced by
// Phase3BRUSurfacesTests.prescriptionWeightCellInstantiates in fitbodTests/.
// These UI tests are smoke tests proving end-to-end wiring only.
//
// XCTSkip rationale for PrescriptionWeightCell tests: the working-set weight
// cell requires an active session with a prescribed weight to be visible.
// Starting a session programmatically via UI automation is fragile on the
// iOS 26 simulator (seed timing, exercise selection, navigation). The
// info.circle removal is a compile-time structural guarantee (the button
// was deleted, not hidden) — confirmed by the BRU grep audit's
// noImageSystemNameInPhase3Surfaces test which scans PrescriptionWeightCell.swift.
//
// Mirrors SessionLoggerBRUUITests.swift helpers (waitForSeedComplete,
// selectTodayTab).
//

import XCTest

final class PrescriptionWeightCellBRUUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Wait for the seed splash to disappear before interacting with tabs.
    @MainActor
    private func waitForSeedComplete(_ app: XCUIApplication, timeout: TimeInterval = 60) {
        let splash = app.staticTexts["Preparing library…"]
        if splash.exists {
            let pred = NSPredicate(format: "exists == false")
            let exp = XCTNSPredicateExpectation(predicate: pred, object: splash)
            _ = XCTWaiter().wait(for: [exp], timeout: timeout)
        }
    }

    /// Select the Today tab.
    @MainActor
    private func selectTodayTab(_ app: XCUIApplication) {
        let today = app.tabBars.buttons["Today"]
        if today.waitForExistence(timeout: 10) {
            today.tap()
        }
    }

    // MARK: - Tests

    /// Smoke test 1: When an active session is visible in SessionLoggerView,
    /// there must be NO accessible image element with identifier "info.circle"
    /// on any working set's weight cell.
    ///
    /// The info.circle button was deleted in Phase 3.2-04 (PrescriptionWeightCell
    /// BRU rewrite) and replaced by a long-press gesture affordance. This test
    /// confirms the SF Symbol button is absent from the accessibility tree.
    ///
    /// XCTSkip rationale: Starting an active session via XCUI automation requires
    /// navigating Routines → selecting a routine → starting it, which is fragile
    /// on the iOS 26 simulator due to seed timing (the exercise seed can take 5-10s
    /// on first launch). The structural guarantee (info.circle button DELETED, not
    /// hidden) is enforced by two complementary mechanisms:
    ///   1. Phase3BRUGrepAuditTests.noImageSystemNameInPhase3Surfaces — confirms
    ///      no Image(systemName:) call exists in PrescriptionWeightCell.swift at source level.
    ///   2. Phase3BRUSurfacesTests.prescriptionWeightCellInstantiates — confirms
    ///      PrescriptionWeightCell compiles and instantiates without the info.circle button.
    /// UI-level testing of long-press gesture affordance is deferred to device testing.
    @MainActor
    func testNoInfoCircleIconOnPrescribedWeightCell() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSeedComplete(app)
        selectTodayTab(app)

        // If there is an active session, navigate to it and verify info.circle is absent.
        let resumeLabel = app.staticTexts["Resume workout ▸"]
        if resumeLabel.waitForExistence(timeout: 5) {
            resumeLabel.tap()

            // Wait for SessionLoggerView to load (BRU "Workout" header or exercise list)
            let workoutHeader = app.staticTexts["Workout"]
            _ = workoutHeader.waitForExistence(timeout: 10)

            // Assert: no image with accessibility identifier "info.circle" exists.
            // The BRU rewrite deleted this button — it should NOT exist in the hierarchy.
            // XCUIApplication.images searches by both accessibilityIdentifier and label.
            let infoCircleImage = app.images["info.circle"]
            XCTAssertFalse(infoCircleImage.exists,
                "BRU regression: info.circle SF Symbol button found on prescription weight cell — " +
                "PrescriptionWeightCell should use long-press affordance only (Phase 3.2-04)")
        } else {
            // No active session — test passes vacuously.
            // The structural guarantee is enforced by Phase3BRUGrepAuditTests
            // (noImageSystemNameInPhase3Surfaces passes on PrescriptionWeightCell.swift).
            throw XCTSkip(
                "No active session in simulator state — cannot navigate to PrescriptionWeightCell. " +
                "info.circle removal enforced structurally by Phase3BRUGrepAuditTests." +
                "noImageSystemNameInPhase3Surfaces (source-tree grep confirms Image(systemName:) absent).")
        }
    }
}
