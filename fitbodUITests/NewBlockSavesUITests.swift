//
//  NewBlockSavesUITests.swift
//  fitbodUITests
//
//  Ticket T11, review item 36: New Block's two saves. The top action reads
//  SAVE DRAFT and needs only a name.
//

import XCTest

final class NewBlockSavesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Repro

    /// The review says the top SAVE saved a block without a name, but both
    /// saves called one save that needs a name. This records what a
    /// nameless tap does, then asks for a SAVE DRAFT that waits for a name.
    @MainActor
    func testNamelessTopSaveMakesNoBlock() throws {
        let app = openBlankNewBlock()
        let topSave = topSaveControl(in: app)
        let label = topSave.label
        let enabled = topSave.isEnabled
        topSave.tap()
        // Waits the whole 3 s while New Block rightly stays open.
        let closed = newBlockTitle(in: app).waitForNonExistence(timeout: 3)
        if !closed {
            UITestNavigation.hittable(app.buttons, "Cancel").tap()
            XCTAssertTrue(newBlockTitle(in: app).waitForNonExistence(timeout: 5),
                          "CANCEL must close an untouched New Block")
        }
        let blocks = blockCards(in: app).count
        record("Nameless top save: label \"\(label)\", enabled \(enabled), "
            + "New Block closed \(closed), blocks on Program \(blocks)")
        XCTAssertFalse(closed, "A nameless top save must not close New Block")
        XCTAssertEqual(blocks, 0, "A nameless top save must not make a block")
        XCTAssertEqual(label, "SAVE DRAFT", "The top action must say it saves a draft")
        XCTAssertFalse(enabled, "SAVE DRAFT must wait for a name")
    }

    // MARK: - Acceptance

    /// SAVE DRAFT saves a block with only a name, and Program lists it as a
    /// draft. Today's Start a block opens one with no phases, so the bottom
    /// action asks for a phase, and EDIT BLOCK's SAVE CHANGES still does.
    @MainActor
    func testSaveDraftSavesANameOnlyBlockAsADraft() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openStartABlock(in: app)
        UITestNavigation.type("Name Only", into: nameField(in: app))
        expectBottomAction("ADD A PHASE", enabled: false, in: app)
        let saveDraft = app.buttons.labeled("SAVE DRAFT")
        XCTAssertTrue(saveDraft.isEnabled, "SAVE DRAFT needs only a name")
        saveDraft.tap()
        XCTAssertTrue(UITestNavigation.disappears(newBlockTitle(in: app), within: 5), "SAVE DRAFT must close New Block")

        UITestNavigation.selectTab("Program", in: app)
        let card = app.buttons.labeled("DRAFT block: Name Only")
        XCTAssertTrue(UITestNavigation.appears(card), "Program must list the name-only block as a draft")

        UITestNavigation.reveal(card, in: app)
        card.tap()
        UITestNavigation.hittable(app.buttons, "EDIT").tap()
        XCTAssertTrue(UITestNavigation.appears(editBlockTitle(in: app)), "EDIT must open EDIT BLOCK")
        expectBottomAction("ADD A PHASE", enabled: false, in: app)
        XCTAssertFalse(app.buttons.labeled("SAVE DRAFT").exists, "EDIT BLOCK has no SAVE DRAFT")
    }

    // MARK: - New Block

    /// Program → + NEW → + New block → Blank Block: three phases, no name.
    @MainActor
    private func openBlankNewBlock() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        XCTAssertTrue(UITestNavigation.appears(newBlockTitle(in: app)), "New Block never opened")
        return app
    }

    @MainActor
    private func newBlockTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("NEW BLOCK")
    }

    @MainActor
    private func editBlockTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("EDIT BLOCK")
    }

    /// Today's Start a block: New Block on the blank template, named
    /// "Blank Block" with no phases.
    @MainActor
    private func openStartABlock(in app: XCUIApplication) {
        UITestNavigation.selectTab("Today", in: app)
        let start = app.buttons.labeled("Start a block")
        UITestNavigation.reveal(start, in: app)
        start.tap()
        XCTAssertTrue(UITestNavigation.appears(newBlockTitle(in: app)), "Start a block must open New Block")
    }

    /// Waits until the bottom action reads `label`, then checks whether it
    /// can be tapped.
    @MainActor
    private func expectBottomAction(
        _ label: String, enabled: Bool, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let action = app.buttons.labeled(label)
        XCTAssertTrue(UITestNavigation.appears(action, within: 5),
                      "The bottom action must read \(label), not \"\(bottomAction(in: app).label)\"",
                      file: file, line: line)
        XCTAssertEqual(action.isEnabled, enabled,
                       "\(label) must be \(enabled ? "enabled" : "disabled")", file: file, line: line)
    }

    /// The builder's only text field. Its placeholder "NAME YOUR BLOCK" is
    /// a separate text.
    @MainActor
    private func nameField(in app: XCUIApplication) -> XCUIElement {
        app.textFields.firstMatch
    }

    /// The top-right save, whatever it reads. While the name is empty, no
    /// bottom label starts with SAVE.
    @MainActor
    private func topSaveControl(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let saves = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "SAVE"))
        XCTAssertTrue(UITestNavigation.appears(saves.firstMatch, within: 5), "New Block has no top save", file: file, line: line)
        return saves.allElementsBoundByIndex.min { $0.frame.minY < $1.frame.minY } ?? saves.firstMatch
    }

    /// The bottom bar's primary action: the tappable button to the right of
    /// CANCEL whose frame spans CANCEL's middle. Its frame is taller than
    /// CANCEL's, and the tab bar under New Block shares the band.
    @MainActor
    private func bottomAction(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let cancel = UITestNavigation.hittable(app.buttons, "Cancel", file: file, line: line).frame
        let action = app.buttons.allElementsBoundByIndex
            .filter { $0.frame.minY < cancel.midY && $0.frame.maxY > cancel.midY && $0.frame.minX > cancel.maxX }
            .filter(\.isHittable)
            .min { $0.frame.minX < $1.frame.minX }
        XCTAssertNotNil(action, "New Block has no action beside CANCEL", file: file, line: line)
        return action ?? app.buttons.labeled("Cancel")
    }

    // MARK: - Program

    /// Program's block cards, read as "DRAFT block: Spring Base".
    @MainActor
    private func blockCards(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
            "DRAFT block:", "READY block:", "ACTIVE block:"
        ))
    }

    // MARK: - Notes

    /// Keeps a note in the result bundle, even when the test passes.
    @MainActor
    private func record(_ note: String) {
        let attachment = XCTAttachment(string: note)
        attachment.name = "T11-note"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
