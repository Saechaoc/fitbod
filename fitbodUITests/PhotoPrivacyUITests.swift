import XCTest

final class PhotoPrivacyUITests: XCTestCase {
    @MainActor
    func testUnreadablePhotoRetryAndRemovalPreserveTheExercise() throws {
        continueAfterFailure = false
        let app = UITestNavigation.launch(UITestNavigation.freshStore + ["-fitbod-seed-unreadable-photo"])
        let error = app.staticTexts["photoPreparation.message"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        app.buttons["photoPreparation.retry"].tap()
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(app.buttons["Settings"].frame.minY, app.buttons["photoPreparation.later"].frame.maxY)
        UITestNavigation.saveScreenshot("RM004", "photo-retry")
        app.buttons["photoPreparation.later"].tap()
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        UITestNavigation.type("Unreadable photo test", into: search)
        let exercise = app.staticTexts["Unreadable photo test"].firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 10))
        exercise.tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        let remove = app.buttons["customExercise.removePhoto"]
        UITestNavigation.reveal(remove, in: app)
        XCTAssertTrue(remove.waitForExistence(timeout: 10))
        remove.tap()
        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true).tap()
        UITestNavigation.relaunch(app)
        XCTAssertFalse(error.exists, "Removing the unreadable photo must let preparation succeed")
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.type("Unreadable photo test", into: search)
        XCTAssertTrue(exercise.waitForExistence(timeout: 10), "Removing a photo must keep the exercise")
    }
}
