# Fitbod

## What This Is

A personal iOS app for comprehensive, detail-rich weight training tracking — built for one serious lifter (the developer) who finds existing apps (Strong, Hevy, Jefit, FitNotes, Fitbod) shallow on routine building, prescription, periodization, and progress visualization. It treats lifting like a discipline: per-exercise prescription, user-selectable smart progression, defined training blocks, auto warm-up ramps, and RP-style muscle-volume tracking.

## Core Value

**Granular, prescriptive workout sessions** — every set in a session is intentionally specified (intent, target reps, target RPE, smart-progressed weight) rather than a replay of last time, and progress is visible at the resolution serious lifters actually train at.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope. Building toward these. Hypotheses until shipped and validated. -->

**Routines**
- [ ] Build, view, edit, and reorder routines with low friction (clear primary pain point in existing apps)
- [ ] Routine template differs from a routine instance (the actual session that gets logged)
- [ ] Same routine can recur with different per-exercise intent (e.g., strength Mon / hypertrophy Thu) and the app keeps separate histories

**Prescription & progression**
- [ ] Per-exercise prescription: each exercise instance carries intent (strength / hypertrophy / etc.), target reps, target RPE/RIR, prescribed weight
- [ ] Smart progression — user picks the model per exercise or per block from:
  - RPE/RIR autoregulation (back-calculate weight from prior RPE + reps)
  - Double progression (hit top of rep range → add weight)
  - Block-periodized (curve defined by block phase)
  - Hybrid (block macro, RPE-driven daily)
- [ ] Auto warm-up ramp on first compound of session (e.g., 3 light ascending sets to top set)

**Periodization**
- [ ] User-defined training blocks: phase (accumulation/intensification/realization), length, deload schedule
- [ ] Scheduled deload (e.g., 4 load + 1 deload) auto-cuts volume/intensity that week
- [ ] App surfaces "consider deload" alert when fatigue/performance metrics spike

**Tracking inputs (per set)**
- [ ] Weight, reps, RPE, rest duration, tempo, form notes

**Progress views**
- [ ] Per-exercise history with intent split (strength sessions charted separately from hypertrophy)
- [ ] Per-exercise PRs (1RM est., top set, volume PRs)
- [ ] Weekly tonnage and set count
- [ ] Plateau detection signal (configurable: stalls over N sessions)
- [ ] Muscle heatmap / body view: which muscles hit recently and how hard

**Fatigue & volume model**
- [ ] Each exercise mapped to primary/secondary muscles with stimulus weighting
- [ ] RP-style weekly volume tracking per muscle vs MEV/MAV/MRV thresholds (user-tunable)
- [ ] Volume bars per muscle group color-coded against thresholds

**Exercise library**
- [ ] 1000+ bundled exercises seeded from an open dataset (wger / free-exercise-db candidates)
- [ ] Filter-heavy UX: by muscle, equipment, grip, mechanic (compound/isolation), pattern
- [ ] Custom exercise variations (user-added) supported

**Platform**
- [ ] iOS native, SwiftUI + SwiftData (Xcode template already in repo)
- [ ] Local-only persistence for v1

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
| iOS native SwiftUI + SwiftData | Xcode template already created with this stack; native is the right call for a phone-first workout logger with future Watch potential | — Pending |
| Single-user, local-only v1 | Personal app — no need for accounts, cloud, or backend complexity that dwarfs feature work | — Pending |
| Per-exercise prescription as the core unit | User explicitly chose this over session-level tag, separate routines, or mesocycle-only — gives maximum granularity for differentiating strength vs hypertrophy work on the same exercise | — Pending |
| User-selectable progression model (4 options: RPE/RIR, double, block, hybrid) | User wants choice — different exercises and blocks call for different models | — Pending |
| RP-style weekly volume tracking against MEV/MAV/MRV | User's chosen muscle-fatigue model — most prescriptive of the four offered | — Pending |
| Deload: scheduled by default + auto-suggest when fatigue spikes | User wanted both deterministic block-driven deloads and adaptive alerts | — Pending |
| 1000+ exercise library seeded from open dataset (wger / free-exercise-db) | "Exhaustive bundled" was the user's preference; comprehensive library is part of the differentiation | — Pending |
| Auto warm-up ramp on first compound only | Explicit user need; specified for the *initial* lift, not every exercise | — Pending |
| Phone-only v1 (no Watch, no HealthKit, no VBT) | User excluded all hardware integrations from v1 scope | — Pending |

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
*Last updated: 2026-05-10 after initialization*
