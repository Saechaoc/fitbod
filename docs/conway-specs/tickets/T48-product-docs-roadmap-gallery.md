---
id: T48
title: Product docs, roadmap, gallery and review page
phase: 7
items: []
depends_on: [T47]
size: M
sim: large
owns: [docs/CORE-SCREENS.md, docs/SETUP.md, docs/ROADMAP.md, docs/design-system/components.md, fitbod/Design/BRUComponentGallery.swift, .lavish/milestone-1-closeout.html, new:fitbodUITests/ComponentGalleryEntriesUITests.swift]
---

# T48: Product docs, roadmap, gallery and review page

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The product docs, the roadmap and the component gallery describe the app as it was before this closeout.
This run added shared components, removed controls, and moved some work to the roadmap.

## Target

`docs/CORE-SCREENS.md`, `docs/SETUP.md`, `docs/ROADMAP.md`, the design-system docs, the component gallery and the local review page `.lavish/milestone-1-closeout.html`.

## Change

1. Update `CORE-SCREENS.md` so each screen's states and interactions match the build.
2. Update `SETUP.md` with the gate phones, the lanes' DerivedData folders, serial test runs with `-parallel-testing-enabled NO`, and the DEBUG launch flags.
   Say that simulator ids differ between Macs.
   The run log copy in your evidence folder lists the phones and folders, and the worker rules list the rest.
3. Check that `ROADMAP.md` has each of these, and add any that is missing:
   - every removed control from the run log copy, under "Removed in Milestone 1 closeout";
   - whether a first log counts as a PR (decision 9);
   - the readout font and the dark slab glare;
   - the full inline routine creator from `bru-screens/create-flows.jsx`;
   - the Off-Season and Pre-Meet presets;
   - the custom exercise fields PATTERN, TEMPO, BAR WT and INCREMENT.
4. Add an entry to `BRUComponentGallery.swift` for each shared component added to `fitbod/Design/` since the run base, and document each one in `docs/design-system/components.md`.
5. Update the other design-system docs where this run changed tokens or rules.
6. Refresh `.lavish/milestone-1-closeout.html` so it matches the closeout docs from T47.
7. Write `changelog-draft.md` in your evidence folder: the user-facing changes of this run, grouped by tab.
   The user decides where it goes, because workers never edit changelogs.

## Constraints

- In the parts you edit, put one sentence on each line, and use "-" instead of em dashes.
- Never edit a changelog file, including `docs/design-system/changelog.md`.
- Edit the review page as a local file only.
  Never publish it, share it, or open it with a publishing tool.
- The gallery stays DEBUG-only, as it is today.

## Ownership

You may edit the files in `owns` and the design-system docs except the changelog.
Ask before you edit anything else.

## Repro first

Write `ComponentGalleryEntriesUITests` first.
It opens the gallery from Settings, asserts that each new component's entry exists, and saves a screenshot of each.
It fails before you add the entries.

## Observable acceptance

- `ComponentGalleryEntriesUITests` passes on the large phone, and `screens/` holds a screenshot of each new entry.
- `notes.md` lists each changed statement in `CORE-SCREENS.md` with the test or screenshot that backs it.
- `SETUP.md` names both phones with their ids, the DerivedData path, the serial test flag and the DEBUG flags.
- `ROADMAP.md` has every item in step 3.
- The review page matches the closeout docs, is committed, and was not published.
- `changelog-draft.md` exists in your evidence folder.
- `python3 docs/design-system/tokens_check.py` passes.

## Hints

- Find the new components with `git log --name-status <run base>..HEAD -- fitbod/Design/`.
- `MilestoneOneJourneyUITests.testComponentGalleryInteractions` shows how to open the gallery from Settings.
- The run log lists every removed control and every new shared helper.
