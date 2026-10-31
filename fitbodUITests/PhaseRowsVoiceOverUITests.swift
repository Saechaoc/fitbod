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
//  Ticket T105, findings F166 to F169, F172 and F173. A tap on a revealed
//  Delete closed its card, because the card's tap area stayed where the
//  card rests, over the Delete; it now deletes the phase. VoiceOver read
//  the name band's pencil as "Compose", walked the progression chart's
//  marks and labels one by one, read the phase editor's steppers as "−"
//  and "+", and offered Move Up on the first card and Move Down on the
//  last, where they do nothing.
//
//  The VoiceOver tests drive real VoiceOver through XCUIVoiceOverService,
//  which needs iOS 27. It reads speech and moves the focus, and a swipe up
//  or down steps through the focused element's actions. It reports the
//  first 64 characters of each utterance. A tap or a double tap from
//  XCUITest bypasses VoiceOver, so these tests read the actions by name and
//  the other tests use the controls the way a touch does. Each test turns
//  VoiceOver off at its start as well as at its end, because a run killed
//  mid-test never runs the teardown. Only Xcode 27's SDK has the service,
//  so under Xcode 26 (Swift 6.3), which docs/SETUP.md names, the VoiceOver
//  tests compile to a skip.
//

import XCTest

final class PhaseRowsVoiceOverUITests: XCTestCase {
    // The tests and helpers are @MainActor because XCUIApplication and
    // XCUIDevice are main-actor isolated.
    private static let accumulation = "Phase 1: Accumulation"
    private static let peak = "Phase 2: Peak"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let voiceOver = XCUIDevice.shared.voiceOverService
            if voiceOver.isEnabled { try voiceOver.disable() }
        }
        #endif
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
        let weeksPlus = UITestNavigation.hittable(app.buttons, "Increase weeks", exactLabel: true)
        XCTAssertEqual(weeksPlus.value as? String, "1 week", "The WEEKS + must read the weeks as its value")
        weeksPlus.tap()
        XCTAssertEqual(weeksPlus.value as? String, "2 weeks", "The WEEKS + must read the weeks after a tap")
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
        let delete = revealDelete(on: card, in: app)
        UITestNavigation.saveScreenshot("T24", "delete-revealed")
        XCTAssertEqual(delete.frame.midY, card.frame.midY, accuracy: 0.5, "The revealed Delete must be phase 2's")
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", Self.peak)).count, 1,
                       "The revealed Delete must not repeat the card's label")
    }

    // MARK: - Revealed Delete

    /// A tap on the rest of a revealed card closes it, deleting nothing and
    /// opening no phase editor. A tap on a revealed Delete deletes its phase
    /// through the undo toast, as a full swipe does, and UNDO puts the phase
    /// back. The card's tap area stayed where the card rests, over the
    /// Delete, so a tap on the Delete closed the card and the phase stayed.
    @MainActor
    func testTapOnRevealedDeleteDeletesThePhase() throws {
        let app = openNewBlockWithTwoPhases()
        let card = phaseCard(Self.peak, in: app)
        UITestNavigation.revealAboveBottomBar(card, in: app, scroll: .dragInMargin)

        var delete = revealDelete(on: card, in: app)
        // Left of the revealed Delete, where the card still shows.
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == false"), object: delete)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 5), .completed, "A tap on the card must close it over its Delete")
        XCTAssertTrue(app.staticTexts.labeled("PHASES · 2").exists, "A tap on the card must delete nothing")
        XCTAssertFalse(app.buttons.labeled("Done").exists, "A tap on a revealed card must close it, not open its phase editor")

        delete = revealDelete(on: card, in: app)
        UITestNavigation.saveScreenshot("T105", "delete-revealed")
        delete.tap()
        let count = app.staticTexts.labeled("PHASES · 1")
        let deleted = count.exists || count.waitForExistence(timeout: 5)
        UITestNavigation.saveScreenshot("T105", "delete-tapped")
        XCTAssertTrue(deleted, "A tap on the revealed Delete must delete phase 2, and New Block reads \(phaseCountLabel(in: app))")
        XCTAssertFalse(card.exists, "\(Self.peak) must be gone")
        XCTAssertTrue(app.staticTexts.labeled("Phase deleted").exists, "The delete must offer the undo toast")
        UITestNavigation.hittable(app.buttons, "UNDO", exactLabel: true).tap()
        let restored = app.staticTexts.labeled("PHASES · 2")
        XCTAssertTrue(restored.exists || restored.waitForExistence(timeout: 5), "UNDO must put phase 2 back")
        XCTAssertTrue(card.exists, "UNDO must put \(Self.peak) back")
    }

    // MARK: - VoiceOver

    /// VoiceOver reads each phase card once, with its settings, as a button.
    @MainActor
    func testVoiceOverReadsEachPhaseOnce() throws {
        #if compiler(>=6.4)
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
        #else
        throw XCTSkip("Driving VoiceOver needs Xcode 27's XCUIVoiceOverService")
        #endif
    }

    /// VoiceOver reads New Block's controls by name. It skips the name
    /// band's decorative pencil, which it read as "Compose". It reads the
    /// progression chart as one element that sums the block up, where it
    /// read the chart's title, legend, marks and labels one by one. A phase
    /// card's actions are Delete Phase and the moves the card can make, for
    /// a person who cannot make the ⋮⋮ drag or the swipe to Delete: the
    /// first card offers no Move Up and the last no Move Down, where they
    /// did nothing. And each phase editor stepper reads its direction and
    /// stat, such as "Increase weeks", with the stat's value, where it read
    /// "−" and "+". One launch and one walk serve every check.
    @MainActor
    func testVoiceOverReadsNewBlockControlsByName() throws {
        #if compiler(>=6.4)
        guard #available(iOS 27.0, *) else { throw XCTSkip("Driving VoiceOver needs iOS 27") }
        let app = openNewBlockWithTwoPhases()
        let voiceOver = try startVoiceOver()
        var spoken: [String] = []
        for _ in 0..<60 {
            let utterance = try voiceOver.moveForward().utterance
            spoken.append(utterance)
            if utterance.contains(Self.accumulation) { break }
        }
        XCTContext.runActivity(named: "VoiceOver read: \(spoken.joined(separator: " | "))") { _ in }
        XCTAssertTrue(spoken.last?.contains(Self.accumulation) == true, "VoiceOver must reach \(Self.accumulation)")

        var problems: [String] = []
        if let pencil = spoken.first(where: { $0.contains("Compose") }) {
            problems.append("VoiceOver must skip the name band's pencil, and it reads \"\(pencil)\"")
        }
        // The chart's card sits between DAYS PER WEEK's + and the PHASES head.
        if let plus = spoken.firstIndex(where: { $0.hasPrefix("Increase days per week") }),
           let head = spoken.firstIndex(where: { $0.hasPrefix("PHASES") }), plus < head {
            let chart = Array(spoken[(plus + 1)..<head])
            if chart.count != 1 || chart.first?.hasPrefix("Progression overview") != true {
                problems.append("VoiceOver must read the progression chart as one element, and it reads \(chart)")
            }
        } else {
            problems.append("VoiceOver must reach DAYS PER WEEK's + and then the PHASES head, and it reads \(spoken)")
        }

        // Three swipes down step through a card's default and its two
        // actions, wrapping past the last, or through three actions if the
        // card offered a move it cannot make.
        for (label, offered, withheld) in [
            (Self.accumulation, ["Move Down", "Delete Phase"], ["Move Up"]),
            (Self.peak, ["Move Up", "Delete Phase"], ["Move Down"]),
        ] {
            var focused = spoken.last ?? ""
            for _ in 0..<10 where !focused.contains(label) {
                focused = try voiceOver.moveForward().utterance
            }
            XCTAssertTrue(focused.contains(label), "VoiceOver must reach \(label)")
            var actions: Set<String> = []
            for _ in 0..<3 {
                app.swipeDown()
                actions.insert(try voiceOver.currentSpeech().utterance)
            }
            XCTContext.runActivity(named: "\(label) actions: \(actions.sorted().joined(separator: " | "))") { _ in }
            problems += offered.filter { !actions.contains($0) }
                .map { "VoiceOver must offer \($0) on \(label), not only \(actions.sorted())" }
            problems += withheld.filter { actions.contains($0) }
                .map { "VoiceOver must not offer \($0) on \(label), where it does nothing" }
        }
        try voiceOver.disable()

        // VoiceOver reports only the start of the chart's summary, so XCUITest
        // reads it whole.
        let summary = "2 weeks, 2 phases. Week 1: volume Hold, intensity 75%. Week 2: volume -20%, intensity 95%."
        let chart = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Progression overview")).firstMatch
        let read = chart.exists ? chart.value as? String : nil
        if read != summary {
            problems.append("The chart must sum up its first and last weeks, \"\(summary)\", and it reads \(read ?? "no such element or value")")
        }

        // A tap from XCUITest bypasses VoiceOver, so it opens the phase editor
        // as a touch does; VoiceOver then reads the sheet from its top.
        phaseCard(Self.accumulation, in: app).tap()
        UITestNavigation.waitUntilStill(editorDone(in: app))
        try voiceOver.enable()
        var sheet: [String] = []
        for _ in 0..<30 {
            let utterance = try voiceOver.moveForward().utterance
            sheet.append(utterance)
            if utterance.hasPrefix("Done") { break }
        }
        try voiceOver.disable()
        XCTContext.runActivity(named: "The phase editor read: \(sheet.joined(separator: " | "))") { _ in }
        for (stepper, value) in [
            ("Decrease weeks", "1 week"), ("Increase weeks", "1 week"),
            ("Decrease volume", "Hold"), ("Increase volume", "Hold"),
            ("Decrease intensity", "75%"), ("Increase intensity", "75%"),
        ] {
            let read = sheet.first { $0.hasPrefix(stepper) }
            if read?.contains(value) != true {
                problems.append("VoiceOver must read \"\(stepper)\" with its value, \(value), and it reads \(read ?? "no such stepper")")
            }
        }
        XCTAssertEqual(problems, [])
        #else
        throw XCTSkip("Driving VoiceOver needs Xcode 27's XCUIVoiceOverService")
        #endif
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
        let title = app.staticTexts.labeled("NEW BLOCK")
        XCTAssertTrue(title.exists || title.waitForExistence(timeout: 10), "Start a block must open New Block",
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
        let header = app.staticTexts.labeled("PHASES · \(count)")
        XCTAssertTrue(header.exists || header.waitForExistence(timeout: 5),
                      "New Block must have \(count) phases", file: file, line: line)
    }

    /// The phase card labeled `label`, such as "Phase 1: Accumulation".
    @MainActor
    private func phaseCard(_ label: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(card.exists || card.waitForExistence(timeout: 10), "Missing \(label)", file: file, line: line)
        return card
    }

    /// The open phase editor's Done.
    @MainActor
    private func editorDone(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let done = app.buttons.labeled("Done")
        XCTAssertTrue(done.exists || done.waitForExistence(timeout: 5), "The phase editor must open", file: file, line: line)
        return done
    }

    /// A slow, short drag on `card` reveals its Delete, which this returns;
    /// a fast full swipe would delete the phase at once.
    @MainActor
    private func revealDelete(on card: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        let end = card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        let delete = UITestNavigation.hittable(app.buttons, "Delete", exactLabel: true)
        UITestNavigation.waitUntilStill(delete)
        return delete
    }

    /// New Block's phase count head, such as "PHASES · 2".
    @MainActor
    private func phaseCountLabel(in app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "PHASES · ")).firstMatch.label
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
}
