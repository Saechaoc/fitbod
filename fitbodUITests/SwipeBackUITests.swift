import XCTest

/// Ticket T18, review items 35 and 43. An edge swipe from the left goes back
/// one screen on every pushed screen, the same as the screen's own back
/// control, in every tab and in the Settings sheet. The app hides the system
/// navigation bar to draw its BRU headers, and UIKit's back swipe does not
/// start under a hidden bar, so an edge swipe on Plate Inventory did nothing.
/// On a stack's root screen the swipe does nothing. The block overview showed
/// the system back button above its BRU ‹ BACK.
///
/// Each swipe test opens one screen the way a user does, swipes back with
/// `UITestNavigation.swipeBack(in:)`, and checks that the screen closes and
/// the control that opened it shows again where it was. No pushed screen
/// asks before it leaves: the editors that ask (the routine builder, the
/// block builder and the custom exercise editor) open as sheets. An
/// exercise's history and its chart open on Library's stack (T96); before,
/// VIEW ALL HISTORY returned to the Library list (see the T18 notes).
///
/// Ticket T106, finding F183. A sideways drag that started and ended on a
/// full-width row pressed it, so an edge swipe on a root screen that
/// started on a row opened the row. Program's template rows, History's
/// rows, the PR rows and Library's rows now open only on a tap: a touch
/// that moves more than 10pt before it lifts opens nothing, and a drag up
/// that starts on a row still scrolls. At AX3 a History row keeps its
/// weekday whole (finding F187).
final class SwipeBackUITests: XCTestCase {
    /// The control `open` tapped last, and where it sat.
    private var lastOpened: (control: XCUIElement, frame: CGRect)?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Today

    @MainActor
    func testWorkoutSwipesBackToToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let resume = app.buttons["resumeSlab.resume"]
        open(resume, in: app)
        assertSwipeBack(from: logger(in: app), "the workout logger", to: resume, in: app)
    }

    @MainActor
    func testHistorySwipesBackToToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let sessions = app.buttons["today.sessions"]
        open(sessions, in: app)
        assertSwipeBack(from: historyRow(in: app), "History", to: sessions, in: app)
    }

    @MainActor
    func testWorkoutSummarySwipesBackToHistory() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        open(app.buttons["today.sessions"], in: app)
        let row = historyRow(in: app)
        open(row, in: app)
        assertSwipeBack(from: summary(in: app), "the workout summary", to: row, in: app)
    }

    @MainActor
    func testMuscleDetailSwipesBackToToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        let bar = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", "Chest:", "sets this week,"
        )).firstMatch
        open(bar, in: app)
        let detail = app.staticTexts.labeled("Contributing Exercises")
        assertSwipeBack(from: detail, "the chest's volume detail", to: bar, in: app)
    }

    @MainActor
    func testBlockOverviewSwipesBackToToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        let band = app.staticTexts.labeled("LIVE BLOCK")
        open(band, in: app)
        assertSwipeBack(from: endBlock(in: app), "the block overview", to: band, in: app)
    }

    /// + New routine opens the name step (T21); no routine exists until SAVE.
    @MainActor
    func testNewRoutineSwipesBackToToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        let newRoutine = app.buttons["+ New routine"]
        open(newRoutine, in: app)
        assertSwipeBack(from: nameStep(in: app), "the new routine's name step", to: newRoutine, in: app)
    }

    /// SAVE puts the routine's editor in the name step's place, so a swipe
    /// from the editor goes back to Today.
    @MainActor
    func testSavedRoutineSwipesBackToToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        open(app.buttons["+ New routine"], in: app)
        nameNewRoutine(in: app)
        assertSwipeBack(from: addSession(in: app), "the new routine", to: app.buttons["today.sessions"], in: app)
    }

    /// Today lists a routine's sessions when nothing is scheduled, and a
    /// session opens its detail on Today's stack.
    @MainActor
    func testSessionFromTodaySwipesBackToToday() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        open(app.buttons["+ New routine"], in: app)
        nameNewRoutine(in: app)
        open(addSession(in: app), in: app)
        let existing = button(beginningWith: "Bench & Squat", in: app)
        XCTAssertTrue(existing.waitForExistence(timeout: 10), "Add session must list the seeded session")
        existing.tap()
        XCTAssertTrue(addSession(in: app).waitForExistence(timeout: 10), "Adding the session must close the sheet")
        UITestNavigation.hittable(app.buttons, "Back").tap()

        let session = button(beginningWith: "Bench & Squat", in: app)
        open(session, in: app)
        assertSwipeBack(from: startWorkout(in: app), "the session", to: session, in: app)
    }

    // MARK: - Program

    @MainActor
    func testBlockOverviewSwipesBackToProgram() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        let card = button(beginningWith: "ACTIVE block: Live Block", in: app)
        open(card, in: app)
        assertSwipeBack(from: endBlock(in: app), "the block overview", to: card, in: app)
    }

    @MainActor
    func testRoutineSwipesBackToProgram() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        let card = button(beginningWith: "Live Routine", in: app)
        open(card, in: app)
        assertSwipeBack(from: app.buttons["Session 1: Live Push"], "the routine", to: card, in: app)
    }

    /// The routine's + ADD SESSION marks it: the session row stays scaled
    /// down after the tap that opens it (see the T18 notes).
    @MainActor
    func testSessionSwipesBackToRoutine() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        open(button(beginningWith: "Live Routine", in: app), in: app)
        open(app.buttons["Session 1: Live Push"], in: app)
        assertSwipeBack(from: startWorkout(in: app), "the session", to: addSession(in: app), in: app)
    }

    @MainActor
    func testStartedWorkoutSwipesBackToSession() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        UITestNavigation.selectTab("Program", in: app)
        open(button(beginningWith: "Live Routine", in: app), in: app)
        open(app.buttons["Session 1: Live Push"], in: app)
        let start = startWorkout(in: app)
        open(start, in: app)
        assertSwipeBack(from: logger(in: app), "the workout logger", to: start, in: app)
    }

    @MainActor
    func testResumedWorkoutSwipesBackToProgram() throws {
        let app = UITestNavigation.launch(UITestNavigation.seededWorkout)
        UITestNavigation.selectTab("Program", in: app)
        let resume = app.buttons.labeled("Resume ▸")
        open(resume, in: app)
        assertSwipeBack(from: logger(in: app), "the workout logger", to: resume, in: app)
    }

    /// + NEW's + New routine opens the name step on Program's stack (T21).
    @MainActor
    func testNewRoutineSwipesBackToProgram() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New routine").tap()
        assertSwipeBack(from: nameStep(in: app), "the new routine's name step", to: app.staticTexts["PROGRAM"], in: app)
    }

    /// Program lists archived routines once one is archived (T20).
    @MainActor
    func testArchivedRoutinesSwipeBackToProgram() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New routine").tap()
        nameNewRoutine(in: app)
        open(app.buttons.labeled("Archive routine"), in: app)
        UITestNavigation.hittable(app.buttons, "Archive", exactLabel: true).tap()
        let archived = app.buttons.labeled("Archived routines")
        open(archived, in: app)
        let restore = button(beginningWith: "Restore ", in: app)
        assertSwipeBack(from: restore, "Archived routines", to: archived, in: app)
    }

    // MARK: - Progress

    @MainActor
    func testHistorySwipesBackToProgress() throws {
        let app = openProgress()
        let workouts = app.buttons["progress.history"]
        open(workouts, in: app)
        assertSwipeBack(from: historyRow(in: app), "History", to: workouts, in: app)
    }

    @MainActor
    func testWorkoutSummarySwipesBackToProgressHistory() throws {
        let app = openProgress()
        open(app.buttons["progress.history"], in: app)
        let row = historyRow(in: app)
        open(row, in: app)
        assertSwipeBack(from: summary(in: app), "the workout summary", to: row, in: app)
    }

    @MainActor
    func testExerciseChartSwipesBackToProgress() throws {
        let app = openProgress()
        let bench = button(beginningWith: "Barbell Bench Press", in: app)
        open(bench, in: app)
        assertSwipeBack(from: chart(in: app), "the bench press's chart", to: bench, in: app)
    }

    @MainActor
    func testWeeklyTonnageSwipesBackToProgress() throws {
        let app = openProgress()
        let tonnage = button(beginningWith: "Weekly Tonnage", in: app)
        open(tonnage, in: app)
        assertSwipeBack(from: tonnageChart(in: app), "Weekly Tonnage", to: tonnage, in: app)
    }

    /// A swipe that starts on the muscle chips, a row that scrolls
    /// sideways, goes back too, as it does where the system bar shows.
    @MainActor
    func testSwipeOnWeeklyTonnagesChipsSwipesBackToProgress() throws {
        let app = openProgress()
        let tonnage = button(beginningWith: "Weekly Tonnage", in: app)
        open(tonnage, in: app)
        assertSwipeBack(from: tonnageChart(in: app), "Weekly Tonnage", to: tonnage, in: app,
                        alongRowOf: button(beginningWith: "Abdominals", in: app))
    }

    /// A tap on the tonnage chart opens that week's workouts.
    @MainActor
    func testWeekDetailSwipesBackToWeeklyTonnage() throws {
        let app = openProgress()
        open(button(beginningWith: "Weekly Tonnage", in: app), in: app)
        let chart = tonnageChart(in: app)
        XCTAssertTrue(chart.waitForExistence(timeout: 10), "Weekly Tonnage must open")
        UITestNavigation.waitUntilStill(chart, interval: 0.3)
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let week = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Week of ")).firstMatch
        assertSwipeBack(from: week, "the week's workouts", to: chart, in: app)
    }

    @MainActor
    func testPersonalRecordsSwipeBackToProgress() throws {
        let app = openProgress()
        let records = button(beginningWith: "Personal Records", in: app)
        open(records, in: app)
        assertSwipeBack(from: recordRow(in: app), "Personal Records", to: records, in: app)
    }

    @MainActor
    func testRecordSessionSwipesBackToPersonalRecords() throws {
        let app = openProgress()
        open(button(beginningWith: "Personal Records", in: app), in: app)
        let record = recordRow(in: app)
        open(record, in: app)
        let session = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Session of ")).firstMatch
        assertSwipeBack(from: session, "the record's session", to: record, in: app)
    }

    @MainActor
    func testWeekComparisonSwipesBackToProgress() throws {
        let app = openProgress()
        let compare = button(beginningWith: "This week vs last week", in: app)
        open(compare, in: app)
        let comparison = app.staticTexts.matching(NSPredicate(
            format: "label == %@ OR label ==[c] %@", "Δ", "No comparable session"
        )).firstMatch
        assertSwipeBack(from: comparison, "the week comparison", to: compare, in: app)
    }

    // MARK: - Library

    @MainActor
    func testExerciseSwipesBackToLibrary() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        let bench = benchPressRow(in: app)
        open(bench, in: app)
        assertSwipeBack(from: viewAllHistory(in: app), "the bench press", to: bench, in: app)
    }

    @MainActor
    func testExerciseChartSwipesBackToExercise() throws {
        let app = openBenchPress()
        let viewChart = button(beginningWith: "View progress chart", in: app)
        open(viewChart, in: app)
        assertSwipeBack(from: chart(in: app), "the bench press's chart", to: viewChart, in: app)
    }

    /// Ticket T96. VIEW ALL HISTORY opens the bench press's history, with
    /// its PR count and PROGRESS, and PROGRESS opens its chart, both on
    /// Library's stack. VIEW ALL HISTORY went back to the Library list,
    /// because the history pushed a stack of its own. ‹ BACK twice returns
    /// to the bench press.
    @MainActor
    func testExerciseHistoryAndItsChartOpenOnLibrarysStack() throws {
        let app = openBenchPress()
        let viewAll = viewAllHistory(in: app)
        open(viewAll, in: app)
        let prs = historyPRs(in: app)
        XCTAssertTrue(prs.waitForExistence(timeout: 10), "VIEW ALL HISTORY must open the bench press's history")
        UITestNavigation.waitUntilStill(prs, interval: 0.3)
        XCTAssertTrue(waitUntilHittable(prs, timeout: 2), "The history must stay open, not go back to the Library list")
        // The seed's four bench workouts are all from the last 30 days, and
        // ten of their thirteen work sets beat the records before them.
        XCTAssertEqual(prs.value as? String, "10", "PRs · 30d must count the bench press's PR sets")
        let progress = historyProgress(in: app)
        XCTAssertTrue(waitUntilHittable(progress), "The history must offer PROGRESS")
        UITestNavigation.saveScreenshot("T96", "exercise-history")

        open(progress, in: app)
        let progressChart = chart(in: app)
        XCTAssertTrue(progressChart.waitForExistence(timeout: 10), "PROGRESS must open the bench press's chart")
        UITestNavigation.waitUntilStill(progressChart, interval: 0.3)
        XCTAssertTrue(waitUntilHittable(progressChart, timeout: 2), "The chart must stay open")

        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(waitUntilHittable(progress), "‹ BACK on the chart must return to the history")
        XCTAssertTrue(prs.exists, "‹ BACK on the chart must return to the history")
        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(waitUntilHittable(viewAll), "‹ BACK on the history must return to the bench press")
    }

    /// T96: the history opens on Library's stack, so it swipes back.
    @MainActor
    func testExerciseHistorySwipesBackToExercise() throws {
        let app = openBenchPress()
        let viewAll = viewAllHistory(in: app)
        open(viewAll, in: app)
        assertSwipeBack(from: historyPRs(in: app), "the bench press's history", to: viewAll, in: app)
    }

    /// T96: the history's PROGRESS pushes its chart on Library's stack.
    @MainActor
    func testHistoryChartSwipesBackToHistory() throws {
        let app = openBenchPress()
        open(viewAllHistory(in: app), in: app)
        let progress = historyProgress(in: app)
        open(progress, in: app)
        assertSwipeBack(from: chart(in: app), "the history's chart", to: progress, in: app)
    }

    // MARK: - Settings

    /// Review item 35: the swipe did nothing on Plate Inventory.
    @MainActor
    func testPlateInventorySwipesBackToSettings() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let inventory = app.buttons.labeled("Plate Inventory")
        open(inventory, in: app)
        let plates = app.otherElements["plateInventory.tabStrip"]
        assertSwipeBack(from: plates, "Plate Inventory", to: inventory, in: app)
    }

    @MainActor
    func testVolumeTargetsSwipeBackToSettings() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let targets = button(beginningWith: "Volume Targets", in: app)
        open(targets, in: app)
        assertSwipeBack(from: button(beginningWith: "Chest", in: app), "Volume Targets", to: targets, in: app)
    }

    @MainActor
    func testComponentGallerySwipesBackToSettings() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let gallery = app.buttons["settings.componentGallery"]
        open(gallery, in: app)
        assertSwipeBack(from: app.staticTexts["gallery.lastAction"], "the component gallery", to: gallery, in: app)
    }

    /// A swipe let go early springs back. Plate Inventory, which hides the
    /// system bar over Settings, which shows it, stays drawn as it was, and
    /// its Done ▸ still goes back.
    @MainActor
    func testSwipeLetGoEarlyLeavesTheScreenAsItWas() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.openSettings(in: app)
        let inventory = app.buttons.labeled("Plate Inventory")
        open(inventory, in: app)
        let plates = app.otherElements["plateInventory.tabStrip"]
        XCTAssertTrue(plates.waitForExistence(timeout: 10), "Plate Inventory must open")
        _ = inventory.waitForNonExistence(timeout: 5)
        UITestNavigation.waitUntilStill(plates, interval: 0.3)
        let before = plates.frame

        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 1, dy: 0))
        let short = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: short, withVelocity: .slow, thenHoldForDuration: 0.5)
        UITestNavigation.waitUntilStill(plates, interval: 0.3)
        UITestNavigation.saveScreenshot("T18", "plate-inventory-after-short-swipe")
        XCTAssertTrue(plates.isHittable, "A swipe let go early must leave Plate Inventory on screen")
        XCTAssertEqual(plates.frame, before, "A swipe let go early must leave Plate Inventory where it was")
        assertNoSystemBar("Plate Inventory", in: app)

        UITestNavigation.hittable(app.buttons, "Done ▸").tap()
        XCTAssertTrue(plates.waitForNonExistence(timeout: 10), "Done ▸ must still close Plate Inventory")
        XCTAssertTrue(waitUntilHittable(inventory), "Done ▸ must return to Settings")
    }

    // MARK: - Root screens

    /// On each tab's first screen and on Settings, an edge swipe does
    /// nothing: the screen stays where it was, and it still opens its next
    /// screen and comes back, so nothing is stuck or half drawn. The swipe
    /// runs along the header. Lower down it would start on a full-width
    /// row, and a drag that starts on a row presses it, with or without
    /// the back swipe.
    @MainActor
    func testSwipeOnARootScreenDoesNothing() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)

        let sessions = app.buttons["today.sessions"]
        assertRootIgnoresSwipe(sessions, alongRowOf: app.staticTexts["Fitbod / Today"], "Today", in: app)
        UITestNavigation.saveScreenshot("T18", "today-after-root-swipe")
        assertStillNavigates(from: sessions, to: app.staticTexts["No sessions yet"], in: app)

        UITestNavigation.selectTab("Program", in: app)
        let program = app.staticTexts["PROGRAM"]
        assertRootIgnoresSwipe(program, alongRowOf: program, "Program", in: app)
        UITestNavigation.hittable(app.buttons, "+ NEW").tap()
        UITestNavigation.hittable(app.buttons, "+ New routine").tap()
        assertBackControlReturns(from: nameStep(in: app), to: program, in: app)

        UITestNavigation.selectTab("Progress", in: app)
        let workouts = app.buttons["progress.history"]
        assertRootIgnoresSwipe(workouts, alongRowOf: headerTitle("Progress", in: app), "Progress", in: app)
        assertStillNavigates(from: workouts, to: app.staticTexts["No sessions yet"], in: app)

        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        assertRootIgnoresSwipe(search, alongRowOf: headerTitle("Library", in: app), "Library", in: app)
        UITestNavigation.type("Barbell Bench Press", into: search, replacing: false)
        let bench = benchPressName(in: app)
        assertStillNavigates(from: bench, to: viewAllHistory(in: app), in: app)

        UITestNavigation.openSettings(in: app)
        let close = app.buttons["Close"]
        assertRootIgnoresSwipe(close, alongRowOf: close, "Settings", in: app)
        UITestNavigation.saveScreenshot("T18", "settings-after-root-swipe")
        let inventory = app.buttons.labeled("Plate Inventory")
        open(inventory, in: app)
        UITestNavigation.hittable(app.buttons, "Done ▸").tap()
        XCTAssertTrue(app.otherElements["plateInventory.tabStrip"].waitForNonExistence(timeout: 10),
                      "Done must close Plate Inventory after a swipe on Settings")
        XCTAssertTrue(waitUntilHittable(inventory), "Settings must show again after Plate Inventory closes")
    }

    // MARK: - Rows open only on a tap

    /// Program is a root screen, so the drag starts 1pt in, where an edge
    /// swipe starts.
    @MainActor
    func testSidewaysDragOnATemplateRowOpensNothing() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Program", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+W, .*")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Program must list its templates")
        UITestNavigation.reveal(row, in: app)
        let newBlock = app.staticTexts.labeled("NEW BLOCK")
        assertSidewaysDragOpensNothing(row, from: 1, "a template row", opening: newBlock, in: app)
        assertTapOpens(row, newBlock, "a template row")
    }

    /// History is a pushed screen, so the drag starts 40pt in, clear of
    /// the edge swipe back.
    @MainActor
    func testSidewaysDragOnAHistoryRowOpensNothing() throws {
        let app = openProgress()
        open(app.buttons["progress.history"], in: app)
        let row = historyRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "History must list the seeded workouts")
        assertSidewaysDragOpensNothing(row, from: 40, "a History row", opening: summary(in: app), in: app)
        assertTapOpens(row, summary(in: app), "a History row")
    }

    /// Personal Records is a pushed screen, so the drag starts 40pt in.
    @MainActor
    func testSidewaysDragOnARecordRowOpensNothing() throws {
        let app = openProgress()
        open(button(beginningWith: "Personal Records", in: app), in: app)
        let records = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Weight PR, "))
        // The third row, low enough to stay on screen once a drag up has
        // scrolled the list.
        let row = records.element(boundBy: 2)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Personal Records must list the seeded records")
        let session = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Session of ")).firstMatch
        assertSidewaysDragOpensNothing(row, from: 40, "a record row", opening: session, in: app)
        assertDragUpScrolls(from: row, "a record row", opening: session, in: app)
        assertTapOpens(row, session, "a record row")
    }

    /// Library is a root screen, so the drag starts 1pt in.
    @MainActor
    func testSidewaysDragOnALibraryRowOpensNothing() throws {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        UITestNavigation.selectTab("Library", in: app)
        // The fourth row, low enough to stay on screen once a drag up has
        // scrolled the list.
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Logged ")).element(boundBy: 3)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Library must list the catalog")
        let exercise = viewAllHistory(in: app)
        assertSidewaysDragOpensNothing(row, from: 1, "a Library row", opening: exercise, in: app)
        assertDragUpScrolls(from: row, "a Library row", opening: exercise, in: app)
        assertTapOpens(row, exercise, "a Library row")
    }

    /// Finding F187: at AX3 a History row broke its weekday in its 64pt
    /// date column, "WED" as "WE" over "D". At accessibility sizes the row
    /// stacks its date over its name and total, so the weekday reads whole
    /// on one line.
    @MainActor
    func testHistoryRowKeepsItsWeekdayWholeAtAX3() throws {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory, textSize: .ax3)
        UITestNavigation.selectTab("Progress", in: app)
        open(app.buttons["progress.history"], in: app)
        let row = historyRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "History must list the seeded workouts")
        revealWhole(row, in: app)
        UITestNavigation.saveScreenshot("T106", "history-row", textSize: .ax3)

        // The row reads its date as "Sunday, October 25"; it draws "SUN 25".
        let weekday = try shortWeekday(in: row.label)
        let date = row.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", weekday + " ")).firstMatch
        XCTAssertTrue(date.exists, "The row must draw its date, \(weekday) and the day, in \(row.label)")
        UITestNavigation.assertNotTallerThanWide(date)
        let text = try UITestNavigation.readText(in: row.frame, of: XCUIScreen.main.screenshot())
        XCTAssertTrue(text.split(separator: " ").contains { $0 == weekday },
                      "The row must draw \(weekday) whole on one line, but reads \"\(text)\"")
    }

    // MARK: - Block overview header

    /// Review item 43: the block overview showed the system back button
    /// above its BRU ‹ BACK. It shows one back control, and its header sits
    /// at the top of the screen, where Today's header sits.
    @MainActor
    func testBlockOverviewShowsOneBackControlAtTheTop() throws {
        let app = UITestNavigation.launch(UITestNavigation.activeBlock)
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "Today must show its header")
        let todayHeaderBottom = settings.frame.maxY

        let band = app.staticTexts.labeled("LIVE BLOCK")
        open(band, in: app)
        XCTAssertTrue(endBlock(in: app).waitForExistence(timeout: 10), "The band must open the block overview")
        UITestNavigation.waitUntilStill(endBlock(in: app), interval: 0.3)
        UITestNavigation.saveScreenshot("T18", "block-overview-header")
        assertOneBackControl(onTopBelow: todayHeaderBottom, in: app)

        UITestNavigation.hittable(app.buttons, "Back").tap()
        XCTAssertTrue(waitUntilHittable(band), "‹ BACK must return to Today")

        UITestNavigation.selectTab("Program", in: app)
        open(button(beginningWith: "ACTIVE block: Live Block", in: app), in: app)
        XCTAssertTrue(endBlock(in: app).waitForExistence(timeout: 10), "The card must open the block overview")
        UITestNavigation.waitUntilStill(endBlock(in: app), interval: 0.3)
        assertOneBackControl(onTopBelow: todayHeaderBottom, in: app)
    }

    // MARK: - Screens

    @MainActor
    private func logger(in app: XCUIApplication) -> XCUIElement {
        app.otherElements["workout.header"]
    }

    @MainActor
    private func historyRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "history.row").firstMatch
    }

    @MainActor
    private func summary(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts["WORKOUT COMPLETE"]
    }

    @MainActor
    private func endBlock(in app: XCUIApplication) -> XCUIElement {
        app.buttons.labeled("END BLOCK")
    }

    /// The routine screen's + ADD SESSION.
    @MainActor
    private func addSession(in app: XCUIApplication) -> XCUIElement {
        app.buttons.labeled("+ Add session")
    }

    /// The name field of the step + New routine opens.
    @MainActor
    private func nameStep(in app: XCUIApplication) -> XCUIElement {
        app.textFields["newRoutine.name"]
    }

    /// Names the routine on its name step and saves it, which opens the
    /// routine's editor in the step's place. It returns once the step has
    /// left the accessibility tree, at the end of that transition: a swipe
    /// during it does nothing (T96 saw one fail in six runs on the small
    /// phone).
    @MainActor
    private func nameNewRoutine(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        UITestNavigation.type("Upper Lower", into: nameStep(in: app), file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Save", exactLabel: true, file: file, line: line).tap()
        XCTAssertTrue(addSession(in: app).waitForExistence(timeout: 10), "SAVE must open the routine", file: file, line: line)
        _ = nameStep(in: app).waitForNonExistence(timeout: 5)
    }

    /// The session screen's START WORKOUT ▸.
    @MainActor
    private func startWorkout(in app: XCUIApplication) -> XCUIElement {
        app.buttons.labeled("Start workout ▸")
    }

    /// An exercise's progress chart, by its first chip.
    @MainActor
    private func chart(in app: XCUIApplication) -> XCUIElement {
        app.buttons["e1RM"]
    }

    @MainActor
    private func tonnageChart(in app: XCUIApplication) -> XCUIElement {
        app.otherElements["weeklyTonnage.chart"]
    }

    @MainActor
    private func recordRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Weight PR, ")).firstMatch
    }

    /// The exercise screen's VIEW ALL HISTORY row.
    @MainActor
    private func viewAllHistory(in app: XCUIApplication) -> XCUIElement {
        button(beginningWith: "View all history", in: app)
    }

    /// An exercise's history, by its PRs · 30d cell, whose value is the count.
    @MainActor
    private func historyPRs(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "PRs · 30d")).firstMatch
    }

    /// The history header's PROGRESS, not the Progress tab.
    @MainActor
    private func historyProgress(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@ AND identifier != %@", "PROGRESS", "Progress")).firstMatch
    }

    @MainActor
    private func button(beginningWith label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", label)).firstMatch
    }

    @MainActor
    private func benchPressName(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Barbell Bench Press - Medium Grip")).firstMatch
    }

    // MARK: - Navigation

    @MainActor
    private func openProgress() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        UITestNavigation.selectTab("Progress", in: app)
        return app
    }

    /// Library, searched for the bench press, whose row is returned.
    @MainActor
    private func benchPressRow(in app: XCUIApplication) -> XCUIElement {
        UITestNavigation.selectTab("Library", in: app)
        let search = app.textFields["library.search.browser"]
        UITestNavigation.type("Barbell Bench Press", into: search, replacing: false)
        return benchPressName(in: app)
    }

    /// The seeded bench press's exercise screen in Library.
    @MainActor
    private func openBenchPress() -> XCUIApplication {
        let app = UITestNavigation.launch(UITestNavigation.progressHistory)
        open(benchPressRow(in: app), in: app)
        XCTAssertTrue(viewAllHistory(in: app).waitForExistence(timeout: 10), "The bench press must open")
        return app
    }

    /// Scrolls `control` into view and taps it once it can be tapped.
    @MainActor
    private func open(_ control: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.waitForExistence(timeout: 15), "Missing \(control)", file: file, line: line)
        UITestNavigation.reveal(control, in: app)
        XCTAssertTrue(waitUntilHittable(control), "\(control) cannot be tapped", file: file, line: line)
        lastOpened = (control, control.frame)
        control.tap()
    }

    /// `UITestNavigation.swipeBack(in:)` along the row of `row` instead of
    /// across the middle of the screen.
    @MainActor
    private func swipeBack(alongRowOf row: XCUIElement, in app: XCUIApplication) {
        let y = row.frame.midY
        let screen = app.coordinate(withNormalizedOffset: .zero)
        screen.withOffset(CGVector(dx: 1, dy: y)).press(
            forDuration: 0.05, thenDragTo: screen.withOffset(CGVector(dx: app.frame.width * 0.8, dy: y)),
            withVelocity: .default, thenHoldForDuration: 0
        )
    }

    /// Waits until `element` has left the screen: it is gone, or something
    /// covers it. Volume Targets' rows stay in the accessibility tree for
    /// seconds after it closes, by its ‹ as well.
    @MainActor
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            if !element.exists || !element.isHittable { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date.now < deadline
        return false
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }

    // MARK: - Checks

    /// Waits for the pushed screen, marked by `screen`, to settle, swipes
    /// back from the left edge, across the middle of the screen or along the
    /// row of `row`, and checks that the screen closes and `opener`, the
    /// control that opened it, can be tapped again, where it was when `open`
    /// tapped it.
    @MainActor
    private func assertSwipeBack(
        from screen: XCUIElement, _ name: String, to opener: XCUIElement, in app: XCUIApplication,
        alongRowOf row: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(screen.waitForExistence(timeout: 15), "\(name) never opened", file: file, line: line)
        // A swipe during a push does nothing, and XCUI reports where views
        // end up, not where they are mid-push. The screen under leaves the
        // accessibility tree once the push is over.
        _ = opener.waitForNonExistence(timeout: 5)
        UITestNavigation.waitUntilStill(screen, interval: 0.3)
        if let row {
            swipeBack(alongRowOf: row, in: app)
        } else {
            UITestNavigation.swipeBack(in: app)
        }
        XCTAssertTrue(waitUntilGone(screen),
                      "An edge swipe on \(name) must go back, but \(name) is still on screen", file: file, line: line)
        XCTAssertTrue(waitUntilHittable(opener, timeout: 5),
                      "The swipe must go back to the screen that opened \(name)", file: file, line: line)
        if let lastOpened, lastOpened.control === opener {
            UITestNavigation.waitUntilStill(opener, interval: 0.3)
            XCTAssertEqual(opener.frame.minX, lastOpened.frame.minX, accuracy: 1,
                           "The screen under \(name) must come back where it was", file: file, line: line)
            XCTAssertEqual(opener.frame.minY, lastOpened.frame.minY, accuracy: 1,
                           "The screen under \(name) must come back where it was", file: file, line: line)
        }
    }

    /// Swipes from the left edge of a root screen, marked by `root`, along
    /// the row of `header`, an element of its header, and checks that the
    /// screen stays put.
    @MainActor
    private func assertRootIgnoresSwipe(
        _ root: XCUIElement, alongRowOf header: XCUIElement, _ name: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(waitUntilHittable(root), "\(name) must show", file: file, line: line)
        XCTAssertTrue(header.exists, "\(name) must show its header", file: file, line: line)
        let before = root.frame
        let barsBefore = systemBars(in: app)
        swipeBack(alongRowOf: header, in: app)
        UITestNavigation.waitUntilStill(root, interval: 0.3)
        XCTAssertTrue(root.exists && root.isHittable, "A swipe on \(name) must leave it on screen", file: file, line: line)
        XCTAssertEqual(root.frame, before, "A swipe on \(name) must not move it", file: file, line: line)
        XCTAssertEqual(systemBars(in: app), barsBefore, "A swipe on \(name) must not show or hide a system bar",
                       file: file, line: line)
    }

    /// A tab's header title, not the tab bar cell's label.
    @MainActor
    private func headerTitle(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let titles = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", title))
        return titles.allElementsBoundByIndex.first { $0.frame.maxY < app.frame.midY } ?? titles.firstMatch
    }

    /// Taps `control` and checks that the next screen, marked by `next`,
    /// opens and its back control returns to `control`.
    @MainActor
    private func assertStillNavigates(
        from control: XCUIElement, to next: XCUIElement, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        open(control, in: app, file: file, line: line)
        assertBackControlReturns(from: next, to: control, in: app, file: file, line: line)
    }

    @MainActor
    private func assertBackControlReturns(
        from screen: XCUIElement, to previous: XCUIElement, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "The next screen must open after a swipe on the root", file: file, line: line)
        UITestNavigation.hittable(app.buttons, "Back", file: file, line: line).tap()
        XCTAssertTrue(screen.waitForNonExistence(timeout: 10), "‹ BACK must close the next screen", file: file, line: line)
        XCTAssertTrue(waitUntilHittable(previous), "‹ BACK must return to the root", file: file, line: line)
    }

    /// Where the system navigation bars on screen sit.
    @MainActor
    private func systemBars(in app: XCUIApplication) -> [CGRect] {
        app.navigationBars.allElementsBoundByIndex.filter(\.isHittable).map(\.frame)
    }

    /// BRU screens draw their own header, so no system navigation bar shows.
    @MainActor
    private func assertNoSystemBar(
        _ name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let bars = systemBars(in: app)
        XCTAssertTrue(bars.isEmpty, "\(name) must not show the system navigation bar, but shows \(bars)",
                      file: file, line: line)
    }

    /// One back control, the BRU ‹ BACK, no system navigation bar, and the
    /// header's top row level with Today's: it starts above the bottom of
    /// Today's header, where a system bar would push it down.
    @MainActor
    private func assertOneBackControl(
        onTopBelow todayHeaderBottom: CGFloat, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let backs = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Back")).allElementsBoundByIndex
        XCTAssertEqual(backs.count, 1, "The block overview must show one back control, but shows \(backs.count): \(backs.map(\.frame))",
                       file: file, line: line)
        assertNoSystemBar("The block overview", in: app, file: file, line: line)
        let back = UITestNavigation.hittable(app.buttons, "Back", file: file, line: line)
        XCTAssertLessThan(back.frame.minY, todayHeaderBottom,
                          "‹ BACK must sit in the top row, level with Today's header, but starts at \(back.frame.minY)",
                          file: file, line: line)
    }

    // MARK: - Row checks

    /// Drags from `inset` points inside the left edge of `row`, along its
    /// middle, 200pt to the right, and checks that the drag opens nothing:
    /// `destination` never shows, and the row stays where it was.
    @MainActor
    private func assertSidewaysDragOpensNothing(
        _ row: XCUIElement, from inset: CGFloat, _ name: String, opening destination: XCUIElement,
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(waitUntilHittable(row), "\(name) cannot be dragged", file: file, line: line)
        UITestNavigation.waitUntilStill(row, interval: 0.3)
        let before = row.frame
        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: before.minX + inset, dy: before.midY))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 200, dy: 0)),
                    withVelocity: .default, thenHoldForDuration: 0)
        // A row opens its screen as the finger lifts, so a screen the drag
        // opened shows well within this wait; nothing showing takes all of it.
        XCTAssertFalse(destination.waitForExistence(timeout: 2),
                       "A sideways drag on \(name) must not open it", file: file, line: line)
        XCTAssertTrue(row.isHittable, "A sideways drag on \(name) must leave it on screen", file: file, line: line)
        XCTAssertEqual(row.frame, before, "A sideways drag on \(name) must leave it where it was", file: file, line: line)
    }

    /// Drags up 200pt from the middle of `row`, and checks that the list
    /// scrolls with the finger and the drag opens nothing.
    @MainActor
    private func assertDragUpScrolls(
        from row: XCUIElement, _ name: String, opening destination: XCUIElement,
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let before = row.frame
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: before.midX, dy: before.midY))
        // Held before it lifts, so the list stops under the finger.
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -200)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
        UITestNavigation.waitUntilStill(row, interval: 0.3)
        XCTAssertFalse(destination.exists, "A drag up that starts on \(name) must not open it", file: file, line: line)
        XCTAssertLessThan(row.frame.minY, before.minY - 100,
                          "A drag up that starts on \(name) must scroll the list, but it moved from \(before) to \(row.frame)",
                          file: file, line: line)
    }

    /// Taps `row` and checks that it opens `destination`.
    @MainActor
    private func assertTapOpens(
        _ row: XCUIElement, _ destination: XCUIElement, _ name: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(waitUntilHittable(row), "\(name) cannot be tapped", file: file, line: line)
        row.tap()
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "A tap on \(name) must open it", file: file, line: line)
    }

    /// Drags a pushed screen until `element` shows whole between its
    /// header and the tab bar.
    @MainActor
    private func revealWhole(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let top = app.buttons["Back"].firstMatch.frame.maxY + 4
        let bottom = UITestNavigation.tab("Today", in: app).frame.minY - 4
        for _ in 0..<6 {
            let frame = element.frame
            if frame.minY >= top && frame.maxY <= bottom { return }
            let drag = max(-300, min(300, (top + bottom) / 2 - frame.midY))
            let startY = drag > 0 ? top + 20 : bottom - 20
            UITestNavigation.dragLogger(from: startY, to: startY + drag, in: app)
            UITestNavigation.waitUntilStill(element)
        }
        XCTFail("\(element) must show whole between the header at \(top) and the tab bar at \(bottom)", file: file, line: line)
    }

    /// The weekday a History row draws, such as "SUN", from its label,
    /// which reads the weekday in full, such as "Sunday".
    private func shortWeekday(in label: String) throws -> String {
        let calendar = Calendar.current
        let parts = label.components(separatedBy: ", ")
        let index = try XCTUnwrap(parts.lazy.compactMap { calendar.weekdaySymbols.firstIndex(of: $0) }.first,
                                  "The row must read its weekday: \(label)")
        return calendar.shortWeekdaySymbols[index].uppercased()
    }
}
