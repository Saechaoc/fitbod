---
status: backlog
created: 2026-10-29
risk: low
scope: two small UI fixes
sources:
  - .planning/archived-phases/260610-jag-verify-and-fix-screen-width-overflow-for/260610-jag-SUMMARY.md
  - .planning/archived-phases/milestone-1-journey-audit.md
---

# Backlog: UI defects carried over from archived quick tasks

The 2026-10-29 cleanup archived the tasks that first recorded these defects.
Both are still in the code, and no current plan or roadmap item covers them.

## 1. The RPE column heading sits on the wrong line

- **Where:** `fitbod/Sessions/SessionExerciseCard.swift:219-247` (heading strip),
  `fitbod/Sessions/SetRow.swift:87` and `:218` (two-line set row).
- **Problem:** The heading strip shows `S · PREVIOUS · WEIGHT · REPS · RPE` on
  one line. Since 260610-jag, each set row shows its RPE chips on line 2, under
  PREVIOUS. The RPE heading now sits above the edit and complete controls.
- **Fix:** Drop RPE from the heading strip, or label the chip line instead.
  Check the result at 390pt and 440pt widths.

## 2. The resume slab's Discard takes taps only on its text and outline

- **Where:** `fitbod/Views/ResumeWorkoutSlab.swift:121-142`.
- **Problem:** Discard is a `.plain` button. Its label has a 44pt frame but no
  `contentShape`, so a tap in the empty space inside the outline misses.
- **Fix:** Add `.contentShape(Rectangle())` after the label's frame, as
  261028-uhg did for SKIP WARM-UPS (`fitbod/Sessions/WarmupRampRows.swift:257`).
  Add a UI test that taps near the button's edge.
