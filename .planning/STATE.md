# Project State: Fitbod

**Last updated:** 2026-05-10

---

## Project Reference

**Core value:** Granular, prescriptive workout sessions — every set is intentionally specified (intent, target reps, target RPE, smart-progressed weight), and progress is visible at the resolution serious lifters actually train at.

**Stack:** SwiftUI + SwiftData, iOS 18+, local-only, phone-only v1, zero third-party dependencies.

**Mode:** MVP — every phase delivers an end-to-end vertical slice (not a horizontal layer).

**Granularity:** standard (5–8 phases).

---

## Current Position

**Phase:** Not started (Phase 1 ready to plan)
**Plan:** —
**Status:** Roadmap created, awaiting `/gsd-plan-phase 1`
**Progress:** [░░░░░░░░░░] 0 / 6 phases complete

### Phase Outlook

| # | Phase | Reqs | Status |
|---|-------|-----:|--------|
| 1 | Foundation & Exercise Library | 14 | Not started |
| 2 | Core Loop (Routines + Sessions) | 20 | Not started |
| 3 | Smart Prescription & Warm-ups | 15 | Not started |
| 4 | Periodization & Blocks | 10 | Not started |
| 5 | Fatigue Model & Plateau Detection | 10 | Not started |
| 6 | Progress Views, Export & Polish | 11 | Not started |

**Coverage:** 80 / 80 v1 requirements mapped.

---

## Performance Metrics

No phases complete yet. Metrics will accumulate at phase transitions.

| Phase | Plans | Reqs Delivered | Notes |
|-------|------:|---------------:|-------|
| — | — | — | — |

---

## Accumulated Context

### Key Decisions (from PROJECT.md, locked in)

- iOS native SwiftUI + SwiftData (Xcode template already created)
- Single-user, local-only v1 (no auth, no cloud, no backend)
- Per-exercise prescription as the core unit
- User-selectable progression model (4 options: RPE/RIR autoreg, double progression, block-periodized, hybrid)
- RP-style weekly volume tracking against MEV/MAV/MRV
- Deload: scheduled by default + advisory fatigue alert (block schedule is canonical)
- 1000+ exercise library seeded from `yuhonas/free-exercise-db` (Unlicense, ~800 exercises)
- Auto warm-up ramp on first compound only
- Phone-only v1 (no Watch, no HealthKit, no VBT)

### Architectural Stance (from research/ARCHITECTURE.md)

1. **MV-VM-lite** — Views bind to `@Model` directly via `@Query` / `@Bindable`. No parallel ViewModel layer mirrors the schema.
2. **Template vs Instance via snapshot** — `SessionFactory.start(...)` copies prescription fields from `RoutineExercise` (template) to `SessionExercise` (instance) at session-start. Template edits never rewrite history.
3. **Progression and fatigue as pure stateless services behind protocols** — `ProgressionStrategy` has four conforming value types; `FatigueModel`, `PlateauDetector`, `PeriodizationEngine` are pure functions over plain inputs. Trivially unit-testable without `ModelContainer`.

### Load-Bearing Pitfalls (from research/PITFALLS.md)

These drive phase ordering and are mitigated by phase placement:

| # | Pitfall | Mitigated in |
|---|---------|--------------|
| 1 | Collapsing template and instance | Phase 1 (schema) + Phase 2 (snapshot proven end-to-end) |
| 2 | Missing `VersionedSchema` in v1 | Phase 1 (FOUND-01) |
| 3 | Volume math correct but UX doesn't drive a decision | Phase 5 (verb labels, not just numbers) |
| 4 | Rest timer drifts/stops on lock | Phase 2 (`Date` + `UNUserNotification`, never foreground `Timer`) |
| 5 | RPE-to-weight back-calc uses population averages | Phase 3 (Tuchscherer as prior; per-lifter calibration after ≥10 sets) |

### Open Research Items (deferred to plan-phase time)

- **Phase 3:** Tuchscherer RPE table cell values + per-exercise per-lifter calibration algorithm (linear vs locally-weighted; min-points threshold)
- **Phase 4:** Block phase curve multipliers (default volume/intensity per accumulation/intensification/realization/deload) confirmed against current RP/RTS literature
- **Phase 5:** Stimulus-weighting table for the ~50 main compound lifts (beyond 1.0/0.5 defaults) + RP-published MEV/MAV/MRV seed values per muscle

### Todos

- [ ] `/gsd-plan-phase 1` — decompose Phase 1 into executable plans
- [ ] Confirm whether `Item.swift` template model is removed before any seed import

### Blockers

None.

---

## Session Continuity

### Last Action

Roadmapper agent created `ROADMAP.md`, `STATE.md`, and updated `REQUIREMENTS.md` traceability with phase mappings.

### Next Action

`/gsd-plan-phase 1` — kick off Foundation & Exercise Library planning. Phase 1 carries the highest architectural weight (versioned schema, template/instance split, seed pipeline, indexes) — do not compress.

### Open Questions

- None at roadmap level. Research items above are deferred to phase planning time when they have specific implementation context.

---

*State initialized: 2026-05-10 after roadmap creation*
