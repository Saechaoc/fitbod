import XCTest

/// Ticket T33, review item 42. An exercise's menu in the workout logger
/// opens Edit Pinned Note. The sheet was a stock Form under a system
/// navigation bar with system Cancel and Save. It now looks and works like
/// the workout notes sheet: a BRU header with CANCEL, PINNED NOTE and SAVE
/// over a bordered editor on paper, with the muted hint "Note for this
/// exercise" under it.
final class PinnedNoteSheetBRUUITests: XCTestCase {

    private static let benchPress = "Barbell Bench Press - Medium Grip"
    private static let hint = "Note for this exercise"
    private static let note = "Pause on the chest"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Repro

    /// The sheet shows no system navigation bar, its BRU header has CANCEL
    /// and SAVE, and the hint under the editor says what the note is for.
    /// The editor has an ink border and draws on the sheet's paper, not on
    /// the system's text background.
    @MainActor
    func testPinnedNoteSheetIsBRU() throws {
        let app = openWorkout(textSize: .default)
        openPinnedNote(in: app)
        UITestNavigation.saveScreenshot("T33", "repro", appearance: appearance)

        XCTAssertFalse(app.navigationBars.firstMatch.exists, "The Pinned Note sheet must not show a system navigation bar")
        XCTAssertTrue(app.buttons.labeled("Cancel").exists, "The BRU header must show CANCEL")
        XCTAssertTrue(app.buttons.labeled("Save").exists, "The BRU header must show SAVE")

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.exists, "The sheet must edit the note in a text editor")
        let hint = app.staticTexts[Self.hint]
        XCTAssertTrue(hint.exists, "The hint under the editor must read \"\(Self.hint)\", but the sheet shows \(sheetTexts(in: app))")
        XCTAssertGreaterThanOrEqual(hint.frame.minY, editor.frame.maxY, "The hint must sit under the editor")

        let screenshot = XCUIScreen.main.screenshot()
        assertPaper(inside: editor, in: screenshot)
        assertBorder(leftOf: editor, in: screenshot)
    }

    // MARK: - Save and the capsule

    /// A note typed and saved shows in the exercise's pinned note capsule.
    /// Emptied and saved, it is no note again, so the capsule hides.
    @MainActor
    func testSavedNoteShowsInCapsule() throws {
        let app = openWorkout(textSize: .default)
        openPinnedNote(in: app)
        let editor = app.textViews.firstMatch
        UITestNavigation.type(Self.note, into: editor, replacing: false, pressingReturn: false)
        app.buttons.labeled("Save").tap()
        XCTAssertTrue(header(in: app).waitForNonExistence(timeout: 5), "SAVE must close the Pinned Note sheet")

        let capsule = app.buttons["Pinned note: \(Self.note)"]
        XCTAssertTrue(capsule.waitForExistence(timeout: 5), "The saved note must show in the exercise's pinned note capsule")
        UITestNavigation.reveal(capsule, in: app)
        UITestNavigation.waitUntilStill(capsule)
        UITestNavigation.saveScreenshot("T33", "capsule", appearance: appearance)
        let shown = try UITestNavigation.readText(in: capsule.frame, of: XCUIScreen.main.screenshot())
        XCTAssertTrue(lettersAndDigits(shown).contains(lettersAndDigits(Self.note)),
                      "The capsule must draw the saved note, but it reads \"\(shown)\"")

        capsule.tap()
        XCTAssertTrue(header(in: app).waitForExistence(timeout: 5), "The capsule must open the Pinned Note sheet")
        XCTAssertEqual(editor.value as? String, Self.note, "The sheet must open on the saved note")
        UITestNavigation.type("", into: editor, pressingReturn: false)
        app.buttons.labeled("Save").tap()
        XCTAssertTrue(header(in: app).waitForNonExistence(timeout: 5), "SAVE must close the Pinned Note sheet")
        XCTAssertTrue(capsule.waitForNonExistence(timeout: 5), "An emptied note saves as no note, so the capsule must hide")
    }

    // MARK: - Fit

    /// The sheet fits the phone at default text and AX3, as it opens and
    /// with a note typed. Screenshots carry the phone's appearance, so a
    /// dark run covers dark mode.
    @MainActor
    func testSheetFitsAtDefaultTextAndAX3() throws {
        for textSize in [UITestNavigation.TextSize.default, .ax3] {
            let app = openWorkout(textSize: textSize)
            openPinnedNote(in: app)
            let title = header(in: app)
            UITestNavigation.waitUntilStill(title)
            UITestNavigation.saveScreenshot("T33", "pinned-note", textSize: textSize, appearance: appearance)

            let screen = app.windows.firstMatch
            let cancel = app.buttons.labeled("Cancel")
            let save = app.buttons.labeled("Save")
            let editor = app.textViews.firstMatch
            let hint = app.staticTexts[Self.hint]
            XCTAssertTrue(hint.exists, "The hint under the editor must read \"\(Self.hint)\"")
            for element in [title, cancel, save, editor, hint] {
                UITestNavigation.assertInside(element, screen)
            }
            UITestNavigation.assertTapTarget(cancel)
            UITestNavigation.assertTapTarget(save)
            UITestNavigation.assertNoOverlap(cancel, save)
            XCTAssertLessThan(cancel.frame.midX, save.frame.midX, "CANCEL must sit left of SAVE")
            if textSize == .default {
                UITestNavigation.assertNoOverlap(cancel, title)
                UITestNavigation.assertNoOverlap(save, title)
            } else {
                // At AX3 the title sits over CANCEL and SAVE, whose 44pt hit
                // areas reach up beside it.
                XCTAssertLessThanOrEqual(title.frame.maxY, min(cancel.frame.midY, save.frame.midY),
                                         "At AX3 the title must sit over CANCEL and SAVE")
            }
            XCTAssertLessThanOrEqual(max(cancel.frame.midY, title.frame.maxY, save.frame.midY), editor.frame.minY,
                                     "The editor must sit under the header")
            XCTAssertGreaterThanOrEqual(hint.frame.minY, editor.frame.maxY, "The hint must sit under the editor")
            assertPaper(inside: editor, in: XCUIScreen.main.screenshot())

            UITestNavigation.type(Self.note, into: editor, replacing: false, pressingReturn: false)
            UITestNavigation.saveScreenshot("T33", "pinned-note-typed", textSize: textSize, appearance: appearance)
            app.terminate()
        }
    }

    // MARK: - Navigation

    /// Launches the demo seed at `textSize` and opens today's Push A.
    @MainActor
    private func openWorkout(textSize: UITestNavigation.TextSize) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: textSize)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "Today must offer to resume the seeded workout")
        UITestNavigation.reveal(resume, in: app)
        resume.tap()
        XCTAssertTrue(app.otherElements["workout.header"].waitForExistence(timeout: 10), "The workout never opened")
        return app
    }

    /// The bench press's long-press menu, then Edit Pinned Note, the way a
    /// user pins a first note.
    @MainActor
    private func openPinnedNote(in app: XCUIApplication) {
        let name = app.staticTexts[Self.benchPress].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Missing the exercise \(Self.benchPress)")
        UITestNavigation.reveal(name, in: app)
        name.press(forDuration: 1.2)
        let edit = app.buttons["Edit Pinned Note"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "The exercise's menu must offer Edit Pinned Note")
        edit.tap()
        XCTAssertTrue(header(in: app).waitForExistence(timeout: 5), "Edit Pinned Note must open the Pinned Note sheet")
    }

    /// The sheet's title, PINNED NOTE.
    @MainActor
    private func header(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("Pinned note")
    }

    // MARK: - Checks

    /// The phone's appearance, which a run sets with `xcrun simctl ui`.
    @MainActor
    private var appearance: UITestNavigation.Appearance {
        XCUIDevice.shared.appearance == .dark ? .dark : .light
    }

    /// The editor's empty bottom draws on bruPaper. The system's text
    /// background is white or black, within 10 of paper on each channel,
    /// so the tolerance is tighter than the default.
    @MainActor
    private func assertPaper(inside editor: XCUIElement, in screenshot: XCUIScreenshot,
                             file: StaticString = #filePath, line: UInt = #line) {
        let paper = appearance == .dark ? UITestNavigation.RGB(hex: 0x0A0A0A) : UITestNavigation.RGB(hex: 0xFAFAF7)
        let point = CGPoint(x: editor.frame.midX, y: editor.frame.maxY - 12)
        if let problem = UITestNavigation.colorProblem(at: point, in: screenshot, is: paper, tolerance: 3) {
            XCTFail("The editor must draw on bruPaper in \(appearance) mode. \(problem)", file: file, line: line)
        }
    }

    /// The editor's 2pt ink border crosses the row through its middle,
    /// within 16pt left of the editor's text area.
    @MainActor
    private func assertBorder(leftOf editor: XCUIElement, in screenshot: XCUIScreenshot,
                              file: StaticString = #filePath, line: UInt = #line) {
        let ink = appearance == .dark ? UITestNavigation.RGB(hex: 0xFAFAF7) : UITestNavigation.RGB(hex: 0x0A0A0A)
        let row = editor.frame.midY
        let hasBorder = stride(from: editor.frame.minX, through: editor.frame.minX - 16, by: -0.5).contains { x in
            UITestNavigation.color(at: CGPoint(x: x, y: row), in: screenshot).map { $0.distance(to: ink) <= 24 } ?? false
        }
        XCTAssertTrue(hasBorder, "The editor must have an ink border left of \(editor.frame)", file: file, line: line)
    }

    /// The labels of the texts on the sheet, for a failure message.
    @MainActor
    private func sheetTexts(in app: XCUIApplication) -> [String] {
        let texts = UITestNavigation.topSheet(in: app)?.staticTexts ?? app.staticTexts
        return texts.allElementsBoundByIndex.map(\.label)
    }

    private func lettersAndDigits(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber })
    }
}
