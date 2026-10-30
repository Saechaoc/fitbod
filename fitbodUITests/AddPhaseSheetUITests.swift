import XCTest

/// Ticket T74, finding F62. New Block's Add Phase sheet showed a stock
/// navigation title, "Add Phase" in the system font, and only a swipe down
/// closed it without a pick. Its title now sits in a BRU header whose
/// CANCEL closes the sheet without adding a phase, like the preset sheet's.
final class AddPhaseSheetUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// No navigation bar reads "Add Phase". The title sits in the BRU
    /// header above the hint line, with CANCEL on its row as a 44pt target.
    @MainActor
    func testTitleSitsInBRUHeader() throws {
        let app = openBlankNewBlock()
        let prompt = openAddPhase(in: app)
        UITestNavigation.waitUntilStill(prompt)
        UITestNavigation.saveScreenshot("T74", "add-phase", appearance: appearance)

        XCTAssertFalse(app.navigationBars["Add Phase"].exists, "The sheet must not show a navigation bar titled Add Phase")
        let title = sheetTitle(in: app)
        XCTAssertLessThanOrEqual(title.frame.maxY, prompt.frame.minY, "The header's title must sit above the hint line")
        // A half-height sheet is inset from the screen's sides and scales
        // its content to fit, so a full-width row gives the scale.
        let scale = UITestNavigation.hittable(app.buttons, "Accumulation").frame.width / app.frame.width
        let cancel = sheetCancel(in: app).frame
        XCTAssertGreaterThanOrEqual(min(cancel.width, cancel.height) / scale, 44 - 0.5,
                                    "CANCEL must stay a 44pt target in the sheet, not \(cancel.size) at scale \(scale)")
    }

    /// CANCEL closes the sheet and leaves New Block's phases as they were.
    @MainActor
    func testCancelClosesWithoutAddingAPhase() throws {
        let app = openBlankNewBlock()
        let before = phaseCount(in: app)
        let prompt = openAddPhase(in: app)

        sheetCancel(in: app).tap()
        XCTAssertTrue(prompt.waitForNonExistence(timeout: 5), "CANCEL must close the sheet")
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").isHittable, "CANCEL must leave New Block open")
        XCTAssertEqual(phaseCount(in: app), before, "CANCEL must not add a phase")
    }

    /// Picking a phase type still adds that phase at the end and closes
    /// the sheet.
    @MainActor
    func testPickAddsThePhaseAndCloses() throws {
        let app = openBlankNewBlock()
        let before = phaseCount(in: app)
        let prompt = openAddPhase(in: app)

        UITestNavigation.hittable(app.buttons, "Peak").tap()
        XCTAssertTrue(prompt.waitForNonExistence(timeout: 5), "Picking Peak must close the sheet")
        XCTAssertEqual(phaseCount(in: app), before + 1, "Picking Peak must add a phase")
        XCTAssertTrue(app.staticTexts.labeled("Phase \(before + 1): Peak").waitForExistence(timeout: 5),
                      "Peak must be the new last phase")
    }

    // MARK: - Helpers

    /// Program → + NEW → + New block → Blank Block: three phases, no name.
    @MainActor
    private func openBlankNewBlock() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "New Block never opened")
        return app
    }

    /// Taps + ADD PHASE and returns the sheet's hint line.
    @MainActor
    private func openAddPhase(in app: XCUIApplication) -> XCUIElement {
        UITestNavigation.hittable(app.buttons, "+ ADD PHASE").tap()
        let prompt = app.staticTexts.labeled("Choose a phase type to add.")
        XCTAssertTrue(prompt.waitForExistence(timeout: 10), "+ ADD PHASE must open its sheet")
        return prompt
    }

    @MainActor
    private func sheetTitle(in app: XCUIApplication) -> XCUIElement {
        let title = app.staticTexts.labeled("Add Phase")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "The sheet must show its title")
        return title
    }

    /// The sheet's CANCEL: the one left of its title, on the title's row.
    /// New Block's own CANCEL stays in the tree under the sheet.
    @MainActor
    @discardableResult
    private func sheetCancel(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let row = sheetTitle(in: app).frame
        let cancels = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Cancel"))
        let cancel = cancels.allElementsBoundByIndex.first {
            $0.isHittable && abs($0.frame.midY - row.midY) < 12 && $0.frame.maxX <= row.minX
        }
        XCTAssertNotNil(cancel, "The sheet's header must show CANCEL left of its title", file: file, line: line)
        return cancel ?? cancels.firstMatch
    }

    /// New Block's phase count, from its "PHASES · 3" header.
    @MainActor
    private func phaseCount(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Int {
        let header = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "PHASES · ")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5), "New Block must show its phase count", file: file, line: line)
        let count = Int(header.label.replacingOccurrences(of: "PHASES · ", with: ""))
        XCTAssertNotNil(count, "Unreadable phase count: \(header.label)", file: file, line: line)
        return count ?? -1
    }

    /// The phone's appearance, which the run sets with `xcrun simctl ui`.
    @MainActor
    private var appearance: UITestNavigation.Appearance {
        XCUIDevice.shared.appearance == .dark ? .dark : .light
    }
}
