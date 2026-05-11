# Research Summary

**Domain:** Personal iOS weight-training tracker for one serious lifter
**Researched:** 2026-05-10
**Stack constraint:** Locked (SwiftUI + SwiftData, iOS 18+, local-only, phone-only v1)
**Overall confidence:** HIGH

---

## Executive Summary

Fitbod is a single-user, comprehensive iOS lifting tracker whose product wedge is **per-exercise prescription with explicit intent** layered on top of **template-vs-instance routine separation**, RP-style volume tracking, and four user-selectable progression algorithms. No competitor models any of these as first-class — Strong/Hevy/Fitbod all collapse intent into notes and let routine edits leak into history. The stack research confirms zero third-party dependencies are needed: SwiftUI + SwiftData (iOS 18) + Swift Charts + Swift Testing cover everything, with `yuhonas/free-exercise-db` (Unlicense, ~800 exercises, JSON) as the bundled seed.

The architecture converges on three opinionated decisions that the entire roadmap rotates around: (1) **MV-VM-lite** — bind views directly to `@Model` types via `@Query`/`@Bindable`, never mirror SwiftData in view models; (2) **snapshot at session start** — `SessionFactory` copies prescription fields from `RoutineExercise` (template) into `SessionExercise` (instance) so template edits never rewrite history; (3) **progression and fatigue as pure stateless services behind protocols** — four `ProgressionStrategy` value types swap per-exercise, all testable without `ModelContainer`. These three together make every later differentiator (intent-split histories, hybrid block+RPE prescription, stimulus-weighted volume math) a clean composition rather than a refactor.

The biggest risk is **Phase 1 architectural debt**. Versioned schema, template-vs-instance split, per-exercise intent on both prescription AND logged exercises, optional/defaulted properties (for future iCloud), and `#Index` on hot paths are all near-impossible to retrofit. Pitfalls research confirms: collapsing template/instance costs HIGH to recover; missing `VersionedSchema` costs HIGH; mixed-intent histories cost MEDIUM and require backfill heuristics. Everything else (RPE calibration, e1RM confidence, deload conflict resolution) is LOW-to-MEDIUM cost if Phase 1 lands correctly. Get Phase 1 right or pay forever; everything downstream is composable on top.

---

## Stack at a Glance

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language / runtime | Swift 6 (strict concurrency), iOS 18.0 deployment target | Single user, no install base — zero cost to picking the highest reasonable target. iOS 18 unlocks `#Index`, `#Unique`, `@Previewable`. |
| UI | SwiftUI | Locked by template. `@Observable` for ephemeral state; never `ObservableObject` in new code. |
| Persistence | SwiftData (iOS 18 API) | Locked by template. Production-ready in 2026. `#Index` on hot paths. **Write models as if for iCloud** (optional/defaulted properties) even though v1 is local-only — cheap insurance. |
| Charts | Swift Charts | Native; sufficient for ≤10k point ceiling. **Muscle heatmap is `Canvas` + SVG paths, not a chart.** |
| Testing | Swift Testing (unit) + XCTest (UI only) | Coexist in same target. UI tests *must* stay XCTest until Apple ships `XCUIApplication` support. |
| Lint/format | Bundled `swift-format` | SwiftLint optional and skippable for solo project. |
| Navigation | `TabView` root, per-tab `NavigationStack` | Never wrap `TabView` in a parent `NavigationStack`. |
| Exercise dataset | `yuhonas/free-exercise-db` (Unlicense, ~800 exercises, JSON, image assets) | Decision converges: best license, cleanest schema, no API dependency. Filter import to `category ∈ {strength, powerlifting, olympic weightlifting, strongman}`. |
| Dependencies | **None** | No SPM packages needed for v1. |

**Seed strategy:** Code-based JSON-on-launch (not bundled `.store` file) — idempotent, version-stamped via `UserDefaults`, runs once inside a `@ModelActor`.

---

## Highest-Leverage Architectural Decisions (Phase 1 Must Get These Right)

These ten decisions are the load-bearing structure. Each is hard or impossible to retrofit.

1. **Template vs Instance via snapshot** — `Routine` / `RoutineExercise` (templates) are separate types from `Session` / `SessionExercise` (instances). `SessionFactory.start(...)` copies prescription fields at session-start time. Template edits never rewrite history. *This is the prerequisite for per-exercise intent histories, edit-routine-without-rewriting-history, and same-routine-different-intent. The biggest single architectural decision in the project.*

2. **Per-exercise intent on BOTH `RoutineExercise` AND `SessionExercise`** — Intent (strength/hypertrophy/power/endurance) is a first-class column on the prescription and is snapshotted onto the logged exercise. This is the actual product wedge — no competitor does this. Drives intent-split charts, intent-filtered PR detection, intent-filtered "previous" column.

3. **`VersionedSchema` + `SchemaMigrationPlan` from Day 1** — Wrap v1 in `enum SchemaV1: VersionedSchema` even with no migrations yet. Cost: 30 minutes. Cost of skipping: data loss on first rename. Non-negotiable.

4. **`ProgressionStrategy` protocol with four pure-function value-type implementations** — `RPEAutoregStrategy`, `DoubleProgressionStrategy`, `BlockPeriodizedStrategy`, `HybridStrategy`. All pure: take history + settings + phase, return `ProgressionSuggestion`. No `ModelContainer` needed for tests. Selectable per `RoutineExercise` via `ProgressionKind` enum (stored as `String` raw — see #9).

5. **`ExerciseMuscleStimulus` join entity with `weight: Double`** — Not "exercise hits chest" boolean. "Exercise contributes 1.0 to chest, 0.5 to triceps." Weekly volume = Σ weighted sets per muscle. *This is the prerequisite for accurate RP-style MEV/MAV/MRV math on compounds.* Seed defaults: primary=1.0, secondary=0.5; user-tunable. **One hand-curated table needed** for the main lifts.

6. **`#Index` on hot query paths (iOS 18)** — `Exercise.canonicalName / equipmentRaw / mechanicRaw / isCustom`, `Session.startedAt / sourceRoutineID`, `SessionExercise.intentRaw`. Library filter UX hits these on every keystroke; intent-split charts hit them on every render. Adding indexes later is a migration.

7. **Write models as if for iCloud (optional/defaulted properties)** — iCloud requires every property optional or defaulted and every relationship optional. v1 is local-only, but writing models this way costs nothing now and unblocks future sync without a painful migration.

8. **MV-VM-lite — bind views to `@Model` directly** — `@Query` for reactive reads, `@Bindable` for editing. **Never wrap `@Query` in a view model** — breaks SwiftUI's reactivity. View models exist only for *ephemeral UI state* (active session controller, filter chip state). This is the largest single time-waster in SwiftData apps; the architecture is structured to forbid it.

9. **Enums persisted as `*Raw: String`, not as enum types** — SwiftData has sharp edges around enum `RawValue` evolution. `intentRaw: String` with a computed `var intent: Intent` accessor keeps most enum additions migration-free.

10. **`@MainActor` for `ModelContext` in views; `@ModelActor` ONLY for the one-time library seed** — Math services (`ProgressionEngine`, `FatigueModel`, `PlateauDetector`) are deliberately synchronous and stateless. Hopping actors during a live workout has perceptible cost; the data volumes are tiny. Reserve `@ModelActor` for the 800-row JSON import.

---

## Features at a Glance

### Table Stakes (v1 must ship — failing any of these fails the "comprehensive" stance)

Exercise library (filterable by muscle/equipment/mechanic) · Custom exercise creation **with required muscle mapping** · Single-screen routine builder (inline search, drag-reorder, supersets) · Per-exercise prescription (intent + target rep range + target RPE + scheme) · Routine instance vs template separation · Set logging (weight, reps, RPE, rest timer, set types, per-set notes) · Rest timer (auto-start, ±15s, **lock-screen notification**, skip-and-log) · Plate calculator integrated with weight entry · Auto warm-up ramp on first compound (plate-rounded, edge-case-aware) · Four selectable progression models per exercise · Previous-set inline display (intent-filtered) · Per-exercise history with intent split · e1RM tracking (Epley + Brzycki, rep-range aware) · PR detection (weight, rep, volume, e1RM — intent-matched) · Tempo entry (4-field) · CSV + JSON export · Local backup/restore · Weight unit settings (global + per-exercise override)

### Differentiators (the "small details that matter")

Per-exercise intent as first-class data (no competitor does this) · Target reps and RPE as **ranges** not single numbers · Per-set prescription override (top set + back-offs) · Recommended weight with **expandable "why this weight?"** calculation breakdown · Block timeline visible on home screen with phase color coding · Mesocycle navigation (swipe between weeks) · Per-muscle volume bars with **MEV/MAV/MRV bands and verbs** ("add a set" / "hold" / "deload soon") · Stimulus-weighted volume aggregation (not double-counting compounds) · User-tunable MEV/MAV/MRV per muscle · Intent-split per-exercise charts · Plateau detection with configurable thresholds and **suggested actions** · "Last time same intent" inline previous column · Pinned exercise notes · Tempo on prescription (not just logging) · Decimal RPE entry · Routine "today" instance editable without mutating template · History shows prescribed vs actual

### Anti-features (deliberately NOT built)

Cardio · Nutrition · Social/streaks/XP/badges · AI black-box recommendations · Beginner onboarding · Workout reminders · HealthKit · Apple Watch (v1) · VBT/accelerometer · Video form analysis · Cloud sync (v1) · Auth/multi-user · Subscriptions · Programs marketplace · Body weight / measurements · Photo progress · Audio cues

---

## Load-Bearing Pitfalls (Roadmap Must Design Around These)

These five pitfalls have the highest blast radius. The full pitfall list is in PITFALLS.md; these are the ones that drive phase structure.

| # | Pitfall | Roadmap implication |
|---|---------|----------------------|
| 1 | **Collapsing template and instance** | Phase 1 ships the snapshot model or the project is structurally broken. HIGH recovery cost. |
| 2 | **Missing `VersionedSchema` in v1** | Phase 1 wraps schema in `SchemaV1` even with empty migration plan. HIGH recovery cost (requires retroactive schema reconstruction). |
| 3 | **Volume math correct but UX numbers don't drive a decision** | Every volume display in the Fatigue Model phase must answer "what should I do about this?" — verbs not numbers. Bars show direct/indirect split visually. Next-session prescription auto-adjusts based on volume state. |
| 4 | **Rest timer drifts/stops on lock** | Logging phase ships `Date`-based timer + `UNUserNotification` scheduled at start — never a foreground `Timer`. The single most user-visible failure mode. |
| 5 | **RPE-to-weight back-calc uses population averages globally** | Progression phase: canonical Tuchscherer table is a *prior*; per-exercise per-lifter calibration over rolling 8-12 week window kicks in after ≥10 data points. Until then, prescribed weight is shown as a *range* with a "calibrating" badge. |

Also load-bearing but lower urgency:

- **Custom exercise muscle mapping required, not optional** — silent volume corruption otherwise (Phase 2 exercise library)
- **Library filter `#Index` from the start** — 300ms keystroke lag at 1000 exercises without indexes (Phase 2)
- **Warm-up ramp edge cases** (deload weeks, unilateral, light weights, plate inventory) — Phase 3 prescription
- **Deload conflict resolution** (block schedule is canonical, fatigue detector emits suggestions only) — Phase 4 periodization
- **e1RM rep-range aware** (Brzycki ≤6 reps, Epley 6-10, suppress >10 reps from PR detection) — Phase 6 progress

---

## Recommended Build Order

The architecture's six-phase ordering is well-established and dependency-driven. Each phase lands on a stable foundation; no phase requires retroactive changes to earlier phases.

### Phase 1 — Foundation (highest architectural weight; everything else assumes this)
**Delivers:** Versioned schema, full `@Model` entity set, `ModelContainer` wired, in-memory preview container, exercise library seed pipeline (`@ModelActor`-backed), exercise library browse/filter/custom-creation UI.

**Why first:** Schema decisions are near-impossible to retrofit. The 800-exercise seed surfaces SwiftData performance issues early when they're cheap to fix. Library is the keystone — every other feature depends on having well-modeled exercises with muscle mappings.

**Pitfalls addressed:** #1 (template/instance), #2 (versioned schema), #5 (stimulus weighting), #7 (filter indexes), #6 (main-thread bulk ops).

**Features delivered:** Exercise library + filter, custom exercise creation (with required muscle mapping).

**Research flag:** Standard SwiftData patterns — no further research needed.

### Phase 2 — Core Loop (the minimum lovable product)
**Delivers:** Routine builder (single-screen, drag-reorder, inline search, prescription as first-class), `SessionFactory.start(...)` (snapshot without progression yet — prescribed weight defaults to last-logged), session logger (set entry, rest timer, set types, per-set notes), per-exercise history with intent split (lists, no charts yet).

**Why next:** Proves the template/instance separation works before any algorithmic complexity is layered on. Validates the intent-split data structure with real data. Rest timer is the #1 user-visible failure mode and must ship correctly from the start.

**Pitfalls addressed:** #1 (snapshot pattern verified end-to-end), #4 (rest timer with `Date` + notification).

**Research flag:** Standard patterns. Rest timer correctness needs care but is well-documented.

### Phase 3 — Smart Prescription
**Delivers:** `OneRepMaxEstimator` + `RPETable`, `ProgressionStrategy` protocol, `DoubleProgressionStrategy`, `RPEAutoregStrategy`, `WarmupGenerator` with edge-case handling, plate calculator, "why this weight?" UI disclosure.

**Why now:** Real logged data from Phase 2 lets each strategy be tested against actual sessions rather than fixtures.

**Pitfalls addressed:** #5 (RPE per-exercise calibration after ≥10 points; until then show range with "calibrating" badge), warm-up edge cases.

**Research flag:** Possibly research RPE table numbers (Tuchscherer) and per-exercise calibration algorithm choice during planning.

### Phase 4 — Periodization
**Delivers:** `Block` + `BlockPhase` models, block builder UI, `PeriodizationEngine.phase(for:on:)`, `BlockPeriodizedStrategy` and `HybridStrategy` (now four strategies live), block timeline on home screen with phase color coding, mesocycle navigation, scheduled deload.

**Why now:** Block-periodized and hybrid strategies both depend on phase resolution.

**Pitfalls addressed:** Sets up the deload conflict resolution model.

**Research flag:** Possibly research block periodization curve shapes during planning.

### Phase 5 — Fatigue Model
**Delivers:** Bundled `MuscleVolumeTarget` defaults (RP-published values), user-tunable in settings, `FatigueModel.weeklyVolume(...)` (stimulus-weighted), volume bars with MEV/MAV/MRV zones AND verb labels, muscle heatmap (`Canvas` + SVG), `PlateauDetector`, fatigue-triggered deload alert (suggestion only).

**Why now:** Sessions exist to compute from.

**Pitfalls addressed:** #3 (verbs not numbers), deload conflict resolution.

**Research flag:** Possibly research stimulus-weighting table for compound exercises (curated weights for the main 50 lifts) during planning.

### Phase 6 — Progress Views & Polish
**Delivers:** Per-exercise intent-split charts (Swift Charts, two series per chart), weekly tonnage chart, PRs view (intent-matched, rep-range-aware e1RM), session comparison view, weekly recap, settings polish, CSV + JSON export, local backup/restore.

**Why last:** Pure presentation polish on a stable backend.

**Pitfalls addressed:** e1RM rep-range aware.

**Research flag:** Standard Swift Charts patterns.

---

## Suggested Phase Structure for the Roadmap

| # | Phase | Deliverable | Pitfalls Addressed | Research Flag |
|---|-------|-------------|--------------------|--------------:|
| 1 | Foundation | Versioned schema, entities, library seed, library browse + custom creation | #1, #2, #5, #6, #7 | None — patterns are standard |
| 2 | Core Loop | Routine builder, session logger, rest timer, intent-split history (lists) | #1 (verified), #4 | None — patterns are standard |
| 3 | Smart Prescription | 2 of 4 progression models, warm-up generator, plate calculator | #5, warm-up edges | Maybe: RPE table / calibration |
| 4 | Periodization | Blocks, scheduled deload, block timeline UI, remaining 2 progression models | (deload conflict groundwork) | Maybe: phase curve multipliers |
| 5 | Fatigue Model | Volume bars + verbs, heatmap, plateau detection, fatigue deload alert | #3, deload conflict | Maybe: stimulus weighting curation |
| 6 | Progress Views & Polish | Intent-split charts, PRs, comparison/recap, export/backup | e1RM rep-range | None |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Apple-native, Context7-verified, no third-party deps. Dataset schema fetched directly. |
| Features | HIGH | 10+ competitor apps inspected; Hevy/Strong/Liftosaur publish detailed docs. Differentiators are concrete UI decisions, not speculation. |
| Architecture | HIGH | SwiftData patterns well-documented; domain entity model derives cleanly from PROJECT.md requirements. MEDIUM only on exact numeric formulas in progression/plateau (deliberately swappable behind protocols). |
| Pitfalls | HIGH | Cross-referenced against Apple docs, recent SwiftData community writeups, and behavior of existing apps. |

### Gaps to Address During Planning

- **Stimulus weighting table for compounds** — `free-exercise-db` provides primary/secondary lists only (boolean). One hand-curated table mapping ~50 main lifts to per-muscle weights is needed for accurate volume math. Defer details to Phase 5 planning.
- **Per-exercise per-lifter RPE calibration algorithm** — research notes "rolling regression over last 8-12 weeks" but exact fit method (linear vs locally-weighted) and minimum data points (research suggests ≥10) need confirmation. Defer to Phase 3 planning.
- **Block phase curve multipliers** — accumulation/intensification/realization/deload values are well-known starting points (e.g., deload = 60% volume, 90% intensity) but exact defaults should be confirmed against current RP/RTS literature. Defer to Phase 4 planning.
- **Live Activity / Dynamic Island for rest timer** — noted as a nice-to-have differentiator but not a v1 must-have. Could be added in Phase 6 polish or deferred to v1.x.

### Areas Where Roadmap Should NOT Add Scope

- iCloud sync (write models as if for it; don't ship it)
- Apple Watch companion
- HealthKit
- VBT / hardware
- Live Activities beyond rest timer
- Any anti-feature from the features list

---

*Research synthesized: 2026-05-10*
