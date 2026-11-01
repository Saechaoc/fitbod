---
id: T146
title: A sideways drag on the Add session sheet adds nothing to the routine
phase: 4
items: []
depends_on: [T144]
size: S
sim: small
owns: [fitbod/Periodization/SplitDetailView.swift]
---

# T146: A sideways drag on the Add session sheet adds nothing to the routine

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F384, which T144's worker found with a probe (3 of 3).

- On a routine's screen, the Add session sheet lists the existing sessions; each row is a `.plain` button that calls `addSlot(for:)`.
- A `.plain` button in a list acts when a sideways drag that starts on it ends, so a sideways drag on a row adds that session to the routine.
  This changes the lifter's routine, which is worse than opening a screen by accident.
- T144 gave the sheet's "+ New session" row `.bruRow`, so only a tap acts on it; the existing-session rows near `SplitDetailView.swift:844` still use `.plain`.

## Target

- The existing-session rows in `SlotPickerSheet` in `fitbod/Periodization/SplitDetailView.swift`.

## Change

1. The rows use `.bruRow`, so only a tap adds a session, and a vertical scroll that starts on a row still scrolls.

## Constraints

- Each row looks as it does today, pressed state included, and keeps its accessibility identifier.
- Commit no new UI test; the user asked for fewer UI tests (T143), and a throwaway check is the proof.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

- On the small phone, with a throwaway check you do not commit: open a routine, open Add session, drag sideways across an existing session's row, and record that the routine gains that session.

## Observable acceptance

- After the change, the same drag adds nothing, and a tap still adds the session; `notes.md` records both checks.
- `SlottedSessionDeleteUITests` passes on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- `.bruRow` is in `fitbod/Design/BRURowButtonStyle.swift`; T144's change to the "+ New session" row in the same sheet is the pattern.
- T144's notes, `docs/conway-specs/evidence/T144/notes.md`, describe the probe.
