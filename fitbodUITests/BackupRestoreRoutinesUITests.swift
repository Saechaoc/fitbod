import XCTest

/// T41: Settings CREATE and RESTORE must replace the routine graph from a
/// real Files backup. A model test cannot prove the share/import wiring or
/// the stored graph after the app's restore restart. Data-integrity smoke,
/// not a width-sensitive layout test.
final class BackupRestoreRoutinesUITests: XCTestCase {
    private static let routine = "Live Routine"
    private static let changedRoutine = "Changed After Backup"
    private static let session = "Live Push"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // XCUIApplication and the shared navigation helpers require the main actor.
    @MainActor
    func testSettingsBackupRestoresRoutineAndSessionAfterRestart() throws {
        let app = UITestNavigation.launch(
            UITestNavigation.freshStore + ["-fitbod-seed-active-block"]
        )
        UITestNavigation.openSettings(in: app)
        let backupName = saveBackupToFiles(in: app)
        tap(app.buttons["Close"])

        UITestNavigation.selectTab("Program", in: app)
        tap(routineRow(Self.routine, in: app))
        let name = app.textFields.matching(NSPredicate(
            format: "label ==[c] %@", "Routine name"
        )).firstMatch
        UITestNavigation.type(Self.changedRoutine, into: name)
        tap(app.buttons.labeled("Back"))
        let changed = routineRow(Self.changedRoutine, in: app)
        XCTAssertTrue(changed.exists || changed.waitForExistence(timeout: 5),
                      "A saved edit after CREATE must be visible before restoring")
        XCTAssertFalse(routineRow(Self.routine, in: app).exists)

        UITestNavigation.openSettings(in: app)
        let restore = app.buttons.labeled("Restore")
        UITestNavigation.reveal(restore, in: app)
        tap(restore)
        pickFile(backupName, in: app)
        let confirm = app.alerts["Restore from backup?"]
        XCTAssertTrue(confirm.exists || confirm.waitForExistence(timeout: 10))
        tap(confirm.buttons["Restore"])
        let complete = app.alerts["Restore complete"]
        XCTAssertTrue(complete.exists || complete.waitForExistence(timeout: 15),
                      "Restoring over an existing routine must finish without a save error or crash")
        tap(complete.buttons["OK"])
        // The production restore flow exits with status zero to reopen the
        // container. Wait for that real lifecycle boundary before relaunching.
        XCTAssertTrue(app.state == .notRunning || app.wait(for: .notRunning, timeout: 10))
        UITestNavigation.relaunch(app)

        UITestNavigation.selectTab("Program", in: app)
        let restored = routineRow(Self.routine, in: app)
        XCTAssertTrue(restored.exists || restored.waitForExistence(timeout: 10),
                      "RESTORE must put the original routine back on Program")
        XCTAssertFalse(routineRow(Self.changedRoutine, in: app).exists,
                       "RESTORE must replace the edited routine rather than leave it beside the backup")
        // Required T41 evidence: a reviewer checks the restored Program row.
        UITestNavigation.saveScreenshot("T41", "restored-routines")
        tap(restored)
        let session = app.buttons.labeled("Session 1: \(Self.session)")
        XCTAssertTrue(session.exists || session.waitForExistence(timeout: 5),
                      "The restored routine must retain its ordered session link")
    }

    @MainActor
    private func saveBackupToFiles(in app: XCUIApplication) -> String {
        let create = app.buttons.labeled("Create")
        UITestNavigation.reveal(create, in: app)
        tap(create)
        let saveToFiles = app.cells.labeled("Save to Files")
        tap(saveToFiles)

        let save = app.buttons.labeled("Save")
        XCTAssertTrue(save.exists || save.waitForExistence(timeout: 15), "Files must offer Save")
        let nameField = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(nameField.exists || nameField.waitForExistence(timeout: 5),
                      "Files must show the backup filename")
        let name = "fitbod-t41-\(UUID().uuidString.prefix(8))"
        nameField.tap()
        let focused = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: nameField
        )
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed)
        // Files selects the whole suggested name when its name field takes focus.
        nameField.typeText(name)
        XCTAssertEqual(nameField.value as? String, name)
        tap(save)
        XCTAssertTrue(!nameField.exists || nameField.waitForNonExistence(timeout: 10),
                      "Files must close after saving the backup")
        return name
    }

    @MainActor
    private func pickFile(_ name: String, in app: XCUIApplication) {
        let file = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@", name
        )).firstMatch
        // Recents or the last folder usually contains the file. If Files
        // starts elsewhere, use its visible Browse > On My iPhone route.
        if !(file.exists || file.waitForExistence(timeout: 5)) {
            tap(app.buttons.labeled("Browse"))
            let onMyPhone = app.descendants(matching: .any).matching(NSPredicate(
                format: "label ==[c] %@", "On My iPhone"
            )).firstMatch
            tap(onMyPhone)
        }
        tap(file)
    }

    @MainActor
    private func routineRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    @MainActor
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 10), file: file, line: line)
        if !element.isHittable {
            // Files and share-sheet rows can exist before their presentation finishes.
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: element)
            XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 5), .completed,
                           "The intended control must be tappable", file: file, line: line)
        }
        element.tap()
    }
}
