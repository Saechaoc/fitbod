import XCTest

/// Review item 20: the custom exercise editor was a stock iOS form, with a
/// slider and a segmented role picker on every muscle, and its muscle picker
/// was a stock list under a system navigation bar. Both are BRU screens now.
/// The picker shows each muscle's name alone, so Lower Back no longer reads
/// "Upper", and a copy of the bench press lists its primary muscle, Chest,
/// above its secondary ones.
final class CustomExerciseEditorBRUUITests: XCTestCase {

    private static let benchPress = "Barbell Bench Press - Medium Grip"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Repro

    /// A copy of the bench press has three muscles, so the stock editor
    /// drew a slider and a role picker for each, beside the Mechanic picker.
    /// The detail screen under the sheet keeps its own switch, so the check
    /// reads the editor sheet alone.
    @MainActor
    func testEditorHasNoStockControls() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openCopy(of: Self.benchPress, in: app)
        UITestNavigation.saveScreenshot("T32", "editor-copy")

        let editor = editorSheet(in: app)
        XCTAssertEqual(editor.sliders.count, 0, "The editor must not draw a stock slider")
        XCTAssertEqual(editor.segmentedControls.count, 0, "The editor must not draw a stock segmented control")
        XCTAssertEqual(editor.switches.count, 0, "The editor must not draw a stock switch")
    }

    @MainActor
    func testMusclePickerHasNoNavigationBar() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNewExercise(in: app)
        openMusclePicker(in: app)
        UITestNavigation.saveScreenshot("T32", "picker")

        XCTAssertFalse(app.navigationBars.firstMatch.exists, "The muscle picker must be a BRU sheet with no navigation bar")
    }

    /// Each row reads the muscle's name alone, and the rows run in name order.
    @MainActor
    func testMusclePickerRowsShowOnlyTheMuscleName() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNewExercise(in: app)
        openMusclePicker(in: app)

        let lowerBack = app.buttons["musclePicker.lower back"]
        XCTAssertTrue(lowerBack.waitForExistence(timeout: 10))
        XCTAssertEqual(lowerBack.label, "Lower Back", "A picker row must show only the muscle's name")

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "musclePicker."))
            .allElementsBoundByIndex
            .sorted { $0.frame.minY < $1.frame.minY }
        let labels = rows.map(\.label)
        XCTAssertEqual(labels.count, 17, "The picker must list all 17 muscles")
        XCTAssertEqual(labels, labels.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                       "The picker must list muscles by name")
    }

    /// The launch that imports the catalog keeps each exercise's muscles in
    /// import order, primary first. Every later launch reads them back from
    /// the store in a new order, the way a returning user meets them, so the
    /// test checks the copy after several launches.
    @MainActor
    func testCopyListsThePrimaryMuscleFirst() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        for launch in 1...4 {
            UITestNavigation.relaunch(app)
            openCopy(of: Self.benchPress, in: app)
            UITestNavigation.saveScreenshot("T32", "editor-copy-launch-\(launch)")

            let chest = editorText("Chest", in: app)
            let triceps = editorText("Triceps", in: app)
            let shoulders = editorText("Shoulders", in: app)
            XCTAssertLessThan(chest.frame.minY, triceps.frame.minY,
                              "Launch \(launch): Chest, the primary muscle, must sit above Triceps")
            XCTAssertLessThan(chest.frame.minY, shoulders.frame.minY,
                              "Launch \(launch): Chest, the primary muscle, must sit above Shoulders")
        }
    }

    // MARK: - Acceptance

    /// A new exercise with one primary and one secondary muscle saves, and
    /// after a relaunch EDIT reopens it with both roles and weights.
    @MainActor
    func testSavedMusclesReopenWithTheirRolesAndWeights() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let exerciseName = "T32 Landmine Press"
        openNewExercise(in: app)
        UITestNavigation.type(exerciseName, into: app.textFields["customExercise.name"])
        addMuscle("chest", in: app)
        addMuscle("triceps", in: app)
        // Triceps starts at the secondary default, 50%; a tick sets 25%.
        tapTick("triceps", percent: 25, in: app)
        assertMuscle("chest", role: "Primary", percent: 100, in: app)
        assertMuscle("triceps", role: "Secondary", percent: 25, in: app)
        XCTAssertEqual(status(in: app), "Valid, 1 primary mapped. Ready to save.")
        UITestNavigation.saveScreenshot("T32", "editor-new-before-save")

        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["customExercise.name"].waitForNonExistence(timeout: 5), "SAVE must close the editor")

        // A relaunch reads the exercise back from the store.
        UITestNavigation.relaunch(app)
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        UITestNavigation.type(exerciseName, into: search, replacing: false, pressingReturn: false)
        let row = app.staticTexts[exerciseName]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The saved exercise must be in the Library")
        row.tap()
        UITestNavigation.hittable(app.buttons, "Edit", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["customExercise.name"].waitForExistence(timeout: 10), "EDIT must open the editor")
        XCTAssertEqual(app.textFields["customExercise.name"].value as? String, exerciseName)

        assertMuscle("chest", role: "Primary", percent: 100, in: app)
        assertMuscle("triceps", role: "Secondary", percent: 25, in: app)
        let secondaryHead = editorText("Secondary stimulus", in: app)
        XCTAssertLessThan(muscleRow("chest", in: app).frame.maxY, secondaryHead.frame.minY,
                          "Chest must sit in the primary section")
        XCTAssertLessThan(secondaryHead.frame.maxY, muscleRow("triceps", in: app).frame.minY,
                          "Triceps must sit in the secondary section")
        XCTAssertTrue(app.staticTexts.labeled("Edit exercise").exists, "EDIT must title the editor Edit exercise")
        let delete = app.buttons.labeled("Delete exercise")
        UITestNavigation.reveal(delete, in: app)
        UITestNavigation.saveScreenshot("T32", "editor-edit-reopened")
    }

    /// A role chip moves its muscle to the other section, and each section
    /// lists its muscles heaviest first.
    @MainActor
    func testRoleChipMovesTheMuscleAndSectionsSortByWeight() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openCopy(of: Self.benchPress, in: app)

        tapTick("triceps", percent: 75, in: app)
        XCTAssertLessThan(muscleRow("triceps", in: app).frame.minY, muscleRow("shoulders", in: app).frame.minY,
                          "Triceps at 75% must sit above Shoulders at 50%")

        let shouldersRole = app.buttons["customExercise.role.shoulders"]
        XCTAssertEqual(shouldersRole.label.lowercased(), "secondary")
        shouldersRole.tap()
        XCTAssertEqual(shouldersRole.label.lowercased(), "primary", "The chip must switch the role")
        let secondaryHead = editorText("Secondary stimulus", in: app)
        XCTAssertLessThan(muscleRow("chest", in: app).frame.minY, muscleRow("shoulders", in: app).frame.minY,
                          "Chest at 100% must sit above Shoulders at 50% in the primary section")
        XCTAssertLessThan(muscleRow("shoulders", in: app).frame.maxY, secondaryHead.frame.minY,
                          "A primary muscle must move above the secondary section")
        XCTAssertLessThan(secondaryHead.frame.maxY, muscleRow("triceps", in: app).frame.minY)
        assertMuscle("shoulders", role: "Primary", percent: 50, in: app)
        XCTAssertEqual(status(in: app), "Valid, 2 primary mapped. Ready to save.")
        UITestNavigation.saveScreenshot("T32", "editor-role-switched")
    }

    /// The footer says what the draft still needs, by today's save rules: a
    /// name, and a primary muscle at 0.5 or more.
    @MainActor
    func testStatusLineSaysWhatIsMissing() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNewExercise(in: app)
        XCTAssertEqual(status(in: app), "Needs a name and a primary muscle. Can't save yet.")
        UITestNavigation.saveScreenshot("T32", "editor-new-empty")

        UITestNavigation.type("T32 Status Probe", into: app.textFields["customExercise.name"])
        XCTAssertEqual(status(in: app), "Needs a primary muscle. Can't save yet.")

        addMuscle("chest", in: app)
        XCTAssertEqual(status(in: app), "Valid, 1 primary mapped. Ready to save.")

        tapTick("chest", percent: 25, in: app)
        XCTAssertEqual(status(in: app), "Needs a primary at 0.5 or more. Can't save yet.")
        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true).tap()
        XCTAssertTrue(editorText("A primary muscle needs a weight of 0.5 or more to save.", in: app).exists,
                      "SAVE on a light primary must say why it cannot save")
        XCTAssertTrue(app.textFields["customExercise.name"].exists, "SAVE must keep an invalid draft open")
    }

    /// Equipment opens a BRU list with no navigation bar; Mechanic is a BRU
    /// segmented control.
    @MainActor
    func testEquipmentOpensABRUListAndMechanicIsSegmented() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        openNewExercise(in: app)

        let equipment = app.buttons["customExercise.equipment"]
        XCTAssertEqual(equipment.value as? String, "Barbell")
        equipment.tap()
        let dumbbell = app.buttons["customExercise.equipment.dumbbell"]
        XCTAssertTrue(dumbbell.waitForExistence(timeout: 10), "Equipment must open its list")
        XCTAssertTrue(app.staticTexts.labeled("Equipment").exists)
        XCTAssertFalse(app.navigationBars.firstMatch.exists, "The equipment list must be a BRU sheet")
        XCTAssertTrue(app.buttons["customExercise.equipment.barbell"].isSelected, "The list must mark the current kind")
        UITestNavigation.saveScreenshot("T32", "equipment-list")
        dumbbell.tap()
        XCTAssertTrue(dumbbell.waitForNonExistence(timeout: 5), "Picking a kind must close the list")
        XCTAssertEqual(equipment.value as? String, "Dumbbell")

        let isolation = UITestNavigation.hittable(editorSheet(in: app).buttons, "Isolation", exactLabel: true)
        isolation.tap()
        XCTAssertTrue(isolation.isSelected, "Mechanic must select Isolation")
    }

    /// The editor and the picker fit the screen at default text and AX3.
    /// Screenshots carry the phone's appearance, so a dark run covers dark.
    @MainActor
    func testEditorAndPickerFitTheScreen() throws {
        let appearance: UITestNavigation.Appearance = XCUIDevice.shared.appearance == .dark ? .dark : .light
        for textSize in [UITestNavigation.TextSize.default, .ax3] {
            let app = UITestNavigation.launch(UITestNavigation.freshStore, textSize: textSize)
            openCopy(of: Self.benchPress, in: app)
            let editor = editorSheet(in: app)
            UITestNavigation.saveScreenshot("T32", "editor", textSize: textSize, appearance: appearance)

            // The copy's long name shrinks to fit rather than ending in "…".
            let nameField = app.textFields["customExercise.name"]
            let shownName = try UITestNavigation.readText(
                in: nameField.frame.insetBy(dx: -4, dy: -4), of: XCUIScreen.main.screenshot()
            )
            XCTAssertTrue(lettersAndDigits(shownName).contains("COPY"),
                          "The name field must show the copy's whole name, but it reads \"\(shownName)\"")
            assertFitsWidth(nameField, in: app)
            assertFitsWidth(editor.buttons.labeled("Cancel"), in: app)
            assertFitsWidth(editor.buttons.labeled("Save"), in: app)
            assertFitsWidth(app.buttons["customExercise.equipment"], in: app)
            for mechanic in ["Compound", "Isolation"] {
                assertFitsWidth(editor.buttons.labeled(mechanic), in: app)
            }
            for slug in ["chest", "triceps", "shoulders"] {
                let role = app.buttons["customExercise.role.\(slug)"]
                let remove = app.buttons["customExercise.remove.\(slug)"]
                let percent = app.staticTexts["customExercise.percent.\(slug)"]
                for control in [role, remove, percent] {
                    assertFitsWidth(control, in: app)
                }
                UITestNavigation.assertTapTarget(role)
                UITestNavigation.assertTapTarget(remove)
                UITestNavigation.assertNoOverlap(role, remove)
                for tick in [25, 50, 75, 100] {
                    let button = app.buttons["customExercise.weight.\(slug).\(tick)"]
                    assertFitsWidth(button, in: app)
                    UITestNavigation.assertTapTarget(button)
                    UITestNavigation.assertNoOverlap(button, percent)
                }
            }
            let status = app.descendants(matching: .any)["customExercise.status"]
            assertFitsWidth(status, in: app)

            let add = app.buttons.labeled("Add Another Muscle")
            UITestNavigation.reveal(add, in: app)
            assertFitsWidth(add, in: app)
            UITestNavigation.assertTapTarget(add)
            UITestNavigation.saveScreenshot("T32", "editor-end", textSize: textSize, appearance: appearance)

            add.tap()
            let lowerBack = app.buttons["musclePicker.lower back"]
            XCTAssertTrue(lowerBack.waitForExistence(timeout: 10), "The muscle picker must open")
            assertFitsWidth(lowerBack, in: app)
            UITestNavigation.assertTapTarget(lowerBack)
            UITestNavigation.saveScreenshot("T32", "picker", textSize: textSize, appearance: appearance)
            app.terminate()
        }
    }

    // MARK: - Helpers

    /// Library search → the exercise's detail screen → COPY.
    @MainActor
    private func openCopy(of exerciseName: String, in app: XCUIApplication) {
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        UITestNavigation.type(exerciseName, into: search, replacing: false, pressingReturn: false)
        let row = app.staticTexts[exerciseName]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Missing Library row: \(exerciseName)")
        row.tap()
        UITestNavigation.hittable(app.buttons, "Copy", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["customExercise.name"].waitForExistence(timeout: 10), "COPY must open the editor")
    }

    /// Library "+ New" → an empty editor.
    @MainActor
    private func openNewExercise(in app: XCUIApplication) {
        UITestNavigation.selectTab("Library", in: app)
        UITestNavigation.hittable(app.buttons, "+ New", exactLabel: true).tap()
        XCTAssertTrue(app.textFields["customExercise.name"].waitForExistence(timeout: 10), "+ NEW must open the editor")
    }

    /// The add-muscle control reads "Add Primary Muscle" until the exercise
    /// has a primary muscle.
    @MainActor
    private func openMusclePicker(in app: XCUIApplication) {
        let add = UITestNavigation.hittable(app.buttons, "Add Primary Muscle", exactLabel: true)
        add.tap()
        XCTAssertTrue(app.buttons["musclePicker.chest"].waitForExistence(timeout: 10), "The muscle picker must open")
    }

    /// A text in the editor sheet, not on the detail screen under it.
    @MainActor
    private func editorText(_ label: String, in app: XCUIApplication) -> XCUIElement {
        let text = editorSheet(in: app).staticTexts.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 10), "The editor must show \(label)")
        return text
    }

    /// The sheet on top: the editor, unless a picker is open over it.
    @MainActor
    private func editorSheet(in app: XCUIApplication) -> XCUIElement {
        let sheet = UITestNavigation.topSheet(in: app)
        XCTAssertNotNil(sheet, "The editor must be a sheet")
        return sheet ?? app
    }

    /// "+ ADD MUSCLE" → the picker → `slug`'s row, scrolled into view.
    @MainActor
    private func addMuscle(_ slug: String, in app: XCUIApplication) {
        let add = app.buttons.matching(NSPredicate(
            format: "label IN %@", ["Add Primary Muscle", "Add Another Muscle"]
        )).firstMatch
        UITestNavigation.reveal(add, in: app)
        add.tap()
        let row = app.buttons["musclePicker.\(slug)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The muscle picker must open")
        UITestNavigation.reveal(row, in: app)
        row.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "Picking a muscle must close the picker")
    }

    /// A muscle row's container, identified by the muscle's slug.
    @MainActor
    private func muscleRow(_ slug: String, in app: XCUIApplication) -> XCUIElement {
        let row = app.descendants(matching: .any)["customExercise.muscle.\(slug)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The editor must list \(slug)")
        return row
    }

    @MainActor
    private func tapTick(_ slug: String, percent: Int, in app: XCUIApplication) {
        let tick = app.buttons["customExercise.weight.\(slug).\(percent)"]
        UITestNavigation.reveal(tick, in: app)
        tick.tap()
        XCTAssertTrue(tick.isSelected, "The \(percent)% tick must hold \(slug)'s weight")
    }

    /// The row's chip reads its role, its percent reads its weight, and the
    /// matching tick is the selected one.
    @MainActor
    private func assertMuscle(
        _ slug: String, role: String, percent: Int, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let chip = app.buttons["customExercise.role.\(slug)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "The editor must list \(slug)", file: file, line: line)
        // BRU labels reach accessibility uppercased.
        XCTAssertEqual(chip.label.lowercased(), role.lowercased(), "\(slug)'s role", file: file, line: line)
        XCTAssertEqual(app.staticTexts["customExercise.percent.\(slug)"].label, "\(percent)%",
                       "\(slug)'s weight", file: file, line: line)
        XCTAssertTrue(app.buttons["customExercise.weight.\(slug).\(percent)"].isSelected,
                      "\(slug)'s \(percent)% tick must be selected", file: file, line: line)
    }

    /// What the status footer says, as VoiceOver reads it.
    @MainActor
    private func status(in app: XCUIApplication) -> String {
        let footer = app.descendants(matching: .any)["customExercise.status"]
        XCTAssertTrue(footer.waitForExistence(timeout: 10), "The editor must show its status line")
        return footer.label
    }

    /// The element sits within the screen's width.
    @MainActor
    private func assertFitsWidth(
        _ element: XCUIElement, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing \(element)", file: file, line: line)
        let screen = app.windows.firstMatch.frame
        let frame = element.frame
        let name = element.identifier.isEmpty ? element.label : element.identifier
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(name) starts off the screen: \(frame)", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(name) runs off the screen: \(frame)", file: file, line: line)
    }

    /// Text read off the screen, reduced to its letters and digits.
    private func lettersAndDigits(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber })
    }
}
