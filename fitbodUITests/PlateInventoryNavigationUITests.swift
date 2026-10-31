import XCTest

/// Ticket T19. Review items 43, 37 and 25. Settings > Plate Inventory hid
/// the system bar and showed no back button, and its SAVE INVENTORY did
/// nothing, because a plate count saves as it changes. Its header now
/// shows ‹ BACK, which returns to Settings, and its footer keeps Done ▸
/// alone.
final class PlateInventoryNavigationUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - ‹ BACK

    /// ‹ BACK, Plate Inventory and ••• share the header row, left to
    /// right, and ‹ BACK returns to Settings.
    @MainActor
    func testBackReturnsToSettings() throws {
        try assertBackReturnsToSettings(textSize: .default)
    }

    /// At AX3 the header stacks Plate Inventory over ‹ BACK and •••, and
    /// ‹ BACK still returns to Settings.
    @MainActor
    func testBackReturnsToSettingsAtAX3() throws {
        try assertBackReturnsToSettings(textSize: .ax3)
    }

    // MARK: - No save button

    /// A plate count saves as it changes, so the screen offers no save
    /// button. A changed count survives leaving Plate Inventory by ‹ BACK
    /// and opening it again, and a relaunch.
    @MainActor
    func testPlateCountSavesWithoutASaveButton() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let inventory = openPlateInventory(in: app)
        XCTAssertFalse(app.buttons.labeled("Save inventory").exists, "Plate Inventory must not offer SAVE INVENTORY")
        XCTAssertTrue(app.buttons.labeled("Done ▸").exists, "Plate Inventory must keep Done ▸")

        let plate45 = plateRow("45", in: app)
        XCTAssertTrue(plate45.waitForExistence(timeout: 10), "A fresh barbell inventory lists a 45 lb plate")
        XCTAssertEqual(plate45.value as? String, "4 per side")
        tapFirstTallyBox(of: plate45)
        XCTAssertTrue(waitForValue(plate45, "1 per side"), "A tally box must set the plate's count")

        UITestNavigation.hittable(app.buttons, "Back", exactLabel: true).tap()
        XCTAssertTrue(waitUntilHittable(inventory), "‹ BACK must return to Settings")
        openPlateInventory(in: app)
        XCTAssertTrue(waitForValue(plateRow("45", in: app), "1 per side"),
                      "The count must survive leaving Plate Inventory and opening it again")

        UITestNavigation.relaunch(app)
        UITestNavigation.openSettings(in: app)
        openPlateInventory(in: app)
        XCTAssertTrue(waitForValue(plateRow("45", in: app), "1 per side"), "The count must survive a relaunch")
    }

    // MARK: - Weights at AX3

    /// Plate Inventory shares the calculator's plate row. At AX3 its
    /// longest weights, 2.5 and 1.25, which end the list, stay whole on one
    /// line: the 1.25 lb plate read "1.2" over "5".
    @MainActor
    func testPlateWeightsStayWholeAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: .ax3)
        UITestNavigation.openSettings(in: app)
        openPlateInventory(in: app)
        let top = app.otherElements["plateInventory.tabStrip"].frame.maxY
        // The footer's 2pt rule sits on top of Done ▸.
        let bottom = app.buttons.labeled("Done ▸").frame.minY - 2
        let last = plateRow("1.25", in: app)
        for _ in 0..<8 where !(last.exists && last.frame.maxY <= bottom) {
            app.swipeUp(velocity: .slow)
        }
        UITestNavigation.waitUntilStill(last)
        UITestNavigation.saveScreenshot("T19", "plate-inventory-weights", textSize: .ax3)

        var problems: [String] = []
        for weight in ["2.5", "1.25"] {
            let row = plateRow(weight, in: app)
            guard row.exists, row.frame.minY >= top, row.frame.maxY <= bottom else {
                problems.append("The \(weight) lb plate never shows whole above the footer")
                continue
            }
            problems += try UITestNavigation.numberProblems(in: row)
        }
        XCTAssertEqual(problems, [], "No plate weight may break inside its number at AX3")
    }

    // MARK: - Helpers

    /// Opens Plate Inventory at `textSize`, saves its header, checks it,
    /// and goes back by ‹ BACK.
    @MainActor
    private func assertBackReturnsToSettings(
        textSize: UITestNavigation.TextSize, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize)
        UITestNavigation.openSettings(in: app)
        let inventory = openPlateInventory(in: app, file: file, line: line)
        let title = UITestNavigation.hittable(app.staticTexts, "Plate Inventory", exactLabel: true, file: file, line: line)
        let back = UITestNavigation.hittable(app.buttons, "Back", exactLabel: true, file: file, line: line)
        let more = UITestNavigation.hittable(app.buttons, "More", exactLabel: true, file: file, line: line)
        let strip = app.otherElements["plateInventory.tabStrip"]
        UITestNavigation.waitUntilStill(back, interval: 0.3)
        UITestNavigation.saveScreenshot("T19", "plate-inventory-header", textSize: textSize)

        let shown = UITestNavigation.latin(try UITestNavigation.readText(in: back.frame, of: XCUIScreen.main.screenshot()))
        XCTAssertTrue(shown.contains("BACK"), "The back control must read ‹ BACK, but reads \"\(shown)\"",
                      file: file, line: line)
        let window = app.windows.firstMatch
        for control in [back, title, more] {
            UITestNavigation.assertInside(control, window, file: file, line: line)
        }
        UITestNavigation.assertTapTarget(back, file: file, line: line)
        UITestNavigation.assertTapTarget(more, file: file, line: line)
        UITestNavigation.assertNoOverlap(back, more, file: file, line: line)
        XCTAssertLessThan(back.frame.midX, more.frame.midX, "‹ BACK must sit left of •••", file: file, line: line)
        XCTAssertLessThanOrEqual(max(back.frame.midY, title.frame.maxY, more.frame.midY), strip.frame.minY,
                                 "The header must sit above the tab strip", file: file, line: line)
        if textSize == .default {
            UITestNavigation.assertNoOverlap(back, title, file: file, line: line)
            UITestNavigation.assertNoOverlap(title, more, file: file, line: line)
            XCTAssertLessThan(back.frame.midX, title.frame.minX, "‹ BACK must sit left of the title", file: file, line: line)
            XCTAssertGreaterThan(more.frame.midX, title.frame.maxX, "••• must sit right of the title", file: file, line: line)
        } else {
            XCTAssertLessThanOrEqual(title.frame.maxY, min(back.frame.midY, more.frame.midY),
                                     "At AX3 the title must sit over ‹ BACK and •••", file: file, line: line)
        }

        back.tap()
        XCTAssertTrue(strip.waitForNonExistence(timeout: 10), "‹ BACK must close Plate Inventory", file: file, line: line)
        XCTAssertTrue(waitUntilHittable(inventory), "‹ BACK must return to Settings", file: file, line: line)
    }

    /// Settings' Plate Inventory row, then the pushed screen's tab strip,
    /// once it has stopped moving in. Returns the row.
    @MainActor
    @discardableResult
    private func openPlateInventory(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let inventory = app.buttons.labeled("Plate Inventory")
        _ = inventory.waitForExistence(timeout: 10)
        UITestNavigation.reveal(inventory, in: app)
        inventory.tap()
        let strip = app.otherElements["plateInventory.tabStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10), "Plate Inventory must open", file: file, line: line)
        UITestNavigation.waitUntilStill(strip, interval: 0.3)
        return inventory
    }

    /// A PlateTallyRow is one adjustable element, such as "45 lb plate"
    /// with the value "4 per side".
    @MainActor
    private func plateRow(_ weight: String, in app: XCUIApplication) -> XCUIElement {
        app.otherElements["\(weight) lb plate"]
    }

    /// The four tally boxes start 116pt in (16pt padding, the 90pt weight
    /// column, 10pt spacing) and end 106pt before the trailing edge, 3pt
    /// apart. Tapping the first box of a full row sets the count to one.
    @MainActor
    private func tapFirstTallyBox(of row: XCUIElement) {
        UITestNavigation.waitUntilStill(row, interval: 0.3)
        let firstBox = 116 + (row.frame.width - 231) / 8
        row.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: firstBox, dy: 0)).tap()
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval = 10) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [matches], timeout: timeout) == .completed
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }
}

extension UITestNavigation {
    /// `text` in capitals, with each Cyrillic capital that Vision reads for
    /// its Latin twin, such as "К" in "BACК", read as that Latin capital.
    static func latin(_ text: String) -> String {
        let twins: [Character: Character] = [
            "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C", "Т": "T", "Х": "X",
        ]
        return String(text.uppercased().map { twins[$0] ?? $0 })
    }

    /// A problem for each number in `element`'s label that the screen does
    /// not show whole on one line: split, such as "1.2" over "5", or cut
    /// short, such as "1…". XCUI reads the whole label however the text
    /// wraps or truncates, so the lines come off a screenshot.
    static func numberProblems(in element: XCUIElement) throws -> [String] {
        let screenshot = XCUIScreen.main.screenshot()
        let lines = try textLines(in: element.frame.insetBy(dx: -4, dy: -4), of: screenshot).map(\.text)
        // A shown number may run on from a digit Vision reads into a
        // neighbor, such as a plate's bar read as "1" in "12.5".
        let shown = lines.flatMap { numbers(in: readable($0)) }
        // A one-digit number cannot break across lines.
        let broken = numbers(in: element.label).filter { number in
            number.count > 1 && !shown.contains { $0.contains(number) }
        }
        return broken.isEmpty ? [] : ["\"\(element.label)\" does not show \(broken) whole on one line: the screen reads \(lines)"]
    }

    /// The numbers in `text`, such as ["45", "2.5"].
    private static func numbers(in text: String) -> [String] {
        text.matches(of: /\d+(?:\.\d+)?/).map { String($0.output) }
    }

    /// A line Vision read, without the spaces it reads into tracked text,
    /// with "O" read as a zero and a comma as a point.
    private static func readable(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: ",", with: ".")
    }
}
