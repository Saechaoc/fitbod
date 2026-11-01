---
id: T141
title: Cable, machine, band, bodyweight and kettlebell prescriptions skip barbell plate math
phase: 3
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Sessions/SessionFactory.swift, new:fitbodTests/NonBarbellPrescriptionTests.swift]
---

# T141: Cable, machine, band, bodyweight and kettlebell prescriptions skip barbell plate math

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F347, which T125's worker found.
`docs/DEVELOPMENT.md` never defers prescription math.

- `SessionFactory.equipmentKind(for:)` (`SessionFactory.swift:610`) returns `.dumbbell` for dumbbells and `.barbell` for every other equipment: machine, cable, bands, bodyweight, weighted bodyweight, kettlebell and other.
- `SessionFactory` then prescribes with that inventory's bar weight and plates (near `SessionFactory.swift:376`): it hands them to the progression strategy and to the warm-up ramp.
  So a cable or machine exercise is prescribed and warmed up as if it were a barbell lift with a 45 lb bar, and a 25 lb cable pushdown sits below the bar weight.

## Target

- `equipmentKind(for:)` and the prescription inputs in `fitbod/Sessions/SessionFactory.swift`.

## Change

1. Barbell exercises keep the barbell inventory, and dumbbell exercises the dumbbell inventory, as today.
2. Machine, cable, bands, bodyweight, weighted bodyweight, kettlebell and other exercises get no bar weight and no plates: their prescribed weight rounds to the exercise's smallest increment, or the default increment, from zero.
3. Their warm-up ramp, if they get one, starts from zero rather than from an empty bar.
4. An exercise's own bar weight override still applies to any exercise that sets one.

## Constraints

- Barbell and dumbbell prescriptions, warm-ups and their tests stay exactly as they are.
- No schema change.
- Units relabel and never convert, as `CLAUDE.md` says.

## Ownership

You may edit the files in `owns`, plus prescription and warm-up tests your change breaks.
Ask before you edit anything else, such as a progression strategy.

## Repro first

In `NonBarbellPrescriptionTests`, with an in-memory store:

- Prescribe a cable exercise whose last working set was 25 lb × 12, and assert that the prescription has no bar weight and a weight near 25 lb, not at or above 45 lb.
- Prescribe a machine exercise, and assert that its warm-up ramp, if any, does not start at an empty bar.

Record in `notes.md` what each gives today.

## Observable acceptance

- The repro tests pass with `fitbodTests`.
- Every existing prescription, progression and warm-up test passes unchanged.
- The app and the widget build.

## Hints

- `ExercisePrescription` carries `barWeight` and `plates` to the logger; T125 shows plate stacks only for barbell and dumbbell sets.
- `PlateInventorySeeder.swift` seeds the barbell and dumbbell inventories.
