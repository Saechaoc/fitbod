import XCTest

/// Review items 33, 41 and 42: the workout, set and pinned note sheets.
final class NoteSheetsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Item 41: the demo bench press has warm-ups, and its first working
    /// set's note is still SET 1 NOTE.
    @MainActor
    func testFirstWorkingSetNoteIsSetOne() throws {
        let app = UITestNavigation.openSeededWorkout()
        openSetNote(in: app)
        let title = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH[c] 'SET ' AND label ENDSWITH[c] ' NOTE'"
        )).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label.uppercased(), "SET 1 NOTE",
                       "Warm-ups must not count in the set note's number")
    }

    @MainActor
    private func openSetNote(in app: XCUIApplication) {
        let note = app.buttons["Note for set 1"].firstMatch
        UITestNavigation.reveal(note, in: app)
        note.tap()
    }
}
