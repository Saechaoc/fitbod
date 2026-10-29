# Product decisions

The user approved these nine decisions with the plan (`.planning/noble-wishing-conway.md`).
Workers never change them.
If a ticket seems to conflict with one of them, the decision wins, and the worker asks the coordinator.
How each decision becomes code is in [tradeoffs.md](tradeoffs.md).

1. Program's template rows are generated from `BlockTemplates.swift`.
   That file becomes the one preset catalog for both Program and New Block.
   It gains a real 5/3/1 template: 4 weeks, with one week each of accumulation, intensification, realization and deload.
2. Picking a New Block preset sets the name and the phases.
   It asks before replacing phases you have edited, and it leaves days per week alone.
   Presets that have no real definition are removed.
3. New Block has two saves.
   The top action saves a draft, and the bottom action saves a ready block.
   Both need a name, and their labels say which is which.
4. The workout, set and pinned note sheets each edit a local copy.
   SAVE writes the copy.
   CANCEL and swipe-down throw it away.
5. "Logged sets" means completed working sets, and skipped warm-ups never count.
   One shared count drives the resume slab, the resume banner and the logger.
6. Finishing a workout with no completed sets offers Discard instead of saving.
   Empty workouts already saved stay in history, but they are left out of session counts and Compare.
7. Archiving a routine asks for confirmation first.
   Archived routines move to an Archived list on Program, where they can be restored.
   Every other routine list leaves them out.
8. A visible WHY control opens Why-this-weight and dismisses the keyboard.
   Use writes the suggested weight.
   Override closes the sheet and focuses the weight field.
9. Whether a first log counts as a PR stays a roadmap decision.
