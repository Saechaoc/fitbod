//
//  RampAndStripsAX3UITests.swift
//  fitbodUITests
//
//  T28, review items 10, 11 and 25. At AX3 the warm-up ramp broke apart:
//  its set labels wrapped as "W" over "1" in their 36pt column, weights
//  broke as "9" over "0", and the plate text broke as "10+10+2" over
//  ".5". The History and workout summary stat strips kept three columns
//  and broke "SESSI" over "ONS" and "4,23" over "0". In VoiceOver the
//  bar-only ramp row read "Plates: ." and showed no plate text, and the
//  last row read "1 reps".
//
//  The ramp is the demo seed's bench press: 100 lb of work, so W1 is the
//  45 lb bar, then 60, 75 and 90 lb. History holds the seed's finished
//  Push A, which also opens the workout summary.
//
//  XCUITest lists a ramp row's texts and plate drawing under the row,
//  though VoiceOver reads the row as one element, so VoiceOver's reading
//  is checked with real VoiceOver (XCUIVoiceOverService, iOS 27). The
//  W labels are also measured from the screenshot: each is the only
//  signal-orange text in its row, so its drawn box shows a wrap or "•••".
//

import XCTest

final class RampAndStripsAX3UITests: XCTestCase {

    override func setUpWithError() throws {
        // Every check runs, so one broken part does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Ramp at AX3

    /// At AX3 each row's W label is one line, drawn whole, and its plate
    /// text reads in full on one line: "BAR" on the bar-only row.
    @MainActor
    func testRampSetLabelsAndPlateTextStayWholeAtAX3() throws {
        let app = openWorkout(textSize: .ax3)
        let rows = rampRows(in: app)

        for (index, row) in rows.enumerated() {
            let name = "W\(index + 1)"
            UITestNavigation.revealInLogger(row, in: app)
            if index == 0 { UITestNavigation.saveScreenshot("T28", "ramp", textSize: .ax3) }
            if index == rows.count - 1 { UITestNavigation.saveScreenshot("T28", "ramp-end", textSize: .ax3) }
            let screenshot = XCUIScreen.main.screenshot()

            UITestNavigation.assertNotTallerThanWide(row.staticTexts[name])
            if let label = drawnBox(of: .signal, in: row.frame, of: screenshot) {
                XCTAssertGreaterThan(label.width, label.height,
                                     "\(name) drawn at \(label) must be one line, not W over \(index + 1)")
                XCTAssertGreaterThan(label.height, label.width / 3,
                                     "\(name) drawn at \(label) must show its letters, not •••")
            } else {
                XCTFail("\(name) draws no label in its row at \(row.frame)")
            }

            // Vision can read a row's columns as one line, so the plate
            // text only has to end a line.
            let plates = Self.plateTexts[index]
            let lines = try UITestNavigation.textLines(in: row.frame, of: screenshot)
                .map { $0.text.replacingOccurrences(of: " ", with: "").uppercased() }
            XCTAssertTrue(lines.contains { $0.hasSuffix(plates) },
                          "\(name)'s plate text must read \"\(plates)\" on one line; the row reads \(lines)")
        }
    }

    /// At AX3 each ramp row's label reads the set's name, its weight and
    /// unit, its reps counted with the plural helper, and its plates per
    /// side or "bar only".
    @MainActor
    func testRampRowLabelsAtAX3() throws {
        let app = openWorkout(textSize: .ax3)
        let rows = rampRows(in: app)

        for (index, row) in rows.enumerated() {
            let name = "Warm-up set \(index + 1)"
            let label = row.label
            XCTAssertEqual(elements(labeledBeginningWith: name + ":", in: app).count, 1,
                           "\(name) must be one element")
            XCTAssertNotNil(label.range(of: #"^Warm-up set \#(index + 1): \d+(\.\d+)? (lb|kg) "#, options: .regularExpression),
                            "\(name) must read its weight with its unit: \(label)")
            XCTAssertFalse(label.contains("1 reps"), "\(name) must count one rep as \"1 rep\": \(label)")
            XCTAssertNotNil(label.range(of: #" (1 rep|([02-9]|\d{2,}) reps) "#, options: .regularExpression),
                            "\(name) must read its reps: \(label)")
            XCTAssertFalse(label.contains("Plates: ."), "\(name) must not read an empty plate list: \(label)")
        }

        let barOnly = rows[0].label
        XCTAssertTrue(barOnly.localizedCaseInsensitiveContains("bar only"),
                      "The bar-only row must say \"bar only\": \(barOnly)")
        XCTAssertTrue(rows[3].label.contains(" 1 rep "), "W4 is one rep: \(rows[3].label)")
        XCTAssertTrue(rows[3].label.contains("10, 10, 2.5"),
                      "W4 must read its plates per side: \(rows[3].label)")
    }

    /// Real VoiceOver reads each ramp row once, as its label, and never
    /// stops on the plate drawing inside a row.
    @MainActor
    func testVoiceOverReadsEachRampRowOnce() throws {
        #if compiler(>=6.4)
        guard #available(iOS 27.0, *) else { throw XCTSkip("Driving VoiceOver needs iOS 27") }
        let app = openWorkout(textSize: .ax3)
        _ = rampRows(in: app)
        let voiceOver = try startVoiceOver()
        var spoken: [String] = []
        for _ in 0..<60 {
            let utterance = try voiceOver.moveForward().utterance
            spoken.append(utterance)
            if utterance.localizedCaseInsensitiveContains("Skip all warm-up sets") { break }
        }
        try voiceOver.disable()
        XCTContext.runActivity(named: "VoiceOver read: \(spoken.joined(separator: " | "))") { _ in }

        for set in 1...4 {
            let reads = spoken.filter { $0.contains("Warm-up set \(set):") }
            XCTAssertEqual(reads.count, 1, "VoiceOver must read warm-up set \(set) once, not \(reads.count) times: \(reads)")
        }
        let drawings = spoken.filter { $0.contains("Plates each side") || $0.contains("No plates loaded") }
        XCTAssertEqual(drawings, [], "VoiceOver must not stop on a ramp row's plate drawing")
        XCTAssertTrue(spoken.contains { $0.localizedCaseInsensitiveContains("Skip all warm-up sets") },
                      "VoiceOver must walk past the ramp to SKIP WARM-UPS: \(spoken)")
        #else
        throw XCTSkip("Driving VoiceOver needs Xcode 27's XCUIVoiceOverService")
        #endif
    }

    // MARK: - Strips at AX3

    /// At AX3 History's strip stacks its cells, and each value, label and
    /// caption draws on one line.
    @MainActor
    func testHistoryStripStacksAndReadsWholeAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: .ax3)
        openHistory(in: app)
        let cells = historyCells(in: app)
        UITestNavigation.saveScreenshot("T28", "history-strip", textSize: .ax3)

        assertReadWhole(cells)
        assertStacked(cells, in: app)
    }

    /// At AX3 the workout summary's strip stacks its cells, and each
    /// value and label draws on one line.
    @MainActor
    func testSummaryStripStacksAndReadsWholeAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: .ax3)
        openHistory(in: app)
        openSummary(in: app)
        let cells = summaryCells(in: app)
        UITestNavigation.saveScreenshot("T28", "summary-strip", textSize: .ax3)

        assertReadWhole(cells)
        assertStacked(cells, in: app)
    }

    // MARK: - Default text keeps today's look

    /// At default text each ramp row stays one row: the W label in its
    /// 36pt column, level with the weight, reps and plates beside it.
    @MainActor
    func testRampKeepsItsRowsAtDefaultText() throws {
        let app = openWorkout(textSize: .default)
        let rows = rampRows(in: app)
        let column = app.windows.firstMatch.frame.minX + 16 + 36

        for (index, row) in rows.enumerated() {
            let name = "W\(index + 1)"
            UITestNavigation.revealInLogger(row, in: app)
            if index == 0 { UITestNavigation.saveScreenshot("T28", "ramp", textSize: .default) }
            let screenshot = XCUIScreen.main.screenshot()
            let frame = row.frame

            XCTAssertLessThanOrEqual(frame.height, Self.defaultRowHeight,
                                     "\(name)'s row at \(frame) must stay one row")
            guard let label = drawnBox(of: .signal, in: frame, of: screenshot) else {
                XCTFail("\(name) draws no label in its row at \(frame)")
                continue
            }
            XCTAssertGreaterThan(label.width, label.height, "\(name) drawn at \(label) must be one line")
            XCTAssertLessThanOrEqual(label.maxX, column, "\(name) drawn at \(label) must stay in its 36pt column")
            XCTAssertEqual(label.midY, frame.midY, accuracy: 4,
                           "\(name) drawn at \(label) must sit level with the row's weight and plates")
        }
    }

    /// At default text History's strip and the workout summary's strip
    /// keep their three columns, each value and label on one line.
    @MainActor
    func testStripsKeepTheirColumnsAtDefaultText() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: .default)
        openHistory(in: app)
        let history = historyCells(in: app)
        UITestNavigation.saveScreenshot("T28", "history-strip", textSize: .default)
        assertReadWhole(history)
        assertSideBySide(history)

        openSummary(in: app)
        let summary = summaryCells(in: app)
        UITestNavigation.saveScreenshot("T28", "summary-strip", textSize: .default)
        assertReadWhole(summary)
        assertSideBySide(summary)
    }

    // MARK: - Seed

    /// The plate text of W1 to W4: the bar alone, then the plates per
    /// side for 60, 75 and 90 lb on a 45 lb bar.
    private static let plateTexts = ["BAR", "5+2.5", "10+5", "10+10+2.5"]

    /// The most a ramp row measures at default text: a 22pt weight over
    /// its reps, with 10pt of padding above and below. Stacked, a row is
    /// three lines.
    private static let defaultRowHeight: CGFloat = 70

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

    /// Opens History from Today's Sessions cell.
    @MainActor
    private func openHistory(in app: XCUIApplication) {
        let sessions = app.buttons["today.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 10), "Today must show its Sessions cell")
        UITestNavigation.reveal(sessions, in: app)
        sessions.tap()
        XCTAssertTrue(readout("Sessions in the last 30 days", in: app).waitForExistence(timeout: 10),
                      "History never opened")
    }

    /// Opens the summary of History's one finished workout.
    @MainActor
    private func openSummary(in app: XCUIApplication) {
        let row = app.buttons.matching(identifier: "history.row").firstMatch
        UITestNavigation.reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.staticTexts["WORKOUT COMPLETE"].waitForExistence(timeout: 10), "The summary never opened")
    }

    #if compiler(>=6.4)
    /// Turns VoiceOver on until the test ends.
    @available(iOS 27.0, *)
    @MainActor
    private func startVoiceOver() throws -> XCUIVoiceOverService {
        let voiceOver = XCUIDevice.shared.voiceOverService
        addTeardownBlock { @MainActor in
            if voiceOver.isEnabled { try? voiceOver.disable() }
        }
        if !voiceOver.isEnabled { try voiceOver.enable() }
        return voiceOver
    }
    #endif

    // MARK: - Elements

    /// A stat strip cell, and the colors its value and labels draw in.
    private struct Cell {
        let element: XCUIElement
        let value: TextColor
        /// Its label, and the caption under its value when it has one.
        let mutedLines: Int
    }

    /// The ramp's rows, W1 to W4. Each is one accessibility element.
    @MainActor
    private func rampRows(in app: XCUIApplication) -> [XCUIElement] {
        let rows = (1...4).map { elements(labeledBeginningWith: "Warm-up set \($0):", in: app).firstMatch }
        XCTAssertTrue(rows[0].waitForExistence(timeout: 10), "The bench press must show its warm-up ramp")
        for (index, row) in rows.enumerated() {
            XCTAssertTrue(row.exists, "Missing ramp row W\(index + 1)")
        }
        return rows
    }

    /// History's strip: sessions, tonnage in signal orange, and sessions
    /// per week, each with a caption under its value.
    @MainActor
    private func historyCells(in app: XCUIApplication) -> [Cell] {
        cells([
            ("Sessions in the last 30 days", .ink),
            ("Tonnage in the last 30 days, pounds", .signalText),
            ("Sessions per week, last 4 weeks", .ink),
        ], mutedLines: 2, in: app)
    }

    /// The summary's strip: duration, working sets and volume.
    @MainActor
    private func summaryCells(in app: XCUIApplication) -> [Cell] {
        cells([("Duration", .ink), ("Sets", .ink), ("Volume · lb", .ink)], mutedLines: 1, in: app)
    }

    /// The strip's cells, scrolled to show whole between the header and
    /// the tab bar, so one screenshot holds every pixel they draw.
    @MainActor
    private func cells(_ readouts: [(label: String, value: TextColor)], mutedLines: Int, in app: XCUIApplication) -> [Cell] {
        let cells = readouts.map { Cell(element: readout($0.label, in: app), value: $0.value, mutedLines: mutedLines) }
        for cell in cells {
            XCTAssertTrue(cell.element.waitForExistence(timeout: 10), "Missing stat cell: \(cell.element)")
        }
        revealWhole(cells.map(\.element), in: app)
        return cells
    }

    /// Drags a pushed screen until `elements` show whole between its
    /// header and the tab bar. The Back button's hit area reaches below
    /// the header, so content that cannot move further down is already
    /// at the top of the page, under the header.
    @MainActor
    private func revealWhole(_ elements: [XCUIElement], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let top = app.buttons["Back"].firstMatch.frame.maxY + 4
        let bottom = UITestNavigation.tab("Today", in: app).frame.minY - 4
        var previous: CGRect?
        for _ in 0..<8 {
            let span = elements.map(\.frame).reduce(CGRect.null) { $0.union($1) }
            if span.maxY <= bottom && span.minY >= top { return }
            if span.maxY <= bottom, let previous, abs(previous.minY - span.minY) < 0.5 { return }
            previous = span
            // Aim for the middle of the band. A frame cut off at the scroll
            // view's edge reads short, and a drag under 40pt may not scroll.
            let distance = (top + bottom) / 2 - span.midY
            let drag = distance > 0 ? min(300, max(40, distance)) : max(-300, min(-40, distance))
            let startY = drag > 0 ? top + 20 : bottom - 20
            UITestNavigation.dragLogger(from: startY, to: startY + drag, in: app)
        }
        XCTFail("The strip must show whole between the header at \(top) and the tab bar at \(bottom)", file: file, line: line)
    }

    @MainActor
    private func readout(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    @MainActor
    private func elements(labeledBeginningWith prefix: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
    }

    // MARK: - Checks

    /// Each cell draws its value on one line, and its label and caption
    /// each on one line.
    @MainActor
    private func assertReadWhole(_ cells: [Cell], file: StaticString = #filePath, line: UInt = #line) {
        let screenshot = XCUIScreen.main.screenshot()
        for cell in cells {
            let name = "\"\(cell.element.label)\" at \(cell.element.frame)"
            XCTAssertEqual(drawnLines(of: cell.value, in: cell.element.frame, of: screenshot), 1,
                           "\(name) must draw its value \"\(cell.element.value as? String ?? "")\" on one line",
                           file: file, line: line)
            XCTAssertEqual(drawnLines(of: .muted, in: cell.element.frame, of: screenshot), cell.mutedLines,
                           "\(name) must draw its label and caption each on one line", file: file, line: line)
        }
    }

    /// At accessibility sizes the cells stack, each the strip's width.
    @MainActor
    private func assertStacked(_ cells: [Cell], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for (above, below) in zip(cells, cells.dropFirst()) {
            XCTAssertGreaterThanOrEqual(below.element.frame.minY, above.element.frame.maxY,
                                        "\"\(below.element.label)\" must sit under \"\(above.element.label)\"",
                                        file: file, line: line)
            XCTAssertEqual(below.element.frame.minX, above.element.frame.minX, accuracy: 0.5,
                           "Stacked cells share their leading edge", file: file, line: line)
        }
        for cell in cells {
            UITestNavigation.assertInside(cell.element, app.windows.firstMatch, file: file, line: line)
        }
    }

    /// At default text the cells share one row, left to right.
    @MainActor
    private func assertSideBySide(_ cells: [Cell], file: StaticString = #filePath, line: UInt = #line) {
        for (left, right) in zip(cells, cells.dropFirst()) {
            XCTAssertEqual(right.element.frame.minY, left.element.frame.minY, accuracy: 0.5,
                           "\"\(right.element.label)\" must share a row with \"\(left.element.label)\"",
                           file: file, line: line)
            XCTAssertLessThan(left.element.frame.maxX, right.element.frame.minX,
                              "\"\(left.element.label)\" comes before \"\(right.element.label)\"", file: file, line: line)
        }
    }

    // MARK: - Pixels

    /// Light-mode text colors, told apart by their pixels. Antialiasing
    /// blends a glyph's edge into the paper, so each color also takes its
    /// blends part of the way to paper.
    private enum TextColor {
        /// bruSignal #FF5C1A: the ramp's W labels.
        case signal
        /// bruInk #0A0A0A: stat values.
        case ink
        /// bruSignalText #C03700: History's tonnage.
        case signalText
        /// bruMuted #69655C: stat labels and captions. It is warmer than
        /// the grays ink blends into on paper.
        case muted

        func matches(red: Int, green: Int, blue: Int) -> Bool {
            switch self {
            case .signal: red >= 220 && green <= 160 && blue <= 120 && red - green >= 80
            case .ink: max(red, green, blue) <= 70
            case .signalText: (150...230).contains(red) && green <= 110 && blue <= 80 && red - green >= 80
            case .muted: (80...180).contains(red) && abs(red - green) <= 10 && red - blue >= 8
            }
        }
    }

    /// The box, in screen points, around the pixels of `color` inside
    /// `rect`, or nil when it draws none there.
    @MainActor
    private func drawnBox(of color: TextColor, in rect: CGRect, of screenshot: XCUIScreenshot) -> CGRect? {
        guard let cut = UITestNavigation.pixels(in: rect, of: screenshot) else { return nil }
        let width = Int(cut.frame.width)
        var box: (minX: Int, minY: Int, maxX: Int, maxY: Int)?
        for row in 0..<Int(cut.frame.height) {
            for column in 0..<width where matches(color, cut.bytes, at: row * width + column) {
                box = (min(box?.minX ?? column, column), box?.minY ?? row,
                       max(box?.maxX ?? column, column), row)
            }
        }
        guard let box else { return nil }
        let scale = screenshot.image.scale
        return CGRect(x: (cut.frame.minX + CGFloat(box.minX)) / scale, y: (cut.frame.minY + CGFloat(box.minY)) / scale,
                      width: CGFloat(box.maxX - box.minX + 1) / scale, height: CGFloat(box.maxY - box.minY + 1) / scale)
    }

    /// How many lines of `color` text draw inside `rect`: the runs of
    /// pixel rows that hold at least two pixels of it.
    @MainActor
    private func drawnLines(of color: TextColor, in rect: CGRect, of screenshot: XCUIScreenshot) -> Int {
        guard let cut = UITestNavigation.pixels(in: rect, of: screenshot) else { return 0 }
        let width = Int(cut.frame.width)
        var lines = 0
        var previousRowDraws = false
        for row in 0..<Int(cut.frame.height) {
            let rowDraws = (0..<width).lazy.filter { self.matches(color, cut.bytes, at: row * width + $0) }.prefix(2).count == 2
            if rowDraws && !previousRowDraws { lines += 1 }
            previousRowDraws = rowDraws
        }
        return lines
    }

    private func matches(_ color: TextColor, _ bytes: [UInt8], at pixel: Int) -> Bool {
        color.matches(red: Int(bytes[pixel * 4]), green: Int(bytes[pixel * 4 + 1]), blue: Int(bytes[pixel * 4 + 2]))
    }
}
