//
//  RestSheetAndRPEChipsUITests.swift
//  fitbodUITests
//
//  T36, review items 23 and 24. Tapping the rest dock opened the rest
//  sheet at half height, with SKIP cut off below it. At AX3 the RPE chips'
//  "10" touched its border, and the REST label in the dock's 40pt ring ran
//  past the ring (T80).
//
//  Every test logs set 1 of the demo workout's bench press, 180 s rest.
//  The dock's countdown row is one combined accessibility element, so the
//  REST label inside its ring is read from the screenshot. Every test that
//  starts a rest ends it, so no "Rest complete" banner shows in a later test.
//

import XCTest

final class RestSheetAndRPEChipsUITests: XCTestCase {
    // The tests and helpers are @MainActor because XCUIApplication and
    // XCUIElement are main-actor isolated.

    /// bruPaper in light mode: an unselected chip's fill.
    private static let paper = UITestNavigation.RGB(hex: 0xFAFAF7)
    /// bruInk in light mode: a selected chip's fill.
    private static let ink = UITestNavigation.RGB(hex: 0x0A0A0A)
    /// The dock's progress ring is 40pt square.
    private static let ringSize: CGFloat = 40

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Rest sheet

    /// Tapping the dock opens the rest sheet with SKIP on screen, no drag
    /// needed, the sheet ending just below its footer. It still drags up to
    /// full height; after DONE it opens at its content's height again, and a
    /// tap on SKIP right away ends the rest. At default text the dock's REST
    /// label sits inside its ring. One launch walks the sheet's whole flow,
    /// so this is a short journey rather than a single case.
    @MainActor
    func testRestSheetShowsSkipWithoutADragAndSkipEndsTheRest() throws {
        let app = openWorkout()
        logSetOne(in: app)
        let dock = restDock(in: app)
        UITestNavigation.waitUntilStill(dock)
        try assertRingLabelInsideRing(of: dock)
        UITestNavigation.saveScreenshot("T36", "rest-dock")

        let skip = expandRestSheet(from: dock, in: app)
        UITestNavigation.saveScreenshot("T36", "rest-sheet")
        XCTAssertTrue(skip.isHittable, "SKIP must take a tap without a drag; it is at \(skip.frame)")
        XCTAssertLessThanOrEqual(skip.frame.maxY, app.frame.maxY,
                                 "SKIP at \(skip.frame) must lie above the bottom of the \(app.frame.height)pt screen")
        try assertSheetFitsItsContent(in: app)

        let sheet = try openSheet(in: app)
        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: sheet.frame.midX, dy: sheet.frame.minY + 20))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -sheet.frame.minY)),
                    withVelocity: .default, thenHoldForDuration: 0.1)
        UITestNavigation.waitUntilStill(skip)
        let dragged = try openSheet(in: app)
        XCTAssertLessThan(dragged.frame.minY, fullHeightTop(in: app),
                          "The rest sheet must drag up to full height; it stops at \(dragged.frame)")
        UITestNavigation.saveScreenshot("T36", "rest-sheet-full")
        app.buttons["DONE"].tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 5), "DONE must close the rest sheet")

        let reopened = expandRestSheet(from: dock, in: app)
        try assertSheetFitsItsContent(in: app)
        XCTAssertTrue(reopened.isHittable, "SKIP must take a tap as soon as the sheet opens")
        reopened.tap()
        XCTAssertTrue(dock.waitForNonExistence(timeout: 5), "SKIP must end the rest")
        XCTAssertTrue(!reopened.exists || reopened.waitForNonExistence(timeout: 5), "SKIP must close the rest sheet")
    }

    // MARK: - AX3

    /// At AX3 the "10" chip keeps its digits off its border: columns of
    /// pixels 3pt inside its left and right borders are all its fill. Every
    /// chip keeps its 44pt target and lies whole on screen.
    @MainActor
    func testRPEChipDigitsClearTheirBordersAtAX3() throws {
        let app = openWorkout(textSize: .ax3)
        let ten = chip("10", in: app)
        reveal(ten, in: app)
        UITestNavigation.waitUntilStill(ten)
        UITestNavigation.saveScreenshot("T36", "rpe-chips", textSize: .ax3)

        let screenshot = XCUIScreen.main.screenshot()
        let frame = ten.frame
        let fill = ten.isSelected ? Self.ink : Self.paper
        for (side, x) in [("left", frame.minX + 3), ("right", frame.maxX - 3)] {
            let stray = try strayPixels(inColumnAt: x, from: frame.minY + 3, to: frame.maxY - 3, of: screenshot, fill: fill)
            XCTAssertTrue(stray.isEmpty,
                          "3pt inside its \(side) border the 10 chip at \(frame) must be all \(fill); found \(stray.prefix(5))")
        }
        for value in 6...10 {
            let shown = chip("\(value)", in: app)
            UITestNavigation.assertTapTarget(shown)
            XCTAssertGreaterThanOrEqual(shown.frame.minX, 0, "Chip \(value) at \(shown.frame) must not be cut off")
            XCTAssertLessThanOrEqual(shown.frame.maxX, app.frame.maxX, "Chip \(value) at \(shown.frame) must not be cut off")
        }
    }

    /// At AX3 the dock's ring shows no REST label, or one at most 40pt
    /// wide, because RESTING beside it says the same. The rest sheet still
    /// opens at full height.
    @MainActor
    func testRestDockRingLabelFitsAtAX3() throws {
        let app = openWorkout(textSize: .ax3)
        logSetOne(in: app)
        let dock = restDock(in: app)
        UITestNavigation.waitUntilStill(dock)
        UITestNavigation.saveScreenshot("T36", "rest-dock", textSize: .ax3)
        for label in try ringLabels(in: dock) {
            XCTAssertLessThanOrEqual(label.box.width, Self.ringSize,
                                     "At AX3 the dock may show no REST label or one at most 40pt wide; \"\(label.text)\" draws at \(label.box)")
        }

        let skip = expandRestSheet(from: dock, in: app)
        XCTAssertLessThan(try openSheet(in: app).frame.minY, fullHeightTop(in: app),
                          "At AX3 the rest sheet must open at full height")
        UITestNavigation.saveScreenshot("T36", "rest-sheet", textSize: .ax3)
        skip.tap()
        XCTAssertTrue(dock.waitForNonExistence(timeout: 5), "SKIP must end the rest")
    }

    // MARK: - Helpers

    /// How far below a content-measured sheet's footer its bottom edge may
    /// sit: the content's 24pt bottom padding plus the home indicator's
    /// 34pt inset. At full height the sheet runs on over 200pt.
    private static let contentHeightSlack: CGFloat = 70

    /// Opens today's demo workout at `textSize`, with set 1's reps in view.
    @MainActor
    private func openWorkout(textSize: UITestNavigation.TextSize = .default) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: textSize)
        let resume = app.buttons["resumeSlab.resume"]
        XCTAssertTrue(resume.exists || resume.waitForExistence(timeout: 10), "Today must offer the workout")
        UITestNavigation.reveal(resume, in: app)
        resume.tap()
        XCTAssertTrue(app.otherElements["workout.header"].waitForExistence(timeout: 10), "The workout never opened")
        reveal(app.textFields["set.reps.1.S1"], in: app)
        return app
    }

    /// Scrolls the logger until `element` loads, since at AX3 a set's row
    /// loads only near the screen, and then into view.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<10 where !element.exists {
            let (top, bottom) = UITestNavigation.loggerSpan(in: app)
            UITestNavigation.dragLogger(from: bottom - 20, to: top + 20, in: app)
        }
        XCTAssertTrue(element.exists, "\(element) never loaded", file: file, line: line)
        UITestNavigation.revealInLogger(element, in: app, file: file, line: line)
    }

    /// Types 6 reps into set 1 and checks it off, which starts its rest.
    @MainActor
    private func logSetOne(in app: XCUIApplication) {
        let reps = app.textFields["set.reps.1.S1"]
        reveal(reps, in: app)
        UITestNavigation.type("6", into: reps, pressingReturn: false)
        let complete = app.buttons["set.complete.1.S1"]
        reveal(complete, in: app)
        complete.tap()
        XCTAssertTrue(waitForLabel(complete, "Set 1 complete"), "Set 1 must be logged")
    }

    /// The dock's countdown row, once a rest runs.
    @MainActor
    private func restDock(in app: XCUIApplication) -> XCUIElement {
        let dock = app.descendants(matching: .any).matching(identifier: "rest.status").firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 10), "Logging a set must start the rest")
        return dock
    }

    /// The rest sheet's SKIP. The dock's SKIP stays under the sheet, with
    /// the same VoiceOver label and its own identifier; the sheet's reads
    /// in capitals.
    @MainActor
    private func expandedSkip(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "label ==[c] %@ AND identifier != %@", "Skip remaining rest", "rest.skip"
        )).firstMatch
    }

    /// Taps the dock and returns the rest sheet's SKIP once the sheet has
    /// stopped sliding up.
    @MainActor
    private func expandRestSheet(
        from dock: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        dock.tap()
        let skip = expandedSkip(in: app)
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "Tapping the dock must open the rest sheet", file: file, line: line)
        UITestNavigation.waitUntilStill(skip)
        return skip
    }

    /// The open rest sheet shows its controls and its footer, and ends just
    /// below the footer, so it opened at its content's height.
    @MainActor
    private func assertSheetFitsItsContent(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) throws {
        let sheet = try openSheet(in: app, file: file, line: line)
        let footer = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "PRESCRIBED")).firstMatch
        for part in [app.buttons["rest.expanded.minus15"], app.buttons["rest.expanded.plus15"], expandedSkip(in: app), footer] {
            UITestNavigation.assertInside(part, sheet, file: file, line: line)
        }
        XCTAssertLessThan(sheet.frame.maxY - footer.frame.maxY, Self.contentHeightSlack,
                          "The sheet at \(sheet.frame) must end just below its footer at \(footer.frame)", file: file, line: line)
    }

    /// The sheet on top, which must be there.
    @MainActor
    private func openSheet(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) throws -> XCUIElement {
        try XCTUnwrap(UITestNavigation.topSheet(in: app), "No sheet is on screen", file: file, line: line)
    }

    /// A sheet at full height starts this close to the top of the screen;
    /// one measured from the rest sheet's content starts far lower.
    @MainActor
    private func fullHeightTop(in app: XCUIApplication) -> CGFloat {
        app.frame.height * 0.15
    }

    /// Set 1's chip for `value`. Set 1's controls come first in the logger.
    @MainActor
    private func chip(_ value: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", "RPE \(value)")).firstMatch
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ label: String) -> Bool {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [match], timeout: 5) == .completed
    }

    /// The lines Vision reads in the dock's countdown row that hold the
    /// ring's REST label. RESTING and REST COMPLETE are the status beside
    /// the ring, not the label, so they do not count.
    @MainActor
    private func ringLabels(in dock: XCUIElement) throws -> [(text: String, box: CGRect)] {
        try UITestNavigation.textLines(in: dock.frame, of: XCUIScreen.main.screenshot()).filter { line in
            let letters = line.text.uppercased().filter(\.isLetter)
            return letters.replacingOccurrences(of: "RESTING", with: "")
                .replacingOccurrences(of: "RESTCOMPLETE", with: "")
                .contains("REST")
        }
    }

    /// The dock shows its REST label, drawn inside its 40pt ring at the
    /// leading end of the countdown row.
    @MainActor
    private func assertRingLabelInsideRing(of dock: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws {
        let ring = CGRect(x: dock.frame.minX, y: dock.frame.midY - Self.ringSize / 2,
                          width: Self.ringSize, height: Self.ringSize)
        let labels = try ringLabels(in: dock)
        XCTAssertEqual(labels.count, 1, "The dock's ring must show its REST label; read \(labels)", file: file, line: line)
        for label in labels {
            XCTAssertTrue(ring.insetBy(dx: -1, dy: -1).contains(label.box),
                          "The REST label at \(label.box) must lie inside the ring at \(ring)", file: file, line: line)
        }
    }

    /// The pixels in a one-pixel column at `x`, from `top` to `bottom`, in
    /// screen points, that are not within 8 of `fill` on every channel.
    @MainActor
    private func strayPixels(
        inColumnAt x: CGFloat, from top: CGFloat, to bottom: CGFloat,
        of screenshot: XCUIScreenshot, fill: UITestNavigation.RGB
    ) throws -> [String] {
        let scale = screenshot.image.scale
        let column = CGRect(x: x, y: top, width: 1 / scale, height: bottom - top)
        let cut = try XCTUnwrap(UITestNavigation.pixels(in: column, of: screenshot), "Cannot read the pixels of \(column)")
        let width = Int(cut.frame.width)
        return (0..<(cut.bytes.count / 4)).compactMap { pixel in
            let color = UITestNavigation.RGB(
                red: Int(cut.bytes[pixel * 4]), green: Int(cut.bytes[pixel * 4 + 1]), blue: Int(cut.bytes[pixel * 4 + 2])
            )
            guard color.distance(to: fill) > 8 else { return nil }
            let y = (cut.frame.minY + CGFloat(pixel / width)) / scale
            return "\(color) at y \(String(format: "%.1f", y))"
        }
    }
}
