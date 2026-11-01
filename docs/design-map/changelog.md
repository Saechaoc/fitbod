# Changelog

Newest first, one entry for each stage of [plan.md](plan.md).

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
