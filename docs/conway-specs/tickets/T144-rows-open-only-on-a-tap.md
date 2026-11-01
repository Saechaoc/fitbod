---
id: T144
title: Every full-width row that opens a screen opens only on a tap
phase: 4
items: []
depends_on: [T137]
size: M
sim: small
owns: [fitbod/Periodization/ProgramView.swift, fitbod/Settings/SettingsView.swift, fitbod/ExerciseLibrary/ExerciseDetailView.swift, fitbod/ExerciseLibrary/CustomExerciseEditor.swift, fitbod/Periodization/SplitDetailView.swift, fitbod/Views/TodaySessionPicker.swift, fitbod/Progress/ProgressHomeView.swift]
---

# T144: Every full-width row that opens a screen opens only on a tap

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F366 and F367, which T137's worker found.

- A `.plain` button in a list opens its screen when a sideways drag or an edge swipe that starts on it ends.
  T106 gave the Library's rows the `.bruRow` style, and T137 gave Progress's rows the same style, so only a tap opens them.
- Fifteen other full-width rows still use `.plain`: seven on Program, three in Settings, two on the Library's exercise screen, one in the custom exercise editor, one in the routine's add-session sheet, and Today's session picker.
- Progress's Workouts row reads "4 finished · last last week": `historySubLabel` writes "last " before a relative date that already says "last week", "yesterday" or "2 days ago".

## Target

- The fifteen rows in T137's table, `docs/conway-specs/evidence/T137/notes.md`, under "Other full-width `.plain` row buttons that open a screen".
- `historySubLabel` near `fitbod/Progress/ProgressHomeView.swift:419`.

## Change

1. Each of the fifteen rows uses `.bruRow`, so only a tap opens it, and a vertical scroll that starts on it still scrolls.
2. The Workouts row's sub-line reads "4 finished · last week", "4 finished · yesterday" or "4 finished · 2 days ago".
3. The borderline controls and the `.onTapGesture` rows in T137's notes stay as they are.

## Constraints

- Each row looks as it does today, pressed state included.
- Keep every row's accessibility identifier.
- Commit no new UI test; the user asked for fewer UI tests (T143), and the throwaway checks below are the proof.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

- On the small phone, drag sideways from the left edge of Program's first routine row and record that it opens the routine.
  A throwaway check is enough; record the result in `notes.md`, and do not commit it.

## Observable acceptance

- The same drag opens nothing after the change, on one row per screen in Target, and a tap still opens each.
  `notes.md` records each check.
- The kept UI suites that open these screens pass on the small phone; `notes.md` names them.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- `.bruRow` is in `fitbod/Design/BRURowButtonStyle.swift`.
- T39 also owns `ExerciseDetailView.swift`, for its numeric field near line 370, so the two tickets do not run at the same time.
