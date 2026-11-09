---
quick_id: 261108-ftx
description: Resolve the 21 playtest findings of 2026-11-08
date: 2026-11-08
---

# Resolve the 21 playtest findings of 2026-11-08

The findings and their "Done when" criteria are in `docs/user-testing-notes/fitbod-playtest-roadmap-reconciliation.md`.
Code fixes land one atomic commit per group.
Device-only findings get a repro record and a roadmap home instead of code.

## Tasks

1. FT-04 and FT-11: one header in the Add Exercise picker; no inline plate graphic during weight entry (the plate calculator stays).
2. FT-01: Discard stays in the logger menu after sets are logged; the confirmation names how many logged sets will be deleted.
3. FT-03 and FT-09: a visible exercise menu (Why this weight?, Swap, Edit pinned note, Remove) beside the long-press menu; Remove names the logged sets it discards; Why this weight? works after logging and shows the logged weight against the recommendation.
4. FT-12: exercise sections collapse to header, set count and completion in the logger; the summary opens compact and expands per exercise.
5. FT-06: completing a working set carries its weight and reps to the next untouched working set; + Add Set copies the last logged set; manual edits and planned targets win; RPE stays fresh. Unit tests.
6. FT-07, FT-08 and FT-10: the previous column reads LAST TIME and says it matches the intent; the effort row is labelled RPE; the set type is one picker on the set label that shows the current choice.
7. FT-05: add Single-Leg Kneeling Leg Curl to the seed and bump SEED_VERSION so installs pick it up without losing history.
8. FT-14 and FT-15: slab colours that stay dark in dark mode (Resume, Done Today, Start workout, Volume summary); one routine-creation action when there is no routine.
9. FT-17 and FT-18: Volume reachable from Progress with per-muscle detail from the list and the heatmap; neck is a live region; under-MEV volume reads amber in both themes.
10. FT-02: the logger lives on Today's stack only; Program, a template and a Live Activity all resume through the same request, so Back always lands on Today.
11. FT-20: give the widget extension the asset catalog and fonts the Live Activity renders with.
12. Docs: the three roadmap edits from the playtest doc, a resolution section in the playtest doc, device repro steps for FT-16, FT-19, FT-20 and FT-21, the Today exit rule in `docs/design-map/redesign/today-layouts.md`, SUMMARY and STATE row.

FT-13 (custom Finish confirmation) shipped later the same day as a BRU sheet (af274c08); see the summary.
