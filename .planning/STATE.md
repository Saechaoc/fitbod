---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Roadmap created, awaiting `/gsd-plan-phase 1`
last_updated: "2026-05-11T06:17:58.785Z"
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 12
  completed_plans: 4
  percent: 33
---

# Project State: Fitbod

**Last updated:** 2026-05-11

---

## Project Reference

**Core value:** Granular, prescriptive workout sessions — every set is intentionally specified (intent, target reps, target RPE, smart-progressed weight), and progress is visible at the resolution serious lifters actually train at.

**Stack:** SwiftUI + SwiftData, iOS 18+, local-only, phone-only v1, zero third-party dependencies.

**Mode:** MVP — every phase delivers an end-to-end vertical slice (not a horizontal layer).

**Granularity:** standard (5–8 phases).

---

## Current Position

**Phase:** 1 — Foundation & Exercise Library (in progress)
**Plan:** 01-02 complete (Wave 1, sequence 2 of N) — next: 01-03
**Status:** Schema versioning + ModelContainer wired; project compiles end-to-end for the first time since `Item.swift` was deleted in Wave 0
**Progress:** [░░░░░░░░░░] 0 / 6 phases complete (Phase 1 in flight)

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

Phase 1 in flight; metrics roll up at phase completion. Per-plan duration table:

| Phase | Plan | Duration (s) | Tasks | Files | Notes |
|-------|------|-------------:|------:|------:|-------|
| 1 | 00-01 | 240 (approx) | 3 | 12 | Project hygiene — delete Item.swift, bump Swift 6, scaffold folders |
| 1 | 00-02 | 180 (approx) | 2 | 3 | Asset catalog — AccentColor + placeholder AppIcon |
| 1 | 01-01 | 480 | 1 | 23 | 12 entity models + 11 enums |
| 1 | 01-02 | 68 | 2 | 4 | SchemaV1 + FitbodSchemaMigrationPlan + fitbodApp rewire + RootView stub |

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

- [x] `/gsd-plan-phase 1` — decompose Phase 1 into executable plans (PLAN-INDEX.md created)
- [x] Confirm `Item.swift` template model is removed before any seed import (plan 00-01 deleted it; plan 01-02 removed all `Item.self` references)
- [ ] Plan 01-03 — `PreviewModelContainer.make()` + first batch of SchemaV1 unit tests (Wave 1, next)
- [ ] Plans 02-01 / 02-02 — `ExerciseDTO` + `ExerciseLibraryImporter` (Wave 2)
- [ ] Plans 03-01 / 03-02 / 03-03 / 03-04 — RootView TabView + ExerciseLibraryView + custom exercise editor (Wave 3)

### Phase 1 Plans Completed

- **00-01** (Wave 0): Project hygiene — deleted `Item.swift`, bumped Swift 6 + strict concurrency, scaffolded feature-organized folders. Commits: `24ac4e0` / `8a16c96` / `40d9531` / `fa32cf2`.
- **00-02** (Wave 0, parallel): Asset catalog — AccentColor `#0E7C86` / `#3FBFC9`, placeholder AppIcon. Commits: `a1df0f3` / `e0c68d4`.
- **01-01** (Wave 1, seq 1): 12 `@Model` entities + 11 String-backed enums + 23 files. Commits: `cb27292` / `6aed051` / `8e35c93` / `adf8a7b` / `a4c5991`.
- **01-02** (Wave 1, seq 2): `SchemaV1: VersionedSchema` + `FitbodSchemaMigrationPlan` + `fitbodApp` rewire + interim `RootView` stub. Commits: `28795c8` / `58ea362`. Closes FOUND-01.

### Blockers

None.

---

## Session Continuity

### Last Action

Executed plan 01-02 (schema versioning + ModelContainer wiring). Project now compiles end-to-end (parse-PASS via `xcrun swiftc -parse` over the full source tree; `xcodebuild` unavailable in current environment — will be verified locally by user). FOUND-01 closed.

### Next Action

`/gsd-execute-phase 01-03` — adds `PreviewModelContainer.make()` factory and the first batch of Swift Testing unit tests over `SchemaV1` (FOUND-02 reflection, enum round-trip, cascade rules including `exerciseToSessionExerciseNullifies` proving LIB-05).

### Open Questions

- None at this layer. Plan 01-03 will exercise the schema at runtime (in-memory container) for the first time — should surface any macro-expansion edge cases that the parse-only verification has not caught.

### Key Decisions Accumulated (Phase 1)

- **Plan 01-01 D-1**: Public access modifiers throughout (test target reaches via `@testable import`)
- **Plan 01-01 D-2**: snake_case rawValues for multi-word enum cases (matches `yuhonas/free-exercise-db` wire format)
- **Plan 01-01 D-3**: `@Relationship(inverse:)` declared on owning side only (single canonical place per relationship)
- **Plan 01-02 D-1**: `enum FitbodSchemaMigrationPlan: SchemaMigrationPlan` (not `class`) — Apple-canonical form
- **Plan 01-02 D-2**: `let container: ModelContainer` (not `lazy var`) — Sendable-friendly under Swift 6 strict concurrency
- **Plan 01-02 D-4**: Interim `RootView` stays in `ContentView.swift` for this plan; renamed + moved to `App/RootView.swift` by plan 03-01 as a single pbxproj edit

---

*State initialized: 2026-05-10 after roadmap creation. Updated: 2026-05-11 after plan 01-02.*
