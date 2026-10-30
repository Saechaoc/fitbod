//
//  ProgramHeaderAndSheetsAX3UITests.swift
//  fitbodUITests
//
//  Ticket T63, findings F37 and F38, on Program with an empty store:
//
//    - Program's header was a fixed 30pt row inside a fixed 34pt frame,
//      so at AX3 "PROGRAM" and "+ NEW" ran over its two rules.
//    - "+ NEW" took taps across only its 39 x 14pt text.
//    - CREATE BLOCK and CHOOSE PRESET drew a fixed 16pt chevron at every
//      text size, unlike the template rows' chevron since T15.
//    - At AX3 CREATE BLOCK was squeezed into half the screen: its section
//      label and both choices' descriptions were cut short with "…", and
//      the choices' texts ran over their rows' rules.
//
//  CHOOSE PRESET's long names were thought to be cut short at AX3 too,
//  but on the 390pt phone they fit on one line, shrunk to the rows' 0.85
//  minimum scale; that check stays as a regression test.
//
//  At default text the header and both sheets keep their layout. XCUI
//  reads a text's whole label even when the screen cuts it short, so the
//  texts are read off a screenshot, and the header's rules, which are no
//  accessibility element, are found by their pixels.
//

import Vision
import XCTest

final class ProgramHeaderAndSheetsAX3UITests: XCTestCase {
    /// CHOOSE PRESET's rows, top to bottom: FROM SCRATCH, then the catalog.
    private static let presetNames = [
        "FROM SCRATCH", "HYPERTROPHY MESO", "GENERIC STRENGTH MESO", "POWERLIFTING PEAK", "5/3/1 CYCLE",
    ]
    /// CREATE BLOCK's two choices, each a name over a description.
    private static let startChoices = [
        (name: "Blank Block", detail: "Build your own phases manually."),
        (name: "Use Preset", detail: "Start from Hypertrophy Meso, Generic Strength Meso, Powerlifting Peak, or 5/3/1 Cycle."),
    ]
    /// CREATE BLOCK's texts above its choices.
    private static let createBlockHeading = [
        "CREATE BLOCK", "Choose a starting point for your reusable training block.", "CHOOSE STARTING POINT",
    ]
    /// The header at default text: a 30pt row between two 2pt rules.
    private static let defaultHeaderHeight: CGFloat = 34
    /// The space between the header and + NEW's popover.
    private static let popoverGap: CGFloat = 4
    /// bruInk in light mode, the header rules' color.
    private static let ink = UITestNavigation.RGB(hex: 0x0A0A0A)

    override func setUpWithError() throws {
        // Every check reports, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Repro

    /// At AX3 "PROGRAM" and "+ NEW" lie between the header's rules, which
    /// move apart to hold them; + NEW stays a 44pt target, and its popover
    /// still opens right under the header.
    @MainActor
    func testHeaderHoldsItsTextAtAX3() throws {
        let app = openEmptyProgram(textSize: .ax3)
        let title = headerTitle(in: app)
        let new = newButton(in: app)
        UITestNavigation.saveScreenshot("T63", "program-header", textSize: .ax3)
        let screenshot = XCUIScreen.main.screenshot()
        let rules = try XCTUnwrap(headerRules(in: app, of: screenshot))

        let inside = CGRect(x: 0, y: rules.top.upperBound, width: app.frame.width,
                            height: rules.bottom.lowerBound - rules.top.upperBound).insetBy(dx: 0, dy: -0.5)
        XCTAssertTrue(inside.contains(title.frame),
                      "PROGRAM at \(title.frame) must lie between the header's rules, from \(inside.minY) to \(inside.maxY)")
        // XCUI reports + NEW's target, not its text, so its letters are
        // found by their pixels.
        let newLetters = try XCTUnwrap(inkBounds(in: new.frame, of: screenshot), "+ NEW draws no letters")
        XCTAssertTrue(inside.contains(newLetters),
                      "+ NEW's letters at \(newLetters) must lie between the header's rules, from \(inside.minY) to \(inside.maxY)")
        assertLevel(newLetters, withLettersOf: title, in: screenshot)
        XCTAssertGreaterThan(rules.bottom.upperBound - rules.top.lowerBound, Self.defaultHeaderHeight + 0.5,
                             "The header must grow with its text at AX3")
        UITestNavigation.assertTapTarget(new, minimum: 44)
        XCTAssertGreaterThanOrEqual(new.frame.minY, rules.top.lowerBound - 0.5,
                                    "+ NEW's target must not reach into the status bar above the header")
        assertPopoverOpens(under: rules.bottom.upperBound, in: app, textSize: .ax3)
    }

    /// At default text "+ NEW" takes taps across 44 x 44pt from the header's
    /// top edge down, while the header keeps its 34pt height and its texts
    /// their places.
    @MainActor
    func testNewIsA44PointTapTargetAtDefaultText() throws {
        let app = openEmptyProgram(textSize: .default)
        let title = headerTitle(in: app)
        let new = newButton(in: app)
        UITestNavigation.saveScreenshot("T63", "program-header")
        let screenshot = XCUIScreen.main.screenshot()
        let rules = try XCTUnwrap(headerRules(in: app, of: screenshot))

        UITestNavigation.assertTapTarget(new, minimum: 44)
        // The status bar above the header takes no taps, so the target
        // starts at the header's top edge and hangs below the header.
        XCTAssertEqual(new.frame.minY, rules.top.lowerBound, accuracy: 0.5, "+ NEW's target starts at the header's top edge")
        XCTAssertEqual(new.frame.maxX, app.frame.maxX - 16, accuracy: 0.5, "+ NEW keeps its 16pt inset")
        XCTAssertEqual(rules.bottom.upperBound - rules.top.lowerBound, Self.defaultHeaderHeight, accuracy: 0.5,
                       "The header keeps its 34pt height at default text")
        XCTAssertEqual(title.frame.minX, 16, accuracy: 0.5, "PROGRAM keeps its 16pt inset")
        XCTAssertEqual(title.frame.midY, (rules.top.lowerBound + rules.bottom.upperBound) / 2, accuracy: 0.5,
                       "PROGRAM stays centered in the header")
        let newLetters = try XCTUnwrap(inkBounds(in: new.frame, of: screenshot), "+ NEW draws no letters")
        assertLevel(newLetters, withLettersOf: title, in: screenshot)
        assertPopoverOpens(under: rules.bottom.upperBound, in: app, textSize: .default)

        // Taps near each edge of the 44pt target, outside the drawn text,
        // open the popover too.
        let frame = new.frame
        let offsets = [
            CGVector(dx: 0, dy: -(frame.height / 2 - 3)),
            CGVector(dx: 0, dy: frame.height / 2 - 3),
            CGVector(dx: -(frame.width / 2 - 3), dy: 0),
            CGVector(dx: frame.width / 2 - 3, dy: 0),
        ]
        for offset in offsets {
            new.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(offset).tap()
            let opened = app.buttons["+ New block"].waitForExistence(timeout: 5)
            XCTAssertTrue(opened, "A tap \(offset) from the center of + NEW at \(frame) must open its popover")
            if opened {
                closePopover(in: app)
            }
        }
    }

    /// At AX3 CREATE BLOCK opens at full height and scrolls, so its title,
    /// section label and both choices show whole, each choice inside its
    /// row, with a chevron that grows like the template rows' chevron.
    @MainActor
    func testCreateBlockShowsEveryTextWholeAtAX3() throws {
        let app = openEmptyProgram(textSize: .ax3)
        let chevronHeight = templateChevronHeight(in: app)
        openCreateBlock(in: app)
        UITestNavigation.saveScreenshot("T63", "create-block", textSize: .ax3)
        XCTAssertLessThan(app.staticTexts["CREATE BLOCK"].frame.minY, app.frame.height / 3,
                          "At AX3 CREATE BLOCK opens at full height")

        for text in Self.createBlockHeading {
            let element = app.staticTexts[text]
            XCTAssertTrue(element.exists, "CREATE BLOCK shows no \"\(text)\"")
            revealWhole(element, in: app)
            try assertShowsWhole(text, at: element.frame, of: XCUIScreen.main.screenshot())
        }

        var above = app.staticTexts["CHOOSE STARTING POINT"]
        for choice in Self.startChoices {
            let row = sheetRow(choice.name, in: app)
            revealWhole(row, in: app)
            let texts = [row.staticTexts[choice.name], row.staticTexts[choice.detail]]
            let chevron = row.staticTexts["›"]
            UITestNavigation.assertNoOverlap(above, row)
            assertNoTwoOverlap(texts + [chevron])
            for element in texts + [chevron] {
                UITestNavigation.assertInside(element, row)
            }
            let screenshot = XCUIScreen.main.screenshot()
            for (text, element) in zip([choice.name, choice.detail], texts) {
                try assertShowsWhole(text, at: element.frame, of: screenshot)
            }
            XCTAssertEqual(chevron.frame.height, chevronHeight * sheetScale(of: row, in: app), accuracy: 1,
                           "\(choice.name)'s chevron must grow like the template rows' chevron")
            above = row
        }
        UITestNavigation.saveScreenshot("T63", "create-block-end", textSize: .ax3)
    }

    /// At AX3 CHOOSE PRESET opens at full height, every row shows its whole
    /// name inside the row, and its chevron grows like the template rows'.
    @MainActor
    func testChoosePresetShowsEveryWholeNameAtAX3() throws {
        let app = openEmptyProgram(textSize: .ax3)
        let chevronHeight = templateChevronHeight(in: app)
        openChoosePreset(in: app)
        UITestNavigation.saveScreenshot("T63", "choose-preset", textSize: .ax3)
        XCTAssertLessThan(app.staticTexts["CHOOSE PRESET"].frame.minY, app.frame.height / 3,
                          "At AX3 CHOOSE PRESET opens at full height")

        var above = app.staticTexts["CHOOSE PRESET"]
        for name in Self.presetNames {
            let row = sheetRow(name, in: app)
            revealWhole(row, in: app)
            let label = row.staticTexts[name]
            let chevron = row.staticTexts["›"]
            UITestNavigation.assertNoOverlap(above, row)
            UITestNavigation.assertNoOverlap(label, chevron)
            UITestNavigation.assertInside(label, row)
            UITestNavigation.assertInside(chevron, row)
            try assertShowsWhole(name, at: row.frame, of: XCUIScreen.main.screenshot())
            XCTAssertEqual(chevron.frame.height, chevronHeight * sheetScale(of: row, in: app), accuracy: 1,
                           "\(name)'s chevron must grow like the template rows' chevron")
            above = row
        }
        UITestNavigation.saveScreenshot("T63", "choose-preset-end", textSize: .ax3)
    }

    // MARK: - Default text keeps today's layout

    /// At default text CREATE BLOCK and CHOOSE PRESET open at half height
    /// with 64pt choices, 52pt presets and the template rows' 16pt chevron.
    @MainActor
    func testSheetsKeepTheirLayoutAtDefaultText() throws {
        let app = openEmptyProgram(textSize: .default)
        let chevronHeight = templateChevronHeight(in: app)
        openCreateBlock(in: app)
        UITestNavigation.saveScreenshot("T63", "create-block")
        XCTAssertGreaterThan(app.staticTexts["CREATE BLOCK"].frame.minY, app.frame.height / 3,
                             "CREATE BLOCK opens at half height")
        for choice in Self.startChoices {
            let row = sheetRow(choice.name, in: app)
            let scale = sheetScale(of: row, in: app)
            XCTAssertGreaterThanOrEqual(row.frame.height / scale, 64 - 0.5, "\(choice.name) keeps its 64pt minimum height")
            XCTAssertEqual(row.staticTexts["›"].frame.height, chevronHeight * scale, accuracy: 0.5,
                           "\(choice.name) keeps the template rows' 16pt chevron")
        }

        hittableButton("Use Preset", in: app).tap()
        XCTAssertTrue(app.staticTexts["CHOOSE PRESET"].waitForExistence(timeout: 5), "Use Preset must open CHOOSE PRESET")
        UITestNavigation.saveScreenshot("T63", "choose-preset")
        XCTAssertGreaterThan(app.staticTexts["CHOOSE PRESET"].frame.minY, app.frame.height / 3,
                             "CHOOSE PRESET opens at half height")
        for name in Self.presetNames {
            let row = sheetRow(name, in: app)
            let scale = sheetScale(of: row, in: app)
            XCTAssertEqual(row.frame.height / scale, 52, accuracy: 0.5, "\(name) keeps its 52pt row")
            XCTAssertEqual(row.staticTexts["›"].frame.height, chevronHeight * scale, accuracy: 0.5,
                           "\(name) keeps the template rows' 16pt chevron")
        }
    }

    // MARK: - Program

    /// Program on a fresh store, which has no block and no routine, so it
    /// shows the empty state and its template rows.
    @MainActor
    private func openEmptyProgram(textSize: UITestNavigation.TextSize) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize)
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.staticTexts["NO PROGRAM"].waitForExistence(timeout: 10), "Program must show its empty state")
        return app
    }

    @MainActor
    private func newButton(in app: XCUIApplication) -> XCUIElement {
        let new = app.buttons["+ NEW"]
        XCTAssertTrue(new.waitForExistence(timeout: 5), "The header has no + NEW")
        return new
    }

    /// The header's "PROGRAM", the topmost text that reads it.
    @MainActor
    private func headerTitle(in app: XCUIApplication) -> XCUIElement {
        let titles = app.staticTexts.matching(NSPredicate(format: "label == %@", "PROGRAM"))
        XCTAssertTrue(titles.firstMatch.waitForExistence(timeout: 5), "The header has no PROGRAM")
        return titles.allElementsBoundByIndex.min { $0.frame.minY < $1.frame.minY } ?? titles.firstMatch
    }

    /// The header's two 2pt rules, as spans of screen points from the top:
    /// the first two ink runs down a column between "PROGRAM" and "+ NEW",
    /// where no text is drawn.
    @MainActor
    private func headerRules(
        in app: XCUIApplication, of screenshot: XCUIScreenshot, file: StaticString = #filePath, line: UInt = #line
    ) -> (top: ClosedRange<CGFloat>, bottom: ClosedRange<CGFloat>)? {
        let title = headerTitle(in: app)
        let x = (title.frame.maxX + newButton(in: app).frame.minX) / 2
        let runs = inkRuns(at: x, through: title.frame.maxY + 40, of: screenshot)
        guard runs.count >= 2 else {
            XCTFail("Down x = \(x) the screen shows \(runs.count) rules, not the header's two", file: file, line: line)
            return nil
        }
        return (runs[0], runs[1])
    }

    /// Fails unless `letters` sit level with PROGRAM's letters, their
    /// centers within a point.
    @MainActor
    private func assertLevel(
        _ letters: CGRect, withLettersOf title: XCUIElement, in screenshot: XCUIScreenshot,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let titleLetters = inkBounds(in: title.frame, of: screenshot) else {
            return XCTFail("PROGRAM draws no letters", file: file, line: line)
        }
        XCTAssertEqual(letters.midY, titleLetters.midY, accuracy: 1,
                       "+ NEW's letters at \(letters) must sit level with PROGRAM's at \(titleLetters)", file: file, line: line)
    }

    /// Opens + NEW's popover, checks that its top edge sits right under the
    /// header's bottom edge at `headerBottom`, and closes it.
    @MainActor
    private func assertPopoverOpens(
        under headerBottom: CGFloat, in app: XCUIApplication, textSize: UITestNavigation.TextSize,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        newButton(in: app).tap()
        let newBlock = app.buttons["+ New block"]
        XCTAssertTrue(newBlock.waitForExistence(timeout: 5), "+ NEW must open its popover", file: file, line: line)
        UITestNavigation.saveScreenshot("T63", "new-popover", textSize: textSize)
        XCTAssertEqual(newBlock.frame.minY, headerBottom + Self.popoverGap, accuracy: 1,
                       "+ NEW's popover must open right under the header, which ends at \(headerBottom)",
                       file: file, line: line)
        closePopover(in: app)
    }

    /// Taps the dimmed screen beside the popover, which closes it.
    @MainActor
    private func closePopover(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.75)).tap()
        XCTAssertTrue(app.buttons["+ New block"].waitForNonExistence(timeout: 5), "A tap beside the popover must close it")
    }

    /// The height of the first template row's chevron, the one T15 scaled
    /// with the text.
    @MainActor
    private func templateChevronHeight(in app: XCUIApplication) -> CGFloat {
        let row = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+W, .*")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Program shows no template rows")
        UITestNavigation.reveal(row, in: app)
        let chevron = row.staticTexts["›"]
        XCTAssertTrue(chevron.exists, "The template row \(row.label) has no chevron")
        return chevron.frame.height
    }

    // MARK: - Sheets

    /// Program → + NEW → + New block: the CREATE BLOCK sheet.
    @MainActor
    private func openCreateBlock(in app: XCUIApplication) {
        hittableButton("+ NEW", in: app).tap()
        hittableButton("+ New block", in: app).tap()
        XCTAssertTrue(app.staticTexts["CREATE BLOCK"].waitForExistence(timeout: 5), "+ New block must open CREATE BLOCK")
    }

    /// CREATE BLOCK → Use Preset: the CHOOSE PRESET sheet.
    @MainActor
    private func openChoosePreset(in app: XCUIApplication) {
        openCreateBlock(in: app)
        let usePreset = sheetRow("Use Preset", in: app)
        revealWhole(usePreset, in: app)
        usePreset.tap()
        XCTAssertTrue(app.staticTexts["CHOOSE PRESET"].waitForExistence(timeout: 5), "Use Preset must open CHOOSE PRESET")
    }

    /// A sheet row: a button whose label starts with `name`, then its other
    /// texts, such as "GENERIC STRENGTH MESO, ›".
    @MainActor
    private func sheetRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let row = app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR label BEGINSWITH[c] %@", name, name + ","))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The sheet has no \(name) row")
        return row
    }

    /// How much the sheet holding `row` is scaled. A half-height sheet is
    /// inset from the screen's sides and scales its content to fit, so a
    /// full-width row is narrower than the screen.
    @MainActor
    private func sheetScale(of row: XCUIElement, in app: XCUIApplication) -> CGFloat {
        row.frame.width / app.frame.width
    }

    /// Drags the sheet's content up, a little at a time, until `element`
    /// lies wholly above the home indicator.
    @MainActor
    private func revealWhole(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let bottom = app.frame.maxY - 34
        for _ in 0..<12 {
            if element.exists && element.frame.minY >= 0 && element.frame.maxY <= bottom { return }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).press(
                forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
        }
        XCTAssertTrue(element.exists && element.frame.maxY <= bottom,
                      "\(element.label) at \(element.frame) never came wholly on screen", file: file, line: line)
    }

    /// The match a user can tap: a sheet leaves same-named controls under it.
    @MainActor
    private func hittableButton(_ label: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let matches = app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR label BEGINSWITH[c] %@", label, label + ","))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "Missing \(label)", file: file, line: line)
        for _ in 0..<10 {
            if let match = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) { return match }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("No tappable \(label)", file: file, line: line)
        return matches.firstMatch
    }

    // MARK: - Frames

    @MainActor
    private func assertNoTwoOverlap(_ elements: [XCUIElement], file: StaticString = #filePath, line: UInt = #line) {
        for (index, first) in elements.enumerated() {
            for second in elements.dropFirst(index + 1) {
                UITestNavigation.assertNoOverlap(first, second, file: file, line: line)
            }
        }
    }

    // MARK: - Screenshot readers

    /// Fails unless the screen shows all of `text` around `frame`. A text
    /// cut short with "…" loses its last letters.
    @MainActor
    private func assertShowsWhole(
        _ text: String, at frame: CGRect, of screenshot: XCUIScreenshot,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let shown = try readText(in: frame.insetBy(dx: -4, dy: -4), of: screenshot)
        XCTAssertTrue(lettersAndDigits(shown).contains(lettersAndDigits(text)),
                      "The screen must show \"\(text)\" whole, but it reads \"\(shown)\"", file: file, line: line)
    }

    /// The text drawn inside `rect`, in screen points, read line by line
    /// from the top.
    @MainActor
    private func readText(in rect: CGRect, of screenshot: XCUIScreenshot) throws -> String {
        let image = screenshot.image
        let cgImage = try XCTUnwrap(image.cgImage, "The screenshot has no pixels")
        let pixels = CGRect(
            x: rect.minX * image.scale, y: rect.minY * image.scale,
            width: rect.width * image.scale, height: rect.height * image.scale
        ).integral.intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        let crop = try XCTUnwrap(pixels.isEmpty ? nil : cgImage.cropping(to: pixels), "Cannot crop \(rect) from the screenshot")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: crop).perform([request])
        // Vision's boxes start at the bottom left: higher lines first.
        return (request.results ?? [])
            .sorted { ($0.boundingBox.midY, -$0.boundingBox.minX) > ($1.boundingBox.midY, -$1.boundingBox.minX) }
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }

    /// Uppercased letters and digits only, so line breaks, spacing and the
    /// chevron do not matter. Vision reads Space Grotesk's lowercase "y" as
    /// "u", so the two count as one letter.
    private func lettersAndDigits(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.map { $0 == "Y" ? "U" : $0 })
    }

    /// The runs of ink down the column at `x`, from the top of the screen
    /// to `bottom`, as spans of screen points.
    @MainActor
    private func inkRuns(at x: CGFloat, through bottom: CGFloat, of screenshot: XCUIScreenshot) -> [ClosedRange<CGFloat>] {
        let scale = screenshot.image.scale
        let column = CGRect(x: (x * scale).rounded(.down) / scale, y: 0, width: 1 / scale, height: bottom)
        guard let strip = pixels(in: column, of: screenshot) else { return [] }
        let width = Int(strip.frame.width)
        let height = Int(strip.frame.height)
        var runs: [ClosedRange<CGFloat>] = []
        var start: Int?
        for row in 0...height {
            let ink = row < height && isInk(strip.bytes, at: row * width, within: 40)
            if ink && start == nil {
                start = row
            } else if !ink, let first = start {
                runs.append(CGFloat(first) / scale...CGFloat(row) / scale)
                start = nil
            }
        }
        return runs
    }

    /// The box around the letters drawn in ink inside `rect`, in screen
    /// points, or nil when there are none. A row of ink all the way across,
    /// such as one of the header's rules, holds no letters.
    @MainActor
    private func inkBounds(in rect: CGRect, of screenshot: XCUIScreenshot) -> CGRect? {
        guard let crop = pixels(in: rect, of: screenshot) else { return nil }
        let width = Int(crop.frame.width)
        var box = CGRect.null
        for row in 0..<Int(crop.frame.height) {
            let ink = (0..<width).filter { isInk(crop.bytes, at: row * width + $0, within: 96) }
            guard let first = ink.first, let last = ink.last, ink.count < width * 95 / 100 else { continue }
            box = box.union(CGRect(x: first, y: row, width: last - first + 1, height: 1))
        }
        guard !box.isNull else { return nil }
        let scale = screenshot.image.scale
        return CGRect(x: (crop.frame.minX + box.minX) / scale, y: (crop.frame.minY + box.minY) / scale,
                      width: box.width / scale, height: box.height / scale)
    }

    /// The pixels of `rect`, in screen points, cut from the screenshot: where
    /// they lie in device pixels, and their sRGB bytes row by row from the top.
    @MainActor
    private func pixels(in rect: CGRect, of screenshot: XCUIScreenshot) -> (frame: CGRect, bytes: [UInt8])? {
        let image = screenshot.image
        guard let cgImage = image.cgImage, let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let frame = CGRect(
            x: rect.minX * image.scale, y: rect.minY * image.scale,
            width: rect.width * image.scale, height: rect.height * image.scale
        ).integral.intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard !frame.isEmpty, let crop = cgImage.cropping(to: frame) else { return nil }
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: crop.width, height: crop.height, bitsPerComponent: 8,
                bytesPerRow: crop.width * 4, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
            return true
        }
        return drawn ? (frame, bytes) : nil
    }

    /// Whether pixel number `index` of `bytes` is within `tolerance` of ink.
    private func isInk(_ bytes: [UInt8], at index: Int, within tolerance: Int) -> Bool {
        let byte = index * 4
        return UITestNavigation.RGB(red: Int(bytes[byte]), green: Int(bytes[byte + 1]), blue: Int(bytes[byte + 2]))
            .distance(to: Self.ink) <= tolerance
    }
}
