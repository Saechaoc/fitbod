//
//  WorkoutJourneyUITests.swift
//  fitbodUITests
//
//  The milestone-1 journey, end to end, on a fresh install:
//
//    library search + muscle/equipment filters → exercise detail →
//    custom exercise (validation error, then saved) → routine builder
//    (validation error, name, exercises from the picker, prescription) →
//    start workout → log sets (validation error on an empty set) → rest
//    timer ±15 → TERMINATE + RELAUNCH (workout, logged sets and rest timer
//    come back) → finish → summary → History → rename the routine (the
//    logged workout keeps its snapshot name) → start again: previous
//    performance offered → discard.
//
//  Every step attaches a named screenshot ("J01-…") that CI exports to
//  docs/verification/ci/ui-<device>/.
//

import XCTest

final class WorkoutJourneyUITests: FitbodUITestCase {

    @MainActor
    func testEndToEndWorkoutJourneySurvivesRelaunch() throws {
        var app = launchFitbod(reset: true)
        snapshot(app, "J00-today-first-launch")

        // MARK: Library — search, filter, detail

        XCTContext.runActivity(named: "Search and filter the library") { _ in
            app.tabBars.buttons["Library"].tap()
            let search = waitHittable(app.visibleSearchField)
            search.tap()
            search.typeText("bench press")
            waitExists(app.exerciseRow(named: "Barbell Bench Press - Medium Grip"))
            dismissKeyboard(in: app)
            snapshot(app, "J01-library-search")

            app.buttons["filter.muscle"].tap()
            revealAndTap(app.buttons["filter.option.Chest"], in: app)
            waitHittable(app.buttons["filter.done"]).tap()

            app.buttons["filter.equipment"].tap()
            revealAndTap(app.buttons["filter.option.Barbell"], in: app)
            waitHittable(app.buttons["filter.done"]).tap()

            let resultLine = waitExists(app.element("library.resultCount"))
            XCTAssertTrue(resultLine.label.localizedCaseInsensitiveContains("Chest"), resultLine.label)
            XCTAssertTrue(resultLine.label.localizedCaseInsensitiveContains("Barbell"), resultLine.label)
            snapshot(app, "J02-library-filtered")

            revealAndTap(app.exerciseRow(named: "Barbell Bench Press - Medium Grip"), in: app)
            waitExists(app.element("exercise.detail.title"))
            snapshot(app, "J03-exercise-detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()

            waitHittable(app.buttons["filter.clear"]).tap()
            waitHittable(app.buttons["Clear search"]).tap()
        }

        // MARK: Custom exercise — validation, then save

        XCTContext.runActivity(named: "Create a custom exercise from an empty search") { _ in
            let search = waitHittable(app.visibleSearchField)
            search.tap()
            search.typeText("zercher good morning")
            waitExists(app.element("library.empty"))
            dismissKeyboard(in: app)
            snapshot(app, "J04-library-no-match")

            let create = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Zercher Good Morning")).firstMatch
            waitHittable(create).tap()

            waitHittable(app.buttons["custom.save"]).tap()
            waitExists(app.element("custom.errorSummary"))
            snapshot(app, "J05-custom-exercise-validation")

            revealAndTap(app.buttons["custom.addMuscle"], in: app)
            revealAndTap(app.buttons["muscle.option.hamstrings"], in: app)
            waitHittable(app.buttons["custom.save"]).tap()
            waitGone(app.buttons["custom.save"])

            waitExists(app.exerciseRow(named: "Zercher Good Morning"))
            snapshot(app, "J06-custom-exercise-saved")
            waitHittable(app.buttons["Clear search"]).tap()
        }

        // MARK: Routine builder

        XCTContext.runActivity(named: "Build a routine") { _ in
            app.tabBars.buttons["Routines"].tap()
            waitExists(app.element("routines.empty"))
            snapshot(app, "J07-routines-empty")
            waitHittable(app.buttons["New routine"]).tap()

            waitHittable(app.buttons["builder.save"]).tap()
            waitExists(app.element("builder.errorSummary"))
            snapshot(app, "J08-routine-validation")

            let name = waitHittable(app.textFields["builder.name"])
            name.tap()
            name.typeText("Upper A")

            app.buttons["builder.addExercises"].tap()
            let search = waitHittable(app.visibleSearchField)
            search.tap()
            search.typeText("barbell squat")
            // On small iPhones the keyboard covers the results.
            dismissKeyboard(in: app)
            revealAndTap(app.exerciseRow(named: "Barbell Squat"), in: app)
            waitHittable(app.buttons["Clear search"]).tap()
            app.visibleSearchField.tap()
            app.visibleSearchField.typeText("zercher good")
            dismissKeyboard(in: app)
            revealAndTap(app.exerciseRow(named: "Zercher Good Morning"), in: app)
            waitHittable(app.buttons["picker.add"]).tap()

            // The first added exercise opens expanded on its prescription.
            waitExists(app.element("builder.0.sets"))
            dismissKeyboardTip(in: app)
            dismissKeyboard(in: app)
            snapshot(app, "J09-routine-builder")

            waitHittable(app.buttons["builder.save"]).tap()
            waitExists(app.buttons["routine.start.Upper A"])
            snapshot(app, "J10-routines-list")
        }

        // MARK: Workout — log, validate, rest

        XCTContext.runActivity(named: "Start the workout and log sets") { _ in
            app.buttons["routine.start.Upper A"].tap()
            waitExists(app.element("workout.title"), timeout: 20)
            snapshot(app, "J11-workout-start")

            let weight0 = waitHittable(app.textFields["set.0.0.weight"])
            weight0.tap()
            weight0.typeText("225")
            let reps0 = app.textFields["set.0.0.reps"]
            reps0.tap()
            reps0.typeText("5")
            waitHittable(app.buttons["set.0.0.complete"]).tap()

            waitExists(app.element("rest.dock"))
            XCTAssertEqual(app.buttons["set.0.0.complete"].value as? String, "complete")
            waitHittable(app.buttons["rest.plus15"]).tap()
            snapshot(app, "J12-set-logged-rest-timer")

            // Completing an empty set explains what is missing.
            revealAndTap(app.buttons["set.0.1.complete"], in: app)
            waitExists(app.element("set.0.1.error"))
            snapshot(app, "J13-set-validation-error")

            // Set 1's weight was carried forward; only reps are missing.
            XCTAssertEqual(app.textFields["set.0.1.weight"].value as? String, "225")
            let reps1 = app.textFields["set.0.1.reps"]
            revealAndTap(reps1, in: app)
            reps1.typeText("5")
            revealAndTap(app.buttons["set.0.1.complete"], in: app)
            XCTAssertEqual(app.buttons["set.0.1.complete"].value as? String, "complete")
            dismissKeyboard(in: app)
        }

        // MARK: Relaunch

        XCTContext.runActivity(named: "Terminate and relaunch: the workout comes back") { _ in
            app.terminate()
            app = launchFitbod(reset: false, waitForTabs: false)
            waitExists(app.element("workout.title"), timeout: 60, "The active workout did not reopen after relaunch")
            waitExists(app.buttons["set.0.0.complete"])
            XCTAssertEqual(app.buttons["set.0.0.complete"].value as? String, "complete")
            XCTAssertEqual(app.buttons["set.0.1.complete"].value as? String, "complete")
            XCTAssertEqual(app.textFields["set.0.0.weight"].value as? String, "225")
            XCTAssertTrue(app.element("rest.dock").waitForExistence(timeout: 5), "Rest timer was not restored")
            snapshot(app, "J14-relaunch-resumed")
        }

        // MARK: Finish → summary → history

        XCTContext.runActivity(named: "Finish and review") { _ in
            app.buttons["workout.finish"].tap()
            tapDialogButton("Finish workout", in: app, excluding: ["workout.finishBottom"])
            waitExists(app.element("summary.title"), timeout: 20)
            XCTAssertTrue(app.element("summary.sets").label.contains("2"), app.element("summary.sets").label)
            snapshot(app, "J15-summary")
            waitHittable(app.buttons["summary.done"]).tap()

            waitHittable(app.tabBars.buttons["History"]).tap()
            let row = waitExists(app.element("history.row"))
            XCTAssertTrue(row.label.hasPrefix("Upper A,"), row.label)
            snapshot(app, "J16-history")
            row.tap()
            waitExists(app.element("summary.title"))
            snapshot(app, "J17-history-detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // MARK: Snapshot isolation + previous performance

        XCTContext.runActivity(named: "Rename the routine; history keeps the logged name") { _ in
            app.tabBars.buttons["Routines"].tap()
            waitHittable(app.buttons["routine.row.Upper A"]).tap()
            waitHittable(app.buttons["routine.edit"]).tap()
            let name = waitHittable(app.textFields["builder.name"])
            name.replaceText(with: "Upper A v2")
            waitHittable(app.buttons["builder.save"]).tap()
            waitGone(app.buttons["builder.save"])
            app.navigationBars.buttons.element(boundBy: 0).tap()
            waitExists(app.buttons["routine.start.Upper A v2"])

            app.tabBars.buttons["History"].tap()
            let row = waitExists(app.element("history.row"))
            XCTAssertTrue(row.label.hasPrefix("Upper A,"), "History must keep the name logged at the time: \(row.label)")
            snapshot(app, "J18-history-after-rename")
        }

        XCTContext.runActivity(named: "Start again: previous performance, then discard") { _ in
            app.tabBars.buttons["Today"].tap()
            waitHittable(app.buttons["today.start.Upper A v2"]).tap()
            waitExists(app.element("workout.title"), timeout: 20)
            // Warm-up rows can push the first working set below the fold
            // (and lazy lists only create rows that are near the screen).
            let previous = app.buttons["set.0.0.previous"]
            if !previous.exists || !previous.isHittable { reveal(previous, in: app) }
            waitExists(previous)
            XCTAssertTrue(previous.label.contains("225"), previous.label)
            snapshot(app, "J19-previous-performance")
            waitHittable(previous).tap()
            XCTAssertEqual(app.textFields["set.0.0.weight"].value as? String, "225")

            app.buttons["workout.options"].tap()
            tapDialogButton("Discard workout", in: app)
            tapDialogButton("Discard", in: app)
            waitGone(app.element("workout.title"))
            waitExists(app.tabBars.buttons["Today"])
            snapshot(app, "J20-today-after-discard")
        }
    }
}
