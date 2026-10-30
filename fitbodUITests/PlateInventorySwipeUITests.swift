import XCTest

/// Tickets T77 (findings F31 and F67) and T60. Settings > Plate Inventory:
/// swiping a plate row from the trailing edge shows Delete, and Delete takes
/// that plate out of the saved inventory. As in other lists, only one row
/// shows its Delete at a time, and a tap outside the rows or a scroll closes
/// it. The rows sat in a LazyVStack with no swipe actions container, so
/// iOS 27 left every swiped row open, and iOS 26 shows swipe actions only
/// in a List.
final class PlateInventorySwipeUITests: XCTestCase {

    // Light-mode BRU paper.
    private static let paper = UITestNavigation.RGB(hex: 0xFAFAF7)

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - One Delete at a time

    /// With the 35 lb row's Delete open, swiping the 25 lb row closes it and
    /// opens the 25 lb row's Delete instead.
    @MainActor
    func testSwipingASecondRowClosesTheFirstDelete() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        openPlateInventory(in: app)
        openDelete(on: plateRow("35", in: app), in: app)

        let second = plateRow("25", in: app)
        second.swipeLeft()
        let shown = settledDeletes(in: app)
        UITestNavigation.saveScreenshot("T77", "plate-delete-open")
        XCTAssertEqual(shown.count, 1, "Opening the 25 lb row's Delete must close the 35 lb row's, but \(shown.count) Deletes show")
        let delete = try XCTUnwrap(shown.first)
        XCTAssertTrue((second.frame.minY...second.frame.maxY).contains(delete.frame.midY),
                      "The Delete that shows must be the 25 lb row's: Delete \(delete.frame), row \(second.frame)")
    }

    /// A tap on the PLATES AVAILABLE head, outside the rows, closes an open
    /// Delete and keeps the plate.
    @MainActor
    func testTappingThePlatesHeadClosesTheDelete() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        openPlateInventory(in: app)
        let plate = plateRow("35", in: app)
        openDelete(on: plate, in: app)

        let head = app.staticTexts.labeled("Plates available")
        XCTAssertTrue(head.isHittable, "Plate Inventory must show the PLATES AVAILABLE head")
        head.tap()
        let shown = settledDeletes(in: app)
        UITestNavigation.saveScreenshot("T77", "plate-delete-closed-by-tap")
        XCTAssertEqual(shown.count, 0, "A tap on the PLATES AVAILABLE head must close the open Delete, but \(shown.count) still show")
        XCTAssertTrue(plate.exists, "Closing Delete must keep the 35 lb plate")
    }

    /// Scrolling the plates closes an open Delete.
    @MainActor
    func testScrollingClosesTheDelete() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        openPlateInventory(in: app)
        openDelete(on: plateRow("35", in: app), in: app)

        // Drag up from the 10 lb row's weight, clear of its tally boxes.
        let start = plateRow("10", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -150)))
        let shown = settledDeletes(in: app)
        UITestNavigation.saveScreenshot("T77", "plate-delete-closed-by-scroll")
        XCTAssertEqual(shown.count, 0, "Scrolling must close the open Delete, but \(shown.count) still show")
    }

    // MARK: - Delete (T60)

    /// A fresh store's barbell plates include 35 lb. Swiping its row left
    /// shows Delete, and Delete removes the plate. It stays gone when the
    /// screen opens again and after a relaunch.
    @MainActor
    func testSwipeDeletesAPlate() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        openPlateInventory(in: app)
        let plate = plateRow("35", in: app)
        XCTAssertTrue(plate.waitForExistence(timeout: 10), "A fresh barbell inventory lists a 35 lb plate")
        UITestNavigation.waitUntilStill(plate, interval: 0.3)
        UITestNavigation.saveScreenshot("T77", "plate-inventory")
        // The row spans the screen and keeps its own padding: no list insets.
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(plate.frame.minX, window.minX, accuracy: 0.5, "The plate row must start at the screen edge")
        XCTAssertEqual(plate.frame.width, window.width, accuracy: 0.5, "The plate row must span the screen")
        // Its padding shows the paper, not a list row's white.
        UITestNavigation.assertColor(at: CGPoint(x: plate.frame.minX + 8, y: plate.frame.midY),
                                     in: XCUIScreen.main.screenshot(), is: Self.paper, tolerance: 3)

        plate.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Swiping a plate row left must show Delete")
        UITestNavigation.waitUntilStill(delete, interval: 0.3)
        UITestNavigation.saveScreenshot("T77", "plate-delete")
        delete.tap()
        XCTAssertTrue(plate.waitForNonExistence(timeout: 5), "Delete must remove the 35 lb plate")
        XCTAssertTrue(plateRow("45", in: app).exists, "Delete must keep the other plates")

        // Leave the screen and open it again.
        app.buttons.labeled("Done ▸").tap()
        XCTAssertTrue(app.otherElements["plateInventory.tabStrip"].waitForNonExistence(timeout: 5),
                      "Done must leave Plate Inventory")
        openPlateInventory(in: app)
        XCTAssertTrue(plateRow("45", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(plateRow("35", in: app).exists, "The deleted plate must stay gone when Plate Inventory opens again")

        // The saved inventory lost the plate too.
        UITestNavigation.relaunch(app)
        UITestNavigation.openSettings(in: app)
        openPlateInventory(in: app)
        XCTAssertTrue(plateRow("45", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(plateRow("35", in: app).exists, "The deleted plate must stay gone after a relaunch")
    }

    /// The screen's other plate controls still work: a tally box sets a
    /// plate's count, + ADD PLATE adds a plate, and RESET TO DEFAULTS brings
    /// back the default plates.
    @MainActor
    func testOtherPlateControlsStillWork() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        openPlateInventory(in: app)

        let plate45 = plateRow("45", in: app)
        XCTAssertTrue(plate45.waitForExistence(timeout: 10), "A fresh barbell inventory lists a 45 lb plate")
        UITestNavigation.waitUntilStill(plate45, interval: 0.3)
        XCTAssertEqual(plate45.value as? String, "4 per side")
        // The four tally boxes start 116pt in (16pt padding, the 90pt weight
        // column, 10pt spacing) and end 106pt before the trailing edge, 3pt
        // apart. Tapping the first box of a full row sets the count to one.
        let firstBox = 116 + (plate45.frame.width - 231) / 8
        plate45.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: firstBox, dy: 0)).tap()
        XCTAssertTrue(waitForValue(plate45, "1 per side"), "A tally box must set the plate's count")

        let add = app.buttons.labeled("+ ADD PLATE")
        revealAboveFooter(add, in: app)
        add.tap()
        let weight = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "e.g. 25")).firstMatch
        UITestNavigation.type("15", into: weight, replacing: false, pressingReturn: false)
        app.buttons.labeled("Add").tap()
        XCTAssertTrue(plateRow("15", in: app).waitForExistence(timeout: 10), "+ ADD PLATE must add a 15 lb plate")

        let reset = app.buttons.labeled("RESET TO DEFAULTS")
        revealAboveFooter(reset, in: app)
        reset.tap()
        let alert = app.alerts["Reset plate inventory?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "RESET TO DEFAULTS must ask first")
        alert.buttons["Reset"].tap()
        XCTAssertTrue(plateRow("15", in: app).waitForNonExistence(timeout: 5), "Reset must drop the added plate")
        XCTAssertTrue(waitForValue(plate45, "4 per side"), "Reset must restore the default count")
    }

    // MARK: - Helpers

    /// Settings' Plate Inventory row, then the pushed screen's tab strip.
    @MainActor
    private func openPlateInventory(in app: XCUIApplication) {
        let inventory = app.buttons.labeled("Plate Inventory")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: inventory)
        _ = XCTWaiter().wait(for: [ready], timeout: 10)
        UITestNavigation.reveal(inventory, in: app)
        inventory.tap()
        XCTAssertTrue(app.otherElements["plateInventory.tabStrip"].waitForExistence(timeout: 10), "Plate Inventory must open")
    }

    /// Scrolls until `element` sits wholly above the footer bar. XCUI calls
    /// a row that the footer half hides hittable, but its tap at the row's
    /// middle lands on the footer.
    @MainActor
    private func revealAboveFooter(_ element: XCUIElement, in app: XCUIApplication,
                                   file: StaticString = #filePath, line: UInt = #line) {
        // The footer's 2pt rule sits on top of Done ▸.
        let footerTop = app.buttons.labeled("Done ▸").frame.minY - 2
        for _ in 0..<6 {
            if element.exists && element.isHittable && element.frame.maxY <= footerTop { return }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(element.exists && element.isHittable && element.frame.maxY <= footerTop,
                      "\(element) must sit above the footer bar", file: file, line: line)
    }

    /// A PlateTallyRow is one adjustable element, such as "35 lb plate"
    /// with the value "2 per side".
    @MainActor
    private func plateRow(_ weight: String, in app: XCUIApplication) -> XCUIElement {
        app.otherElements["\(weight) lb plate"]
    }

    /// Swipes `row` left once the push has settled, and checks that its
    /// Delete is the one that shows.
    @MainActor
    private func openDelete(on row: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Missing \(row)", file: file, line: line)
        UITestNavigation.waitUntilStill(row, interval: 0.3)
        row.swipeLeft()
        XCTAssertEqual(settledDeletes(in: app).count, 1, "Swiping a plate row left must show its Delete", file: file, line: line)
    }

    /// The Delete actions on screen, once their number has held for a
    /// second: an action slides in or out after the gesture ends.
    @MainActor
    private func settledDeletes(in app: XCUIApplication, timeout: TimeInterval = 6) -> [XCUIElement] {
        let deletes = app.buttons.matching(NSPredicate(format: "label == %@", "Delete"))
        var shown = deletes.allElementsBoundByIndex.filter(\.isHittable)
        var heldSince = Date.now
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline, Date.now.timeIntervalSince(heldSince) < 1 {
            Thread.sleep(forTimeInterval: 0.25)
            let now = deletes.allElementsBoundByIndex.filter(\.isHittable)
            if now.count != shown.count { heldSince = .now }
            shown = now
        }
        return shown
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval = 5) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [matches], timeout: timeout) == .completed
    }
}
