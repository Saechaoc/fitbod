import XCTest

final class TodayStateRoutesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyRoutineRepairReturnsToTheSavedRoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.hittable(app.buttons, "Plan a routine or block").tap()
        UITestNavigation.type("First split", into: app.textFields["newRoutine.name"])
        UITestNavigation.hittable(app.buttons, "Save").tap()
        UITestNavigation.hittable(app.buttons, "Back").tap()
        let repair = app.buttons["today.repair"]
        XCTAssertTrue(UITestNavigation.appears(repair))
        UITestNavigation.saveScreenshot("RM006", "empty-routine-repair")
        repair.tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["Routine name"]))
        XCTAssertEqual(app.textFields["Routine name"].value as? String, "First split")
    }

    @MainActor
    func testEveryDoneWorkoutOpensItsOwnSummary() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore + ["-fitbod-seed-today-done"])
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "doneToday.view."))
        XCTAssertTrue(UITestNavigation.appears(rows.firstMatch))
        XCTAssertEqual(rows.count, 2)
        for name in ["Pull A", "Push A"] {
            let row = rows.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
            XCTAssertTrue(row.exists)
            row.tap()
            XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Workout complete")))
            XCTAssertTrue(app.staticTexts.labeled(name).exists)
            UITestNavigation.hittable(app.buttons, "Back").tap()
        }
    }

    @MainActor
    func testReadyBlockFailureCanRetryAndSurvivesRelaunch() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore
            + ["-fitbod-seed-today-ready", "-fitbod-fail-block-start-once"])
        let start = app.buttons["today.startBlock"]
        XCTAssertTrue(UITestNavigation.appears(start))
        start.tap()
        XCTAssertTrue(UITestNavigation.appears(app.alerts["Couldn't start block"]))
        app.alerts.buttons["Try again"].tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("NEXT UP · 1 OF 3")))
        UITestNavigation.relaunch(app)
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("NEXT UP · 1 OF 3")))
        XCTAssertFalse(app.buttons["today.startBlock"].exists)
    }

    @MainActor
    func testReadyBlockFailureCanOpenItsPlan() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore
            + ["-fitbod-seed-today-ready", "-fitbod-fail-block-start-once"])
        let open = app.buttons["today.openReadyBlock"]
        XCTAssertTrue(UITestNavigation.appears(open))
        UITestNavigation.assertTapTarget(open)
        open.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("Edit")))
        UITestNavigation.hittable(app.buttons, "Back").tap()
        let start = app.buttons["today.startBlock"]
        XCTAssertTrue(UITestNavigation.appears(start))
        start.tap()
        XCTAssertTrue(UITestNavigation.appears(app.alerts["Couldn't start block"]))
        app.alerts.buttons["Open block"].tap()
        XCTAssertTrue(UITestNavigation.appears(app.buttons.labeled("Edit")))
        XCTAssertTrue(app.staticTexts.labeled("Spring Block").exists)
    }

    @MainActor
    func testEmptyScheduledSessionCanOpenRepairAndDiscardAnAlternateStart() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore + ["-fitbod-seed-today-empty"])
        let repair = app.buttons["today.repair"]
        XCTAssertTrue(UITestNavigation.appears(repair))
        XCTAssertFalse(app.buttons.labeled("Start workout ▸").exists)
        repair.tap()
        XCTAssertTrue(UITestNavigation.appears(app.staticTexts.labeled("Session")))
        XCTAssertTrue(app.staticTexts.labeled("Push B").exists)
        UITestNavigation.hittable(app.buttons, "Back").tap()
        startPullAndDiscard(in: app)
        XCTAssertTrue(UITestNavigation.appears(repair))
    }

    @MainActor
    func testRestAndMissingRoutineKeepAlternateStartAccess() throws {
        for state in ["rest", "attach"] {
            let app = UITestNavigation.launch(UITestNavigation.freshStore + ["-fitbod-seed-today-\(state)"])
            startPullAndDiscard(in: app)
            XCTAssertTrue(UITestNavigation.appears(app.buttons["today.chooseSession"]))
        }
    }

    @MainActor
    private func startPullAndDiscard(in app: XCUIApplication) {
        let choose = app.buttons["today.chooseSession"]
        XCTAssertTrue(UITestNavigation.appears(choose))
        choose.tap()
        let pull = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH[c] %@", "sessionSheet.start.", "Pull A"
        )).firstMatch
        XCTAssertTrue(UITestNavigation.appears(pull))
        pull.tap()
        XCTAssertTrue(UITestNavigation.appears(app.textFields["set.reps.1.S1"]))
        UITestNavigation.hittable(app.buttons, "Back").tap()
        let discard = app.buttons["resumeSlab.discard"]
        XCTAssertTrue(UITestNavigation.appears(discard))
        discard.tap()
        XCTAssertTrue(UITestNavigation.disappears(app.buttons["resumeSlab.resume"]))
    }
}
