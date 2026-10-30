import XCTest

/// Review item 34: one tap on Export CSV, Export JSON or backup CREATE opens
/// the share sheet. The first tap used to render the file and the second
/// tap shared it. Nothing is shared: each check closes the sheet.
///
/// Review item 14: the backup footer fills CREATE, not RESTORE, and
/// RESTORE still asks before it replaces any data.
final class SettingsExportUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testExportCSVOpensShareSheetOnFirstTap() throws {
        assertOneTapOpensShareSheet(NSPredicate(format: "label CONTAINS[c] %@", "Export CSV"), named: "Export CSV")
    }

    @MainActor
    func testExportJSONOpensShareSheetOnFirstTap() throws {
        assertOneTapOpensShareSheet(NSPredicate(format: "label CONTAINS[c] %@", "Export JSON"), named: "Export JSON")
    }

    @MainActor
    func testCreateBackupOpensShareSheetOnFirstTap() throws {
        assertOneTapOpensShareSheet(NSPredicate(format: "label ==[c] %@", "Create"), named: "backup CREATE")
    }

    /// The ticket's bar: the share sheet's Save to Files row is up within
    /// 5 s of the tap. The clock starts before `tap()`, which also waits
    /// for the app to settle after the tap.
    @MainActor
    private func assertOneTapOpensShareSheet(
        _ predicate: NSPredicate, named name: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        UITestNavigation.openSettings(in: app)
        let control = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 10), "Missing \(name)", file: file, line: line)
        UITestNavigation.reveal(control, in: app)
        let tapped = Date.now
        control.tap()

        let saveToFiles = app.cells.labeled("Save to Files")
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 5), "One tap on \(name) must open the share sheet", file: file, line: line)
        let elapsed = Date.now.timeIntervalSince(tapped)
        XCTContext.runActivity(named: String(format: "%@ share sheet up %.1f s after the tap", name, elapsed)) { _ in }
        XCTAssertLessThanOrEqual(
            elapsed, 5,
            String(format: "One tap on %@ must open the share sheet within 5 s, not %.1f s", name, elapsed),
            file: file, line: line
        )
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(name) share sheet"
        shot.lifetime = .keepAlways
        add(shot)

        // Close it without sharing anything, as a user taps outside it.
        let sheet = shareSheet(in: app)
        let outside = app.otherElements["PopoverDismissRegion"]
        XCTAssertTrue(outside.exists, "The share sheet must close on a tap outside it", file: file, line: line)
        outside.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "The share sheet must close", file: file, line: line)
        XCTAssertTrue(control.waitForExistence(timeout: 5), "Settings must still show \(name)", file: file, line: line)
    }

    /// The system share sheet's activity list.
    @MainActor
    private func shareSheet(in app: XCUIApplication) -> XCUIElement {
        app.otherElements.matching(identifier: "ActivityListView").firstMatch
    }

    // MARK: - Backup footer (review item 14)

    /// CREATE is the footer's filled primary. RESTORE, which replaces
    /// data, is the ghost secondary, so it shows the paper, not the signal
    /// fill. The paper tells a light run from a dark one.
    @MainActor
    func testBackupFooterFillsCreateNotRestore() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let create = app.buttons.labeled("Create")
        let restore = app.buttons.labeled("Restore")
        XCTAssertTrue(restore.waitForExistence(timeout: 10), "Missing backup RESTORE")
        UITestNavigation.reveal(restore, in: app)
        XCTAssertTrue(create.isHittable, "Missing backup CREATE")
        UITestNavigation.assertTapTarget(create)
        UITestNavigation.assertTapTarget(restore)
        UITestNavigation.assertNoOverlap(create, restore)

        let screenshot = XCUIScreen.main.screenshot()
        // The panel's bottom padding, above the footer's 2pt rule.
        let panel = CGPoint(x: restore.frame.maxX - 12, y: restore.frame.minY - 8)
        guard let paper = UITestNavigation.color(at: panel, in: screenshot) else {
            return XCTFail("No pixel above RESTORE")
        }
        guard let palette = BackupFooterPalette.matching(paper: paper) else {
            return XCTFail("The backup panel is \(paper), neither light nor dark paper")
        }
        UITestNavigation.saveScreenshot("T08", "backup-footer", appearance: palette.appearance)

        // Beside each centered label, inside the panel's outline.
        let createFill = CGPoint(x: create.frame.minX + 10, y: create.frame.midY)
        let restoreFill = CGPoint(x: restore.frame.maxX - 10, y: restore.frame.midY)
        let problems = [
            UITestNavigation.colorProblem(at: createFill, in: screenshot, is: palette.signal).map { "CREATE: \($0)" },
            UITestNavigation.colorProblem(at: restoreFill, in: screenshot, is: palette.paper).map { "RESTORE: \($0)" },
        ].compactMap { $0 }
        XCTAssertTrue(problems.isEmpty, "CREATE must have the signal fill and RESTORE the paper. " + problems.joined(separator: " "))
    }

    // MARK: - Restore confirmation

    /// RESTORE asks before it replaces anything. The test saves a real
    /// backup to Files, switches Units to kg, and picks that backup: the
    /// confirmation must come up with kg still in place, and backing out
    /// keeps kg.
    @MainActor
    func testRestoreAsksBeforeReplacingData() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let backup = saveBackupToFiles(in: app)

        // Settings opens at the top again, where Units is.
        app.buttons["Close"].tap()
        UITestNavigation.openSettings(in: app)
        let kg = app.buttons.labeled("kg")
        XCTAssertTrue(kg.waitForExistence(timeout: 5), "Missing the kg unit")
        kg.tap()
        XCTAssertTrue(kg.isSelected, "Units must switch to kg")

        let restore = app.buttons.labeled("Restore")
        UITestNavigation.reveal(restore, in: app)
        restore.tap()
        pickFile(backup, in: app)

        let confirm = app.alerts["Restore from backup?"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Picking a backup must ask before restoring it")
        XCTAssertTrue(
            confirm.staticTexts["This will replace all current data with the backup. This cannot be undone."].exists,
            "The confirmation must say that restore replaces all data"
        )
        XCTAssertTrue(kg.isSelected, "Nothing may be replaced before the restore is confirmed")
        UITestNavigation.saveScreenshot("T08", "restore-confirmation")

        // An alert keeps its Cancel button, unlike a confirmation dialog.
        confirm.buttons["Cancel"].tap()
        XCTAssertFalse(app.alerts["Restore complete"].waitForExistence(timeout: 3), "Backing out must not restore")
        XCTAssertTrue(kg.isSelected, "Backing out must keep the current data")
    }

    /// Saves a backup to Files through CREATE's share sheet, the way a
    /// user keeps one, and returns the name it saved under. Files will not
    /// replace a backup saved earlier under the same name, so each run
    /// saves its own.
    @MainActor
    private func saveBackupToFiles(in app: XCUIApplication) -> String {
        let create = app.buttons.labeled("Create")
        XCTAssertTrue(create.waitForExistence(timeout: 10), "Missing backup CREATE")
        UITestNavigation.reveal(create, in: app)
        create.tap()
        XCTAssertTrue(shareSheet(in: app).waitForExistence(timeout: 5), "CREATE must open the share sheet")
        let saveToFiles = app.cells.labeled("Save to Files")
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 5), "The share sheet must offer Save to Files")
        saveToFiles.tap()

        let save = app.buttons.labeled("Save")
        let nameField = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(save.waitForExistence(timeout: 15), "Files must offer Save")
        XCTAssertTrue(nameField.exists, "Files must show the backup's name")
        let suggested = nameField.value as? String ?? ""
        XCTAssertTrue(
            NSPredicate(format: "SELF MATCHES %@", "fitbod-backup-[0-9]{4}-[0-9]{2}-[0-9]{2}").evaluate(with: suggested),
            "Files must suggest the backup's dated name, not \"\(suggested)\""
        )
        let name = "fitbod-backup-\(UUID().uuidString.prefix(8))"
        nameField.tap()
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: nameField)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed, "The name must take the keyboard")
        // Focus selects the whole name, so typing replaces it.
        nameField.typeText(name)
        XCTAssertEqual(nameField.value as? String, name, "Files must save the backup as \(name)")
        save.tap()
        XCTAssertTrue(vanishes(nameField, within: 10), "Files must close after saving")
        return name
    }

    @MainActor
    private func vanishes(_ element: XCUIElement, within timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    /// Picks the file named `name` in the Files picker that RESTORE opens:
    /// in Recents or the folder it showed last, else in On My iPhone.
    @MainActor
    private func pickFile(_ name: String, in app: XCUIApplication) {
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        if !file.waitForExistence(timeout: 10) {
            let browse = app.buttons.labeled("Browse")
            XCTAssertTrue(browse.waitForExistence(timeout: 5), "The Files picker must offer Browse")
            browse.tap()
            let onMyPhone = app.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] %@", "On My iPhone")).firstMatch
            XCTAssertTrue(onMyPhone.waitForExistence(timeout: 10), "Browse must list On My iPhone")
            onMyPhone.tap()
        }
        XCTAssertTrue(file.waitForExistence(timeout: 10), "The Files picker must list \(name)")
        file.tap()
    }
}

/// The backup footer's paper and signal in one appearance.
private struct BackupFooterPalette {
    let appearance: UITestNavigation.Appearance
    let paper: UITestNavigation.RGB
    let signal: UITestNavigation.RGB

    static let light = BackupFooterPalette(appearance: .light, paper: .init(hex: 0xFAFAF7), signal: .init(hex: 0xFF5C1A))
    static let dark = BackupFooterPalette(appearance: .dark, paper: .init(hex: 0x0A0A0A), signal: .init(hex: 0xFF7A3D))

    /// The palette whose paper `paper` is, within the pixel check's tolerance.
    static func matching(paper: UITestNavigation.RGB) -> BackupFooterPalette? {
        [light, dark].first { $0.paper.distance(to: paper) <= 8 }
    }
}
