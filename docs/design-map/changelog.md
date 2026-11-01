# Changelog

Newest first: one entry for each stage of [plan.md](plan.md) up to S2, then one for each commit.

## 2026-11-01: S3, iPhone 17e in dark mode and at AX3

- Captured the iPhone 17e in dark mode and at AX3: 79 screenshots in each, for the main state of 72 screens and 7 other states.
  The other 16 screens, 13 dialogs and 3 system sheets, appear only in the walks, which run in light mode at default text.
- At AX3 the logger loads each set row only as it scrolls in.
  So `TourLogger.openWorkout` and `logSet` wait for the row, and `revealInLogger` drags up to 30 times, because the demo workout is about 11,000 pt long at that size.
- `revealInBuilder` starts each drag at a height that no phase card covers, because a drag beside a card does not scroll the page ([T120](../conway-specs/tickets/T120-new-block-toast-and-duration-steppers.md)).
  Where the cards cover every height, it leaves the scroll to the tap.
- The tour reveals rows below the screen instead of waiting for them, because such rows do not exist until they scroll in.
  This covers Program's Archived routines entry and the Volume Targets and Component gallery rows in Settings.
  The logger check waits for the first exercise's name instead of the set 1 field.
- `TourProgressLibrary.tapBelow` taps a form row only once the row sits below the header bar.
  New exercise draws its header bar as a top safe-area inset, so rows scroll under it and XCUITest still calls them hittable.
  On the Pro Max at AX3, the tap hit the bar and the equipment list never opened.
- After these fixes, `testMainToday` and `testMainLoggerSheets` ran again at AX3 on 2026-11-01 and filled 7 states that the first run missed.
  Their 16 images show Sunday, November 1, as [assumptions.md](assumptions.md#phones-and-captures) lists.

## 2026-10-31: S2, iPhone 17e in light mode

- Captured the iPhone 17e in light mode at default text: 210 screenshots in `screens/img/`, and an accessibility tree in `screens/tree/` for each of the 88 main states the tour reached.
- Added `notification-permission`, the system prompt that the first rest timer raises, so the inventory now lists 91 screens, sheets, dialogs and system sheets.
- Listed the "Preparing library…" splash under [States not captured](assumptions.md#states-not-captured).
  It never reaches the screen, so neither the tour nor a screen recording can catch it.
- `DesignTourStatesUITests` now has 20 tests, because W03 runs as three.
  W04 now ends on the restore error, and W15 checks whether a failed Remove Session leaves later saves stuck.
- The tour waits for each app alert it expects and shoots it before its next tap.
  XCUITest's default interruption handler closes an alert that blocks a tap and leaves no trace; in the first run it answered the notification prompt unseen.
- The tour logs each app problem it meets as a named step in the test log and walks on, so one bug does not end a walk.
- `reveal` now scrolls up as well as down, `revealInBuilder` scrolls both New Block and Edit Block, and `revealDelete` opens the Delete of one phase card.
- The tour now reaches the New Block name field with a tap, which scrolls the field into view.
  A drag in the margin beside a phase card does not scroll New Block, as [T120](../conway-specs/tickets/T120-new-block-toast-and-duration-steppers.md) describes.
- `tools/tour_run.sh` takes a comma-separated list of tests, so a rerun repeats only the tests that failed.

## 2026-10-31: S1, screenshot tour

- Added the tour, assembled from parts written for each area of the app.
  `DesignTourMainUITests` has 9 tests that capture the main state of every screen it can reach, in every configuration.
  `DesignTourStatesUITests` has 19 tests for the walks W01 to W16, in light mode at default text.
- The tour closes sheets with its own check of the top sheet.
  iOS 26 floats a half-height sheet 8 pt above the bottom of the screen, and the shared `UITestNavigation.topSheet` does not count it as a sheet.
- `tools/tour_run.sh` now refuses to start while another run holds its lock, and refuses a private copy at the wrong commit.
- `tools/tour_export.py` now scales every screenshot to exactly 2x, has a self-test, and handles a run with no attachments.
  The plan's `sips -Z 1700` gave the 17e 2x but the Pro Max only 1.8x.
- `tools/check_map.py` now accepts `captured: none` for a screen with no screenshot, and checks HTML `<img src>` paths.
  Each screen file shows its main screenshot at a width of 300.

## 2026-10-31: S0, scaffold

- Added the index ([README.md](README.md)), [assumptions.md](assumptions.md), [conventions.md](conventions.md) and this changelog.
  `conventions.md` is a leaf the plan did not list; it holds the templates and rules that the screen, workflow and audit writers share.
- Added `tools/check_map.py` and `tools/check.sh`, which check that the files agree with each other.
- Added a skeleton for each of the 90 screens, sheets, dialogs and system sheets in `tools/inventory.tsv`.

## 2026-10-31: plan and capture tools

- Added [plan.md](plan.md).
- Added the tour runner, the exporter and the screen inventory under `tools/`.
