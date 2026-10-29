---
id: T37
title: Library and exercise detail polish
phase: 3
items: [24, 25]
depends_on: [T03]
size: M
sim: small
owns: [fitbod/ExerciseLibrary/ExerciseLibraryView.swift, fitbod/ExerciseLibrary/ExerciseDetailView.swift, fitbod/Design/BRUSectionHead.swift, new:fitbodUITests/LibraryPolishUITests.swift]
---

# T37: Library and exercise detail polish

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

- The Library shows a lone section header "3" for "3/4 Sit-Up".
- The Library search placeholder, "Search exercises", is very faint.
- On exercise detail, "View all history" used an ASCII ">" in the body font in the review snapshot, unlike other navigation rows.
- On exercise detail at AX3, "RECENT PERFORMANCE" breaks as "PERFORMANC" over "E".

## Target

- The section grouping and the search field in `fitbod/ExerciseLibrary/ExerciseLibraryView.swift`.
- The history link row and the RECENT PERFORMANCE head in `fitbod/ExerciseLibrary/ExerciseDetailView.swift`.
- The accessibility layout of `fitbod/Design/BRUSectionHead.swift`.

## Change

1. Names that start with a digit or a symbol go in one section headed "#", after Z.
2. The search placeholder uses a BRU text color with at least 4.5:1 contrast on the paper background, in light and dark mode.
3. "View all history" uses the same chevron and style as the other navigation rows on the screen.
   The current code may already do this, so check first.
4. At accessibility sizes, `BRUSectionHead` puts its right-side label under the title, and the title wraps only between words.
5. At default text, every section head looks as it does today.

## Constraints

- `BRUSectionHead` is on almost every screen.
  Change only its accessibility branch, and check three other screens that use it at AX3.
- Keep the Library's sort order inside each section, and keep search and filters as they are.

## Ownership

You may edit the files in `owns`, plus Library tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Search the Library for "3/4", and assert that its section header is "#".
- Save a screenshot of the empty search field, sample the placeholder's darkest pixel and the field's background, and assert a contrast ratio of at least 4.5:1.
- Open an exercise, save a screenshot of the history row, and record in `notes.md` what its chevron looks like.
- At AX3, assert with frame checks that the RECENT PERFORMANCE head's title and right label do not intersect, and that no line of the title is a single letter.

Record which of these fail.

## Observable acceptance

- Every repro test passes on the small phone.
- `ExerciseCopyEditSheetUITests` and `CustomExerciseEntryUITests` pass on the small phone.
- `fitbodTests` passes, including the BRU audit suites.
- Screenshots of the Library sections, the search field, the history row and three section heads at AX3 are in `screens/`.

## Hints

- Sections come from `sectioned(_:)` near `ExerciseLibraryView.swift:343`.
- The placeholder comes from `TextField("Search exercises", ...)` near line 152; a `prompt` text can carry its own color.
- The history row uses `linkRow`, near `ExerciseDetailView.swift:277`.
- RECENT PERFORMANCE is near `ExerciseDetailView.swift:606`.
