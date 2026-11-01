---
id: T145
title: A tempo keeps each part in its place
phase: 4
items: []
depends_on: [T39]
size: S
sim: small
owns: [fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Sessions/TempoEntryRow.swift, new:fitbod/Sessions/TempoParts.swift, new:fitbodTests/TempoPartsTests.swift]
---

# T145: A tempo keeps each part in its place

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F380, which T39's worker found by reading the code.

- A tempo is stored as four dash-joined parts, Ecc-Bot-Con-Top, such as "3-1-2-0" or "-1--" for a Bot pause alone.
- The session editor reads it with `split(separator: "-")` near `fitbod/Routines/PrescriptionEditorRow.swift:246`, which drops empty parts.
  So a tempo with only Bot set, stored "-1", reads back as Ecc 1.
- Editing one part writes the shifted parts back, so a tempo with a gap moves its other parts to the wrong places.
- The logger's `TempoEntryRow` already keeps empty parts with `omittingEmptySubsequences: false`.

## Target

- `tempoField` in `PrescriptionEditorRow.swift`, and the parse in `TempoEntryRow.swift`.

## Change

1. One small helper in `fitbod/Sessions/TempoParts.swift` splits a stored tempo into exactly four parts, keeping empty ones, and joins four parts back, nil when all four are empty.
2. The session editor and the logger both use it, so editing one part leaves the others where they were.

## Constraints

- A tempo stored today reads back as it was entered whenever it has no empty part.
- The stored format stays dash-joined; no schema change.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

- In `TempoPartsTests`, assert that "-1" reads back as Bot 1 with the other parts empty, and that setting Top on "-1-2-" gives "-1-2-5".
  Both fail with the session editor's parse today; record that in `notes.md`.

## Observable acceptance

- `TempoPartsTests` covers nil, "", all four parts, each single part, and a gap, and passes with `fitbodTests` on the large phone.
- `fitbodTests` passes, and the app and the widget build.
- Commit no UI test; the user asked for fewer UI tests (T143).

## Hints

- `TempoEntryRow.swift:89` shows the parse that keeps empty parts.
- T39 made both rows' fields select their value on focus; keep that.
