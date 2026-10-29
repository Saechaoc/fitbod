import XCTest

/// Review item 34: one tap on Export CSV, Export JSON or backup CREATE opens
/// the share sheet. The first tap used to render the file and the second
/// tap shared it. Nothing is shared: each check closes the sheet.
final class SettingsExportUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testExportCSVOpensShareSheetOnFirstTap() throws {
        assertOneTapOpensShareSheet(NSPredicate(format: "label CONTAINS[c] %@", "Export CSV"), named: "Export CSV")
    }

    @MainActor
    func testExportJSONOpensShareSheetOnFirstTap() throws {
        assertOneTapOpensShareSheet(NSPredicate(format: "label CONTAINS[c] %@", "Export JSON"), named: "Export JSON")
    }

    @MainActor
    func testCreateBackupOpensShareSheetOnFirstTap() throws {
        assertOneTapOpensShareSheet(NSPredicate(format: "label ==[c] %@", "Create"), named: "backup CREATE")
    }

    @MainActor
    private func assertOneTapOpensShareSheet(
        _ predicate: NSPredicate, named name: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        UITestNavigation.openSettings(in: app)
        let control = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 10), "Missing \(name)", file: file, line: line)
        UITestNavigation.reveal(control, in: app)
        control.tap()

        let sheet = shareSheet(in: app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "One tap on \(name) must open the share sheet", file: file, line: line)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(name) share sheet"
        shot.lifetime = .keepAlways
        add(shot)

        // Close it without sharing anything, as a user taps outside it.
        let outside = app.otherElements["PopoverDismissRegion"]
        XCTAssertTrue(outside.exists, "The share sheet must close on a tap outside it", file: file, line: line)
        outside.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "The share sheet must close", file: file, line: line)
        XCTAssertTrue(control.waitForExistence(timeout: 5), "Settings must still show \(name)", file: file, line: line)
    }

    /// The system share sheet's activity list.
    @MainActor
    private func shareSheet(in app: XCUIApplication) -> XCUIElement {
        app.otherElements.matching(identifier: "ActivityListView").firstMatch
    }
}
