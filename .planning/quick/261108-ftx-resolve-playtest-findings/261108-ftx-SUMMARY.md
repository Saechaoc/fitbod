---
quick_id: 261108-ftx
status: complete
date: 2026-11-08
commit: af274c08
---

# Summary

Resolved the 21 playtest findings of 2026-11-08 listed in `docs/user-testing-notes/fitbod-playtest-roadmap-reconciliation.md`.
Eighteen shipped as code in eleven commits, and four phone checks remain: the heatmap reach, the permission prompt, the Lock Screen card and the icon's dark and tinted appearance.
The playtest doc now ends with a resolution table and the device reproduction steps.

## Commits

| Commit | Findings | What changed |
| --- | --- | --- |
| 55c59656 | FT-04, FT-11 | One Add Exercise header; no plate stack under a set. |
| 8f2ec371 | FT-01 | Discard stays in the logger menu after sets are logged; the confirmation names what is lost. |
| 5493abeb | FT-03, FT-09, FT-12 | Visible exercise menu, Why this weight? after logging, collapsible exercises and a compact summary. |
| 6ee5adc4 | FT-06 | A logged working set carries its weight and reps to the next untouched working set. |
| 13a73d29 | FT-07, FT-08, FT-10 | One set-type picker, an RPE label, the LAST TIME column with its explanation. |
| 0892c2cf | FT-05 | Single-Leg Kneeling Leg Curl in the seed at version 3; installs re-seed without losing history. |
| 1002f225 | FT-14, FT-15 | Dark slabs stay dark on `bruSlab` with `bruOnSlab` text; one routine action with no block. |
| d89992fb | FT-17, FT-18 | Volume from Progress with per-muscle detail from the list and the figures, a neck tile, amber under MEV. |
| 35ff44f5 | FT-02 | The logger lives on Today's stack only, so Back always lands on Today; one `ResumeWorkoutRequest` for Program, a session's START WORKOUT ▸ and the Live Activity. |
| 03199d32 | FT-20 | The widget extension carries the app's asset catalog and the six fonts, with the fonts registered in its Info.plist. |
| 3febe870 | (test) | The History delete test reveals Delete workout before tapping it; a known flake since the 1.1 full run. |
| af274c08 | FT-13 | The finish confirmation is a BRU sheet on paper with the set count and elapsed time, Finish or Discard workout, and Keep logging; the finish UI tests find the actions by identifier. |
| 3c8478e1 | (chore) | Xcode's re-quoting of the six widget font paths in the project file, committed so the tree stays clean. |

The docs commit after this table carries `docs/ROADMAP.md`, the redesign plan, layouts, decisions (O-15, O-16) and changelog, the playtest doc and this record.
A second docs commit records FT-13 and the device checks driven from the Mac.

## Device-only

- FT-16: the 402pt and 430pt simulators show both heatmap figures whole with the calves visible, so the cut-off needs a phone capture; acceptance recorded on redesign step 1.4.
- FT-19: the app asks one permission once and starts one Live Activity per rest, neither with an Always Allow button, so the prompt's text and owner need the phone; steps in the playtest doc.
- FT-20: the blank Lock Screen card is fixed in the bundle and a Debug build of `main` is on the phone; confirm with the steps in the playtest doc.
- FT-21: the light icon the phone generated for the installed build matches the artwork at 1024 and at Home Screen size; dark and tinted appearance need the phone.

## Verification

- Each code commit ran its own unit suites and the UI suites it touched before landing; all passed, see the commit messages.
- FT-02 added `WorkoutExitUITests`, which starts a workout from Program and resumes from Program's banner and checks that Back lands on Today both times.
- FT-20: the widget bundle in DerivedData now has `Assets.car` with every bru colour, the six `.ttf` files and `UIAppFonts` in its Info.plist; before the change it had none of them. The build is warning-free for the extension.
- Full tier after the FT-20 commit (`scripts/test.sh full`, two simulators at the large text size): 1,265 unit tests passed with the one expected failure; 1,348 of 1,350 UI and unit tests passed, with one failure, `SessionHistoryBRUUITests/testCorrectionSaveCancelDeleteAndRelaunch`; the widget build succeeded.
- That failure also appeared in the 1.1 and 1.2 full runs and was left open as a contention flake. It failed alone today too: the recording shows the Edit workout screen scrolled to the bottom with Delete workout fully visible and no confirmation, because XCTest's own scroll-then-tap lands while the scroll view still moves and the tap only stops it. The test now reveals the button with the house helper first (3febe870); it passed alone afterwards at the large text size.
- FT-13: the 23 tests in the suites that touch the finish flow passed on the dedicated simulator; a 430pt capture shows the sheet on paper at content height with the title, "0 sets logged · 12:04", DISCARD WORKOUT and KEEP LOGGING.
- FT-16: captures of Progress › Volume at 430pt, the phone's width, show FRONT and BACK whole with the calves visible and the bottom rule above the tab bar, as the 402pt simulator did.
- FT-21: `xcrun devicectl device info appIcon` pulled the icon the phone generated for the installed build; it matches `AppIcon-1024.png` at 1024 and at Home Screen size.
- GitNexus: `detect_changes` rated the FT-13 diff low, 15 symbols in 7 files with no affected process; `impact` on `SessionLoggerView` read CRITICAL by count, 540 impacted with 2 direct callers and no process, because the index counts tests and whole files as callers.
- Device: the Debug build of `main` at 3c8478e1 built for the iPhone 15 Pro Max with the Personal Team and installed through devicectl; its widget bundle carries `Assets.car`, the six fonts and `UIAppFonts`. The launch from the Mac was refused because the phone was locked, so the first launch is a tap on the phone.

## Not checked

- No human check ran on the phone. The build is installed there but was not launched, and the Lock Screen card, the permission prompt, the heatmap reach in hand and the icon's dark and tinted appearance need the device pass in the playtest doc.
- `log collect` from the Mac needs root, so the phone's log was not read; the sudo one-liner is in the playtest doc's FT-19 steps.
- GitNexus impact analysis reported CRITICAL for `openRequestedWorkout`, `SessionTemplateDetailView`, `ResumeWorkoutRequest` and `ProgramView` before the FT-02 edit, because the index counts every test file as a caller; `detect_changes` rated the FT-02 and FT-20 diffs low with no affected processes. Earlier commits in this task were rated high on the same basis.
- `fitbod.xcodeproj/project.pbxproj.bak`, `.bak2` and `.bak3` are tracked stray backups from earlier project surgery; they were left alone.
