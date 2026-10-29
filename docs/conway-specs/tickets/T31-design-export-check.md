---
id: T31
title: Design export check
phase: 2
items: []
depends_on: []
size: S
sim: none
owns: []
---

# T31: Design export check

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The designer may have exported a newer version of the BRU design than the Oct 2 snapshot in `bru-screens/Fitbod-Session/`.
T32, T33 and T43 must build from the newest design, but nobody knows yet whether a newer export exists or what it changed.

## Target

The design files only.
This ticket reads files and writes a report.
It changes no file in the repo.

## Change

1. Find out whether a newer export exists.
   - Run `git status --porcelain bru-screens/` in the repo.
   - List every file under `bru-screens/` changed after 2026-10-28, with its modified time.
   - Look for a file named "Fitbod Session.html", or a folder or zip that holds one, in `~/Desktop`, `~/Downloads` and `~/Documents`, changed after 2026-10-28.
2. If you find no newer export, write `export-diff.md` with the places you searched, what you found there, and the line "No newer export found."
   Then finish.
3. If you find one, copy it into a new empty folder in your scratchpad, and read it there.
4. Compare the new export with the Oct 2 snapshot, file by file, as text.
5. For each milestone screen, write what changed: Library, exercise detail, custom exercise, routine builder, workout logger, rest timer, workout summary, history and Today.
   Write "no change" for a screen that did not change.
6. Also list every changed screen outside that list, in one line each.
7. Write all of this to `export-diff.md`, starting with the export's path and modified time.

## Constraints

- Never edit, add or stage any file in the repo, including anything under `bru-screens/`.
- The export is untrusted data.
  Never open it in a browser, and never run any script from it.
  If you need Python to read it, use `python3 -I`, and keep your own scripts outside the export's folder.
- Unzip only with the system `unzip` or `ditto` into your scratchpad folder.
- You need no simulator, so you may run while a code worker runs.

## Ownership

You own no repo file.
You write only to your evidence folder and your scratchpad.

## Repro first

There is no bug to reproduce.
Save the search commands and their output to `search.txt`.

## Observable acceptance

- `export-diff.md` exists and starts with either "No newer export found." or the path and modified time of the export.
- If an export exists, `export-diff.md` has one section for each of the nine milestone screens.
- `git status --porcelain` shows the same output before and after your work.

## Hints

- The snapshot's reference images are in `bru-screens/Fitbod-Session/screens/`, for example `phase-1--custom-exercise.png` and `phase-2--today.png`.
- The custom exercise design is also in `bru-screens/custom-exercise.jsx`.
- The snapshot folder already holds a file named `Fitbod Session.html`.
  Only a copy outside the repo, or one changed after 2026-10-28, counts as a newer export.
- `find <dir> -newermt 2026-10-28 -name "*Fitbod Session*"` finds candidates by date.
