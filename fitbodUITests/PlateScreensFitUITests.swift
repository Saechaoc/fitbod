import XCTest

/// Ticket T107. Findings F196 to F200, which T19's worker found, and F47,
/// which T17's worker found. Plate Inventory's equipment tabs break only
/// between words at every text size; the calculator's EQUIPMENT heading
/// drops "TAP TO CHANGE", since its BAR and INVENTORY cells do nothing; at
/// AX3 the calculator's target shows whole without scrolling; the
/// quick-adjust chips and the tally boxes take taps in a 44pt band, and at
/// AX3 each tally box is at least 44pt wide; and inside the Settings sheet
/// no gray band shows under Done ▸. No plate in the per-side stack covers
/// another plate's label: PlateStackLayoutTests checks that, and this suite
/// saves the stacks.
final class PlateScreensFitUITests: XCTestCase {

    // Light-mode BRU ink.
    private static let ink = UITestNavigation.RGB(hex: 0x0A0A0A)

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Text sizes

    /// At default text, under Done ▸ the screen shows one color down to its
    /// bottom edge: the 24pt filler drew a gray band there. A tap 10pt above
    /// a tally box's drawn top edge sets its plate's count, and one 10pt
    /// above a quick-adjust chip's drawn top edge changes the target. With
    /// a 137.5 lb target the per-side stack loads a 45 and a 1.25, whose
    /// plate covered part of the 45's label. The EQUIPMENT heading reads no
    /// "TAP TO CHANGE", and its BAR and INVENTORY cells still do nothing
    /// when tapped.
    @MainActor
    func testPlateScreensFitAtDefaultText() throws {
        let app = openPlateInventory(textSize: .default)
        UITestNavigation.saveScreenshot("T107", "plate-inventory")
        var problems = try tabProblems(in: app)
        problems += bandProblems(under: UITestNavigation.hittable(app.buttons, "Done ▸", exactLabel: true), in: app)
        problems += tallyTapProblems(in: app)

        let title = openCalculator(in: app)
        UITestNavigation.saveScreenshot("T107", "calculator")
        problems += chipProblems(in: app)
        problems += perSideStackProblems(under: title, in: app)
        problems += equipmentProblems(under: title, in: app)
        XCTAssertEqual(problems, [], "The plate screens must fit at default text")
    }

    /// From XXXL up the tabs broke inside words: "DUMBBELLS" read
    /// "DUMBBELL" over "S" on the large phone.
    @MainActor
    func testPlateScreensFitAtXXXL() throws {
        let app = openPlateInventory(textSize: .xxxl)
        UITestNavigation.saveScreenshot("T107", "plate-inventory", textSize: .xxxl)
        let problems = try tabProblems(in: app)
        openCalculator(in: app)
        UITestNavigation.saveScreenshot("T107", "calculator", textSize: .xxxl)
        XCTAssertEqual(problems, [], "The equipment tabs must keep their words whole at XXXL")
    }

    /// At AX3 on the small phone the tabs read "BARB" over "ELL" and "DUMB"
    /// over "BELL" over "S", and each tally box was about 20pt wide. The
    /// calculator's target must show whole in its sheet without scrolling:
    /// at 9b942de it already did, and this keeps it so.
    @MainActor
    func testPlateScreensFitAtAX3() throws {
        let app = openPlateInventory(textSize: .ax3)
        UITestNavigation.saveScreenshot("T107", "plate-inventory", textSize: .ax3)
        var problems = try tabProblems(in: app)
        problems += tallyWidthProblems(in: app)

        openCalculator(in: app)
        UITestNavigation.saveScreenshot("T107", "calculator", textSize: .ax3)
        let target = app.staticTexts.labeled("60")
        let sheet = app.scrollViews.allElementsBoundByIndex.last { $0.isHittable }
        if !target.exists || sheet == nil {
            problems.append("The calculator must show its target, 60, in a scroll view")
        } else if let sheet, !sheet.frame.insetBy(dx: -0.5, dy: -0.5).contains(target.frame) {
            problems.append("The target \(target.frame) must show whole in the calculator \(sheet.frame) without scrolling")
        }
        XCTAssertEqual(problems, [], "The plate screens must fit at AX3")
    }

    // MARK: - Evidence

    /// The logger draws the warm-up rows' plates with the same primitive,
    /// at mini size and without labels. They stand in for the set's plate
    /// stack, which no tap opens at 9b942de: SetRow's tap gesture on the
    /// weight cell never fires (notes.md).
    @MainActor
    func testLoggerWarmUpPlatesAtDefaultText() throws {
        let app = UITestNavigation.openSeededWorkout()
        let plates = app.otherElements.matching(NSPredicate(format: "label CONTAINS %@", "Plates each side")).firstMatch
        XCTAssertTrue(plates.waitForExistence(timeout: 10), "The warm-up ramp must draw its plates")
        UITestNavigation.waitUntilStill(plates)
        UITestNavigation.assertInside(plates, app.windows.firstMatch)
        UITestNavigation.saveScreenshot("T107", "logger-plates")
    }

    // MARK: - Checks

    /// A problem for each equipment tab whose label breaks inside a word.
    /// "TRAP BAR" may break at its space and "EZ-BAR" after its hyphen.
    /// Vision reads spaces into tracked text, so each line Vision reads in
    /// a tab is compared without its spaces.
    @MainActor
    private func tabProblems(in app: XCUIApplication) throws -> [String] {
        let strip = app.otherElements["plateInventory.tabStrip"]
        let screenshot = XCUIScreen.main.screenshot()
        var problems: [String] = []
        for (label, pieces) in [("BARBELL", ["BARBELL"]), ("DUMBBELLS", ["DUMBBELLS"]),
                                ("EZ-BAR", ["EZ-", "BAR"]), ("TRAP BAR", ["TRAP", "BAR"])] {
            let tab = strip.buttons.labeled(label)
            guard tab.exists else {
                problems.append("Plate Inventory must show the \(label) tab")
                continue
            }
            // Inside the tab's 1pt separators, which Vision can read as letters.
            let lines = try UITestNavigation.textLines(in: tab.frame.insetBy(dx: 1.5, dy: 1.5), of: screenshot)
                .map { Self.readable($0.text) }
            if !Self.splitsBetween(pieces, lines) {
                problems.append("The \(label) tab reads \(lines), so it breaks inside a word")
            }
        }
        return problems
    }

    /// Whether `lines` read `pieces` in order, each line whole pieces.
    private static func splitsBetween(_ pieces: [String], _ lines: [String]) -> Bool {
        var rest = pieces[...]
        for line in lines {
            var read = ""
            while read.count < line.count, let piece = rest.first {
                read += piece
                rest = rest.dropFirst()
            }
            if read != line { return false }
        }
        return rest.isEmpty && !lines.isEmpty
    }

    /// A line of text Vision read, in Latin capitals, without spaces, and
    /// with any dash read as a hyphen.
    @MainActor
    private static func readable(_ text: String) -> String {
        String(UITestNavigation.latin(text).filter { $0 != " " }.map { "‐–—−".contains($0) ? "-" : $0 })
    }

    /// Problems with the screen under `done`, beside the home indicator:
    /// from Done ▸'s bottom edge down to the bottom of the screen, every
    /// pixel must be one color.
    @MainActor
    private func bandProblems(under done: XCUIElement, in app: XCUIApplication) -> [String] {
        let window = app.windows.firstMatch.frame
        // The home indicator is 134pt to 148pt wide, centered.
        let x = window.midX - 100
        let colors = Self.column(atX: x, from: done.frame.maxY + 1, to: window.maxY - 0.5, in: XCUIScreen.main.screenshot())
        guard let first = colors.first?.color else {
            return ["No pixels under Done ▸ at \(done.frame)"]
        }
        let others = colors.filter { $0.color.distance(to: first) > 4 }
        guard let other = others.first else { return [] }
        return ["Under Done ▸ the screen is \(first) down to y \(other.y), then \(other.color): \(others.count) of \(colors.count) pixel rows differ"]
    }

    /// A tap 10pt above the drawn top edge of the 45 lb plate's first tally
    /// box sets the plate's count from 4 to 1.
    @MainActor
    private func tallyTapProblems(in app: XCUIApplication) -> [String] {
        let row = plateRow("45", in: app)
        guard row.waitForExistence(timeout: 10), row.value as? String == "4 per side" else {
            return ["A fresh barbell inventory must list the 45 lb plate, 4 per side"]
        }
        UITestNavigation.waitUntilStill(row, interval: 0.3)
        // At default text the four tally boxes start 116pt in (16pt padding,
        // the 90pt weight column, 10pt spacing) and end 106pt before the
        // trailing edge, 3pt apart.
        let x = row.frame.minX + 116 + (row.frame.width - 231) / 8
        guard let top = Self.drawnTop(at: CGPoint(x: x, y: row.frame.midY), in: XCUIScreen.main.screenshot()) else {
            return ["No tally box is drawn at x \(x) in the 45 lb row \(row.frame)"]
        }
        Self.tap(CGPoint(x: x, y: top - 10), in: app)
        if !waitForValue(row, "1 per side") {
            return ["A tap 10pt above the first tally box's drawn top edge, y \(top), must set the 45 lb plate to 1 per side, but it reads \(row.value ?? "nothing")"]
        }
        return []
    }

    /// At AX3 each of the 45 lb plate's four tally boxes is drawn at least
    /// 44pt wide.
    @MainActor
    private func tallyWidthProblems(in app: XCUIApplication) -> [String] {
        let row = plateRow("45", in: app)
        guard row.waitForExistence(timeout: 10) else {
            return ["A fresh barbell inventory must list the 45 lb plate"]
        }
        let top = app.otherElements["plateInventory.tabStrip"].frame.maxY
        // The footer's 2pt rule sits on top of Done ▸.
        let bottom = app.buttons.labeled("Done ▸").frame.minY - 2
        for _ in 0..<6 where !(row.frame.minY >= top && row.frame.maxY <= bottom) {
            let distance = row.frame.maxY > bottom ? -(row.frame.maxY - bottom + 20) : top - row.frame.minY + 20
            Self.drag(by: max(-250, min(250, distance)), from: (top + bottom) / 2, in: app)
            UITestNavigation.waitUntilStill(row)
        }
        guard row.frame.minY >= top, row.frame.maxY <= bottom else {
            return ["The 45 lb plate \(row.frame) must show whole between the tabs and the footer"]
        }
        UITestNavigation.saveScreenshot("T107", "plate-inventory-tally", textSize: .ax3)
        guard let widths = Self.tallyBoxWidths(in: row.frame, of: XCUIScreen.main.screenshot()) else {
            return ["No four tally boxes are drawn in the 45 lb plate's row \(row.frame)"]
        }
        let narrow = widths.filter { $0 < 44 - 0.5 }
        return narrow.isEmpty ? [] : ["At AX3 each tally box must be at least 44pt wide, but they are \(widths.map { String(format: "%.1f", $0) })pt"]
    }

    /// Each quick-adjust chip takes taps in a band at least 44pt tall, and a
    /// tap 10pt above +5's drawn top edge raises the target from 60 to 65.
    @MainActor
    private func chipProblems(in app: XCUIApplication) -> [String] {
        var problems: [String] = []
        // A medium sheet lays out at the window's width and draws inset, so
        // on screen it shrinks by the sheet's width over the window's.
        let window = app.windows.firstMatch.frame
        let sheet = app.scrollViews.allElementsBoundByIndex.last { $0.isHittable }?.frame ?? window
        let band = 44 * sheet.width / window.width
        for label in ["Subtract 5 lb", "Subtract 2.5 lb", "Add 2.5 lb", "Add 5 lb"] {
            let chip = app.buttons.labeled(label)
            if chip.frame.height < band - 0.5 {
                problems.append("\(label) takes taps in \(chip.frame.height)pt, under \(band)pt")
            }
        }
        let add5 = app.buttons.labeled("Add 5 lb")
        // Inside the chip's 6pt padding, clear of its 1.5pt outline's sides
        // and of its text.
        let x = add5.frame.minX + 3
        guard let top = Self.drawnTop(at: CGPoint(x: x, y: add5.frame.midY), in: XCUIScreen.main.screenshot()) else {
            return problems + ["+5 has no drawn outline at x \(x) in \(add5.frame)"]
        }
        Self.tap(CGPoint(x: add5.frame.midX, y: top - 10), in: app)
        if !app.staticTexts.labeled("65").waitForExistence(timeout: 3) {
            problems.append("A tap 10pt above +5's drawn top edge, y \(top), must raise the target from 60 to 65")
        }
        return problems
    }

    /// The chips raise the target to 137.5 lb, from 65 after +5's tap or
    /// from 60 without it, and the per-side stack shows its 45 and 1.25.
    @MainActor
    private func perSideStackProblems(under title: XCUIElement, in app: XCUIApplication) -> [String] {
        let add5 = app.buttons.labeled("Add 5 lb")
        let taps = app.staticTexts.labeled("65").exists ? 14 : 15
        for _ in 0..<taps { add5.tap() }
        app.buttons.labeled("Add 2.5 lb").tap()
        guard app.staticTexts.labeled("137.5").waitForExistence(timeout: 5) else {
            return ["The chips must raise the target to 137.5"]
        }
        let stack = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH %@", "Bar: 45 lb.")).firstMatch
        guard revealWhole(stack, under: title, in: app) else {
            return ["The calculator must show the per-side stack for 137.5"]
        }
        UITestNavigation.saveScreenshot("T107", "calculator-137_5")
        return stack.label.contains("one 45, one 1.25") ? [] : ["137.5 lb must load a 45 and a 1.25 per side: \(stack.label)"]
    }

    /// The EQUIPMENT heading reads no "TAP TO CHANGE", and a tap on BAR or
    /// on INVENTORY leaves the calculator as it was.
    @MainActor
    private func equipmentProblems(under title: XCUIElement, in app: XCUIApplication) -> [String] {
        var problems: [String] = []
        let hints = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "tap to change"))
        if hints.count > 0 {
            problems.append("The calculator must not read \"Tap to change\", but \(hints.count) element(s) do")
        }
        let readout = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH[c] %@ AND label CONTAINS[c] %@", "Bar ", "Plates"
        )).firstMatch
        let before = readout.label
        for label in ["Bar", "Inventory"] {
            let cell = app.staticTexts.labeled(label)
            guard revealWhole(cell, under: title, in: app) else {
                problems.append("The calculator must show its \(label) cell")
                continue
            }
            cell.tap()
            UITestNavigation.waitUntilStill(title)
            if !title.isHittable || !readout.exists || readout.label != before || app.alerts.count > 0 {
                problems.append("A tap on \(label) must leave the calculator as it was")
            }
        }
        UITestNavigation.saveScreenshot("T107", "calculator-equipment")
        return problems
    }

    // MARK: - Navigation

    /// Settings > Plate Inventory on a fresh store at `textSize`, once the
    /// push has stopped moving.
    @MainActor
    private func openPlateInventory(
        textSize: UITestNavigation.TextSize, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize, file: file, line: line)
        UITestNavigation.openSettings(in: app)
        let inventory = app.buttons.labeled("Plate Inventory")
        _ = inventory.waitForExistence(timeout: 10)
        UITestNavigation.reveal(inventory, in: app)
        inventory.tap()
        let strip = app.otherElements["plateInventory.tabStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10), "Plate Inventory must open", file: file, line: line)
        UITestNavigation.waitUntilStill(strip, interval: 0.3)
        return app
    }

    /// ••• opens the calculator. Returns its title once the sheet has
    /// stopped moving.
    @MainActor
    @discardableResult
    private func openCalculator(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        UITestNavigation.hittable(app.buttons, "More", exactLabel: true, file: file, line: line).tap()
        let title = app.staticTexts.labeled("Plate calculator")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "••• must open the plate calculator", file: file, line: line)
        UITestNavigation.waitUntilStill(title, interval: 0.3)
        return title
    }

    /// Drags the calculator's content until `element` shows whole between
    /// the sheet's header and the bottom of the screen. False when it never
    /// does.
    @MainActor
    private func revealWhole(_ element: XCUIElement, under title: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        let top = title.frame.maxY + 50
        let bottom = app.windows.firstMatch.frame.maxY - 40
        for _ in 0..<10 {
            let frame = element.frame
            if frame.minY >= top - 50 && frame.maxY <= bottom && element.isHittable { return true }
            let distance = frame.maxY > bottom ? -(frame.maxY - bottom + 40) : top - frame.minY + 40
            Self.drag(by: max(-(bottom - top - 40), min(bottom - top - 40, distance)), from: (top + bottom) / 2, in: app)
            UITestNavigation.waitUntilStill(element)
        }
        return element.frame.maxY <= bottom && element.isHittable
    }

    /// A PlateTallyRow is one adjustable element, such as "45 lb plate"
    /// with the value "4 per side".
    @MainActor
    private func plateRow(_ weight: String, in app: XCUIApplication) -> XCUIElement {
        app.otherElements["\(weight) lb plate"]
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval = 3) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [matches], timeout: timeout) == .completed
    }

    // MARK: - Gestures

    /// Taps the screen at `point`, in points.
    @MainActor
    private static func tap(_ point: CGPoint, in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
    }

    /// Drags `distance` points down, or up when it is negative, from `y`
    /// across the middle of the screen, and holds before it lets go so the
    /// content does not fling on.
    @MainActor
    private static func drag(by distance: CGFloat, from y: CGFloat, in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: y))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    // MARK: - Pixels

    /// The colors down a one-pixel column at `x`, from `top` to `bottom` in
    /// points, one per device pixel row, each with its y in points.
    @MainActor
    private static func column(
        atX x: CGFloat, from top: CGFloat, to bottom: CGFloat, in screenshot: XCUIScreenshot
    ) -> [(y: CGFloat, color: UITestNavigation.RGB)] {
        let scale = screenshot.image.scale
        guard bottom > top,
              let cut = UITestNavigation.pixels(in: CGRect(x: x, y: top, width: 1 / scale, height: bottom - top), of: screenshot)
        else { return [] }
        let width = Int(cut.frame.width)
        return (0..<Int(cut.frame.height)).map { row in
            let i = row * width * 4
            return ((cut.frame.minY + CGFloat(row)) / scale,
                    UITestNavigation.RGB(red: Int(cut.bytes[i]), green: Int(cut.bytes[i + 1]), blue: Int(cut.bytes[i + 2])))
        }
    }

    /// The colors along a one-pixel row at `y`, from `left` to `right` in
    /// points, one per device pixel, each with its x in points.
    @MainActor
    private static func row(
        atY y: CGFloat, from left: CGFloat, to right: CGFloat, in screenshot: XCUIScreenshot
    ) -> [(x: CGFloat, color: UITestNavigation.RGB)] {
        let scale = screenshot.image.scale
        guard right > left,
              let cut = UITestNavigation.pixels(in: CGRect(x: left, y: y, width: right - left, height: 1 / scale), of: screenshot)
        else { return [] }
        return (0..<Int(cut.frame.width)).map { column in
            let i = column * 4
            return ((cut.frame.minX + CGFloat(column)) / scale,
                    UITestNavigation.RGB(red: Int(cut.bytes[i]), green: Int(cut.bytes[i + 1]), blue: Int(cut.bytes[i + 2])))
        }
    }

    /// Ink, or as dark as an antialiased ink edge.
    private static func isInk(_ color: UITestNavigation.RGB) -> Bool {
        color.distance(to: ink) <= 60
    }

    /// The top edge, in points, of the ink box drawn around `point`: going
    /// up from `point`, past any paper inside an outline, to the top of the
    /// first ink. Nil when no ink is within 40pt above it.
    @MainActor
    private static func drawnTop(at point: CGPoint, in screenshot: XCUIScreenshot) -> CGFloat? {
        let pixels = column(atX: point.x, from: point.y - 40, to: point.y, in: screenshot).reversed()
        var top: CGFloat?
        for pixel in pixels {
            if isInk(pixel.color) {
                top = pixel.y
            } else if top != nil {
                break
            }
        }
        return top
    }

    /// The drawn widths, in points, of a full row's four tally boxes in
    /// `frame`: the first line of pixels across it that shows four ink runs
    /// of one width, 2pt to 4.5pt apart. Nil when no line does.
    @MainActor
    private static func tallyBoxWidths(in frame: CGRect, of screenshot: XCUIScreenshot) -> [CGFloat]? {
        let scale = screenshot.image.scale
        for y in stride(from: frame.minY + 2, to: frame.maxY - 2, by: 1) {
            var runs: [(start: CGFloat, end: CGFloat)] = []
            for pixel in row(atY: y, from: frame.minX, to: frame.maxX, in: screenshot) where isInk(pixel.color) {
                if let last = runs.last, pixel.x - last.end <= 1 / scale + 0.01 {
                    runs[runs.count - 1].end = pixel.x
                } else {
                    runs.append((pixel.x, pixel.x))
                }
            }
            guard runs.count >= 4 else { continue }
            for start in 0...(runs.count - 4) {
                let four = runs[start..<(start + 4)]
                let widths = four.map { $0.end - $0.start + 1 / scale }
                let gaps = zip(four.dropLast(), four.dropFirst()).map { $1.start - $0.end - 1 / scale }
                if widths.min()! >= 6, widths.max()! - widths.min()! <= 1.5, gaps.allSatisfy({ (2...4.5).contains($0) }) {
                    return widths
                }
            }
        }
        return nil
    }
}
