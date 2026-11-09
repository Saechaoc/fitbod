# Playtest fixes: logger, volume, finish sheet and widget resources

> Historical completed implementation plan, archived 2026-11-08. Current scope/acceptance: [RM-059](../../ROADMAP.md#rm-059), [RM-060](../../ROADMAP.md#rm-060) and the explicitly open device owners below. Original task/STATE/SUMMARY instructions and old paths are historical; use [DEVELOPMENT.md](../../DEVELOPMENT.md) for new work.

**Scope:** FT-01–12/14/15/17/18 code changes: logger routing/discard/exercise actions/carry-forward/RPE/type/Why/compact sections, catalog addition and volume routes/amber. FT-13 finish sheet and FT-20 packaging landed separately below. Physical reach, prompt ownership, Lock Screen appearance and dark/tinted icon observations are excluded from implementation acceptance.
**Build/commits:** 2026-11-08, `55c59656` through `3c8478e1`, with `af274c08` for FT-13 and documentation recorded at `ba27f304`. Commit-specific affected unit/UI suites were recorded passing. `WorkoutExitUITests` covers Program start/resume returning Back to Today.
**Recorded results:** Full tier after widget resources: 1,350 enumerated/run, 1,348 passed, one History-delete failure and one expected failure. The delete case passed alone after `3febe870`; no later fully green configuration matrix is claimed.

## Finish confirmation

[RM-060](../../ROADMAP.md#rm-060), FT-13, `af274c08`: BRU paper sheet with set count/elapsed time, Finish or Discard if empty, and Keep logging. All 23 affected tests passed; a 430pt content-height capture was inspected. This bounded feature is Done without requiring a personal phone sign-off. Broader release checks remain separate.

## Widget resources and device limits

[RM-008](../../ROADMAP.md#rm-008), FT-20, `03199d32`: shared asset catalog and six fonts reach the extension, with `UIAppFonts`; built bundle inspection and extension build passed. `3c8478e1` was built and installed on iPhone 15 Pro Max on 2026-11-08, but Mac launch was refused while locked. No Lock Screen/Island rendering or lifecycle observation was recorded.

Earlier signing fix `e72ae87e` removed the invalid `com.apple.developer.usernotifications.live-activities` entitlement; its device build/install/launch passed, but no Live Activity was started. Signing success is not rendering proof.

**Still open in the roadmap:** [RM-007](../../ROADMAP.md#rm-007) FT-19 prompt identification, [RM-008](../../ROADMAP.md#rm-008) FT-20 rendering/lifecycle, [RM-045](../../ROADMAP.md#rm-045) FT-16 physical heatmap reach, [RM-046](../../ROADMAP.md#rm-046) FT-21 installed dark/tinted icons and [RM-047](../../ROADMAP.md#rm-047) broader physical checks. These block only dependent acceptance/release work; RM-006 and other independent work may proceed. No app/device checks were rerun while archiving.

**Provenance:** `.planning/quick/261108-ftx-resolve-playtest-findings/261108-ftx-PLAN.md` and its summary at `ba27f304`; signing summary `261108-a5s-SUMMARY.md` at the same revision. No logs or screenshots copied into this archive.

## Preserved plan

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
