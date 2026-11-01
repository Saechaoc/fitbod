import XCTest

/// Ticket T20, review item 44. Archive routine asks "Archive routine?" with
/// Archive and a visible Keep routine, after the deny rule for a routine a
/// live block uses. An archived routine leaves Program, and Program's
/// Archived routines entry, shown only while a routine is archived, opens
/// ARCHIVED ROUTINES, whose RESTORE brings it back.
final class ArchiveRoutineUITests: XCTestCase {

    /// The progress-history seed's one session, which no routine holds.
    private static let session = "Bench & Squat"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Archive asks first

    /// Archive routine asks first. Keep routine closes the dialog and keeps
    /// the routine on Program and Today, and Program offers no Archived
    /// routines entry while nothing is archived.
    @MainActor
    func testArchiveAsksFirstAndKeepRoutineKeepsIt() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        let name = makeRoutineOnProgram(in: app)

        tapArchiveRoutine(in: app)
        XCTAssertTrue(dialogTitle(in: app).waitForExistence(timeout: 5),
                      "Archive routine must ask first, not archive at once")
        UITestNavigation.hittable(app.buttons, "Archive", exactLabel: true)
        let keep = UITestNavigation.hittable(app.buttons, "Keep routine", exactLabel: true)
        UITestNavigation.saveScreenshot("T20", "archive-dialog")
        keep.tap()
        XCTAssertTrue(dialogTitle(in: app).waitForNonExistence(timeout: 5), "Keep routine must close the dialog")
        XCTAssertTrue(routineNameField(in: app, value: name).exists, "Keep routine must leave the routine open")

        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(programRow(name, in: app).waitForExistence(timeout: 10), "Program must still list \(name)")
        assertNoArchivedEntry(in: app)
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertTrue(todayGroup(name, in: app).waitForExistence(timeout: 10), "Today must still offer \(name)")
    }

    // MARK: - Archived routines

    /// Program shows Archived routines once a routine is archived. It opens
    /// ARCHIVED ROUTINES, whose RESTORE puts the routine back on Program and
    /// Today at once, and the entry leaves with the last archived routine.
    /// A relaunch reads both changes back.
    @MainActor
    func testArchivedRoutinesRestoresTheRoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        let name = makeRoutineOnProgram(in: app)
        archiveOpenRoutine(in: app)
        XCTAssertTrue(routineNameField(in: app, value: name).waitForNonExistence(timeout: 5),
                      "Archiving must take Program back to its list")

        UITestNavigation.relaunch(app)
        UITestNavigation.selectTab("Program", in: app)
        let entry = archivedEntry(in: app)
        scrollProgram(toward: entry, in: app)
        XCTAssertTrue(entry.exists, "Program must offer a way to reach the archived routine")
        UITestNavigation.assertTapTarget(entry)
        UITestNavigation.saveScreenshot("T20", "archived-entry")
        entry.tap()
        // At default text the title's words are joined by a no-break space (T38).
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label MATCHES[c] %@", "Archived.routines"))
                        .firstMatch.waitForExistence(timeout: 10),
                      "The entry must open ARCHIVED ROUTINES")
        let restore = UITestNavigation.hittable(app.buttons, "Restore \(name)", exactLabel: true)
        UITestNavigation.assertTapTarget(restore)
        UITestNavigation.assertNoOverlap(archivedRow(name, in: app), restore)
        UITestNavigation.saveScreenshot("T20", "archived-list")
        restore.tap()
        XCTAssertTrue(restore.waitForNonExistence(timeout: 5), "RESTORE must take \(name) off the archived list")
        XCTAssertTrue(app.staticTexts.labeled("No archived routines.").waitForExistence(timeout: 5),
                      "The emptied list must say so")

        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(programRow(name, in: app).waitForExistence(timeout: 10), "RESTORE must put \(name) back on Program")
        assertNoArchivedEntry(in: app)
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertTrue(todayGroup(name, in: app).waitForExistence(timeout: 10), "RESTORE must put \(name) back on Today")

        UITestNavigation.relaunch(app)
        XCTAssertTrue(todayGroup(name, in: app).waitForExistence(timeout: 10), "Today must still offer \(name) after a relaunch")
        UITestNavigation.selectTab("Program", in: app)
        XCTAssertTrue(programRow(name, in: app).waitForExistence(timeout: 10), "Program must still list \(name) after a relaunch")
        assertNoArchivedEntry(in: app)
    }

    // MARK: - Deny rule

    /// The routine the active block runs still shows Cannot Archive Routine,
    /// with no confirmation first, and nothing changes: the routine stays
    /// open and on Program, Program offers no Archived routines, and Today
    /// still runs the block.
    @MainActor
    func testArchiveIsStillDeniedWhileTheActiveBlockUsesTheRoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "Live Routine").tap()
        XCTAssertTrue(routineNameField(in: app, value: "Live Routine").waitForExistence(timeout: 10),
                      "Program's row must open Live Routine")

        tapArchiveRoutine(in: app)
        let alert = app.alerts["Cannot Archive Routine"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "A routine the active block uses must show the deny alert")
        XCTAssertFalse(dialogTitle(in: app).exists, "The deny rule must run before the confirmation")
        UITestNavigation.saveScreenshot("T20", "archive-denied")
        alert.buttons["OK"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "OK must close the alert")
        XCTAssertTrue(routineNameField(in: app, value: "Live Routine").exists, "A denied archive must leave the routine open")

        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(programRow("Live Routine", in: app).waitForExistence(timeout: 10),
                      "Program must still list Live Routine")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "ACTIVE block: Live Block"))
                        .firstMatch.exists, "Live Block must stay active")
        assertNoArchivedEntry(in: app)
        UITestNavigation.selectTab("Today", in: app)
        XCTAssertTrue(app.staticTexts.labeled("LIVE BLOCK").waitForExistence(timeout: 10),
                      "Today must still run Live Block")
    }

    // MARK: - A block that uses an archived routine

    /// Once Live Block ends, its routine can be archived. The ended block
    /// keeps working: Program still lists it and its overview opens. The
    /// routine waits on ARCHIVED ROUTINES and stays out of New Block's
    /// routine picker.
    @MainActor
    func testEndedBlockKeepsWorkingAfterItsRoutineIsArchived() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        endLiveBlock(in: app)

        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "Live Routine").tap()
        XCTAssertTrue(routineNameField(in: app, value: "Live Routine").waitForExistence(timeout: 10),
                      "Program's row must open Live Routine")
        archiveOpenRoutine(in: app)
        XCTAssertTrue(routineNameField(in: app, value: "Live Routine").waitForNonExistence(timeout: 5),
                      "A routine only an ended block uses must archive")
        XCTAssertFalse(programRow("Live Routine", in: app).exists, "Program must not list Live Routine")

        let ended = app.buttons.labeled("DONE block: Live Block")
        XCTAssertTrue(ended.waitForExistence(timeout: 10), "Program must still list the ended block")
        ended.tap()
        XCTAssertTrue(app.staticTexts.labeled("Block · Live Block").waitForExistence(timeout: 10),
                      "The ended block's overview must still open")
        UITestNavigation.hittable(app.buttons, "Back").tap()

        let entry = archivedEntry(in: app)
        scrollProgram(toward: entry, in: app)
        XCTAssertTrue(entry.exists, "Program must offer the archived routine")
        entry.tap()
        UITestNavigation.hittable(app.buttons, "Restore Live Routine", exactLabel: true)
        UITestNavigation.hittable(app.buttons, "Back").tap()

        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New block").tap()
        UITestNavigation.hittable(app.buttons, "Blank Block").tap()
        XCTAssertTrue(app.staticTexts.labeled("NEW BLOCK").waitForExistence(timeout: 10), "New Block never opened")
        UITestNavigation.revealAboveBottomBar(app.buttons, "+ ATTACH ▸", in: app).tap()
        XCTAssertTrue(app.staticTexts.labeled("Choose Routine").waitForExistence(timeout: 5),
                      "+ ATTACH ▸ must open the routine picker")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Live Routine"))
                        .firstMatch.exists, "New Block's routine picker must leave the archived routine out")
    }

    // MARK: - Helpers

    /// Makes a routine on Program with + NEW, as `makeRoutine(from:in:)`
    /// does, and leaves it open on Program.
    @MainActor
    private func makeRoutineOnProgram(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> String {
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW", file: file, line: line).tap()
        return makeRoutine(
            from: UITestNavigation.hittable(app.buttons, "+ New routine", file: file, line: line),
            in: app, file: file, line: line
        )
    }

    /// Makes a routine the way a user does: `newRoutine` opens the name
    /// step, a typed name and SAVE open the routine, and + Add session adds
    /// the seeded session. The routine stays open. Returns its name.
    @MainActor
    private func makeRoutine(
        from newRoutine: XCUIElement, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) -> String {
        let name = "Upper Lower"
        newRoutine.tap()
        UITestNavigation.type(name, into: app.textFields["newRoutine.name"], file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true, file: file, line: line).tap()
        XCTAssertTrue(app.textFields["newRoutine.name"].waitForNonExistence(timeout: 10), "SAVE must leave the name step",
                      file: file, line: line)
        let field = routineNameField(in: app, value: name)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "+ New routine must open the new routine", file: file, line: line)
        let picker = app.staticTexts.labeled("Existing sessions")
        UITestNavigation.hittable(app.buttons, "+ Add session", file: file, line: line).tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "+ Add session must list the existing sessions", file: file, line: line)
        UITestNavigation.hittable(app.buttons, Self.session, file: file, line: line).tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Adding \(Self.session) must close the session picker",
                      file: file, line: line)
        return name
    }

    /// The open routine's name field, whose value begins with `value`.
    @MainActor
    private func routineNameField(in app: XCUIApplication, value: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label ==[c] %@ AND value BEGINSWITH %@", "Routine name", value
        )).firstMatch
    }

    /// Taps Archive routine at the bottom of the open routine.
    @MainActor
    private func tapArchiveRoutine(in app: XCUIApplication) {
        let archive = app.buttons.labeled("Archive routine")
        UITestNavigation.reveal(archive, in: app)
        archive.tap()
    }

    /// Taps Archive routine and confirms with the dialog's Archive.
    /// `testArchiveAsksFirstAndKeepRoutineKeepsIt` proves the dialog; here a
    /// build that archives at once goes on, so the checks after it still run.
    @MainActor
    private func archiveOpenRoutine(in app: XCUIApplication) {
        tapArchiveRoutine(in: app)
        let confirm = app.buttons.labeled("Archive")
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        }
    }

    @MainActor
    private func dialogTitle(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled("Archive routine?")
    }

    /// Program's ROUTINES row, read as "Upper Lower, 1 sessions".
    @MainActor
    private func programRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    /// Today's Start a workout heading for a routine's sessions.
    @MainActor
    private func todayGroup(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.labeled(name)
    }

    @MainActor
    private func archivedEntry(in app: XCUIApplication) -> XCUIElement {
        app.buttons.labeled("Archived routines")
    }

    /// An ARCHIVED ROUTINES row's name and session count, read as
    /// "Upper Lower, 1 session".
    @MainActor
    private func archivedRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    /// Swipes Program up until `element` is on screen, or for `maxSwipes`
    /// swipes, so the caller's assertion says what is missing.
    @MainActor
    private func scrollProgram(toward element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            app.scrollViews.allElementsBoundByIndex.last(where: \.isHittable)?.swipeUp(velocity: .slow)
        }
    }

    /// Program, scrolled to its end, offers no Archived routines entry.
    @MainActor
    private func assertNoArchivedEntry(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<2 {
            app.scrollViews.allElementsBoundByIndex.last(where: \.isHittable)?.swipeUp(velocity: .slow)
        }
        XCTAssertFalse(archivedEntry(in: app).exists, "Program must offer Archived routines only while one is archived",
                       file: file, line: line)
    }

    /// Ends Live Block from Today's band and puts off its review, as
    /// BlockLifecycleEntryPointsUITests does.
    @MainActor
    private func endLiveBlock(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.selectTab("Today", in: app)
        let band = app.staticTexts.labeled("LIVE BLOCK")
        XCTAssertTrue(band.waitForExistence(timeout: 10), "Today must show the active block's band", file: file, line: line)
        band.tap()
        UITestNavigation.hittable(app.buttons, "END BLOCK", file: file, line: line).tap()
        let alert = app.alerts["End block?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "END BLOCK must ask first", file: file, line: line)
        alert.buttons["End Block"].tap()
        XCTAssertTrue(app.buttons.labeled("END BLOCK").waitForNonExistence(timeout: 5), "The block must end",
                      file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Back", file: file, line: line).tap()
        let review = app.staticTexts.labeled("Block review")
        UITestNavigation.hittable(app.buttons, "Plan custom", file: file, line: line).tap()
        XCTAssertTrue(review.waitForNonExistence(timeout: 5), "Plan custom must close the review", file: file, line: line)
    }
}
