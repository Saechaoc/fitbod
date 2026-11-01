//
//  BlockOverviewStatesUITests.swift
//  fitbodUITests
//
//  Ticket T12, review items 28, 29 and 25: the block overview follows the
//  block's derived status. Ready and draft blocks have their own heroes and
//  show no NOW, current week or progress before they start. Blocks number
//  #1, #2, #3 in start-date order. A completed block shows each phase's
//  honest state, marks only logged sessions Completed and shows no day
//  states. BlockStatesSeed supplies one block in each live state.
//

import XCTest

final class BlockOverviewStatesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Repro

    /// A ready block's hero read "● ACTIVE BLOCK".
    @MainActor
    func testReadyBlockHeroDoesNotSayActive() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStates)
        openBlock("READY block: Summer Block", in: app)
        let label = hero(in: app).label
        XCTAssertFalse(label.localizedCaseInsensitiveContains("active"),
                       "A ready block's hero must not say ACTIVE, but it reads \"\(label)\"")
        XCTAssertTrue(label.hasPrefix("Ready block #2: Summer Block"),
                      "The hero must say READY BLOCK, but it reads \"\(label)\"")
        let starts = "starts \(Self.mediumDate(Self.tomorrow))"
        XCTAssertTrue(label.contains(starts), "The ready hero must give its start date, \(starts): \"\(label)\"")
        XCTAssertTrue(label.contains("4 weeks: Accumulation 3 weeks, Deload 1 week"),
                      "The ready hero must give its weeks and phases: \"\(label)\"")
    }

    /// Blocks were numbered by the week of the year they start in, so every
    /// block that starts in late October was "#44".
    @MainActor
    func testBlocksAreNumberedInStartDateOrder() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStates)
        let blocks = [
            ("ACTIVE block: Spring Block", 1),
            ("READY block: Summer Block", 2),
            ("DRAFT block: Autumn Block", 3),
        ]
        for (card, number) in blocks {
            openBlock(card, in: app)
            let label = hero(in: app).label
            XCTAssertTrue(label.contains(" block #\(number): "),
                          "\(card) must be #\(number) in start-date order, but its hero reads \"\(label)\"")
            goBack(in: app)
        }
    }

    /// Phase 1 showed NOW, and the screen a current week, before the block
    /// started.
    @MainActor
    func testReadyBlockStartingTomorrowShowsNoNowOrCurrentWeek() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStates)
        openBlock("READY block: Summer Block", in: app)
        XCTAssertFalse(app.staticTexts["NOW"].exists, "No phase may show NOW before the block starts")
        let weekHeader = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "WEEK [0-9]+ OF [0-9]+")).firstMatch
        XCTAssertFalse(weekHeader.exists, "A block that has not started has no current week, but the screen shows \"\(weekHeader.label)\"")
        let progress = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'In progress'")).firstMatch
        XCTAssertFalse(progress.exists, "A block that has not started shows no progress")
        XCTAssertFalse(hero(in: app).label.localizedCaseInsensitiveContains("week 1 of"),
                       "The hero must not give a current week before the start date")
    }

    /// A block ended during week 1 marked every phase DONE and every session
    /// Completed, and still showed TODAY, NEXT and "N LEFT".
    @MainActor
    func testBlockEndedInWeekOneShowsHonestPhasesAndNoDayStates() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStates)
        openBlock("ACTIVE block: Spring Block", in: app)
        let end = app.buttons.labeled("END BLOCK")
        XCTAssertTrue(UITestNavigation.appears(end), "An active block must offer END BLOCK")
        end.tap()
        let confirm = app.alerts.buttons["End Block"]
        XCTAssertTrue(UITestNavigation.appears(confirm), "END BLOCK must ask before it ends the block")
        confirm.tap()
        goBack(in: app)
        openBlock("DONE block: Spring Block", in: app)

        let heroLabel = hero(in: app).label
        XCTAssertTrue(heroLabel.hasPrefix("Completed block"),
                      "The ended block must open on the completed hero, but it reads \"\(heroLabel)\"")

        var problems: [String] = []
        if !heroLabel.hasPrefix("Completed block #1: Spring Block") {
            problems.append("the hero must read \"Completed block #1: Spring Block\", not \"\(heroLabel)\"")
        }
        let expectedPhases = [("Accumulation", "CUT SHORT"), ("Intensification", "NOT REACHED"), ("Deload", "NOT REACHED")]
        for (phase, state) in expectedPhases {
            let shown = rowLabel(beside: app.staticTexts[phase], among: Self.phaseStates, in: app)
            if shown != state {
                problems.append("\(phase) shows \(shown ?? "no state"), not \(state)")
            }
        }
        let dayStates = app.descendants(matching: .any).matching(Self.dayStatePredicate).allElementsBoundByIndex.map(\.label)
        if !dayStates.isEmpty {
            problems.append("a completed block shows day states: \(dayStates)")
        }
        for (session, state) in [("Upper A", "Completed"), ("Upper B", "Not logged")] {
            let shown = rowLabel(beside: app.staticTexts[session], among: ["Completed", "Not logged"], in: app)
            if shown != state {
                problems.append("session \(session) shows \(shown ?? "nothing"), not \(state)")
            }
        }
        XCTAssertTrue(problems.isEmpty, "The block ended in week 1: " + problems.joined(separator: "; "))
    }

    /// A draft block's hero also read "● ACTIVE BLOCK".
    @MainActor
    func testDraftBlockHeroNamesItsFirstMissingPiece() throws {
        let app = UITestNavigation.launch(UITestNavigation.blockStates)
        openBlock("DRAFT block: Autumn Block", in: app)
        let label = hero(in: app).label
        XCTAssertTrue(label.hasPrefix("Draft block #3: Autumn Block"),
                      "The hero must say DRAFT BLOCK, but it reads \"\(label)\"")
        XCTAssertTrue(label.contains("pick a routine"),
                      "The draft hero must name its first missing piece, the routine: \"\(label)\"")
    }

    // MARK: - Helpers

    private static let phaseStates = ["DONE", "NOW", "CUT SHORT", "NOT REACHED"]

    /// A day state anywhere on screen: the strip's TODAY and NEXT, as shown
    /// or as VoiceOver reads a cell, and its "N LEFT" count. Case matters:
    /// the tab bar's Today tab reads "Today".
    private static let dayStatePredicate = NSPredicate(
        format: "label == 'TODAY' OR label == 'NEXT' OR label ENDSWITH ', today' OR label ENDSWITH ', next' "
            + "OR label ENDSWITH ', upcoming' OR label MATCHES '[0-9]+ LEFT'"
    )

    private static var tomorrow: Date {
        Calendar.current.startOfDay(for: Date.now.addingTimeInterval(24 * 3600))
    }

    /// The date as the app writes it, such as "Oct 31, 2026".
    private static func mediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// The overview's hero, one element VoiceOver reads as "Ready block #2:
    /// Summer Block, …".
    @MainActor
    private func hero(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "label MATCHES[c] %@", "(active|ready|draft|completed) block .*"
        )).firstMatch
    }

    /// Opens a block from its Program card, read as "READY block: Summer Block".
    @MainActor
    private func openBlock(_ card: String, in app: XCUIApplication) {
        UITestNavigation.selectTab("Program", in: app)
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", card)).firstMatch
        XCTAssertTrue(UITestNavigation.appears(button), "Program must list \(card)")
        UITestNavigation.reveal(button, in: app)
        button.tap()
        XCTAssertTrue(UITestNavigation.appears(hero(in: app)), "\(card) must open the block overview")
    }

    @MainActor
    private func goBack(in app: XCUIApplication) {
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(UITestNavigation.disappears(hero(in: app)), "‹ BACK must close the block overview")
    }

    /// The label among `labels` on the same row as `element`, or nil.
    @MainActor
    private func rowLabel(beside element: XCUIElement, among labels: [String], in app: XCUIApplication) -> String? {
        guard element.exists else { return nil }
        let row = element.frame
        let candidates = app.staticTexts.matching(NSPredicate(format: "label IN %@", labels)).allElementsBoundByIndex
        return candidates.first { abs($0.frame.midY - row.midY) <= max(row.height, 12) }?.label
    }
}

extension UITestNavigation {
    /// A fresh store plus one block in each live state on a shared routine
    /// (BlockStatesSeed).
    static let blockStates = [resetFlag, "-fitbod-seed-block-states"]
}
