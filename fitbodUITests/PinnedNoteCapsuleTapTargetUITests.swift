import XCTest

/// Ticket T55, finding F18. The pinned note capsule in the workout logger's
/// exercise header takes a tap anywhere in a 44pt band around its drawn box,
/// not only on the box, and the tap still opens the Pinned Note sheet.
final class PinnedNoteCapsuleTapTargetUITests: XCTestCase {

    private let benchPress = "Barbell Bench Press - Medium Grip"
    private let note = "Pause on the chest"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// The capsule is a 44pt tall tap target, and the header row grows no
    /// more than that band needs.
    @MainActor
    func testCapsuleIsA44PointTapTarget() throws {
        let app = UITestNavigation.openSeededWorkout()
        let capsule = pinNote(in: app)
        UITestNavigation.saveScreenshot("T55", "pinned-note-row")
        UITestNavigation.assertTapTarget(capsule, minimum: 44)
        UITestNavigation.assertHeight(capsule, atMost: 44)
    }

    /// A tap on the drawn box opens the Pinned Note sheet, and so does a tap
    /// in the band above or below it. SwiftUI already hands a button taps a
    /// few points outside its frame, so this passes without the band too; it
    /// guards that the band keeps taking them.
    @MainActor
    func testTapInBandOutsideDrawnBoxOpensPinnedNote() throws {
        let app = UITestNavigation.openSeededWorkout()
        let capsule = pinNote(in: app)
        assertTapOpensPinnedNote(capsule, offset: 0, in: app)
        // The one-line drawn box is under 35pt tall with its stroke and sits
        // in the middle of the band, so 20pt from its center is outside the
        // box and inside the 44pt band.
        assertTapOpensPinnedNote(capsule, offset: -20, in: app, screenshot: "pinned-note-sheet-from-band")
        assertTapOpensPinnedNote(capsule, offset: 20, in: app)
    }

    // MARK: - Helpers

    /// Gives the first exercise a pinned note through its long-press menu's
    /// Edit Pinned Note, the way a user pins a first note, and returns the
    /// capsule that shows it.
    @MainActor
    private func pinNote(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts[benchPress].firstMatch.press(forDuration: 1.2)
        let edit = app.buttons["Edit Pinned Note"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()

        let header = sheetHeader(in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Edit Pinned Note must open the Pinned Note sheet")
        let editor = app.textViews.firstMatch
        editor.tap()
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: editor)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed, "The note never took keyboard focus")
        editor.typeText(note)
        XCTAssertEqual(editor.value as? String, note, "The note must read what was typed")
        app.buttons.labeled("Save").tap()
        XCTAssertTrue(waitForDisappearance(header), "SAVE must close the Pinned Note sheet")

        let capsule = app.buttons["Pinned note: \(note)"]
        XCTAssertTrue(capsule.waitForExistence(timeout: 5), "The saved note must show as a capsule in the header")
        UITestNavigation.reveal(capsule, in: app)
        return capsule
    }

    /// Taps `offset` points below the capsule's center, or above it when
    /// negative, and checks the tap opens the Pinned Note sheet. CANCEL then
    /// closes it.
    @MainActor
    private func assertTapOpensPinnedNote(
        _ capsule: XCUIElement,
        offset: CGFloat,
        in app: XCUIApplication,
        screenshot: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = capsule.frame
        capsule.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: offset)).tap()
        let header = sheetHeader(in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "A tap \(offset)pt from the center of the capsule at \(frame) must open the Pinned Note sheet",
                      file: file, line: line)
        if let screenshot {
            UITestNavigation.saveScreenshot("T55", screenshot)
        }
        app.buttons.labeled("Cancel").tap()
        XCTAssertTrue(waitForDisappearance(header), "CANCEL must close the Pinned Note sheet", file: file, line: line)
    }

    @MainActor
    private func sheetHeader(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("Pinned note")
    }

    @MainActor
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
