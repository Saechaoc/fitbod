# Requirements: Fitbod

**Defined:** 2026-05-10
**Core Value:** Granular, prescriptive workout sessions — every set is intentionally specified (intent, target reps, target RPE, smart-progressed weight), and progress is visible at the resolution serious lifters actually train at.

---

## v1 Requirements

User explicitly wants a maximalist v1 (the app's stance is "comprehensive over simple"). Every requirement below is in scope for first release.

### LIB — Exercise Library

- [x] **LIB-01**: User can browse the bundled exercise library (~800 exercises seeded from `yuhonas/free-exercise-db`, Unlicense)
- [x] **LIB-02**: User can multi-facet filter exercises by muscle group, equipment, mechanic (compound/isolation), and movement pattern
- [x] **LIB-03**: User can search exercises by name with type-ahead (responsive at 1000+ entries via SwiftData `#Index` on hot fields)
- [x] **LIB-04**: User can create custom exercises with required primary + secondary muscle mapping (with per-muscle stimulus weights), equipment, mechanic, and optional image
- [x] **LIB-05**: User can edit and delete custom exercises without affecting historical session data
- [x] **LIB-06**: Bundled exercises distinguish bodyweight, weighted-bodyweight, machine, dumbbell, barbell, cable, and bands; UI input fields adapt per kind

### ROUTINE — Routine Builder & Templates

- [x] **ROUTINE-01**: User can build a routine in a single screen — inline exercise search-and-add, drag-handle reorder, no modal exercise picker
- [x] **ROUTINE-02**: Each exercise in a routine carries first-class prescription: training intent (strength / hypertrophy / power / endurance / technique), target rep range, target RPE range
- [x] **ROUTINE-03**: User can set per-set prescription overrides within an exercise (e.g. top set + back-off sets with different rep/RPE targets)
- [x] **ROUTINE-04**: User can group exercises into supersets and giant sets (2–N exercises with shared accent rail and smart-scroll between paired sets)
- [x] **ROUTINE-05**: User can choose a progression model per exercise from four options: RPE/RIR autoreg, double progression, block-periodized, hybrid
- [x] **ROUTINE-06**: User can duplicate routines and organize them into folders
- [x] **ROUTINE-07**: Routine templates are stored separately from session instances — editing a routine never rewrites historical session data (snapshot-at-session-start)
- [x] **ROUTINE-08**: The same routine recurring on different days with different intent (e.g. strength Mon, hypertrophy Thu) maintains separate per-intent histories for each exercise
- [x] **ROUTINE-09**: Each routine exercise has a default rest timer (heuristic by mechanic: compound ≈ 180s, isolation ≈ 90s) that the user can override per exercise

### SESS — Session Logging

- [x] **SESS-01**: Starting a session calls `SessionFactory.start(...)` which snapshots all routine prescription fields onto the session — subsequent edits to the routine template never alter this session
- [x] **SESS-02**: User can log per set: weight, reps, RPE (decimal RPE supported via long-press), set type (warmup / working / drop / failure / rest-pause), and per-set form notes
- [x] **SESS-03**: Set inputs auto-populate from the previous matching-intent session of the same exercise; an inline "previous" column shows weight × reps × RPE from that last instance
- [x] **SESS-04**: Rest timer auto-starts on set completion, exposes ±15s buttons, fires a lock-screen notification when it reaches 0, displays as a Live Activity / Dynamic Island while running, and auto-stops on next set entry
- [x] **SESS-05**: User can swap an exercise mid-session without mutating the routine template (substitution applies to this session only)
- [x] **SESS-06**: User can add unplanned exercises mid-session (added to the session, not the routine)
- [x] **SESS-07**: User can enter optional tempo per set as 4-field eccentric / bottom-pause / concentric / top-pause
- [x] **SESS-08**: User can record partial reps (e.g. "8 + 2 partials") and cluster / rest-pause sub-reps (e.g. `[8, 3, 2]`) per set
- [x] **SESS-09**: Bodyweight and weighted-bodyweight exercises log reps + added/assisted weight (signed: negative = assist)
- [x] **SESS-10**: User can view per-exercise history with intent split as separate streams (strength series vs hypertrophy series, toggleable / both visible)
- [x] **SESS-11**: Workout-level notes and pinned per-exercise notes are surfaced inline in the session UI

### WARM — Warm-up Generation

- [x] **WARM-01**: First compound exercise of a session auto-generates a warm-up ramp (3–5 ascending sets) plate-rounded to the user's plate inventory
- [x] **WARM-02**: Warm-up generator handles edge cases correctly: deload weeks (skip), unilateral lifts (halve loads), light working weights (skip when <1.5× bar), bodyweight (skip)
- [x] **WARM-03**: User can override the warm-up scheme per exercise or disable warm-ups

### PRES — Smart Prescription & Progression

- [x] **PRES-01**: At session start, each working exercise displays a recommended weight computed by its selected progression model
- [x] **PRES-02**: User can expand "Why this weight?" on any prescription to see the calculation breakdown (last session's data, formula, percent, rounding)
- [x] **PRES-03**: `RPEAutoregStrategy` back-calculates target weight from prior RPE + reps using Tuchscherer table as a prior; switches to per-exercise per-lifter calibration after ≥10 logged sets (shown as a "calibrating" badge until then)
- [x] **PRES-04**: `DoubleProgressionStrategy` advances weight by the exercise's smallest-increment when all working sets hit the top of the rep range
- [ ] **PRES-05**: `BlockPeriodizedStrategy` resolves weight from the active block phase's intensity curve
- [ ] **PRES-06**: `HybridStrategy` combines block phase context with RPE-driven daily adjustment
- [x] **PRES-07**: User can manually override the recommended weight; the override is recorded as actual performance and feeds into the next session's calculation (never ignored)
- [x] **PRES-08**: Integrated plate calculator: given target weight and bar weight, output a plate stack respecting the user's plate inventory
- [x] **PRES-09**: All progression rounding respects per-exercise smallest weight increment (microplates, plate jumps)
- [x] **PRES-10**: "You earned the weight bump" banner surfaces when double progression triggers an increment

### BLOCK — Periodization

- [ ] **BLOCK-01**: User can define training blocks with phase sequence (accumulation, intensification, realization, deload) and week length per phase
- [ ] **BLOCK-02**: Active block visible on home screen: phase chip, "Week N of M", days remaining, phase color-coded
- [ ] **BLOCK-03**: User can navigate weeks within a block (swipe between weeks / mesocycle navigation)
- [ ] **BLOCK-04**: Scheduled deload weeks auto-reduce prescribed volume (~50%) and adjust intensity per the deload phase definition
- [ ] **BLOCK-05**: Deload weeks are visually distinct (banner / calendar tint / volume targets cut on bars and heatmap)
- [ ] **BLOCK-06a**: UI scaffold for the "consider deload" advisory — `ConsiderDeloadBanner` view + `FatigueAdvisory` protocol exist and are wired into TodayView; `StubFatigueAdvisory` returns `false` so the banner never renders in Phase 4. The advisory contract returns only `FatigueSuggestion` (never `DeloadMutation`), enforcing BLOCK-08 at the type level. (Phase 4)
- [ ] **BLOCK-06b**: Real fatigue/performance signal — e1RM-drop / RPE-creep / missed-rep detection populates a non-stub `FatigueAdvisory` implementation; banner activates above threshold (suggestion only, never auto-applies). Closes the substance half of the original BLOCK-06. (Phase 5)
- [ ] **BLOCK-07**: End-of-block produces a phase-end review (total volume, e1RM deltas, PRs hit, recommended next phase)
- [ ] **BLOCK-08**: Scheduled block deload is canonical; fatigue-triggered alerts are advisory and never override the block schedule

### VOL — Volume & Fatigue Model

- [ ] **VOL-01**: Each exercise maps primary and secondary muscles via an `ExerciseMuscleStimulus` join with `weight: Double` (defaults: 1.0 primary, 0.5 secondary; hand-curated for the top ~50 lifts; user-tunable per exercise)
- [ ] **VOL-02**: Weekly volume per muscle computed as the stimulus-weighted sum of working sets from logged sessions
- [ ] **VOL-03**: Per-muscle MEV / MAV / MRV thresholds seeded from RP-published values, user-tunable in settings
- [ ] **VOL-04**: Per-muscle volume bars display current weekly sets with MEV/MAV/MRV color zones AND verb labels ("add a set" / "hold" / "near MRV — deload soon" / "over MRV — deload")
- [ ] **VOL-05**: Front and back body silhouette heatmap shows weekly volume per muscle as color intensity; muscle regions are tappable to drill into the per-muscle detail view
- [ ] **VOL-06**: Per-muscle frequency tracking (count of sessions per week in which the muscle met a minimum stimulus threshold)
- [ ] **VOL-07**: Weekly recap auto-surfaced at the week boundary: muscles hit, muscles under-trained, e1RM movement, sessions logged

### PROG — Progress Views & Charts

- [ ] **PROG-01**: Per-exercise time-series chart with intent split — strength series and hypertrophy series rendered as distinct lines on the same chart
- [ ] **PROG-02**: e1RM trend per exercise using both Epley and Brzycki formulas, rep-range aware (Brzycki for ≤6 reps, Epley for 6–10 reps, suppress >10 reps from PR detection)
- [ ] **PROG-03**: Top-set e1RM vs all-set average e1RM displayed as separate toggleable series
- [ ] **PROG-04**: Weekly tonnage chart (total weight × reps), sliceable by week / block phase / muscle group
- [ ] **PROG-05**: PRs view per exercise: weight PRs, rep PRs, volume PRs, e1RM PRs (intent-matched, rep-range aware)
- [ ] **PROG-06**: Plateau detection signal per exercise with configurable threshold (e.g. e1RM flat ±X% over N sessions); visual stall flag on the exercise card with suggested action
- [ ] **PROG-07**: Session comparison view: this week's session vs last week's same-routine session, side-by-side per-exercise diff
- [ ] **PROG-08**: Live PR detection at set save (in-session banner: "weight PR" / "volume PR" / "e1RM PR")

### EXP — Data Export & Backup

- [ ] **EXP-01**: User can export all data as CSV (sessions → exercises → sets, one row per set)
- [ ] **EXP-02**: User can export all data as JSON (full schema preserved, version-stamped)
- [ ] **EXP-03**: User can create a full database backup file shareable via AirDrop / Files / iCloud Drive
- [ ] **EXP-04**: User can restore from a backup file with explicit confirmation (data-loss warning)

### SET — Settings & Configuration

- [x] **SET-01**: Global weight units (lb / kg) toggle
- [x] **SET-02**: Per-exercise weight unit override
- [x] **SET-03**: User defines plate inventory per equipment type (which plates available, microplates yes/no)
- [x] **SET-04**: User defines smallest weight increment per equipment type (consumed by all progression rounding and warm-up ramping)
- [ ] **SET-05**: User-tunable MEV / MAV / MRV per muscle
- [ ] **SET-06**: User-tunable plateau detection thresholds per exercise (or global default)
- [x] **SET-07**: User-tunable RPE-autoreg calibration window (rolling N weeks / minimum N data points)

### FOUND — Foundational Quality Bars (apply across all features)

- [x] **FOUND-01**: Schema wrapped in `SchemaV1: VersionedSchema` with `SchemaMigrationPlan` scaffold from day 1 (zero migrations yet, but framework in place) — closed by plan 01-02 (commit `28795c8`)
- [x] **FOUND-02**: All model properties optional or default-valued, all relationships optional (cheap insurance for future iCloud sync without retroactive migration)
- [x] **FOUND-03**: All enums persisted as `*Raw: String` columns with computed enum accessors
- [x] **FOUND-04**: SwiftData `#Index` declarations on every hot query field (`Exercise.canonicalName`, `equipmentRaw`, `mechanicRaw`, `isCustom`; `Session.startedAt`, `sourceRoutineID`; `SessionExercise.intentRaw`)
- [x] **FOUND-05**: Exercise library seed runs once inside a `@ModelActor`, idempotent, version-stamped via `UserDefaults`, completes in <2s on cold launch — closed by plan 02-02 (commits `998bacb` / `97f023a`)
- [x] **FOUND-06**: Views bind directly to `@Model` types via `@Query` / `@Bindable`; no parallel view-model layer mirrors the schema (MV-VM-lite stance)
- [x] **FOUND-07**: Progression and fatigue services are pure-function value types behind protocols, testable without a `ModelContainer`

---

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### SYNC — iCloud Sync (future)

- **SYNC-01**: User can opt in to iCloud sync via `ModelConfiguration(cloudKitDatabase: .private)` — models are already shaped for this (see FOUND-02)
- **SYNC-02**: Conflict resolution policy (last-write-wins per record)

### WATCH — Apple Watch Companion (future)

- **WATCH-01**: User can log sets from the wrist mid-workout
- **WATCH-02**: Rest timer haptics on the Watch
- **WATCH-03**: Optional heart rate capture during sets

---

## Out of Scope

Explicitly excluded — documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cardio tracking | App scope is weight training only; no general fitness creep |
| Nutrition / macro tracking | Out of scope — separate domain |
| Body weight / measurements / photo progress | Out of scope for v1; HealthKit is excluded |
| Social features (friends, streaks, XP, badges, sharing, leaderboards) | Personal single-user app; fights the serious-training stance |
| AI black-box recommendations (Fitbod-style) | Explicitly rejected — recommendations must be transparent (PRES-02 "Why this weight?") |
| Beginner onboarding / tutorials | User is the developer; no audience to onboard |
| Workout reminders / scheduling notifications | Out of scope — user drives their own schedule |
| HealthKit read/write | Excluded for v1; would couple to Apple Health domain semantics |
| Apple Watch companion | Phone-only v1 (see WATCH in v2) |
| VBT / accelerometer / external sensors | No hardware integration v1 |
| Video form analysis / form-check upload / AI form review | Out of scope; text per-set notes are sufficient |
| iCloud sync (shipping) | Excluded for v1 (see SYNC in v2); models are shaped for it (FOUND-02) but sync is not wired |
| Authentication / multi-user | Single-user app |
| Subscriptions / monetization / paywalls | Personal app, no commercial path planned |
| App Store distribution / TestFlight | Personal install via Xcode only for v1 |
| Programs marketplace / shareable routines / community library | Out of scope — single-user app |
| Audio cues / spoken set guidance | Out of scope |
| Third-party SPM dependencies | Locked out — entire stack is Apple-native (SwiftData, SwiftUI, Swift Charts, Swift Testing) |

---

## Traceability

Mapped to phases by `gsd-roadmapper` during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| LIB-01 | Phase 1 | Complete |
| LIB-02 | Phase 1 | Complete |
| LIB-03 | Phase 1 | Complete |
| LIB-04 | Phase 1 | Complete |
| LIB-05 | Phase 1 | Complete |
| LIB-06 | Phase 1 | Complete |
| ROUTINE-01 | Phase 2 | Complete |
| ROUTINE-02 | Phase 2 | Complete |
| ROUTINE-03 | Phase 2 | Complete |
| ROUTINE-04 | Phase 2 | Complete |
| ROUTINE-05 | Phase 2 | Complete |
| ROUTINE-06 | Phase 2 | Complete |
| ROUTINE-07 | Phase 2 | Complete |
| ROUTINE-08 | Phase 2 | Complete |
| ROUTINE-09 | Phase 2 | Complete |
| SESS-01 | Phase 2 | Complete |
| SESS-02 | Phase 2 | Complete |
| SESS-03 | Phase 2 | Complete |
| SESS-04 | Phase 2 | Complete |
| SESS-05 | Phase 2 | Complete |
| SESS-06 | Phase 2 | Complete |
| SESS-07 | Phase 2 | Complete |
| SESS-08 | Phase 2 | Complete |
| SESS-09 | Phase 2 | Complete |
| SESS-10 | Phase 2 | Complete |
| SESS-11 | Phase 2 | Complete |
| WARM-01 | Phase 3 | Complete |
| WARM-02 | Phase 3 | Complete |
| WARM-03 | Phase 3 | Complete |
| PRES-01 | Phase 3 | Complete |
| PRES-02 | Phase 3 | Complete |
| PRES-03 | Phase 3 | Complete |
| PRES-04 | Phase 3 | Complete |
| PRES-05 | Phase 4 | Pending |
| PRES-06 | Phase 4 | Pending |
| PRES-07 | Phase 3 | Complete |
| PRES-08 | Phase 3 | Complete |
| PRES-09 | Phase 3 | Complete |
| PRES-10 | Phase 3 | Complete |
| BLOCK-01 | Phase 4 | Pending |
| BLOCK-02 | Phase 4 | Pending |
| BLOCK-03 | Phase 4 | Pending |
| BLOCK-04 | Phase 4 | Pending |
| BLOCK-05 | Phase 4 | Pending |
| BLOCK-06a | Phase 4 | Pending (UI scaffold + protocol type-level enforcement; stub signal) |
| BLOCK-06b | Phase 5 | Pending (real fatigue signal populates the FatigueAdvisory implementation) |
| BLOCK-07 | Phase 4 | Pending |
| BLOCK-08 | Phase 4 | Pending |
| VOL-01 | Phase 5 | Pending |
| VOL-02 | Phase 5 | Pending |
| VOL-03 | Phase 5 | Pending |
| VOL-04 | Phase 5 | Pending |
| VOL-05 | Phase 5 | Pending |
| VOL-06 | Phase 5 | Pending |
| VOL-07 | Phase 5 | Pending |
| PROG-01 | Phase 6 | Pending |
| PROG-02 | Phase 6 | Pending |
| PROG-03 | Phase 6 | Pending |
| PROG-04 | Phase 6 | Pending |
| PROG-05 | Phase 6 | Pending |
| PROG-06 | Phase 5 | Pending |
| PROG-07 | Phase 6 | Pending |
| PROG-08 | Phase 6 | Pending |
| EXP-01 | Phase 6 | Pending |
| EXP-02 | Phase 6 | Pending |
| EXP-03 | Phase 6 | Pending |
| EXP-04 | Phase 6 | Pending |
| SET-01 | Phase 1 | Complete |
| SET-02 | Phase 3 | Complete |
| SET-03 | Phase 3 | Complete |
| SET-04 | Phase 3 | Complete |
| SET-05 | Phase 5 | Pending |
| SET-06 | Phase 5 | Pending |
| SET-07 | Phase 3 | Complete |
| FOUND-01 | Phase 1 | Complete (plan 01-02, commit 28795c8) |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| FOUND-05 | Phase 1 | Complete (plan 02-02, commits 998bacb / 97f023a) |
| FOUND-06 | Phase 1 | Complete |
| FOUND-07 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 81 total (6 LIB + 9 ROUTINE + 11 SESS + 3 WARM + 10 PRES + 9 BLOCK + 7 VOL + 8 PROG + 4 EXP + 7 SET + 7 FOUND = 81)
- Mapped to phases: 81
- Unmapped: 0
- Note: BLOCK-06 was split into BLOCK-06a (Phase 4 UI scaffold + protocol contract) and BLOCK-06b (Phase 5 real fatigue signal) on 2026-05-22 per checker blocker #5; this raises BLOCK count from 8 to 9 and total from 80 to 81.

Per-phase counts:
- Phase 1 (Foundation & Exercise Library): 14 — FOUND-01..07, LIB-01..06, SET-01
- Phase 2 (Core Loop — Routines + Sessions): 20 — ROUTINE-01..09, SESS-01..11
- Phase 3 (Smart Prescription & Warm-ups): 15 — PRES-01,02,03,04,07,08,09,10; WARM-01..03; SET-02,03,04,07
- Phase 4 (Periodization & Blocks): 10 — BLOCK-01..05, BLOCK-06a, BLOCK-07, BLOCK-08; PRES-05, PRES-06
- Phase 5 (Fatigue Model & Plateau Detection): 11 — VOL-01..07; PROG-06; SET-05, SET-06; BLOCK-06b
- Phase 6 (Progress Views, Export & Polish): 11 — PROG-01,02,03,04,05,07,08; EXP-01..04

---
*Requirements defined: 2026-05-10*
*Last updated: 2026-05-22 — BLOCK-06 split into BLOCK-06a (Phase 4) + BLOCK-06b (Phase 5) per checker blocker #5*
