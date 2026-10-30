//
//  ProgramDarkModeUITests.swift
//  fitbodUITests
//
//  T16, review item 9. In dark mode every tab turned dark except Program,
//  which kept its light paper: its block and routine rows showed white
//  text on cream, CHOOSE ROUTINE showed black text on black, and New Block
//  stayed light. Program, New Block and the block name field mixed fixed
//  RGB colors with adaptive ones.
//
//  The run sets the phone's appearance with `xcrun simctl ui`. Each test
//  checks the screen's paper against bruPaper in that appearance and
//  measures text contrast in a screenshot. The phase color checks hold in
//  dark mode, the mode the ticket sets contrast for.
//

import XCTest

final class ProgramDarkModeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Every check runs, so one failure does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Program

    /// A fresh store has no block and no routine, so Program shows its
    /// empty state. The screen is paper, and the first template's name
    /// reads against its row.
    @MainActor
    func testProgramEmptyStateDrawsOnPaper() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(app.staticTexts["NO PROGRAM"].waitForExistence(timeout: 10), "Program must show its empty state")
        let row = try firstTemplateRow(in: app)
        let name = row.label.components(separatedBy: ", ")[1]
        let title = row.staticTexts[name]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Missing the template name \(name)")
        UITestNavigation.reveal(row, in: app)
        waitUntilStill(title)
        UITestNavigation.saveScreenshot("T16", "program-empty", appearance: appearance)
        let screenshot = XCUIScreen.main.screenshot()

        assertPaper(at: CGPoint(x: 6, y: title.frame.midY), in: screenshot, "Program's empty state")
        assertContrast(of: title, atLeast: 4.5, in: screenshot)
    }

    /// With T17's active block, Program lists the block and its routine,
    /// and each row's title reads against the screen's paper.
    @MainActor
    func testProgramBlockAndRoutineRowsRead() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "ACTIVE block: Live Block")).firstMatch
        let routine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Live Routine,")).firstMatch
        let blockTitle = card.staticTexts["Live Block"]
        let routineTitle = routine.staticTexts["Live Routine"]
        XCTAssertTrue(blockTitle.waitForExistence(timeout: 10), "Program must list the active Live Block")
        XCTAssertTrue(routineTitle.waitForExistence(timeout: 10), "Program must list Live Routine")
        waitUntilStill(blockTitle)
        UITestNavigation.saveScreenshot("T16", "program-block", appearance: appearance)
        let screenshot = XCUIScreen.main.screenshot()

        assertPaper(at: CGPoint(x: 6, y: blockTitle.frame.midY), in: screenshot, "Program's block row")
        assertContrast(of: blockTitle, atLeast: 4.5, in: screenshot)
        assertContrast(of: routineTitle, atLeast: 4.5, in: screenshot)
    }

    // MARK: - New Block

    /// New Block draws on paper, and its block name field reads.
    @MainActor
    func testNewBlockDrawsOnPaper() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openBlankNewBlock(in: app)
        let title = app.staticTexts.labeled("NEW BLOCK")
        let nameLabel = app.staticTexts.labeled("BLOCK NAME")
        let placeholder = app.staticTexts.labeled("NAME YOUR BLOCK")
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 10), "Missing the block name field")
        XCTAssertTrue(placeholder.exists, "The empty block name field must show its placeholder")
        waitUntilStill(title)
        UITestNavigation.saveScreenshot("T16", "new-block", appearance: appearance)
        let screenshot = XCUIScreen.main.screenshot()

        assertPaper(at: CGPoint(x: 6, y: title.frame.midY), in: screenshot, "New Block's top bar")
        assertPaper(at: CGPoint(x: 6, y: nameLabel.frame.midY), in: screenshot, "New Block's page")
        assertContrast(of: nameLabel, atLeast: 4.5, in: screenshot)
        // The 46pt placeholder is large display text.
        assertContrast(of: placeholder, atLeast: 3, in: screenshot)
    }

    /// + ATTACH opens CHOOSE ROUTINE, whose routine names read against
    /// their rows.
    @MainActor
    func testChooseRoutineNamesRead() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        openBlankNewBlock(in: app)
        let attach = app.buttons.labeled("+ ATTACH ▸")
        XCTAssertTrue(attach.waitForExistence(timeout: 10), "New Block must offer + ATTACH")
        revealAboveBottomBar(attach, in: app)
        attach.tap()
        XCTAssertTrue(app.staticTexts.labeled("Choose Routine").waitForExistence(timeout: 10),
                      "+ ATTACH must open CHOOSE ROUTINE")
        let routine = hittable(app.buttons, "Live Routine")
        waitUntilStill(routine)
        UITestNavigation.saveScreenshot("T16", "choose-routine", appearance: appearance)
        let screenshot = XCUIScreen.main.screenshot()

        // The row is one button, with its name 16pt in from the sheet's edge.
        // Its leading part, inset from the sheet's edge and the rules above
        // and below the row, holds only the name: no ✓ and no scroll bar.
        let row = routine.frame
        let name = CGRect(x: row.minX + 8, y: row.minY + 4, width: row.width * 0.6 - 8, height: row.height - 8)
        assertContrast(in: name, atLeast: 4.5, in: screenshot, "Live Routine in CHOOSE ROUTINE")
    }

    /// New Block with all five phase kinds: Accumulation, Intensification
    /// and Deload from the blank block, then Peak and Realization from
    /// + ADD PHASE. In dark mode each chart label reads on its phase band,
    /// and each phase badge's number reads on its fill as large text.
    @MainActor
    func testNewBlockPhaseColorsRead() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openBlankNewBlock(in: app)
        let prompt = app.staticTexts.labeled("Choose a phase type to add.")
        for kind in ["Peak", "Realization"] {
            hittable(app.buttons, "+ ADD PHASE").tap()
            XCTAssertTrue(prompt.waitForExistence(timeout: 10), "+ ADD PHASE must open its sheet")
            let choice = hittable(app.buttons, kind)
            if kind == "Peak" {
                waitUntilStill(choice)
                UITestNavigation.saveScreenshot("T16", "add-phase", appearance: appearance)
            }
            choice.tap()
            XCTAssertTrue(prompt.waitForNonExistence(timeout: 5), "Picking \(kind) must close the sheet")
        }
        let checksContrast = appearance == .dark

        let labels = ["ACCUM.", "INTENS.", "DELOAD", "PEAK", "REAL."].map { app.staticTexts[$0] }
        for label in labels {
            XCTAssertTrue(label.waitForExistence(timeout: 10), "The chart must label every phase: \(label)")
        }
        waitUntilStill(labels[0])
        UITestNavigation.saveScreenshot("T16", "new-block-chart", appearance: appearance)
        let chart = XCUIScreen.main.screenshot()
        if checksContrast {
            for label in labels {
                assertContrast(of: label, atLeast: 4.5, in: chart)
            }
        }

        for (index, kind) in ["Accumulation", "Intensification", "Deload", "Peak", "Realization"].enumerated() {
            let badge = phaseBadge(index + 1, kind, in: app)
            revealAboveBottomBar(badge, in: app)
            waitUntilStill(badge)
            if checksContrast {
                assertContrast(of: badge, atLeast: 3, in: XCUIScreen.main.screenshot())
            }
        }
        UITestNavigation.saveScreenshot("T16", "new-block-phases", appearance: appearance)
    }

    // MARK: - Navigation

    /// Program → + NEW → + New block → Blank Block.
    @MainActor
    private func openBlankNewBlock(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Program", in: app)
        hittable(app.buttons, "+ NEW", file: file, line: line).tap()
        hittable(app.buttons, "+ New block", file: file, line: line).tap()
        hittable(app.buttons, "Blank Block", file: file, line: line).tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "New Block never opened",
                      file: file, line: line)
    }

    /// The top template row. A row's label starts with its weeks:
    /// "8W, Hypertrophy Meso, ACCUM 5 · INTNS 2 · DELOAD 1, ›".
    @MainActor
    private func firstTemplateRow(in app: XCUIApplication) throws -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+W, .*"))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 10), "Program shows no template rows")
        let rows = query.allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
        return try XCTUnwrap(rows.first, "Program shows no template rows")
    }

    /// The number in phase `number`'s badge: the leading text of its card,
    /// which labels each of its texts "Phase 1: Accumulation".
    @MainActor
    private func phaseBadge(_ number: Int, _ kind: String, in app: XCUIApplication) -> XCUIElement {
        let texts = app.staticTexts.matching(NSPredicate(format: "label == %@", "Phase \(number): \(kind)"))
        XCTAssertTrue(texts.firstMatch.waitForExistence(timeout: 10), "Missing phase \(number), \(kind)")
        return texts.allElementsBoundByIndex.min { $0.frame.minX < $1.frame.minX } ?? texts.firstMatch
    }

    /// Drags New Block's page until `element` sits between the top bar and
    /// the bottom bar, which covers the end of the scroll view. The drag
    /// starts in the page margin, clear of the phase cards' swipe gesture.
    @MainActor
    private func revealAboveBottomBar(_ element: XCUIElement, in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        // The bar's 52pt buttons sit 24pt below its top edge; CANCEL's frame is its text.
        let barTop = hittable(app.buttons, "Cancel", file: file, line: line).frame.midY - 50
        let pageTop = app.staticTexts.labeled("NEW BLOCK").frame.maxY + 20
        let window = app.windows.firstMatch
        for _ in 0..<8 {
            let frame = element.frame
            if frame.minY >= pageTop && frame.maxY <= barTop { return }
            let distance = frame.maxY > barTop ? -(frame.maxY - barTop + 80) : pageTop - frame.minY + 80
            let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 8, dy: (pageTop + barTop) / 2))
            let end = start.withOffset(CGVector(dx: 0, dy: max(-300, min(300, distance))))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            waitUntilStill(element)
        }
        XCTFail("\(element) must scroll between New Block's bars", file: file, line: line)
    }

    /// The match a user can tap: a sheet or cover leaves same-named
    /// controls under it.
    @MainActor
    @discardableResult
    private func hittable(
        _ query: XCUIElementQuery, _ label: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let matches = query.matching(NSPredicate(format: "label ==[c] %@ OR label BEGINSWITH[c] %@", label, label + ","))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "Missing \(label)", file: file, line: line)
        for _ in 0..<10 {
            if let match = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) { return match }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("No tappable \(label)", file: file, line: line)
        return matches.firstMatch
    }

    /// Waits until `element` stops moving, so a sheet or scroll has settled
    /// before a screenshot.
    @MainActor
    private func waitUntilStill(_ element: XCUIElement) {
        var last = element.frame
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.25)
            let frame = element.frame
            if frame == last { return }
            last = frame
        }
    }

    // MARK: - Colors

    /// The phone's appearance, which the run sets with `xcrun simctl ui`.
    @MainActor
    private var appearance: UITestNavigation.Appearance {
        XCUIDevice.shared.appearance == .dark ? .dark : .light
    }

    @MainActor
    private func assertPaper(at point: CGPoint, in screenshot: XCUIScreenshot, _ place: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let paper = appearance == .dark ? UITestNavigation.RGB(hex: 0x0A0A0A) : UITestNavigation.RGB(hex: 0xFAFAF7)
        let sampled = UITestNavigation.color(at: point, in: screenshot).map(\.description) ?? "off screen"
        XCTContext.runActivity(named: "Paper: \(place) at (\(point.x), \(point.y)) is \(sampled), bruPaper is \(paper)") { _ in }
        if let problem = UITestNavigation.colorProblem(at: point, in: screenshot, is: paper) {
            XCTFail("\(place) must draw on bruPaper in \(appearance) mode. \(problem)", file: file, line: line)
        }
    }

    @MainActor
    private func assertContrast(of text: XCUIElement, atLeast minimum: Double, in screenshot: XCUIScreenshot,
                                file: StaticString = #filePath, line: UInt = #line) {
        assertContrast(in: text.frame, atLeast: minimum, in: screenshot, "\"\(text.label)\"", file: file, line: line)
    }

    @MainActor
    private func assertContrast(in region: CGRect, atLeast minimum: Double, in screenshot: XCUIScreenshot, _ text: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard let contrast = TextContrast(in: region, of: screenshot) else {
            return XCTFail("\(text) is not on screen at \(region)", file: file, line: line)
        }
        let measured = "\(text) at \(region) is \(contrast.glyph) on \(contrast.background) in \(appearance) mode: "
            + "\(String(format: "%.2f", contrast.ratio)):1"
        XCTContext.runActivity(named: "Contrast: \(measured), needs \(String(format: "%.1f", minimum)):1") { _ in }
        XCTAssertGreaterThanOrEqual(
            contrast.ratio, minimum, "\(measured), below \(String(format: "%.1f", minimum)):1",
            file: file, line: line
        )
    }
}

// MARK: - Text contrast

/// A text's glyph color and the background behind it, read from a
/// screenshot the way `UITestNavigation.color(at:in:)` reads one pixel.
private struct TextContrast {
    let glyph: UITestNavigation.RGB
    let background: UITestNavigation.RGB

    /// The WCAG 2 contrast ratio, from 1 to 21.
    var ratio: Double {
        let lighter = max(glyph.luminance, background.luminance)
        let darker = min(glyph.luminance, background.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Reads every pixel in `region`, in screen points. The commonest color
    /// is the background between the glyphs, and the glyph color is the
    /// pixel whose luminance is farthest from it. Nil when `region` is off
    /// the screenshot.
    @MainActor
    init?(in region: CGRect, of screenshot: XCUIScreenshot) {
        let image = screenshot.image
        guard let cgImage = image.cgImage, let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let pixels = CGRect(x: region.minX * image.scale, y: region.minY * image.scale,
                            width: region.width * image.scale, height: region.height * image.scale)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard !pixels.isEmpty, let crop = cgImage.cropping(to: pixels) else { return nil }
        let width = crop.width
        let height = crop.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var counts: [UInt32: Int] = [:]
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            let hex = UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2])
            counts[hex, default: 0] += 1
        }
        guard let backgroundHex = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        let background = UITestNavigation.RGB(hex: backgroundHex)
        let glyphHex = counts.keys.max {
            abs(UITestNavigation.RGB(hex: $0).luminance - background.luminance)
                < abs(UITestNavigation.RGB(hex: $1).luminance - background.luminance)
        } ?? backgroundHex
        self.glyph = UITestNavigation.RGB(hex: glyphHex)
        self.background = background
    }
}

private extension UITestNavigation.RGB {
    /// WCAG 2 relative luminance, from 0 for black to 1 for white.
    var luminance: Double {
        func linear(_ channel: Int) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
