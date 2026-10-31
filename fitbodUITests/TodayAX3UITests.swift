//
//  TodayAX3UITests.swift
//  fitbodUITests
//
//  T27, review items 46, 24 and 25. At AX3 on the 390pt iPhone 17e, Today
//  broke words apart: the start slab's meta line read "EXER", "CISE", "S",
//  the resume slab wrapped the arrow of "RESUME ▸" to its own line, the lift
//  list wrapped "01" into "0" over "1" in its 32pt column, and the COMPOUND
//  chip read "COMPOUN" over "D". At every size the start slab counted
//  "1 EXERCISES".
//
//  The start slab and the lift list come from the active-block seed, whose
//  one session has one exercise, the barbell bench press. The resume slab
//  comes from the demo seed's unfinished Push A.
//

import XCTest

final class TodayAX3UITests: XCTestCase {
    /// A 1.5pt outline stroked on an element's edge reaches 0.75pt outside
    /// it on each side, and XCUI counts that in the element's frame.
    private static let outlineOverhang: CGFloat = 1.5

    override func setUpWithError() throws {
        // Every check runs, so one broken part does not hide the rest.
        continueAfterFailure = true
    }

    // MARK: - Start slab

    /// A session of one exercise and three sets reads "1 EXERCISE" and
    /// "3 SETS", not "1 EXERCISES".
    @MainActor
    func testStartSlabCountsOneExercise() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        let meta = startSlabMeta(in: app)
        XCTAssertEqual(meta.exercises.label.uppercased(), "1 EXERCISE", "One exercise reads singular")
        XCTAssertEqual(meta.sets.label.uppercased(), "3 SETS", "Three sets read plural")
    }

    /// At AX3 the meta line stacks its exercises, sets and minutes, each on
    /// one line, instead of breaking "EXERCISES" over three lines.
    @MainActor
    func testStartSlabMetaLineStacksItsPartsAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock, textSize: .ax3)
        let meta = startSlabMeta(in: app)
        let lineHeight = labelLineHeight(in: app)
        UITestNavigation.reveal(app.buttons.labeled("Start workout ▸"), in: app)
        UITestNavigation.saveScreenshot("T27", "start-slab", textSize: .ax3)

        for part in meta.parts {
            UITestNavigation.assertHeight(part, atMost: lineHeight + 1)
            UITestNavigation.assertInside(part, app.windows.firstMatch)
        }
        assertNoTwoOverlap(meta.parts)
    }

    // MARK: - Lift list

    /// At AX3 the row's "01" stays on one line beside the exercise, and the
    /// COMPOUND chip stays whole under the exercise's name.
    @MainActor
    func testLiftListNumberAndChipStayOnOneLineAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock, textSize: .ax3)
        let lineHeight = labelLineHeight(in: app)
        let row = liftRow(in: app)
        UITestNavigation.saveScreenshot("T27", "lift-list", textSize: .ax3)

        // On one line "01" is about as wide as it is tall; wrapped, it is
        // one digit wide and two lines tall.
        let number = row.number.frame
        XCTAssertGreaterThan(number.width, number.height / 2,
                             "\"01\" at \(number) must be one line, not \"0\" over \"1\"")
        UITestNavigation.assertHeight(row.chip, atMost: chipHeight(lineHeight: lineHeight))
        XCTAssertGreaterThanOrEqual(row.chip.frame.minY, row.name.frame.maxY - 0.5,
                                    "At AX3 the chip sits under the exercise's name")
        assertNoTwoOverlap(row.parts)
        UITestNavigation.assertInside(row.chip, app.windows.firstMatch)
    }

    // MARK: - Resume slab

    /// With a workout left unfinished, "RESUME ▸" keeps its arrow on its line
    /// at AX3: it spans the slab with DISCARD under it, each a full tap target.
    @MainActor
    func testResumePillStaysOnOneLineAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: .ax3)
        let slab = resumeSlab(in: app)
        UITestNavigation.saveScreenshot("T27", "resume-slab", textSize: .ax3)

        XCTAssertEqual(drawnTextLines(in: slab.resume), 1, "\"RESUME ▸\" must draw on one line")
        XCTAssertGreaterThanOrEqual(slab.discard.frame.minY, slab.resume.frame.maxY - 0.5,
                                    "At AX3 DISCARD sits under RESUME ▸")
        XCTAssertEqual(slab.resume.frame.width, app.windows.firstMatch.frame.width - 32, accuracy: 0.5,
                       "RESUME ▸ spans the slab inside its 16pt padding")
        XCTAssertEqual(slab.discard.frame.width - Self.outlineOverhang, slab.resume.frame.width, accuracy: 0.5,
                       "DISCARD spans the slab as RESUME ▸ does")
        XCTAssertEqual(slab.discard.frame.midX, slab.resume.frame.midX, accuracy: 0.5,
                       "DISCARD sits straight under RESUME ▸")
        UITestNavigation.assertTapTarget(slab.resume)
        UITestNavigation.assertTapTarget(slab.discard)
        assertNoTwoOverlap(slab.texts + [slab.resume, slab.discard])
    }

    // MARK: - Default text keeps Today's layout

    /// At default text the meta line stays one line of three parts, and the
    /// lift list row keeps "01" in its 32pt column and the chip beside the
    /// exercise's name.
    @MainActor
    func testStartSlabAndLiftListKeepTheirLayoutAtDefaultText() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock, textSize: .default)
        let meta = startSlabMeta(in: app)
        let lineHeight = labelLineHeight(in: app)
        UITestNavigation.reveal(app.buttons.labeled("Start workout ▸"), in: app)
        UITestNavigation.saveScreenshot("T27", "start-slab", textSize: .default)

        for part in meta.parts {
            UITestNavigation.assertHeight(part, atMost: lineHeight + 1)
            XCTAssertEqual(part.frame.midY, meta.exercises.frame.midY, accuracy: 0.5,
                           "\(part.label) shares the meta line's one line")
        }
        XCTAssertLessThan(meta.exercises.frame.maxX, meta.sets.frame.minX, "Exercises come before sets")
        XCTAssertLessThan(meta.sets.frame.maxX, meta.minutes.frame.minX, "Sets come before minutes")

        let row = liftRow(in: app)
        UITestNavigation.saveScreenshot("T27", "lift-list", textSize: .default)
        XCTAssertLessThanOrEqual(row.number.frame.width, 32, "\"01\" fits its 32pt column")
        XCTAssertEqual(row.name.frame.minX - row.number.frame.minX, 42, accuracy: 0.5,
                       "The name starts after the 32pt number column and its 10pt gap")
        XCTAssertGreaterThan(row.chip.frame.minX, row.name.frame.maxX, "The chip sits beside the exercise's name")
        XCTAssertLessThan(row.chip.frame.minY, row.sets.frame.maxY, "The chip sits beside the name and sets, not under them")
        UITestNavigation.assertHeight(row.chip, atMost: chipHeight(lineHeight: lineHeight))
    }

    /// At default text RESUME ▸ and DISCARD stay side by side, RESUME ▸ at
    /// BRU's 52pt action height.
    @MainActor
    func testResumeSlabKeepsItsButtonsSideBySideAtDefaultText() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout, textSize: .default)
        let slab = resumeSlab(in: app)
        UITestNavigation.saveScreenshot("T27", "resume-slab", textSize: .default)

        XCTAssertEqual(drawnTextLines(in: slab.resume), 1, "\"RESUME ▸\" draws on one line")
        XCTAssertEqual(slab.resume.frame.midY, slab.discard.frame.midY, accuracy: 0.5,
                       "RESUME ▸ and DISCARD share one row")
        XCTAssertEqual(slab.resume.frame.width, (app.windows.firstMatch.frame.width - 40) / 2, accuracy: 0.5,
                       "RESUME ▸ takes half the row: 16pt slab padding each side, 8pt between the buttons")
        XCTAssertEqual(slab.discard.frame.width - Self.outlineOverhang, slab.resume.frame.width, accuracy: 0.5,
                       "DISCARD is as wide as RESUME ▸")
        XCTAssertEqual(slab.discard.frame.midX - slab.resume.frame.midX, slab.resume.frame.width + 8, accuracy: 0.5,
                       "DISCARD sits 8pt after RESUME ▸")
        XCTAssertEqual(slab.resume.frame.height, 52, accuracy: 0.5, "RESUME ▸ keeps BRU's 52pt action height")
        UITestNavigation.assertTapTarget(slab.discard)
    }

    // MARK: - Elements

    private struct SlabMeta {
        let exercises: XCUIElement
        let sets: XCUIElement
        let minutes: XCUIElement

        var parts: [XCUIElement] { [exercises, sets, minutes] }
    }

    private struct LiftRow {
        let number: XCUIElement
        let name: XCUIElement
        let sets: XCUIElement
        let chip: XCUIElement

        var parts: [XCUIElement] { [number, name, sets, chip] }
    }

    private struct ResumeSlab {
        let texts: [XCUIElement]
        let resume: XCUIElement
        let discard: XCUIElement
    }

    /// The start slab's meta line: "1 EXERCISE", "3 SETS" and "~11 MIN".
    @MainActor
    private func startSlabMeta(in app: XCUIApplication) -> SlabMeta {
        let meta = SlabMeta(
            exercises: app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "(?i)[0-9]+ exercises?")).firstMatch,
            sets: app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "(?i)[0-9]+ sets?")).firstMatch,
            minutes: app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "(?i)~[0-9]+ min")).firstMatch
        )
        for part in meta.parts {
            XCTAssertTrue(part.waitForExistence(timeout: 10), "Missing meta line part: \(part)")
        }
        return meta
    }

    /// One line of the slab's 11pt mono labels: the height of NEXT, which
    /// fits its line at every size.
    @MainActor
    private func labelLineHeight(in app: XCUIApplication) -> CGFloat {
        let next = app.staticTexts.labeled("NEXT")
        XCTAssertTrue(next.waitForExistence(timeout: 10), "Today must show the start slab")
        return next.frame.height
    }

    /// The lift list's one row, scrolled into view: its number, the
    /// exercise's name, its sets and its chip. The seeded exercise is the
    /// barbell bench press, a compound lift of three sets of 5-8.
    @MainActor
    private func liftRow(in app: XCUIApplication) -> LiftRow {
        let row = LiftRow(
            number: app.staticTexts["01"],
            name: app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "bench press")).firstMatch,
            sets: app.staticTexts.labeled("3 × 5-8"),
            chip: app.staticTexts.labeled("Compound")
        )
        for part in row.parts {
            UITestNavigation.reveal(part, in: app)
        }
        return row
    }

    /// The resume slab, scrolled into view: its RESUME label, routine name
    /// and logged sets, and its RESUME ▸ and DISCARD buttons.
    @MainActor
    private func resumeSlab(in app: XCUIApplication) -> ResumeSlab {
        let slab = ResumeSlab(
            texts: [
                app.staticTexts.labeled("RESUME"),
                app.staticTexts["Push A"],
                app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "(?i)[0-9]+ sets? logged")).firstMatch,
            ],
            resume: app.buttons["resumeSlab.resume"],
            discard: app.buttons["resumeSlab.discard"]
        )
        XCTAssertTrue(slab.resume.waitForExistence(timeout: 10), "Today must show the resume slab")
        UITestNavigation.reveal(slab.discard, in: app)
        for text in slab.texts {
            XCTAssertTrue(text.exists, "Missing resume slab text: \(text)")
        }
        return slab
    }

    // MARK: - Checks

    /// The most a chip of one line can measure: one line of its 11pt mono
    /// label, its 3pt padding above and below, its outline's overhang, and
    /// half a point for rounding.
    private func chipHeight(lineHeight: CGFloat) -> CGFloat {
        lineHeight + 6 + Self.outlineOverhang + 0.5
    }

    /// How many lines of dark text `element` draws: the runs of pixel rows
    /// that hold dark pixels, 4pt inside its edges so a border does not
    /// count. "RESUME ▸" on one line is one run; with its arrow wrapped, two.
    @MainActor
    private func drawnTextLines(in element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) -> Int {
        let screenshot = XCUIScreen.main.screenshot()
        guard let cut = UITestNavigation.pixels(in: element.frame.insetBy(dx: 4, dy: 4), of: screenshot) else {
            XCTFail("\(element) is not on the screenshot", file: file, line: line)
            return 0
        }
        let width = Int(cut.frame.width)
        var lines = 0
        var previousRowIsDark = false
        for row in 0..<Int(cut.frame.height) {
            let darkPixels = (0..<width).count { column in
                let index = (row * width + column) * 4
                return max(cut.bytes[index], cut.bytes[index + 1], cut.bytes[index + 2]) < 96
            }
            let rowIsDark = darkPixels >= 2
            if rowIsDark && !previousRowIsDark { lines += 1 }
            previousRowIsDark = rowIsDark
        }
        return lines
    }

    @MainActor
    private func assertNoTwoOverlap(_ elements: [XCUIElement], file: StaticString = #filePath, line: UInt = #line) {
        for (index, first) in elements.enumerated() {
            for second in elements.dropFirst(index + 1) {
                UITestNavigation.assertNoOverlap(first, second, file: file, line: line)
            }
        }
    }
}
