//
//  ActionPopoverFitUITests.swift
//  fitbodUITests
//
//  Ticket T83, finding F85, on Program's + NEW popover with an empty store:
//
//    - BRUActionPopover was a fixed 200pt wide with fixed 40pt rows, so at
//      AX3 on the 390pt phone its items read "+ New…" and "+ New r…".
//    - Its 40pt rows were under the 44pt tap minimum at every text size.
//
//  XCUI reports each item as a button the size of its row, with no text
//  inside it, and reads the whole title even when the screen cuts it
//  short. So each title is read off a screenshot cropped to its row, and
//  the popover's edges are found by the pixels of its white surface.
//

import XCTest

final class ActionPopoverFitUITests: XCTestCase {
    /// The popover's items, top to bottom.
    private static let titles = ["+ New block", "+ New routine"]
    /// bruTabSurface in light mode, the popover's surface.
    private static let surface = UITestNavigation.RGB(hex: 0xFFFFFF)
    /// bruInk in light mode, the titles' color.
    private static let ink = UITestNavigation.RGB(hex: 0x0A0A0A)

    override func setUpWithError() throws {
        // Every check reports, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Repro

    /// At AX3 each item shows its whole title inside its row, inside the
    /// popover, which stays on screen. A tap just above + New routine's
    /// bottom edge opens the new routine.
    @MainActor
    func testItemsShowTheirWholeTitlesAtAX3() throws {
        let app = openNewPopover(textSize: .ax3)
        UITestNavigation.saveScreenshot("T83", "new-popover", textSize: .ax3)
        let rows = try assertItemsFit(in: app)

        rows[1].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).withOffset(CGVector(dx: 0, dy: -3)).tap()
        let name = app.descendants(matching: .any).matching(NSPredicate(
            format: "label ==[c] %@ AND value BEGINSWITH %@", "Routine name", "Untitled routine"
        )).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10),
                      "A tap just above + New routine's bottom edge must open the new routine")
    }

    /// At default text each item is a 44pt tap target, and the popover
    /// keeps its 200pt width and its place under + NEW. A tap just inside
    /// + New block's trailing edge, past its title, opens CREATE BLOCK.
    @MainActor
    func testItemsAre44PointTapTargetsAtDefaultText() throws {
        let app = openNewPopover(textSize: .default)
        UITestNavigation.saveScreenshot("T83", "new-popover")
        let rows = try assertItemsFit(in: app)
        for row in rows {
            XCTAssertEqual(row.frame.height, 44, accuracy: 0.5, "\(row.label) grows to 44pt and no more at default text")
            XCTAssertEqual(row.frame.width, 200, accuracy: 0.5, "\(row.label) keeps the popover's 200pt width")
            XCTAssertEqual(row.frame.maxX, app.frame.maxX - 14, accuracy: 0.5, "\(row.label) keeps its place under + NEW")
        }

        rows[0].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -3, dy: 0)).tap()
        XCTAssertTrue(app.staticTexts["CREATE BLOCK"].waitForExistence(timeout: 5),
                      "A tap just inside + New block's trailing edge must open CREATE BLOCK")
    }

    // MARK: - Popover

    /// Program on a fresh store, with + NEW's popover open.
    @MainActor
    private func openNewPopover(textSize: UITestNavigation.TextSize) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize)
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.staticTexts["NO PROGRAM"].waitForExistence(timeout: 10), "Program must show its empty state")
        app.buttons["+ NEW"].tap()
        for title in Self.titles {
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5), "+ NEW's popover has no \(title)")
        }
        return app
    }

    /// Checks that each item is a 44pt tap target lying inside the popover,
    /// which stays on screen, and that its title shows whole inside its row.
    /// Returns the items' rows, top to bottom.
    @MainActor
    private func assertItemsFit(in app: XCUIApplication) throws -> [XCUIElement] {
        let rows = Self.titles.map { app.buttons[$0] }
        let screenshot = XCUIScreen.main.screenshot()
        let area = rows.map(\.frame).reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -40, dy: -40)
        let popover = try XCTUnwrap(box(of: Self.surface, within: 8, in: area, of: screenshot),
                                    "The popover's white surface is not on screen")
        XCTAssertTrue(popover.minX > app.frame.minX + 0.5 && popover.maxX < app.frame.maxX - 0.5,
                      "The popover at \(popover) must stay on the \(app.frame.width)pt screen, clear of its edges")
        UITestNavigation.assertNoOverlap(rows[0], rows[1])

        for (title, row) in zip(Self.titles, rows) {
            UITestNavigation.assertTapTarget(row, minimum: 44)
            UITestNavigation.assertInside(row, app)
            XCTAssertTrue(popover.insetBy(dx: -1, dy: -1).contains(row.frame),
                          "\(title)'s row at \(row.frame) must lie inside the popover at \(popover)")
            // Letters cut off at the row's edge would reach it.
            let letters = box(of: Self.ink, within: 96, in: row.frame, of: screenshot)
            XCTAssertNotNil(letters, "\(title)'s row draws no letters")
            if let letters {
                XCTAssertTrue(row.frame.insetBy(dx: 1, dy: 1).contains(letters),
                              "\(title)'s letters at \(letters) must lie inside its row at \(row.frame)")
            }
            let shown = try UITestNavigation.readText(in: row.frame.insetBy(dx: 1, dy: 1), of: screenshot)
            XCTAssertTrue(lettersAndDigits(shown).contains(lettersAndDigits(title)),
                          "The popover must show \"\(title)\" whole inside its row, but it reads \"\(shown)\"")
        }
        return rows
    }

    // MARK: - Screenshot readers

    /// Uppercased letters and digits only, so line breaks and spacing do
    /// not matter.
    private func lettersAndDigits(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    /// The box, in screen points, around the pixels inside `rect` within
    /// `tolerance` of `color`, or nil when there are none.
    @MainActor
    private func box(
        of color: UITestNavigation.RGB, within tolerance: Int, in rect: CGRect, of screenshot: XCUIScreenshot
    ) -> CGRect? {
        guard let crop = UITestNavigation.pixels(in: rect, of: screenshot) else { return nil }
        let width = Int(crop.frame.width)
        var (left, right, top, bottom) = (Int.max, Int.min, Int.max, Int.min)
        for row in 0..<Int(crop.frame.height) {
            for column in 0..<width {
                let byte = (row * width + column) * 4
                let pixel = UITestNavigation.RGB(
                    red: Int(crop.bytes[byte]), green: Int(crop.bytes[byte + 1]), blue: Int(crop.bytes[byte + 2])
                )
                guard pixel.distance(to: color) <= tolerance else { continue }
                (left, right) = (min(left, column), max(right, column))
                (top, bottom) = (min(top, row), max(bottom, row))
            }
        }
        guard left <= right else { return nil }
        let scale = screenshot.image.scale
        return CGRect(
            x: (crop.frame.minX + CGFloat(left)) / scale,
            y: (crop.frame.minY + CGFloat(top)) / scale,
            width: CGFloat(right - left + 1) / scale,
            height: CGFloat(bottom - top + 1) / scale
        )
    }
}
