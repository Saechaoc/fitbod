//
//  PhaseRowsVoiceOverUITests.swift
//  fitbodUITests
//
//  Ticket T24, review item 45. New Block's phase card set its label on a
//  container that did not combine its children, so each of its texts
//  inherited the label and VoiceOver read "Phase 1: Accumulation" 12 times.
//  Each card is now one button: its label once, its stat columns as its
//  value, a tap or VoiceOver's activate opens its phase editor, and Move Up,
//  Move Down and Delete Phase are its actions. A revealed Delete is a
//  button of its own. XCUITest still lists a card's texts under the card,
//  each by its own label, though VoiceOver reads the card as one element.
//
//  The VoiceOver tests drive real VoiceOver through XCUIVoiceOverService,
//  which needs iOS 27. It reads speech and moves the focus, and a swipe up
//  or down steps through the focused element's actions. A tap or a double
//  tap from XCUITest bypasses VoiceOver, so these tests read the actions by
//  name and the other tests use the controls the way a touch does.
//

import XCTest

final class PhaseRowsVoiceOverUITests: XCTestCase {
    private static let accumulation = "Phase 1: Accumulation"
    private static let peak = "Phase 2: Peak"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Repro

    /// A one-phase block has one element labeled "Phase 1: Accumulation".
    @MainActor
    func testPhaseCardReadsItsLabelOnce() throws {
        let app = openNewBlockWithOnePhase()
        let matches = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", Self.accumulation))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 10), "New Block must show phase 1")
        let elements = matches.allElementsBoundByIndex
        let found = elements.map { "type \($0.elementType.rawValue) value \($0.value ?? "nil") at \($0.frame)" }
        XCTContext.runActivity(named: "\(elements.count) elements labeled \(Self.accumulation): \(found.joined(separator: "; "))") { _ in }
        UITestNavigation.saveScreenshot("T24", "one-phase")
        XCTAssertEqual(elements.count, 1, "VoiceOver must read \(Self.accumulation) once, not once for each part of its card")
    }

    // MARK: - Value

    /// The card's value reads its WEEKS, VOL and INT columns, and follows an
    /// edit in the phase editor.
    @MainActor
    func testPhaseCardValueReadsItsSettings() throws {
        let app = openNewBlockWithOnePhase()
        let card = phaseCard(Self.accumulation, in: app)
        XCTAssertEqual(card.value as? String, "1 week, volume Hold, intensity 75%", "The card's value must read its stat columns")

        card.tap()
        let done = editorDone(in: app)
        let weeksPlus = app.buttons.matching(NSPredicate(format: "label == %@", "+")).allElementsBoundByIndex
            .filter(\.isHittable).min { $0.frame.minY < $1.frame.minY }
        XCTAssertNotNil(weeksPlus, "The phase editor must offer + on its WEEKS row")
        weeksPlus?.tap()
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Done must close the phase editor")
        XCTAssertEqual(card.value as? String, "2 weeks, volume Hold, intensity 75%", "The card's value must follow the edit")
    }

    // MARK: - Controls

    /// Every control in a phase card stays reachable through accessibility:
    /// the card is one button whose tap opens the phase editor, and a swipe
    /// reveals Delete as a button of its own. VoiceOver reaches the ⋮⋮ drag
    /// and the swipe through the card's actions, which
    /// testVoiceOverOffersEachPhaseCardAction reads.
    @MainActor
    func testPhaseCardControlsStayReachable() throws {
        let app = openNewBlockWithTwoPhases()
        let card = phaseCard(Self.peak, in: app)
        XCTAssertEqual(card.elementType, .button, "The card must read as a button")
        UITestNavigation.revealAboveBottomBar(card, in: app, scroll: .dragInMargin)

        card.tap()
        let done = editorDone(in: app)
        UITestNavigation.waitUntilStill(done)
        // The editor's title reads "Peak". The card's own "Peak" sits under
        // the sheet, and the chart's band label reads "PEAK".
        let titles = app.staticTexts.matching(NSPredicate(format: "label == %@", "Peak")).allElementsBoundByIndex
        XCTAssertTrue(titles.contains(where: \.isHittable), "A tap on the card must open Peak's phase editor")
        UITestNavigation.saveScreenshot("T24", "phase-editor")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Done must close the phase editor")

        let deletes = app.buttons.matching(NSPredicate(format: "label == %@", "Delete"))
        XCTAssertFalse(deletes.allElementsBoundByIndex.contains(where: \.isHittable), "Delete must stay hidden until a swipe")
        // A slow, short drag reveals Delete; a fast full swipe deletes at once.
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        let end = card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        let delete = UITestNavigation.hittable(app.buttons, "Delete", exactLabel: true)
        UITestNavigation.waitUntilStill(delete)
        UITestNavigation.saveScreenshot("T24", "delete-revealed")
        XCTAssertEqual(delete.frame.midY, card.frame.midY, accuracy: 0.5, "The revealed Delete must be phase 2's")
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", Self.peak)).count, 1,
                       "The revealed Delete must not repeat the card's label")
    }

    // MARK: - VoiceOver

    /// VoiceOver reads each phase card once, with its settings, as a button.
    @MainActor
    func testVoiceOverReadsEachPhaseOnce() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Driving VoiceOver needs iOS 27") }
        _ = openNewBlockWithTwoPhases()
        let voiceOver = try startVoiceOver()
        var spoken: [String] = []
        for _ in 0..<60 {
            let utterance = try voiceOver.moveForward().utterance
            spoken.append(utterance)
            if utterance.hasPrefix("CANCEL") { break }
        }
        try voiceOver.disable()
        XCTContext.runActivity(named: "VoiceOver read: \(spoken.joined(separator: " | "))") { _ in }

        for (label, settings) in [(Self.accumulation, "1 week, volume Hold, intensity 75%"), (Self.peak, "1 week, volume -20%, intensity 95%")] {
            let reads = spoken.filter { $0.contains(label) }
            XCTAssertEqual(reads.count, 1, "VoiceOver must read \(label) once, not \(reads.count) times: \(reads)")
            let read = reads.first ?? ""
            XCTAssertTrue(read.contains(settings), "VoiceOver must read \(label)'s settings, \"\(settings)\": \(read)")
            XCTAssertTrue(read.contains("Button"), "VoiceOver must read \(label) as a button: \(read)")
        }
    }

    /// With a phase card focused, VoiceOver's actions are Move Up, Move Down
    /// and Delete Phase: the ⋮⋮ drag and the swipe to Delete, for a person
    /// who cannot make those gestures.
    @MainActor
    func testVoiceOverOffersEachPhaseCardAction() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Driving VoiceOver needs iOS 27") }
        let app = openNewBlockWithTwoPhases()
        let voiceOver = try startVoiceOver()
        var focused = ""
        for _ in 0..<60 {
            focused = try voiceOver.moveForward().utterance
            if focused.contains(Self.peak) { break }
        }
        XCTAssertTrue(focused.contains(Self.peak), "VoiceOver must reach \(Self.peak)")

        // Each swipe down steps back one action, wrapping from the default to
        // the last, so four swipes visit the default and all three actions.
        var actions: [String] = []
        for _ in 0..<4 {
            app.swipeDown()
            actions.append(try voiceOver.currentSpeech().utterance)
        }
        try voiceOver.disable()
        XCTContext.runActivity(named: "\(Self.peak) actions: \(actions.joined(separator: " | "))") { _ in }
        for action in ["Move Up", "Move Down", "Delete Phase"] {
            XCTAssertTrue(actions.contains(action), "VoiceOver must offer \(action) on \(Self.peak), not only \(actions)")
        }
    }

    // MARK: - Helpers

    /// Today → Start a block opens New Block with no phases; + ADD PHASE →
    /// Accumulation adds phase 1.
    @MainActor
    private func openNewBlockWithOnePhase(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore, file: file, line: line)
        let start = app.buttons.labeled("Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "Start a block must open New Block",
                      file: file, line: line)
        addPhase("Accumulation", count: 1, in: app, file: file, line: line)
        return app
    }

    /// New Block with phase 1, Accumulation, and phase 2, Peak.
    @MainActor
    private func openNewBlockWithTwoPhases(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = openNewBlockWithOnePhase(file: file, line: line)
        addPhase("Peak", count: 2, in: app, file: file, line: line)
        return app
    }

    /// + ADD PHASE → `kind`, then waits for the "PHASES · `count`" header.
    @MainActor
    private func addPhase(_ kind: String, count: Int, in app: XCUIApplication, file: StaticString, line: UInt) {
        UITestNavigation.hittable(app.buttons, "+ ADD PHASE", file: file, line: line).tap()
        UITestNavigation.hittable(app.buttons, kind, file: file, line: line).tap()
        XCTAssertTrue(app.staticTexts.labeled("PHASES · \(count)").waitForExistence(timeout: 5),
                      "New Block must have \(count) phases", file: file, line: line)
    }

    /// The phase card labeled `label`, such as "Phase 1: Accumulation".
    @MainActor
    private func phaseCard(_ label: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Missing \(label)", file: file, line: line)
        return card
    }

    /// The open phase editor's Done.
    @MainActor
    private func editorDone(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let done = app.buttons.labeled("Done")
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The phase editor must open", file: file, line: line)
        return done
    }

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
}
