---
phase: 02
slug: core-loop-routines-sessions
mode: mvp
created: 2026-05-11
total_plans: 14
---

# Phase 2 — Plan Index

> Atomic, commit-sized plans for the **Core Loop (Routines + Sessions)** phase. Each plan is one logical commit-sized unit, landed in the order documented below. Every plan maps to ≥1 requirement (ROUTINE-01..09 + SESS-01..11 = 20 total). Every requirement is covered by ≥1 plan. Built around the locked decisions in `02-CONTEXT.md` and `02-UI-SPEC.md`, with implementation guidance from `02-RESEARCH.md`.

## Phase Goal (MVP User Story)

**As a** serious lifter who has just installed Fitbod and seen the bundled exercise library, **I want to** open the Routines tab → build a "Push Day" routine end-to-end (Bench / OHP / Tricep Pushdowns with per-exercise intent, target rep range, target RPE, and rest seconds) → start a session that snapshots the template → log every set with an accurate rest timer that survives lock-screen → and view per-exercise history split by intent, **so that** the same routine logged Mon (strength) vs Thu (hypertrophy) produces two distinct history streams and editing the template tomorrow never rewrites yesterday's logged sets.

## Vertical Slice — Definition of Done

After Wave 5 ships, a real user can:

1. Open the app, tap **Routines** → see the empty state ("No routines yet"). Tap "New Routine."
2. Name the routine "Push Day," tap "Add an exercise" → inline picker (reusing Phase 1's `ExerciseLibraryView` in `onSelect:` mode) surfaces Bench Press. Add it.
3. Inline-expand the prescription editor → set intent = Strength, sets = 3, reps 5–5, RPE 8.5, progression = RPE Autoregulation, rest = 180s, "Track tempo" off.
4. Add OHP + Tricep Pushdowns similarly. Long-press Bench + OHP → "Move to Superset…" → "New Superset" → both get the 4pt accent rail.
5. Add a per-set override on Bench set 1: 6 reps @ RPE 9 (the heavy top set), then sets 2-3 at 5 @ RPE 8.
6. Tap Save. Back on Routines tab — Push Day appears under "Unfiled."
7. Tap Push Day's row swipe-leading → "Start Workout" → `SessionLoggerView` pushes. Header shows "Workout · Push Day · 0:00 · 1 of 3 · Notes."
8. Tap weight cell on Bench set 1 → "Previous" column shows "—" (first-ever session). Type 185, type 5, tap RPE 8 chip, tap completion checkmark → set commits, rest timer starts (180s collapsed pill above the tab bar).
9. Lock the phone. Wait 60s. Lock-screen notification fires: "Rest complete — Bench Press — next set ready."
10. Unlock; open the app. The collapsed pill shows ~2:00 remaining (the Date-derived state survived the lock). Tap pill → expanded sheet with ±15s / Skip. Tap "+15s" → target moves to 195s; pill updates.
11. Tap set 2's weight cell → rest timer stops (auto-stop on next-set entry). Log set 2 (185 × 5 @ 8.0).
12. Long-press the Bench card header → "Swap Exercise…" → picker → swap to Floor Press. Future pending sets re-seed from previous matching-intent Floor Press history (none yet → 0). Logged sets stay (immutable).
13. Tap "+ Add Exercise" at the bottom → picker → add Lateral Raise. New `SessionExercise` row appears with 3 planned sets at hypertrophy intent + 90s rest.
14. Tap the "Notes" header chip → "Workout Notes" sheet → type "Felt strong on bench top set." Done.
15. Tap a SetRow's notes button → "Set 2 Note" sheet → type "Right elbow tucked." Done.
16. Tap "Finish" → confirmation: "Finish Workout? · 5 sets logged · 24:13" → "Finish." Pops to Routines tab.
17. Switch to the **Library** tab → tap Bench Press → detail view → tap "View All History" → `ExerciseHistoryView` with "Strength" chip selected by default. See today's two sets (185 × 5 @ 8.0 each) grouped under today's date.
18. Tap "Hypertrophy" chip → "No Hypertrophy sets — Try a different intent filter." Tap "Show All" → both visible (only strength logged today). Future weeks: same routine logged at hypertrophy intent on Thursday produces a distinct stream visible under the "Hypertrophy" chip.

## Wave Structure

```
Wave 0 — Schema V2 migration (foundation)
   ├── 00-01 schema-v2-new-entities (3 new @Models + additive fields on existing entities)
   └── 00-02 schema-v2-versioned-schema-and-migration (SchemaV2 + MigrationStage.lightweight + tests)

         ↓

Wave 1 — Session snapshot (load-bearing — PITFALLS-doc #1)
   └── 01-01 session-factory-snapshot (SessionFactory.start + PreviousMatchingIntent helper + tests)

         ↓

Wave 2 — Rest timer (load-bearing — PITFALLS-doc #4)
   ├── 02-01 rest-timer-engine-and-notifications (RestTimerEngine + UNUserNotificationCenter scheduler)
   ├── 02-02 rest-timer-live-activity-and-widget-extension (FitbodWidgets target + RestTimerAttributes + LiveActivity)
   └── 02-03 rest-timer-overlay-and-engine-integration (RestTimerOverlay + engine composition)

         ↓

Wave 3 — Routines tab + builder
   ├── 03-01 routines-list-folders-and-resume-banner (RoutinesListView + RoutineFolder UI + ResumeWorkoutBanner)
   ├── 03-02 routine-builder-and-prescription-editor (RoutineBuilderView + PrescriptionEditorRow + ExerciseLibraryView onSelect: refactor)
   └── 03-03 supersets-and-routine-duplication (SupersetAssignmentSheet + RoutineDuplicator)

         ↓

Wave 4 — Session logger
   ├── 04-01 session-logger-view-and-set-row (SessionLoggerView + SessionExerciseCard + SetRow + RPE chips + PreviousColumn)
   ├── 04-02 session-logger-swap-add-and-opt-in-rows (mid-session swap + add unplanned + tempo / partials / cluster rows)
   └── 04-03 session-logger-notes-and-pinned-notes (WorkoutNotesSheet + PerSetNoteSheet + PinnedNoteSheet + PinnedNoteCapsule)

         ↓

Wave 5 — Intent-split history
   └── 05-01 exercise-history-view-with-intent-split (ExerciseHistoryView + IntentFilterChipRow + ExerciseHistoryRow)
```

## Plan-by-Plan Coverage

| Plan | Wave | Complexity | Requirements covered |
|------|------|-----------|----------------------|
| `00-01-PLAN.md` schema-v2-new-entities | 0 | M | ROUTINE-03, ROUTINE-04, ROUTINE-06, SESS-07, SESS-08, SESS-11 (data) |
| `00-02-PLAN.md` schema-v2-versioned-schema-and-migration | 0 | S | (transitive — enables 00-01's data deltas) |
| `01-01-PLAN.md` session-factory-snapshot | 1 | M | **SESS-01**, **ROUTINE-07**, SESS-03 (data path) |
| `02-01-PLAN.md` rest-timer-engine-and-notifications | 2 | M | SESS-04 (engine + notification half) |
| `02-02-PLAN.md` rest-timer-live-activity-and-widget-extension | 2 | M | SESS-04 (Live Activity / Dynamic Island half) |
| `02-03-PLAN.md` rest-timer-overlay-and-engine-integration | 2 | S | SESS-04 (in-app overlay + integration) |
| `03-01-PLAN.md` routines-list-folders-and-resume-banner | 3 | M | ROUTINE-06 (folders), SESS-04 (resume banner) |
| `03-02-PLAN.md` routine-builder-and-prescription-editor | 3 | L | ROUTINE-01, ROUTINE-02, ROUTINE-03, ROUTINE-05, ROUTINE-09, SESS-07 (toggle), SESS-08 (toggle) |
| `03-03-PLAN.md` supersets-and-routine-duplication | 3 | M | ROUTINE-04, ROUTINE-06 (duplication) |
| `04-01-PLAN.md` session-logger-view-and-set-row | 4 | L | SESS-01, SESS-02, SESS-03, SESS-04 (integration), SESS-09, SESS-11, ROUTINE-08 (data path) |
| `04-02-PLAN.md` session-logger-swap-add-and-opt-in-rows | 4 | M | SESS-05, SESS-06, SESS-07, SESS-08 |
| `04-03-PLAN.md` session-logger-notes-and-pinned-notes | 4 | S | SESS-11, SESS-02 |
| `05-01-PLAN.md` exercise-history-view-with-intent-split | 5 | M | **SESS-10**, **ROUTINE-08** |

**14 plans, 20 requirements covered, every requirement in ≥1 plan.**

## Requirement-by-Plan Cross-Reference

| Requirement | Plan(s) that close it |
|-------------|----------------------|
| ROUTINE-01 (single-screen builder) | 03-02 |
| ROUTINE-02 (per-exercise prescription) | 03-02 |
| ROUTINE-03 (per-set overrides) | 00-01 (data), 03-02 (UI) |
| ROUTINE-04 (supersets + giant sets) | 00-01 (data), 03-03 (UI) |
| ROUTINE-05 (progression model picker) | 03-02 |
| ROUTINE-06 (duplicate + folders) | 00-01 (data), 03-01 (folders), 03-03 (duplication) |
| ROUTINE-07 (snapshot — editing routine doesn't rewrite session) | 01-01 (canonical guard test) |
| ROUTINE-08 (same-routine-different-intent = separate histories) | 01-01 (data path), 04-01 (UI plumbing), 05-01 (history view) |
| ROUTINE-09 (default rest by mechanic heuristic) | 03-02 (PrescriptionDefaults) |
| SESS-01 (SessionFactory snapshots all fields) | 01-01 |
| SESS-02 (per-set logging — weight/reps/RPE/set-type/notes) | 04-01 (inputs + RPE chips + set-type chip), 04-03 (notes) |
| SESS-03 (auto-populate from prev matching-intent + inline "previous" column) | 01-01 (helper), 04-01 (PreviousColumn view) |
| SESS-04 (rest timer — Date-based, ±15s, notification, Live Activity, auto-stop) | 02-01 (engine + notifications), 02-02 (Live Activity), 02-03 (overlay + integration), 04-01 (commit handler + auto-stop) |
| SESS-05 (mid-session swap without mutating routine) | 04-02 |
| SESS-06 (add unplanned mid-session) | 04-02 |
| SESS-07 (optional 4-field tempo per set) | 00-01 (toggle field), 03-02 (toggle UI), 04-02 (TempoEntryRow render) |
| SESS-08 (partial reps + cluster sub-reps) | 00-01 (fields), 03-02 (toggle UI), 04-02 (Partials + Cluster rows) |
| SESS-09 (bodyweight signed weight) | 04-01 (numeric keyboard adapts) |
| SESS-10 (per-exercise history with intent split) | 05-01 |
| SESS-11 (workout-level + pinned per-exercise notes inline) | 00-01 (pinnedNote field), 04-01 (header chip stub), 04-03 (sheets + capsule) |

## Pitfall Coverage

| Pitfall | Source | Closing plan(s) |
|---------|--------|----------------|
| PITFALLS-doc #1 (routine template / session instance collapse) | `.planning/research/PITFALLS.md` | 01-01 (canonical SessionFactoryTests) + every Phase 2 plan that touches Session/RoutineExercise |
| PITFALLS-doc #2 (mixing strength + hypertrophy histories) | PITFALLS.md | 01-01 (intent-aware matching-intent query) + 05-01 (intent-split history view) |
| PITFALLS-doc #4 (SwiftData schema versioning) | PITFALLS.md | 00-02 (first V1 → V2 migration is the proof) |
| PITFALLS-doc #4 (rest timer drift on lock — RESEARCH §6 Pitfall 2) | RESEARCH.md | 02-01 (Date-based engine + UNUserNotification scheduler) |
| RESEARCH §6 Pitfall 1 (SwiftData #Predicate UUID workaround) | RESEARCH.md | 01-01 (PreviousMatchingIntent) + 05-01 (ExerciseHistoryView FilteredHistoryList) |
| RESEARCH §6 Pitfall 3 (ActivityKit Activity.request throws on simulator) | RESEARCH.md | 02-02 (silent fallback in RestTimerActivityController) |
| RESEARCH §6 Pitfall 4 (UNNotification permission denied) | RESEARCH.md | 02-01 (LiveNotificationScheduler permission handling) |
| RESEARCH §6 Pitfall 5 (@Bindable write-through on RoutineExercise) | RESEARCH.md | 01-01 (snapshot-immutable-after-edit test) |
| RESEARCH §6 Pitfall 6 (routine duplication missing supersets + overrides) | RESEARCH.md | 03-03 (RoutineDuplicator + RoutineDuplicationTests) |
| RESEARCH §6 Pitfall 7 (active-session conflict) | RESEARCH.md | 01-01 (factory throws) + 03-01 (handleStartTap alert routing) |
| RESEARCH §6 Pitfall 8 (per-set override / targetSets desync) | RESEARCH.md | 03-02 (RoutineExerciseDraft.targetSets didSet prune) |
| RESEARCH §6 Pitfall 9 (Live Activity rate-limit) | RESEARCH.md | 02-02 (200ms debounce in RestTimerActivityController.update) |
| RESEARCH §6 Pitfall 10 (.onMove orderIndex rewrite) | RESEARCH.md | 03-02 (RoutineBuilderView onMove handler) |

## Dependency Graph (compact)

```
00-01  (schema entities + additive fields)
   │
   ▼
00-02  (SchemaV2 + migration plan + tests)
   │
   ├─────────────────────────────────────────────────────────┐
   ▼                                                          ▼
01-01  (SessionFactory.start + PreviousMatchingIntent)      02-01 (RestTimerEngine + notifications)
   │                                                          │
   │                                                          ▼
   │                                                       02-02 (FitbodWidgets + LiveActivity)
   │                                                          │
   │                                                          ▼
   │                                                       02-03 (RestTimerOverlay + engine composition)
   │
   ▼
03-01  (RoutinesListView + folders + ResumeBanner)
   │
   ▼
03-02  (RoutineBuilderView + PrescriptionEditor + ExerciseLibraryView onSelect refactor)
   │
   ▼
03-03  (SupersetAssignmentSheet + RoutineDuplicator)
   │
   ▼
04-01  (SessionLoggerView + SetRow + RPE chips + PreviousColumn)
   │
   ▼
04-02  (Mid-session swap + add unplanned + tempo / partials / cluster rows)
   │
   ▼
04-03  (WorkoutNotesSheet + PerSetNoteSheet + PinnedNoteSheet + PinnedNoteCapsule)
   │
   ▼
05-01  (ExerciseHistoryView + IntentFilterChipRow — final plan, Phase 2 closeout)
```

## Execution Order

Plans run sequentially within waves; waves run sequentially. The dependency graph above is the strict order — no plan ships before all its hard dependencies are committed.

Recommended execution: one plan per Claude session with `/clear` between plans, per the Phase 1 convention. Each plan is sized to land cleanly within a single Claude context window.

## Phase Closeout

After plan `05-01` ships:
- All 20 ROUTINE-* + SESS-* requirements are closed (cross-referenced in the table above).
- The MVP user story above is achievable end-to-end on the simulator.
- Run `/gsd-transition` to move Phase 2 requirements to "Validated" in `REQUIREMENTS.md` and update the ROADMAP progress table.
- Phase 3 entry conditions: SchemaV2 is stable; SessionFactory deep-copy is proven; rest timer + Live Activity are integrated; the session logger surfaces real logged data that Phase 3's progression strategies (`RPEAutoregStrategy` + `DoubleProgressionStrategy`) can back-calculate against.

---

*Phase 2 plan index — generated 2026-05-11 against `02-CONTEXT.md` + `02-UI-SPEC.md` + `02-RESEARCH.md` + `PITFALLS.md` + Phase 1 SUMMARY artifacts.*
