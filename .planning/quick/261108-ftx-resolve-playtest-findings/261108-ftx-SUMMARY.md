---
quick_id: 261108-ftx
status: complete
date: 2026-11-08
commit: 03199d32
---

# Summary

Resolved the 21 playtest findings of 2026-11-08 listed in `docs/user-testing-notes/fitbod-playtest-roadmap-reconciliation.md`.
Seventeen shipped as code in ten commits, one is deferred, and three can only be checked on the phone.
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

The docs commit after this table carries `docs/ROADMAP.md`, the redesign plan, layouts, decisions (O-15, O-16) and changelog, the playtest doc and this record.

## Deferred and device-only

- FT-13: the finish confirmation stays a stock alert until the gym day is stable; recorded in `docs/ROADMAP.md`.
- FT-16: the simulator shows both heatmap figures whole, so the cut-off needs a phone capture; acceptance recorded on redesign step 1.4.
- FT-19: the repeated Live Activity permission prompt needs the phone; steps in the playtest doc.
- FT-20: the blank Lock Screen card is fixed in the bundle; confirm on the phone with the steps in the playtest doc.
- FT-21: compare the installed Home Screen icon with `AppIcon.appiconset` on the phone.

## Verification

- Each code commit ran its own unit suites and the UI suites it touched before landing; all passed, see the commit messages.
- FT-02 added `WorkoutExitUITests`, which starts a workout from Program and resumes from Program's banner and checks that Back lands on Today both times.
- FT-20: the widget bundle in DerivedData now has `Assets.car` with every bru colour, the six `.ttf` files and `UIAppFonts` in its Info.plist; before the change it had none of them. The build is warning-free for the extension.
- Full tier after the FT-20 commit (`scripts/test.sh full`, two simulators at the large text size): 1,265 unit tests passed with the one expected failure; 1,348 of 1,350 UI and unit tests passed, with one failure, `SessionHistoryBRUUITests/testCorrectionSaveCancelDeleteAndRelaunch`; the widget build succeeded.
- That failure also appeared in the 1.1 and 1.2 full runs and was left open as a contention flake. It failed alone today too: the recording shows the Edit workout screen scrolled to the bottom with Delete workout fully visible and no confirmation, because XCTest's own scroll-then-tap lands while the scroll view still moves and the tap only stops it. The test now reveals the button with the house helper first (3febe870); it passed alone afterwards at the large text size.

## Not checked

- Nothing ran on the phone. The Lock Screen card, the permission prompt, the heatmap reach and the icon need the device pass in the playtest doc.
- GitNexus impact analysis reported CRITICAL for `openRequestedWorkout`, `SessionTemplateDetailView`, `ResumeWorkoutRequest` and `ProgramView` before the FT-02 edit, because the index counts every test file as a caller; `detect_changes` rated the FT-02 and FT-20 diffs low with no affected processes. Earlier commits in this task were rated high on the same basis.
- `fitbod.xcodeproj/project.pbxproj.bak`, `.bak2` and `.bak3` are tracked stray backups from earlier project surgery; they were left alone.
