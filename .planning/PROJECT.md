# Fitbod

## What This Is

A personal iOS app for comprehensive, detail-rich weight training tracking — built for one serious lifter (the developer) who finds existing apps (Strong, Hevy, Jefit, FitNotes, Fitbod) shallow on routine building, prescription, periodization, and progress visualization. It treats lifting like a discipline: session-level intent + progression, per-exercise prescription detail, user-defined training blocks with phased mesocycles, auto warm-up ramps, RP-style muscle-volume tracking with MEV/MAV/MRV bars + heatmap, plateau detection, end-of-block review, and CSV/JSON export + .fitbodbackup ZIP backup/restore.

## Current State

**Shipped:** v1.0 — Granular Lifting Tracker (2026-05-23)

7 phases (Phases 1–6 + 3.1 pivot), 67 plans, 304 commits, ~29,500 LOC Swift, 13-day timeline (2026-05-10 → 2026-05-23). SchemaV6 with full migration chain V1→V6. ~616 unit tests passing. All 47 v1 requirements satisfied.

## Core Value

**Granular, prescriptive workout sessions** — every set in a session is intentionally specified (intent, target reps, target RPE, smart-progressed weight) rather than a replay of last time, and progress is visible at the resolution serious lifters actually train at.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

**Routines** — v1.0
- ✓ Build, view, edit, reorder routines with session-level Intent + Progression header pickers (Phase 2 + Phase 3.1 PIVOT-01..04)
- ✓ Routine template vs Session instance separation (Phase 2 + SessionFactory snapshot pattern PITFALLS #1)
- ✓ Same routine recurs with separate intent histories (Phase 2 HIST-01..03 + Phase 3.1 session-level read)

**Prescription & progression** — v1.0
- ✓ Per-exercise prescription detail (Phase 2 PRES-01..04)
- ✓ Four progression models routed via single factory: RPE Autoreg, Double, Block-Periodized, Hybrid (Phase 3 + Phase 4 PRES-05/06)
- ✓ Auto warm-up ramp with deload skip (Phase 3 WARM-01..02 + Phase 4 WarmupDeloadIntegration)

**Periodization** — v1.0
- ✓ User-defined training blocks with phased mesocycles (Phase 4 BLOCK-01..05)
- ✓ Scheduled deload auto-cuts volume + holds intensity (Phase 4 D-12 + DeloadVolumeApplicationTests)
- ✓ Fatigue-triggered "consider deload" advisory (Phase 5 DeloadAdvisor — type-enforced as advisory-only per BLOCK-08)
- ✓ End-of-block review sheet (Phase 4 BLOCK-06/07)

**Tracking inputs (per set)** — v1.0
- ✓ Weight, reps, RPE, rest, tempo, notes (Phase 2 SES-01..06)

**Progress views** — v1.0
- ✓ Per-exercise intent-split history + chart (Phase 2 + Phase 6 PROG-01)
- ✓ Per-exercise PRs (1RM, top set, volume) + in-session PR banner (Phase 6 PROG-02 + PROG-08)
- ✓ Weekly tonnage chart with filter chips (Phase 6 PROG-03)
- ✓ Plateau detection with stall flag + suggested action (Phase 5 SET-06 + PROG-06)
- ✓ Muscle heatmap (front/back silhouette) with drilldown (Phase 5 VOL-01..07)
- ✓ Session comparison (Phase 6 PROG-07)

**Fatigue & volume model** — v1.0
- ✓ Stimulus-weighted per-muscle aggregation (Phase 5 FatigueModel + StimulusWeightTable)
- ✓ RP-style MEV/MAV/MRV bars + user-tunable targets (Phase 5 VOL-01..07 + SET-05)

**Exercise library** — v1.0
- ✓ ~800 bundled exercises seeded from free-exercise-db (Phase 1 LIB-01..06)
- ✓ Multi-facet filter UX (muscle / equipment / mechanic / pattern) (Phase 1)
- ✓ Custom exercise creation (Phase 1)

**Platform** — v1.0
- ✓ iOS native SwiftUI + SwiftData, Swift 6 strict concurrency
- ✓ Local-only persistence (SchemaV6)
- ✓ CSV / JSON export + .fitbodbackup ZIP backup/restore with round-trip canary (Phase 6 EXP-01..04)

### Active

<!-- v1.1 backlog — populated by /gsd:new-milestone. -->

(None — start v1.1 with `/gsd:new-milestone`)

### Out of Scope

<!-- Explicit boundaries with rationale. -->

- **Accounts / auth** — single user (the developer); no multi-user model needed for v1
- **Cloud sync / backend** — local-only data; iCloud sync may come later but not v1
- **Apple Watch companion** — phone-only v1 per scoping; revisit after core is stable
- **HealthKit integration** — explicitly excluded for v1 to keep surface area small
- **Velocity-based training (VBT) / accelerometer features** — too complex for v1
- **Social features, sharing, friends, leaderboards** — personal app
- **Subscriptions / monetization / App Store distribution** — personal app, no commercial path planned for v1
- **Cardio, mobility, nutrition, sleep, recovery, hydration** — scope is weight training only; no general fitness creep
- **Form-check video upload / AI form analysis** — text notes only for v1

## Context

**Codebase state**
- Stock Xcode SwiftUI + SwiftData template was created in `fitbod/` on 2026-05-10 — `fitbodApp.swift`, `ContentView.swift`, and a placeholder `Item.swift` SwiftData model.
- Test targets `fitbodTests/` and `fitbodUITests/` exist but are empty scaffolds.
- Treat content as greenfield. The template's `Item` model and `ContentView` will be replaced.

**Domain context**
- User trains seriously enough to care about RPE, tempo, periodization, deloads, MRV/MEV/MAV — implies hits same muscle group multiple times per week with intentional intent variation (strength vs hypertrophy days).
- Frustration is concrete and specific (not "I want a better app" — they named what breaks): routine builders are bad, prescriptions just replay last session, no warm-up generation, no block definition, same-routine-different-intent collapses into one history.
- "Comprehensive" and "small details that matter" is the design philosophy — not a feature, a stance. Implementation choices should favor more axes of detail (intent, tempo, RPE per set, muscle weighting) over simplicity when they conflict.

**Reference apps and what's wrong with each (for design contrast)**
- Strong, Hevy — clean UX, but rep/weight prescription is "what you did last time"; no autoregulation; periodization is bolt-on at best.
- Jefit — large exercise library but UX dated, no smart progression.
- FitNotes — barebones logger; no prescription, no fatigue model.
- Fitbod (the existing app) — has some smart prescription but black-box, not configurable; treats users as beginners.

**Adjacent frameworks worth referencing during design/research**
- Renaissance Periodization (RP) — MEV/MAV/MRV volume landmarks, mesocycle structure, deload heuristics.
- Reactive Training Systems (RTS) — RPE/RIR-based autoregulation.
- Block periodization (Issurin) — accumulation/intensification/realization phases.

## Constraints

- **Tech stack** — SwiftUI + SwiftData (locked by the existing Xcode template; no good reason to swap)
- **Platform** — iOS only (no Android, no web)
- **Persistence** — Local-only SwiftData for v1; no backend, no auth, no cloud sync
- **User scale** — Single user (the developer); no multi-tenant concerns
- **Hardware** — Phone-only v1; no Apple Watch, no external sensors, no VBT hardware
- **Distribution** — Personal install via Xcode; no App Store, no TestFlight required for v1

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| iOS native SwiftUI + SwiftData | Xcode template already created with this stack; native is the right call for a phone-first workout logger | ✓ Good |
| Single-user, local-only v1 | Personal app — no accounts, cloud, or backend complexity | ✓ Good |
| Session-level intent + progression (Phase 3.1 pivot from per-exercise) | Real programs are organized at session/block level; same exercise rarely flips intent within a session | ✓ Good — clean refactor, all reads simplified |
| User-selectable progression model (4 options: RPE/RIR, double, block, hybrid) | User wants choice per session/block | ✓ Good — all 4 routed via single ProgressionStrategyFactory |
| RP-style weekly volume tracking against MEV/MAV/MRV | Most prescriptive of the four offered models | ✓ Good — verb labels + two-tone bars + heatmap landed |
| Deload: scheduled by default + fatigue advisory (advisory-only per BLOCK-08) | Block schedule is canonical; fatigue advisory can never auto-mutate Block state | ✓ Good — type-level enforcement via DeloadAdvisor return type |
| ~800-exercise library from free-exercise-db (vendored JSON) | Public domain, single-file bundle, no AGPL exposure | ✓ Good — seeded in <2s on background ModelActor |
| Auto warm-up ramp on first compound only, with deload skip | Explicit user need; compound-only avoids per-exercise spam | ✓ Good |
| Phone-only v1 (no Watch, no HealthKit, no VBT) | Hardware integrations excluded from v1 scope | ✓ Good |
| SchemaV1→V6 migration chain with namespaced @Model types per VersionedSchema (Phase 3.1 BLOCKER 3 fix) | Apple's documented pattern; preserves V3 fixture types after V4 field removal | ✓ Good — round-trip canary green |
| Backup as PKWARE ZIP (no AppleArchive) with SHA-256 manifest + 7 restore gates + exit(0) restart | AppleArchive too heavy for personal app; custom ZIP gives deterministic byte layout for snapshot tests | ✓ Good — D-33 round-trip canary green |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-23 after v1.0 milestone*
