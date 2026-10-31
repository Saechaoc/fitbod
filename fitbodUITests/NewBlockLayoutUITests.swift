//
//  NewBlockLayoutUITests.swift
//  fitbodUITests
//
//  Ticket T25. Review items 37 and 46. On the 390pt phone New Block breaks
//  no word in the middle, at default text or at AX3, and at AX3 it cuts off
//  no control label or section head. At accessibility sizes the top bar puts
//  its title on a line of its own, under the back and save actions, and the
//  chart's labels never overlap.
//
//  Ticket T105, findings F191 and F194. A drag moved a phase card a slot
//  for each fixed 110pt of a reading that took about half the finger's
//  travel, so at default text, where a card is 68pt tall, a drag of one
//  card left it in place; at AX3 the two happened to cancel out. The card
//  now follows the finger and steps by the cards' measured heights. And no
//  test pinned the chart's middle label step, Program's short labels such
//  as "ACCUM".
//

import XCTest

final class NewBlockLayoutUITests: XCTestCase {
    // The tests and helpers are @MainActor because XCUIApplication is
    // main-actor isolated.

    /// Every label the chart can write on a phase band: today's
    /// abbreviations, and the short labels Program's rows use.
    private static let phaseLabels = [
        "ACCUM.", "INTENS.", "PEAK", "REAL.", "DELOAD",
        "ACCUM", "INTNS", "REAL",
    ]

    /// The blank block's phase cards, and the words each one shows.
    private static let blankPhaseCards = [
        ("Phase 1:", "01 Accumulation BUILD VOLUME WEEKS VOL +20% INT 70%"),
        ("Phase 2:", "02 Intensification BUILD STRENGTH WEEKS VOL HOLD INT 85%"),
        ("Phase 3:", "03 Deload RECOVER WEEKS VOL -50% INT 60%"),
    ]

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Default text

    /// On the small phone the chart card's head shared one line with its
    /// legend, so "PROGRESSION OVERVIEW" wrapped onto two lines and
    /// "INTENSITY" broke into "INTEN" over "SITY". Each is one line tall,
    /// the chart still names its phases and labels every week, and CANCEL
    /// takes a 44pt tap.
    @MainActor
    func testChartHeadAndLegendStayOnOneLineAtDefaultText() throws {
        let app = openNewBlock(textSize: .default)
        let head = app.staticTexts.labeled("PROGRESSION OVERVIEW")
        let legend = ["VOLUME", "INTENSITY"].map { app.staticTexts.labeled($0) }
        XCTAssertTrue(head.waitForExistence(timeout: 10), "New Block must show the progression chart")
        UITestNavigation.saveScreenshot("T25", "new-block", textSize: .default)

        // DAYS PER WEEK wears the head's font and HIGH the legend's, and
        // neither can wrap, so each is one line of its font.
        let headLine = app.staticTexts.labeled("DAYS PER WEEK").frame.height
        let legendLine = app.staticTexts.labeled("HIGH").frame.height
        var problems = [UITestNavigation.heightProblem(head, atMost: headLine + 1)]
        problems += legend.map { UITestNavigation.heightProblem($0, atMost: legendLine + 1) }
        problems += chartLabelOverlaps(in: app)
        let labels = phaseLabels(in: app).map(\.label)
        if labels != ["ACCUM.", "INTENS.", "DELOAD"] {
            problems.append("The chart must name its three phases as it does today, and it shows \(labels)")
        }
        problems += try weekAxisProblems(weeks: 5, in: app)
        problems += barProblems(in: app)
        XCTAssertEqual(problems.compactMap { $0 }, [])
    }

    /// At default text the rest of New Block keeps every word whole too.
    @MainActor
    func testEveryWordStaysWholeAtDefaultText() throws {
        let app = openNewBlock(textSize: .default)
        XCTAssertEqual(try sweepProblems(in: app, textSize: .default).compactMap { $0 }, [])
    }

    // MARK: - AX3

    /// At AX3 the top bar kept one row, so it read "< PRO…", "NEW B…" and
    /// "SAVE…". The title takes a line of its own under the back and save
    /// actions, and no label in the bar overlaps another or is cut off.
    @MainActor
    func testTopBarGivesTheTitleItsOwnLineAtAX3() throws {
        let app = openNewBlock(textSize: .ax3)
        let back = app.buttons.labeled("< PROGRAM")
        let title = app.staticTexts.labeled("NEW BLOCK")
        let save = app.buttons.labeled("SAVE DRAFT")
        UITestNavigation.saveScreenshot("T25", "new-block-top", textSize: .ax3)

        var problems = [
            UITestNavigation.overlapProblem(back, title),
            UITestNavigation.overlapProblem(title, save),
            UITestNavigation.overlapProblem(back, save),
            UITestNavigation.tapTargetProblem(back),
            UITestNavigation.tapTargetProblem(save),
            // Each action is one line, as tall as the other.
            UITestNavigation.heightProblem(save, atMost: back.frame.height + 1),
        ]
        let actionsBottom = max(back.frame.maxY, save.frame.maxY)
        if title.frame.minY < actionsBottom - 0.5 {
            problems.append("The title starts at y \(title.frame.minY), beside the actions, which end at y \(actionsBottom)")
        }
        problems += try wordProblems([back, title, save])
        XCTAssertEqual(problems.compactMap { $0 }, [])
    }

    /// At AX3 the legend's chips got so little width that their letters
    /// stacked one per line, and the bottom bar cut its labels off. The
    /// legend wraps between its chips, each word shows whole, and the week
    /// axis keeps the last week's label.
    @MainActor
    func testLegendAndBottomBarStayWholeAtAX3() throws {
        let app = openNewBlock(textSize: .ax3)
        var problems = barProblems(in: app)
        problems += try wordProblems([cancel(in: app), primary("NAME FIRST", in: app)])

        revealChart(in: app)
        UITestNavigation.saveScreenshot("T25", "new-block-chart", textSize: .ax3)
        let head = app.staticTexts.labeled("PROGRESSION OVERVIEW")
        let volume = app.staticTexts.labeled("VOLUME")
        let intensity = app.staticTexts.labeled("INTENSITY")
        problems += [
            UITestNavigation.tallerThanWideProblem(volume),
            UITestNavigation.tallerThanWideProblem(intensity),
            UITestNavigation.overlapProblem(volume, intensity),
            UITestNavigation.overlapProblem(head, volume),
            UITestNavigation.overlapProblem(head, intensity),
        ]
        problems += try wordProblems([head, volume, intensity])
        problems += chartLabelOverlaps(in: app)
        problems += try wordProblems(phaseLabels(in: app))
        problems += try weekAxisProblems(weeks: 5, in: app)
        XCTAssertEqual(problems.compactMap { $0 }, [])
    }

    /// At AX3 the chart wrote each phase's label at a fixed point, so the
    /// labels of Generic Strength Meso's one-week phases ran into each
    /// other, and its week axis dropped W8. No two of the chart's labels
    /// overlap, each shows whole, and the axis keeps the last week.
    @MainActor
    func testChartLabelsNeverOverlapAtAX3() throws {
        let app = openNewBlock(preset: "GENERIC STRENGTH MESO", textSize: .ax3)
        var problems = try wordProblems([primary("PICK A ROUTINE", in: app)])
        revealChart(in: app)
        UITestNavigation.saveScreenshot("T25", "new-block-chart-generic", textSize: .ax3)

        problems += chartLabelOverlaps(in: app)
        problems += try wordProblems(phaseLabels(in: app))
        problems += try weekAxisProblems(weeks: 8, in: app)
        XCTAssertEqual(problems.compactMap { $0 }, [])
    }

    /// At AX3 the name, the phase cards and the Routine band broke words
    /// or cut them off: "NAME YOUR B…", "W" over "EE" over "KS", "Accu…",
    /// and chips whose letters stacked. Every word shows whole, and the
    /// band's chips and days stay 44pt tap targets apart from each other.
    @MainActor
    func testEveryWordStaysWholeAtAX3() throws {
        let app = openNewBlock(textSize: .ax3)
        XCTAssertEqual(try sweepProblems(in: app, textSize: .ax3).compactMap { $0 }, [])
    }

    /// At AX3 the duration sheet cut its rows to "… Accumulat…", and the
    /// phase editor cut its values to "+…" and "7…". Each sheet shows every
    /// word whole, and each of its steppers is a 44pt tap target.
    @MainActor
    func testSheetsShowEveryWordWholeAtAX3() throws {
        let app = openNewBlock(textSize: .ax3)
        XCTAssertEqual(try sheetProblems(in: app, textSize: .ax3).compactMap { $0 }, [])
    }

    // MARK: - Phase reorder

    /// A drag reordered phase cards by a fixed 110pt step, measured in a
    /// space that moved with the lifted card, so the card took about half
    /// the finger's travel, and at default text, where a card is 68pt tall,
    /// a drag of one card left it where it was. The card follows the finger
    /// and lands on the slot whose midpoint its center has crossed: a drag
    /// of one card moves it one slot, and a drag of under half a card moves
    /// it none.
    @MainActor
    func testDragLandsOnTheSlotUnderTheFingerAtDefaultText() throws {
        let app = openNewBlock(textSize: .default)
        // Blank Block's phases: Accumulation, Intensification and Deload.
        dragPhaseCard(1, downBy: 1, in: app)
        let second = app.buttons.labeled("Phase 2: Accumulation")
        XCTAssertTrue(second.exists || second.waitForExistence(timeout: 5),
                      "Dragged down by one card, Accumulation must land second, and the cards read \(phaseOrder(in: app))")
        UITestNavigation.saveScreenshot("T105", "drag-one-card")

        let order = phaseOrder(in: app)
        dragPhaseCard(1, downBy: 0.4, in: app)
        XCTAssertEqual(phaseOrder(in: app), order, "Dragged down by under half a card, a card must stay in its slot")
    }

    /// At AX3, where a card is about 200pt tall, the first of three cards
    /// dragged down by two cards lands third. It did before T105 too: the
    /// half-speed drag and the 110pt step happened to cancel out at AX3.
    @MainActor
    func testDragLandsOnTheSlotUnderTheFingerAtAX3() throws {
        let app = openNewBlock(textSize: .ax3)
        // Blank Block's phases: Accumulation, Intensification and Deload.
        dragPhaseCard(1, downBy: 2, in: app)
        let third = app.buttons.labeled("Phase 3: Accumulation")
        XCTAssertTrue(third.exists || third.waitForExistence(timeout: 5),
                      "Dragged down by two cards, Accumulation must land third, and the cards read \(phaseOrder(in: app))")
        UITestNavigation.saveScreenshot("T105", "drag-two-cards", textSize: .ax3)
    }

    // MARK: - Phase label steps

    /// The chart writes today's abbreviations on its phase bands while they
    /// fit, then Program's short labels, and only then none, and no test
    /// pinned that middle step. Narrowed a week at a time, Intensification's
    /// one-week band gives up "INTENS.", and the chart writes "ACCUM",
    /// "INTNS" and "DELOAD" before it drops its labels.
    @MainActor
    func testChartFallsBackToProgramsShortLabels() throws {
        let app = openNewBlock(textSize: .default)
        // Blank Block runs Accumulation 2 weeks, Intensification 2 and
        // Deload 1. Intensification drops to one week, and Deload goes to two
        // so its band keeps "DELOAD" as the block grows.
        let sheet = openDurationSheet(in: app)
        tapWeeks("\u{2212}", of: "Intensification", in: sheet)
        tapWeeks("+", of: "Deload", in: sheet)
        let abbreviations = ["ACCUM.", "INTENS.", "DELOAD"]
        XCTAssertEqual(phaseLabels(in: app).map(\.label), abbreviations, "A five-week block must write today's abbreviations")

        // Each week Accumulation gains narrows Intensification's band. The
        // chart sits under the sheet, where XCUITest still reads its labels.
        var labels = abbreviations
        for _ in 0..<8 where labels == abbreviations {
            tapWeeks("+", of: "Accumulation", in: sheet)
            labels = phaseLabels(in: app).map(\.label)
        }
        UITestNavigation.hittable(sheet.buttons, "Done").tap()
        XCTAssertTrue(app.staticTexts.labeled("Edit Block Duration").waitForNonExistence(timeout: 5), "Done must close the duration sheet")
        revealChart(in: app)
        UITestNavigation.saveScreenshot("T105", "chart-short-labels")
        XCTAssertEqual(labels, ["ACCUM", "INTNS", "DELOAD"],
                       "Once \"INTENS.\" no longer fits its band, the chart must write Program's short labels before it drops them")
        XCTAssertEqual(phaseLabels(in: app).map(\.label), labels, "The chart must keep its short labels once the sheet closes")
        XCTAssertEqual(chartLabelOverlaps(in: app).compactMap { $0 }, [])
    }

    // MARK: - Opening New Block

    /// Program → + NEW → + New block → Blank Block, or Use Preset and
    /// `preset`, at `textSize`, once New Block has finished sliding up.
    @MainActor
    private func openNewBlock(preset: String? = nil, textSize: UITestNavigation.TextSize) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        if let preset {
            UITestNavigation.hittable(app.buttons, "Use Preset").tap()
            let row = app.buttons.matching(NSPredicate(
                format: "label ==[c] %@ OR label BEGINSWITH[c] %@", preset, preset + ","
            )).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10), "CHOOSE PRESET must list \(preset)")
            UITestNavigation.reveal(row, in: app)
            row.tap()
        } else {
            UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        }
        let title = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(title.exists || title.waitForExistence(timeout: 10), "New Block never opened")
        UITestNavigation.waitUntilStill(cancel(in: app))
        return app
    }

    /// Scrolls New Block until the progression chart's card, from its head
    /// to its week labels, sits between the top and bottom bars.
    @MainActor
    private func revealChart(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let head = app.staticTexts.labeled("PROGRESSION OVERVIEW")
        XCTAssertTrue(head.exists || head.waitForExistence(timeout: 10), "New Block must show the progression chart",
                      file: file, line: line)
        let plot = plotArea(in: app)
        // The week labels take the 44pt under the plot.
        reveal({ CGRect(x: 0, y: head.frame.minY, width: 1, height: plot.frame.maxY + 44 - head.frame.minY) },
               named: "The chart card", in: app, file: file, line: line)
    }

    /// Scrolls New Block until `element` sits between the top and bottom bars.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 10), "Missing \(element)", file: file, line: line)
        reveal({ element.frame }, named: "\(element)", in: app, file: file, line: line)
    }

    /// Scrolls New Block until the span `frame` returns sits between the
    /// top bar and the bottom bar, the way a lifter scrolls to it. Each drag
    /// is short and runs in a side margin, clear of the phase cards' swipe
    /// gesture; a drag that leaves the page where it was is tried again in
    /// the other margin.
    @MainActor
    private func reveal(
        _ frame: () -> CGRect, named name: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let topBar = [app.buttons.labeled("< PROGRAM"), app.staticTexts.labeled("NEW BLOCK"), app.buttons.labeled("SAVE DRAFT")]
        let window = app.windows.firstMatch
        var margin: CGFloat = 8
        for _ in 0..<16 {
            let top = topBar.map(\.frame.maxY).max() ?? 0
            // The bottom bar's buttons sit 24pt below its top edge, and
            // CANCEL's middle is 50pt below it.
            let bottom = cancel(in: app).frame.midY - 50
            let span = frame()
            if span.minY >= top && span.maxY <= bottom { return }
            let distance = (top + bottom - span.minY - span.maxY) / 2
            let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: margin, dy: (top + bottom) / 2))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: max(-150, min(150, distance)))),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
            Thread.sleep(forTimeInterval: 0.5)
            if abs(frame().minY - span.minY) < 1 {
                margin = margin < 100 ? window.frame.width - 8 : 8
            }
        }
        XCTFail("\(name) must scroll between New Block's bars", file: file, line: line)
    }

    // MARK: - Elements

    @MainActor
    private func cancel(in app: XCUIApplication) -> XCUIElement {
        UITestNavigation.hittable(app.buttons, "CANCEL")
    }

    @MainActor
    private func primary(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons.labeled(label)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "The bottom bar must read \(label)")
        return button
    }

    /// The phase card numbered `number`, such as "Phase 1: Accumulation".
    @MainActor
    private func phaseCard(_ number: Int, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Phase \(number):")).firstMatch
    }

    /// The phase cards' labels, top to bottom.
    @MainActor
    private func phaseOrder(in app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Phase ")).allElementsBoundByIndex
            .sorted { $0.frame.minY < $1.frame.minY }
            .map(\.label)
    }

    /// Long-presses the ⋮⋮ handle of the phase card numbered `number` and
    /// drags it down by `slots` cards: until the card's bottom edge reaches
    /// the bottom edge of the card that many below it, or that share of the
    /// way to the next card's. The page must hold still under the drag.
    @MainActor
    private func dragPhaseCard(
        _ number: Int, downBy slots: CGFloat, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let passed = Int(slots.rounded(.up))
        let card = phaseCard(number, in: app)
        let target = phaseCard(number + passed, in: app)
        XCTAssertTrue((card.exists || card.waitForExistence(timeout: 5)) && (target.exists || target.waitForExistence(timeout: 5)),
                      "New Block must have phases \(number) and \(number + passed)", file: file, line: line)
        // XCUITest lists the handle under the card, though VoiceOver skips it.
        let handle = card.staticTexts.labeled("⋮⋮")
        XCTAssertTrue(handle.exists, "Phase \(number)'s card must show its ⋮⋮ handle", file: file, line: line)
        let distance = (target.frame.maxY - card.frame.maxY) * slots / CGFloat(passed)
        scroll(handle, toDrag: distance, in: app, file: file, line: line)
        let head = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "PHASES · ")).firstMatch
        let pageTop = head.frame.minY
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.6, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                    withVelocity: .default, thenHoldForDuration: 0.3)
        XCTAssertEqual(head.frame.minY, pageTop, accuracy: 1, "The page must hold still while a card is dragged",
                       file: file, line: line)
    }

    /// Scrolls New Block until `handle` sits between the bars, high enough
    /// that a drag of `distance` from it ends on the screen, over the bottom
    /// bar if it must. Each scroll aims for the middle of that span, so it
    /// is a long drag in the leading margin: a short, slow drag beside a
    /// card can reach the card as a tap.
    @MainActor
    private func scroll(
        _ handle: XCUIElement, toDrag distance: CGFloat, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let topBar = [app.buttons.labeled("< PROGRAM"), app.staticTexts.labeled("NEW BLOCK"), app.buttons.labeled("SAVE DRAFT")]
        let top = topBar.map(\.frame.maxY).max() ?? 0
        // The bottom bar's buttons sit 24pt below its top edge, and CANCEL's
        // middle is 50pt below it.
        let bottomBar = cancel(in: app).frame.midY - 50
        let window = app.windows.firstMatch
        let half = handle.frame.height / 2
        let highest = top + half
        let lowest = min(bottomBar - half, window.frame.maxY - 10 - distance)
        for _ in 0..<6 {
            let middle = handle.frame.midY
            if middle >= highest && middle <= lowest { return }
            let move = max(-300, min(300, (highest + lowest) / 2 - middle))
            let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 8, dy: (top + bottomBar) / 2))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: move)),
                        withVelocity: .default, thenHoldForDuration: 0.3)
            UITestNavigation.waitUntilStill(handle)
        }
        XCTFail("The ⋮⋮ handle must scroll high enough for a \(distance)pt drag to end on the screen", file: file, line: line)
    }

    /// Opens TOTAL WEEKS' duration sheet and returns it.
    @MainActor
    private func openDurationSheet(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let total = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Total weeks, ")).firstMatch
        reveal(total, in: app, file: file, line: line)
        total.tap()
        let title = app.staticTexts.labeled("Edit Block Duration")
        XCTAssertTrue(title.exists || title.waitForExistence(timeout: 5),
                      "TOTAL WEEKS must open the duration sheet", file: file, line: line)
        return presentedSheet(in: app)
    }

    /// Taps `glyph`, "−" or "+", on `phase`'s row of the duration sheet.
    @MainActor
    private func tapWeeks(
        _ glyph: String, of phase: String, in sheet: XCUIElement,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let title = sheet.staticTexts.matching(NSPredicate(format: "label == %@", phase)).firstMatch
        let stepper = sheet.buttons.matching(NSPredicate(format: "label == %@", glyph)).allElementsBoundByIndex
            .min { abs($0.frame.midY - title.frame.midY) < abs($1.frame.midY - title.frame.midY) }
        XCTAssertNotNil(stepper, "The duration sheet must offer \(glyph) on \(phase)'s row", file: file, line: line)
        stepper?.tap()
    }

    /// The chart's plot: the invisible element a DEBUG build lays over it,
    /// because VoiceOver reads the chart's card as one element.
    @MainActor
    private func plotArea(in app: XCUIApplication) -> XCUIElement {
        let matches = app.descendants(matching: .any).matching(identifier: "newBlock.progression.plot")
        XCTAssertTrue(matches.firstMatch.exists || matches.firstMatch.waitForExistence(timeout: 10),
                      "New Block must show the progression chart")
        let sized = matches.allElementsBoundByIndex.filter { $0.frame.width > 0 && $0.frame.height > 0 }
        return sized.min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height } ?? matches.firstMatch
    }

    /// The labels the chart writes on its phase bands, left to right.
    @MainActor
    private func phaseLabels(in app: XCUIApplication) -> [XCUIElement] {
        app.staticTexts.matching(NSPredicate(format: "label IN %@", Self.phaseLabels))
            .allElementsBoundByIndex
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    /// Each pair of the chart's labels, its phase labels and its HIGH and
    /// LOW anchors, that overlap.
    @MainActor
    private func chartLabelOverlaps(in app: XCUIApplication) -> [String?] {
        let labels = phaseLabels(in: app) + ["HIGH", "LOW"].map { app.staticTexts.labeled($0) }.filter(\.exists)
        return labels.indices.flatMap { index in
            labels[(index + 1)...].map { UITestNavigation.overlapProblem(labels[index], $0) }
        }
    }

    /// The back control, SAVE DRAFT, CANCEL and the bottom action each take
    /// a 44pt tap, and the two bottom buttons sit apart.
    @MainActor
    private func barProblems(in app: XCUIApplication) -> [String?] {
        let back = app.buttons.labeled("< PROGRAM")
        let save = app.buttons.labeled("SAVE DRAFT")
        let cancel = cancel(in: app)
        let primary = primary("NAME FIRST", in: app)
        return [
            UITestNavigation.tapTargetProblem(back),
            UITestNavigation.tapTargetProblem(save),
            UITestNavigation.tapTargetProblem(cancel),
            UITestNavigation.tapTargetProblem(primary),
            UITestNavigation.overlapProblem(cancel, primary),
        ]
    }

    // MARK: - Week axis

    /// The week labels under the plot, unless they label every week, or a
    /// regular subset of weeks that ends on the last.
    @MainActor
    private func weekAxisProblems(weeks: Int, in app: XCUIApplication) throws -> [String?] {
        let labeled = try labeledWeeks(in: app)
        let steps = Set(zip(labeled, labeled.dropFirst()).map { $1 - $0 })
        let regular = steps.count <= 1 && (steps.first ?? 1) >= 1
        if labeled.last == weeks && regular { return [] }
        return ["The week axis must label every week, or a regular subset of them ending on W\(weeks), and it labels weeks \(labeled)"]
    }

    /// The weeks the axis labels, left to right, read from the screen: each
    /// run of ink in the row under the plot is one label, and Vision reads
    /// its number. Swift Charts drops a label that collides or runs past the
    /// plot, XCUI does not list axis labels, and Vision runs a whole row of
    /// small labels together, so each label is read by itself.
    @MainActor
    private func labeledWeeks(in app: XCUIApplication) throws -> [Int] {
        let plot = plotArea(in: app).frame
        // The labels sit under the plot, one line of HIGH's font tall,
        // inside the card's 16pt padding.
        let row = CGRect(x: plot.minX - 12, y: plot.maxY + 4, width: plot.width + 24,
                         height: app.staticTexts.labeled("HIGH").frame.height + 8)
        let screenshot = XCUIScreen.main.screenshot()
        guard let (pixels, bytes) = UITestNavigation.pixels(in: row, of: screenshot) else { return [] }
        let width = Int(pixels.width)
        let height = Int(pixels.height)
        let scale = pixels.width / row.width
        // The card's paper, from the row's first pixel.
        let paper = bytes[0..<3].map(Int.init)
        let inked = (0..<width).map { x in
            (0..<height).contains { y in
                let i = (y * width + x) * 4
                return (0..<3).reduce(0) { $0 + abs(Int(bytes[i + $1]) - paper[$1]) } > 60
            }
        }
        // A gap under 4pt is inside one label.
        var runs: [(start: Int, end: Int)] = []
        for x in 0..<width where inked[x] {
            if let last = runs.last, CGFloat(x - last.end) <= 4 * scale {
                runs[runs.count - 1].end = x
            } else {
                runs.append((x, x))
            }
        }
        return try runs.compactMap { run in
            let start = row.minX + CGFloat(run.start) / scale
            let end = row.minX + CGFloat(run.end + 1) / scale
            let label = CGRect(x: start - 4, y: row.minY, width: end - start + 8, height: row.height)
            return Int(try UITestNavigation.readText(in: label, of: screenshot).filter(\.isNumber))
        }
    }

    // MARK: - Words on screen

    /// Scrolls through New Block, from its name to the Routine band's days,
    /// opening its duration sheet and phase editor on the way, and returns
    /// each control, head, card or sheet row whose words do not all show
    /// whole, and each Routine band chip or day that is not a 44pt tap
    /// target apart from its neighbors. Saves a screenshot of each stop.
    @MainActor
    private func sweepProblems(in app: XCUIApplication, textSize: UITestNavigation.TextSize) throws -> [String?] {
        let element = { (label: String) in
            app.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
        }
        let named = { (prefix: String) in
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        }
        var problems = try screenProblems([
            (element("BLOCK NAME"), "BLOCK NAME"),
            (element("NAME YOUR BLOCK"), "NAME YOUR BLOCK"),
            (named("Total weeks, "), "TOTAL WEEKS 5"),
            (element("DAYS PER WEEK"), "DAYS PER WEEK"),
        ])
        UITestNavigation.saveScreenshot("T25", "new-block-name", textSize: textSize)
        // The sheets open from TOTAL WEEKS and the first phase card, which a
        // lazy page drops from the tree once scrolled far past them.
        problems += try sheetProblems(in: app, textSize: textSize)

        let header = [
            (element("PHASES · 3"), "PHASES · 3"),
            (element("Preset"), "PRESET ▾"),
            (element("+ ADD PHASE"), "+ ADD PHASE"),
        ]
        reveal(header[2].0, in: app)
        problems += try screenProblems(header)
        for (prefix, words) in Self.blankPhaseCards {
            let card = named(prefix)
            reveal(card, in: app)
            UITestNavigation.saveScreenshot("T25", "new-block-card-\(prefix.dropLast())", textSize: textSize)
            problems += try screenProblems([(card, words)])
        }

        let rotation = app.buttons.labeled("ROTATION scheduling")
        let fixedWeekly = app.buttons.labeled("FIXED WEEKLY scheduling")
        reveal(fixedWeekly, in: app)
        UITestNavigation.saveScreenshot("T25", "new-block-routine", textSize: textSize)
        let routines = app.staticTexts.matching(NSPredicate(format: "label == %@", "Routine")).allElementsBoundByIndex
        problems += try screenProblems(routines.map { ($0, "Routine") } + [
            (element("None — saves as draft"), "None — saves as draft"),
            (element("+ ATTACH ▸"), "+ ATTACH ▸"),
            (element("Scheduling"), "Scheduling"),
            (rotation, "ROTATION"),
            (fixedWeekly, "FIXED WEEKLY"),
        ])
        if textSize == .ax3 {
            problems += [
                UITestNavigation.tapTargetProblem(element("+ ATTACH ▸")),
                UITestNavigation.tapTargetProblem(rotation),
                UITestNavigation.tapTargetProblem(fixedWeekly),
            ]
        }
        problems.append(UITestNavigation.overlapProblem(rotation, fixedWeekly))

        fixedWeekly.tap()
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            .map { element($0) }
        reveal(days[6], in: app)
        UITestNavigation.saveScreenshot("T25", "new-block-days", textSize: textSize)
        if textSize == .ax3 {
            problems += days.map { UITestNavigation.tapTargetProblem($0) }
        }
        problems += zip(days, days.dropFirst()).map { UITestNavigation.overlapProblem($0, $1) }
        return problems
    }

    /// Opens TOTAL WEEKS' duration sheet and the first phase card's editor,
    /// and returns each of their rows whose words do not all show whole,
    /// and, at AX3, each stepper that is not a 44pt tap target. Saves a
    /// screenshot of each sheet.
    @MainActor
    private func sheetProblems(in app: XCUIApplication, textSize: UITestNavigation.TextSize) throws -> [String?] {
        let total = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Total weeks, ")).firstMatch
        reveal(total, in: app)
        total.tap()
        XCTAssertTrue(app.staticTexts.labeled("Edit Block Duration").waitForExistence(timeout: 5),
                      "TOTAL WEEKS must open the duration sheet")
        var sheet = presentedSheet(in: app)
        UITestNavigation.saveScreenshot("T25", "new-block-duration-sheet", textSize: textSize)
        let text = { (label: String) in sheet.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch }
        var problems = try screenProblems([
            (text("Edit Block Duration"), "Edit Block Duration"),
            (text("TOTAL"), "TOTAL"), (text("WKS"), "WKS"),
            (text("01"), "01"), (text("Accumulation"), "Accumulation"),
            (text("02"), "02"), (text("Intensification"), "Intensification"),
            (text("03"), "03"), (text("Deload"), "Deload"),
        ])
        problems += stepperProblems(in: sheet, textSize: textSize)
        UITestNavigation.hittable(sheet.buttons, "Done").tap()
        XCTAssertTrue(app.staticTexts.labeled("Edit Block Duration").waitForNonExistence(timeout: 5))

        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Phase 1:")).firstMatch
        reveal(card, in: app)
        card.tap()
        XCTAssertTrue(app.staticTexts.labeled("% of training max").waitForExistence(timeout: 5),
                      "A phase card must open its editor")
        sheet = presentedSheet(in: app)
        UITestNavigation.saveScreenshot("T25", "new-block-phase-editor", textSize: textSize)
        problems += try screenProblems([
            (text("Accumulation"), "Accumulation"),
            (text("WEEKS"), "WEEKS"),
            (text("VOLUME"), "VOLUME"), (text("vs base"), "vs base"), (text("+20%"), "+20%"),
            (text("INTENSITY"), "INTENSITY"), (text("% of training max"), "% of training max"), (text("70%"), "70%"),
        ])
        problems += stepperProblems(in: sheet, textSize: textSize)
        UITestNavigation.hittable(sheet.buttons, "Done").tap()
        XCTAssertTrue(app.staticTexts.labeled("% of training max").waitForNonExistence(timeout: 5))
        return problems
    }

    /// At AX3, each of the sheet's − and + steppers that is not a 44pt tap
    /// target; nothing at default text. The phase editor's steppers read by
    /// their stat, such as "Increase weeks".
    @MainActor
    private func stepperProblems(in sheet: XCUIElement, textSize: UITestNavigation.TextSize) -> [String?] {
        guard textSize == .ax3 else { return [] }
        return sheet.buttons.matching(NSPredicate(
            format: "label IN %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@", ["\u{2212}", "+"], "Decrease ", "Increase "
        )).allElementsBoundByIndex.map { UITestNavigation.tapTargetProblem($0) }
    }

    /// The half-height sheet on top, once it stops sliding up: the last
    /// layer's view that starts below the top of the screen. It floats above
    /// the bottom of the screen, so UITestNavigation.topSheet(in:), which
    /// looks for a sheet that reaches the bottom, does not find it.
    @MainActor
    private func presentedSheet(in app: XCUIApplication) -> XCUIElement {
        let layer = app.windows.firstMatch.children(matching: .other).allElementsBoundByIndex.last
        guard let sheet = layer?.children(matching: .other).allElementsBoundByIndex.first(where: { $0.frame.minY > 0.5 })
        else { return app }
        UITestNavigation.waitUntilStill(sheet)
        return sheet
    }

    /// Each element whose words do not all show whole on one line of the
    /// screen. XCUI reads the whole label however the text is cut off or
    /// wraps, so this reads the screen: a cut-off label loses letters, and
    /// a word broken across lines shows on two. Vision can read spaces into
    /// tracked capitals, so a line is compared without them.
    @MainActor
    private func wordProblems(_ elements: [XCUIElement]) throws -> [String?] {
        try screenProblems(elements.map { ($0, $0.label) })
    }

    /// Each element that does not show each of its words, from `words`,
    /// whole on one line of the screen.
    @MainActor
    private func screenProblems(_ checks: [(element: XCUIElement, words: String)]) throws -> [String?] {
        let screenshot = XCUIScreen.main.screenshot()
        return try checks.map { element, words in
            guard element.exists else { return "Missing element: \(element)" }
            let lines = try UITestNavigation.textLines(in: element.frame.insetBy(dx: -4, dy: -4), of: screenshot)
            let shown = lines.map { Self.letters($0.text) }
            // A one-letter word cannot break.
            let broken = words.split(separator: " ").map { Self.letters(String($0)) }
                .filter { word in word.count > 1 && !shown.contains { $0.contains(word) } }
            guard !broken.isEmpty else { return nil }
            return "\"\(element.label)\" does not show \(broken) whole: the screen reads \(lines.map(\.text))"
        }
    }

    /// Uppercased letters and digits only, with a "0" read as an "O".
    private static func letters(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.map { $0 == "0" ? "O" : $0 })
    }
}
