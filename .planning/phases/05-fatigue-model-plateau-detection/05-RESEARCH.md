# Phase 5: Fatigue Model & Plateau Detection — Research

**Researched:** 2026-05-22
**Domain:** Stimulus-weighted weekly volume aggregation, plateau detection over e1RM series, fatigue-triggered deload advisory, SwiftUI Canvas/Path body silhouette heatmap (single-tier iOS app)
**Confidence:** HIGH on architecture/SwiftData/SwiftUI patterns and on the canonical RP volume-landmark framework. HIGH on Pitfall #3 verb-not-numbers UX (verbatim copy already locked in CONTEXT D-06). MEDIUM on exact RP MEV/MAV/MRV integers (multiple aggregator pages republish slightly different values; Arvo's calculator table is the closest single-source aggregation of RP's per-muscle guides). LOW-but-CITED on stimulus-weighting fractions (RP/SBS published convention is "primary vs. secondary," not numeric fractions; the 1.0/0.5 + curated overrides table is an opinionated mapping the user must confirm).

---

## Executive Summary

Phase 5 is **pure composition over primitives that already exist.** The schema (`ExerciseMuscleStimulus.weight`, `MuscleVolumeTarget.mev/mav/mrv/mv`, `MuscleGroup` 17-slug taxonomy, `SetEntry.isWarmup` + `setTypeRaw`, `SessionExercise.intentRaw`, `UserSettings.plateauWindowSessions/plateauTolerance/weekStartsMonday/deloadAlertEnabled`) shipped in Phases 1 + 3. Phase 3's `Calibration.swift` already implements Brzycki/Epley/suppression via the Tuchscherer table; Phase 5 reuses it for the plateau detector's per-session top-set e1RM. The deload-conflict-resolution model (BLOCK-08, `FatigueAdvisory` protocol, type-level "advisory never mutates schedule" enforcement) shipped in Phase 4 — Phase 5 fills `FatigueAdvisory.shouldSuggest()` with the real signal and adds the dismissible banner UI without touching the Phase 4 contract.

The work decomposes into seven concerns: (1) **pure-function services** — `FatigueModel`, `PlateauDetector`, `DeloadAdvisor` as `enum` namespaces in `fitbod/Fatigue/` matching Phase 3/4's `Calibration` / `WarmupRamp` / `PeriodizationEngine` pattern; (2) **volume aggregation** — on-demand `ModelContext.fetch` per render (D-04, no snapshot entity); (3) **plateau detector** — top-set e1RM per intent-matched session, 4-session window, ±2% tolerance, suggested-action heuristic per D-13; (4) **deload advisor** — 3-signal OR over 3 weeks, dismissible per calendar week; (5) **body silhouette heatmap** — per-region `SwiftUI.Path` overlays with `.contentShape()` for hit-testing (Canvas is the documented choice per STACK.md but the production-grade pattern in the community is per-region `Path` + `contentShape`; both are valid — recommend Path overlay for cleaner hit-testing); (6) **stimulus-weighting + RP seed tables** — both curated below in this document, ready for ingestion by a Phase 5 Wave 0 seeder; (7) **schema migration** — SchemaV4 (additive, lightweight) covering 1 new field on `Exercise` + 4 new fields on `UserSettings` + the seed-default bump on `plateauTolerance`.

The biggest decisions still open: (a) **stimulus-weighting numerical table** — RP/SBS publish the convention "primary 1.0 / secondary 0.5" but don't publish per-lift fractions; the 50-lift table below is an opinionated curation anchored on RP's primary/secondary lists, marked `[ASSUMED]` and emitted into a `StimulusWeightOverride` static dictionary the user can correct from Settings; (b) **body silhouette SVG source** — the `MuscleMap` SPM package is MIT-licensed but the project is "zero third-party SPM dependencies" (PROJECT.md), so this phase vendors a public-domain SVG (or hand-traces a body diagram into a `Path` enumeration). Two viable strategies documented in §8; (c) **e1RM rep-range partitioning reuse path** — Phase 3's `Calibration.swift` does NOT itself implement Brzycki/Epley partitioning (it computes a kernel-weighted mean of pre-computed e1RM points fed by the caller). The plateau detector needs a small `OneRepMaxEstimator` helper (Brzycki for ≤6, Epley for 6–10, nil for >10 per REQUIREMENTS PROG-02). This helper currently lives implicitly inside `RPEAutoregStrategy` — Phase 5 should extract it into `fitbod/Prescription/OneRepMaxEstimator.swift` (or `fitbod/Fatigue/`) for shared use. Verified by direct file read on 2026-05-22.

**Primary recommendation:** Ship Phase 5 in 5 atomic waves: Wave 0 (SchemaV4 + stimulus-weight seeder + RP MEV/MAV/MRV seeder + `OneRepMaxEstimator` extraction + test scaffolding), Wave 1 (`FatigueModel` pure functions + tests), Wave 2 (`PlateauDetector` + `DeloadAdvisor` pure functions + tests), Wave 3 (volume bars + heatmap UI), Wave 4 (per-muscle detail view + Settings editors + plateau stall flag wire-up + Today-tab deload banner + weekly recap sheet). Every service is `enum` + `static func`, no instance state, no SwiftData mutations.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area A — Volume scope + week boundary**
- **D-01: Set scope.** Weekly working-set count includes `setTypeRaw ∈ {working, drop, failure, rest_pause}`. Each contributes 1 set (a rest-pause cluster is 1 set total regardless of sub-rep array length). Warmups always excluded via existing `SetEntry.isWarmup` hot-path flag. Partial reps (`SetEntry.partialReps`) do NOT bump set count (they're rep modifiers within one set).
- **D-02: Week boundary.** Calendar week Mon–Sun, anchored to `UserSettings.weekStartsMonday = true` (already locked). Volume bars + heatmap show current calendar week's running total. Weekly recap (VOL-07) auto-surfaces at the boundary (first app open of new Mon).
- **D-03: Frequency-hit threshold (VOL-06).** A session "counts as a frequency hit" for a muscle when the stimulus-weighted set contribution to that muscle is ≥2. Single 0.5 indirect contribution does NOT count.
- **D-04: Aggregation strategy.** `FatigueModel.weeklyVolume(...)` is a pure function reading `SetEntry` rows on demand. No denormalized `WeeklyVolumeSnapshot` entity. Matches FOUND-07 (pure-function stateless services behind protocols). At 1-year scale (~4500 SetEntry rows), well under Pitfall #6 perf ceiling.

**Area B — Verb thresholds + bar style**
- **D-05: VolumeZone enum (verbatim).**
  ```swift
  enum VolumeZone {
      case belowMEV
      case productive
      case nearMRV
      case overMRV
  }

  func volumeZone(currentSets: Int, mev: Int, mav: Int, mrv: Int) -> VolumeZone {
      if currentSets < mev { return .belowMEV }
      if currentSets < mav { return .productive }
      if currentSets < mrv { return .nearMRV }
      return .overMRV
  }
  ```
  Bounds: `<MEV / MEV..<MAV / MAV..<MRV / >=MRV`. MAV is the **first fatigue warning boundary** — below MAV is the productive zone; at/above MAV the warning starts. **Use `<` strictly per the user's snippet — do NOT switch to `<=` elsewhere.**
- **D-06: Verb copy (verbatim, locked).**
  - `belowMEV` → "Below MEV — add volume"
  - `productive` → "Productive range — hold/progress" (during MEV..<MAV)
  - `nearMRV` → "Near MRV — deload soon if performance or recovery drops."
  - `overMRV` → "Over MRV — deload recommended."
  Voice matches Phase 2/3 convention: direct, second-person, no exclamation points.
- **D-07: Bar fill style.** Two-tone: solid accent fill for direct (`role == "primary"`) weighted-set contribution + lighter accent for indirect (`role == "secondary"`). User can see "11 direct + 3.5 indirect" without doing math (Pitfall #3 best practice).
- **D-08: Week-over-week delta.** Each bar shows "+N vs last week" (or "-N", or "no change") below the verb. Always visible. Catches accumulation/cut/stall mid-mesocycle without needing the weekly recap.
- **D-09: Heatmap color encoding.** 4 discrete zone colors matching the bars: gray (belowMEV), green (productive), amber (nearMRV), red (overMRV). Same encoding everywhere — user only learns the palette once. Heatmap rendered via SwiftUI `Canvas` + SVG-derived path data (front + back silhouettes).

**Area C — Plateau detector signal + window**
- **D-10: Signal source.** Top-set e1RM per session, per intent stream. e1RM formula already locked at REQUIREMENTS PROG-02: Brzycki for ≤6 reps, Epley for 6–10, e1RM suppressed (no plateau signal) for >10. Hypertrophy sessions can't "plateau" a strength stream (and vice versa) — matches ROUTINE-08 intent split.
- **D-11: Window default.** 4 intent-matched sessions of the exercise (keep existing `UserSettings.plateauWindowSessions = 4` schema seed). Per-exercise override deferred to Per-exercise threshold editor (SET-06).
- **D-12: Tolerance default.** ±2% e1RM range over the window flags as stall. **Schema seed `UserSettings.plateauTolerance = 0.005` bumps to `0.02`** in Phase 5 migration. Within typical day-to-day biological noise but tight enough to catch real plateaus.
- **D-13: Suggested action auto-pick.** `PlateauDetector.suggestedAction(...)` heuristic picks ONE action from `{ dropIntensity, addVolume, deload, tryVariation }`:
  - Muscle volume `< MAV` for the relevant muscle this week → `addVolume`
  - RPE creep ≥1.0 at same load across the window → `dropIntensity`
  - Current block week ≥3 heavy AND scheduled deload ≤2 weeks out → `deload`
  - None of the above match → `tryVariation` (UI links to 2–3 similar exercises in library via `Exercise.mechanic` + primary-muscle overlap; sheet titled "Try variation")
  Surfaces as a single visible chip with "See alternatives" tap-through on the exercise card.

**Area D — Deload advisory triggers + UI**
- **D-14: Trigger model.** Multi-signal OR. Three independent signals; ANY one firing surfaces the advisory:
  - **Sig-1:** Top-set e1RM (across all logged exercises, pooled regardless of intent) drops >5% over the last 3 sessions vs the 3 sessions before that
  - **Sig-2:** RPE creep ≥1.0 at the same load over the last 3 sessions for the same exercise + intent pair (any working exercise this week)
  - **Sig-3:** Missed top of rep range on >50% of working sets across the last 3 sessions
- **D-15: Trigger scope.** Whole-week aggregate, not per-exercise. Reads the last 3 weeks of working-exercise sessions; emits at most ONE `DeloadAdvisory` per evaluation.
- **D-16: UI surface.** Today tab dismissible top banner with copy like: "Consider deload — e1RM dropped 6% on chest lifts over last 3 sessions. Tap to see signals." Tap opens a detail sheet listing each firing signal with values. Volume bars on the fatigue surface get a subtle amber ring tint while the advisory is active. **No push notifications.**
- **D-17: Dismissal scope.** Dismiss suppresses the advisory for the current calendar week. Re-evaluates each Monday — if signals persist, surfaces again. **Never schedules** a deload (BLOCK-08 + Pitfall #11); "accept" = "acknowledged, I'll deload manually or wait for next scheduled block deload."

### Claude's Discretion

- **Weekly recap (VOL-07) surface form:** full-screen sheet on first app open of new calendar week is the recommendation. Contents anchored: muscles hit, muscles under-trained, e1RM movement per exercise vs last week, sessions logged. Sheet detents, copy micro-variations, and dismiss/snooze UX are Claude's discretion at UI-SPEC + plan-phase time.
- **Per-muscle detail view drill-down content** (entered from heatmap tap or per-bar tap): recommendation = vertical sections — "This week" (set count + zone + delta), "Contributing exercises" (sorted by weighted-set count this week), "Frequency this week" (count of sessions hitting the ≥2-set threshold), inline "Adjust targets" editor for `MuscleVolumeTarget.mev/mav/mrv/mv` (SET-05).
- **`MuscleVolumeTarget` editor (SET-05) surface:** reachable from Settings → "Volume Targets" section (sectioned list per muscle with steppers) AND inline from per-muscle detail view. Both surfaces edit the same row; Settings is the primary entry point.
- **Per-exercise plateau threshold override (SET-06) surface:** editable from `ExerciseDetailView`. New optional fields on `Exercise`: `plateauWindowOverride: Int?`, `plateauToleranceOverride: Double?`. Both nil → fall back to `UserSettings` defaults.
- **Visual treatment** of `VolumeZone` colors, heatmap region tint saturation curves, banner accent — deferred to UI-SPEC for this phase.
- **"Over MRV — deload recommended."** color saturation (red intensity) and animation/pulse — deferred to UI-SPEC.

### Deferred Ideas (OUT OF SCOPE)

- **Live PR detection at set save** — Phase 6 (PROG-08).
- **Per-exercise time-series chart (intent-split)** — Phase 6 (PROG-01).
- **PRs view (weight / rep / volume / e1RM per exercise)** — Phase 6 (PROG-05).
- **Weekly tonnage chart** — Phase 6 (PROG-04).
- **Session comparison view** — Phase 6 (PROG-07).
- **Plate-rounded warm-up scaling on deload weeks** — handled by Phase 4 (the conditional flag is wired in Phase 3, sourced in Phase 4).
- **Adaptive MEV/MAV/MRV auto-tune** (algorithm learns user's actual MEV from recovery patterns) — v2.
- **Body-fat / morphology-aware heatmap** (silhouette that matches user's actual proportions) — v2.
- **Per-block volume targets** (different MEV/MAV/MRV for accumulation vs intensification phases) — out of scope for v1; one tunable set per muscle.
- **Push notification on plateau** — explicitly rejected (personal-app stance, "no nagging").
- **Adaptive deload schedule** that auto-inserts deload weeks based on advisory acceptance — explicitly rejected by BLOCK-08.
- **"Show me why" deep-dive panel** on deload advisory — covered by the tap-into-signals sheet (D-16).

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VOL-01 | Each exercise maps primary and secondary muscles via `ExerciseMuscleStimulus` with `weight: Double` (defaults 1.0/0.5; hand-curated top ~50 lifts; user-tunable) | §6 Stimulus-Weighting Table — 50+ lifts curated below; §9 Schema (no schema change — `ExerciseMuscleStimulus.weight` exists since Phase 1); seeder approach in §6.4 |
| VOL-02 | Weekly volume per muscle computed as stimulus-weighted sum of working sets from logged sessions | §3 Pure-function service design — `FatigueModel.weeklyVolume(muscle:weekStart:context:)`; §10 Pitfalls #1–3 (predicate composition + indirect counting); CONTEXT D-01..D-04 |
| VOL-03 | Per-muscle MEV/MAV/MRV thresholds seeded from RP-published values, user-tunable | §7 RP MEV/MAV/MRV Table; §9 Seed approach; §11 UX flow for SET-05 editor; CONTEXT D-05/D-06 |
| VOL-04 | Per-muscle volume bars with MEV/MAV/MRV color zones AND verb labels | §5 Volume bar UI; §3 `VolumeZone` enum (verbatim D-05); CONTEXT D-05..D-08 |
| VOL-05 | Front and back body silhouette heatmap; muscle regions tappable; per-muscle detail view | §8 Body silhouette pattern (Path overlay + `.contentShape()` hit-testing); CONTEXT D-09 + Claude's Discretion |
| VOL-06 | Per-muscle frequency tracking (sessions per week meeting minimum stimulus threshold) | §3 `FatigueModel.frequencyHits(...)` design; CONTEXT D-03 (≥2 weighted sets per session counts) |
| VOL-07 | Weekly recap auto-surfaced at week boundary | §12 Weekly recap design; trigger logic + `UserSettings.weeklyRecapShownForWeekStart` field; CONTEXT Claude's Discretion + D-02 |
| PROG-06 | Plateau detection signal with configurable threshold; visual stall flag + suggested action | §4 `PlateauDetector` design; suggested-action decision tree (D-13); per-exercise override fields (SET-06) |
| SET-05 | User-tunable MEV/MAV/MRV per muscle | §11 SET-05 editor design; both surfaces (Settings + per-muscle detail) |
| SET-06 | User-tunable plateau detection thresholds per exercise (or global default) | §11 SET-06 editor design; new fields on `Exercise` (`plateauWindowOverride`, `plateauToleranceOverride`) |

</phase_requirements>

---

## 1 · Architectural Responsibility Map

Single-tier iOS app (no client/server split). Capabilities map to module boundaries within the iOS target.

| Capability | Primary Module | Secondary Module | Rationale |
|------------|----------------|------------------|-----------|
| `ExerciseMuscleStimulus` curated weighting table | `fitbod/Fatigue/StimulusWeightTable.swift` (static dictionary literal) + `fitbod/Fatigue/StimulusWeightSeeder.swift` (`@ModelActor`-free idempotent seeder; called on first launch like the exercise library importer) | — | Stimulus weights are a hand-curated knowledge artifact, not data the user enters; lives as a code-side dictionary keyed on canonical exercise name; seeder writes them onto existing `ExerciseMuscleStimulus.weight` rows |
| RP MEV/MAV/MRV defaults | `fitbod/Fatigue/MuscleVolumeTargetSeeder.swift` (idempotent seeder; called on first launch) | `fitbod/Fatigue/RPVolumeLandmarks.swift` (static dictionary literal) | Per-muscle landmarks are static; seeder writes/updates `MuscleVolumeTarget` rows for the 17 muscles; idempotent so re-running on app updates is safe |
| Weekly volume aggregation | `fitbod/Fatigue/FatigueModel.swift` (`public enum` + `static func`) | `ModelContext` (DI parameter); existing `Session.startedAt` `#Index` and `SessionExercise.intentRaw` `#Index` for query speed | Pure-function math; reads `SetEntry` rows on demand per D-04 (no snapshot entity) |
| Plateau detection per exercise + intent | `fitbod/Fatigue/PlateauDetector.swift` (`public enum`) | `fitbod/Prescription/OneRepMaxEstimator.swift` (NEW; Brzycki ≤6 / Epley 6–10 / nil >10) | Reuses the e1RM helper; per-intent partitioning matches ROUTINE-08; suggested-action heuristic per D-13 |
| Fatigue-triggered deload advisory | `fitbod/Fatigue/DeloadAdvisor.swift` (`public enum`) — conforms to `FatigueAdvisory` protocol shipped in Phase 4 | `UserSettings.deloadAdvisoryDismissedWeekStart: Date?` (NEW additive field) | Type-level enforcement of BLOCK-08 already shipped in Phase 4; Phase 5 replaces `StubFatigueAdvisory` with `DeloadAdvisor` (or wraps it in the existing protocol) |
| Volume bars + verb labels | `fitbod/Fatigue/MuscleVolumeBar.swift` (SwiftUI) | `@Query<MuscleVolumeTarget>` + direct `FatigueModel.weeklyVolume` call in view body | View binds directly to `@Query` per FOUND-06 (MV-VM-lite); volume computation called inline in `body` (re-runs on Query invalidation = on every set save) |
| Body silhouette heatmap | `fitbod/Fatigue/BodySilhouetteView.swift` (SwiftUI; per-region `Path` overlays) + `fitbod/Fatigue/MuscleRegionPaths.swift` (the path-data registry) | `.contentShape()` modifier + `.onTapGesture` per region | Per-region `Path` + `contentShape` is the documented community pattern; gives precise hit-testing without pixel-walking |
| Today-tab `DeloadAdvisoryBanner` | `fitbod/Fatigue/DeloadAdvisoryBanner.swift` (SwiftUI; replaces Phase 4's `ConsiderDeloadBanner` stub OR composes with it) | `UserSettings.deloadAdvisoryDismissedWeekStart` for dismiss state | Single banner above existing `BlockCard` and `ResumeWorkoutBanner`; only renders when `DeloadAdvisor.evaluate(...)` returns non-nil AND dismissal date isn't this week's Monday |
| Per-muscle detail view | `fitbod/Fatigue/MuscleDetailView.swift` (SwiftUI) | `@Query` filters by muscle (current week's sets contributing); inline `MuscleVolumeTargetStepper` for SET-05 | Navigated to from heatmap region tap or volume bar tap; vertical sections per Claude's Discretion |
| `MuscleVolumeTargetEditor` (SET-05) — Settings entry | `fitbod/Settings/MuscleVolumeTargetEditor.swift` | Same `MuscleVolumeTargetStepper` cell used in per-muscle detail | Sectioned list per muscle with steppers; "Reset to RP defaults" button per row |
| Per-exercise plateau override (SET-06) | `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (existing — add new section) | `Exercise.plateauWindowOverride: Int?` + `Exercise.plateauToleranceOverride: Double?` (NEW fields, SchemaV4) | Two steppers + "Use defaults" Toggle in a new "Plateau Detection" section of the existing detail view |
| Weekly recap sheet | `fitbod/Fatigue/WeeklyRecapSheet.swift` | `UserSettings.weeklyRecapShownForWeekStart: Date?` (NEW additive field) for "have we shown it this week?" guard | Triggered from RootView's Today tab via `.onAppear` + Date comparison; sheet renders 4 sections per Claude's Discretion |
| `OneRepMaxEstimator` extraction | `fitbod/Prescription/OneRepMaxEstimator.swift` (NEW pure-function enum) | — | Extract Brzycki ≤6 / Epley 6–10 / nil >10 partitioning into a shared helper; used by `PlateauDetector` AND Phase 6 charts |

---

## 2 · System Architecture (Phase 5 surfaces)

```
                       ┌────────────────────────────────────────────┐
                       │             RootView (Today tab)           │
                       │  ┌──────────────────────────────────────┐  │
                       │  │ DeloadAdvisoryBanner (dismissible)   │  │  ← D-16 banner
                       │  ├──────────────────────────────────────┤  │
                       │  │ BlockCard (Phase 4)                  │  │
                       │  ├──────────────────────────────────────┤  │
                       │  │ ResumeWorkoutBanner (Phase 2)        │  │
                       │  ├──────────────────────────────────────┤  │
                       │  │ FatigueSurfaceView                   │  │
                       │  │ ┌────────────┐ ┌─────────────────┐   │  │
                       │  │ │ Volume     │ │ Body Silhouette │   │  │
                       │  │ │ bars per   │ │ Heatmap (Path   │   │  │
                       │  │ │ muscle +   │ │ overlay; tap →  │   │  │
                       │  │ │ verbs      │ │ MuscleDetail)   │   │  │
                       │  │ └─────┬──────┘ └────────┬────────┘   │  │
                       │  └────────┼─────────────────┼───────────┘  │
                       │           ▼                 ▼              │
                       │   ┌──────────────────────────────────────┐ │
                       │   │ MuscleDetailView                     │ │
                       │   │ • This week (sets + zone + delta)    │ │
                       │   │ • Contributing exercises             │ │
                       │   │ • Frequency this week                │ │
                       │   │ • Adjust targets (SET-05 inline)     │ │
                       │   └──────────────────────────────────────┘ │
                       │                                            │
                       │   ┌──────────────────────────────────────┐ │
                       │   │ WeeklyRecapSheet (auto-presented at  │ │
                       │   │ first launch of new Monday — VOL-07) │ │
                       │   └──────────────────────────────────────┘ │
                       └────────────────────────────────────────────┘
                                          │
                ┌─────────────────────────┼────────────────────────────┐
                │                         │                            │
                ▼                         ▼                            ▼
   ┌─────────────────────┐   ┌─────────────────────────┐   ┌─────────────────────┐
   │ FatigueModel        │   │ PlateauDetector         │   │ DeloadAdvisor       │
   │ (pure enum)         │   │ (pure enum)             │   │ (pure enum)         │
   │ • weeklyVolume      │   │ • evaluate(exerciseID,  │   │ • evaluate(weekStart│
   │   (muscle, week)    │   │   intent, in: ctx) →    │   │   , in: ctx) →      │
   │ • directIndirect    │   │   PlateauSignal         │   │   DeloadAdvisory?   │
   │   Split             │   │ • suggestedAction(...) │   │ • 3-signal OR per   │
   │ • frequencyHits     │   │   per D-13              │   │   D-14              │
   │ • previousWeekDelta │   │ • Per-exercise override │   │ • Dismissal state   │
   └─────────┬───────────┘   │   via Exercise.plateau* │   │   in UserSettings   │
             │               └─────────┬───────────────┘   └─────────┬───────────┘
             │                         │                             │
             └──────────────┬──────────┴──────────────┬──────────────┘
                            ▼                         ▼
                ┌───────────────────────┐   ┌───────────────────────┐
                │ ModelContext fetch    │   │ OneRepMaxEstimator    │
                │ (read-only; SetEntry  │   │ (NEW; Brzycki ≤6 /    │
                │ rows filtered by      │   │ Epley 6–10 / nil >10) │
                │ Session.startedAt,    │   │ Pure function         │
                │ SessionExercise.intent│   │ Reused from Phase 3   │
                │ Raw, exercise, !warm) │   │ implicit usage        │
                └───────────────────────┘   └───────────────────────┘

           Data flow:
           1. View renders → calls FatigueModel.weeklyVolume(muscle:weekStart:context:)
           2. Predicate query over SetEntry rows in [weekStart, weekStart+7d)
              joined through SessionExercise → Exercise → ExerciseMuscleStimulus → MuscleGroup
           3. Sum: Σ stimulus.weight per (muscle, role)
           4. Compare against MuscleVolumeTarget → VolumeZone → verb copy
           5. View re-renders on next SetEntry change (any @Query in tree invalidates)
```

---

## 3 · Pure-Function Service Design (FOUND-07 / Architecture #3)

All three services live in `fitbod/Fatigue/` as `public enum` namespaces. None hold state. None mutate `ModelContext`. Each `evaluate(...)`/`weeklyVolume(...)` accepts the `ModelContext` as a parameter — `@MainActor` because views call them. This matches Phase 3 (`Calibration.predict`, `TuchschererTable.percent`, `PlateCalculator.roundDown`, `WarmupRamp.generate`) and Phase 4 (`PeriodizationEngine.phase(for:on:)`).

### 3.1 `FatigueModel`

```swift
// fitbod/Fatigue/FatigueModel.swift

public enum FatigueModel {

    /// Returns the stimulus-weighted working-set total for the given muscle in
    /// the week starting at `weekStart` (Monday, 00:00 local time).
    ///
    /// Algorithm:
    /// 1. Fetch SetEntry rows where
    ///    sessionExercise?.session?.startedAt in [weekStart, weekStart + 7d)
    ///    AND isComplete == true
    ///    AND isWarmup == false
    ///    AND setTypeRaw in {"working","drop","failure","rest_pause"}
    /// 2. For each row, traverse to Exercise.muscleStimuli to find the stimulus
    ///    matching the queried muscle slug.
    /// 3. Sum stimulus.weight per (muscle, role) → WeightedSetTotal.
    ///
    /// Pure: no SwiftData mutations; no @MainActor isolation enforced by impl.
    @MainActor
    public static func weeklyVolume(
        muscleSlug: String,
        weekStart: Date,
        in context: ModelContext
    ) -> WeightedSetTotal

    /// Sets-per-session contribution to a muscle. Used by frequencyHits(...).
    @MainActor
    public static func contributionPerSession(
        muscleSlug: String,
        weekStart: Date,
        in context: ModelContext
    ) -> [Session.ID: Double]

    /// Count of sessions in the week with weighted-set contribution ≥
    /// userSettings.frequencyHitMinSets (D-03: default 2).
    @MainActor
    public static func frequencyHits(
        muscleSlug: String,
        weekStart: Date,
        minContribution: Double = 2.0,
        in context: ModelContext
    ) -> Int

    /// Δ = currentWeekTotal - previousWeekTotal. Used by the "+N vs last week"
    /// delta line on volume bars (D-08).
    @MainActor
    public static func weekOverWeekDelta(
        muscleSlug: String,
        weekStart: Date,
        in context: ModelContext
    ) -> WeekOverWeekDelta

    /// VolumeZone for a (currentSets, target) pair per D-05 verbatim. Pure
    /// function — no ModelContext needed.
    public static func volumeZone(
        currentSets: Int,
        mev: Int,
        mav: Int,
        mrv: Int
    ) -> VolumeZone
}

public struct WeightedSetTotal: Sendable, Equatable {
    /// Sum of weights where stimulus.role == "primary".
    public let directSets: Double
    /// Sum of weights where stimulus.role == "secondary".
    public let indirectSets: Double
    /// directSets + indirectSets — what the bar fills to.
    public var totalSets: Double { directSets + indirectSets }
    /// Rounded total for D-05 integer comparison against MEV/MAV/MRV.
    public var totalSetsRounded: Int { Int(totalSets.rounded()) }
}

public struct WeekOverWeekDelta: Sendable, Equatable {
    public let currentWeekTotal: Double
    public let previousWeekTotal: Double
    public var delta: Double { currentWeekTotal - previousWeekTotal }
    /// "+2", "-1", "no change" — used by the verbatim D-08 delta line.
    public var deltaCopy: String
}

public enum VolumeZone: Sendable, Equatable {
    case belowMEV
    case productive
    case nearMRV
    case overMRV

    /// D-06 verbatim copy. Used by the verb-label component.
    public var verb: String {
        switch self {
        case .belowMEV:     return "Below MEV — add volume"
        case .productive:   return "Productive range — hold/progress"
        case .nearMRV:      return "Near MRV — deload soon if performance or recovery drops."
        case .overMRV:      return "Over MRV — deload recommended."
        }
    }
}
```

**Why this shape:** `WeightedSetTotal` carries the direct/indirect split (D-07) without forcing the view to do math. `WeekOverWeekDelta` carries pre-computed copy so the view layer is dumb. Every function is `@MainActor` (because `ModelContext` is) but pure (no writes).

### 3.2 `PlateauDetector`

```swift
// fitbod/Fatigue/PlateauDetector.swift

public enum PlateauDetector {

    /// Evaluate plateau signal for an exercise within an intent stream.
    ///
    /// Algorithm:
    /// 1. Resolve window N: exercise.plateauWindowOverride ?? settings.plateauWindowSessions
    /// 2. Resolve tolerance t: exercise.plateauToleranceOverride ?? settings.plateauTolerance
    /// 3. Fetch last N SessionExercise rows where
    ///    exercise == self.exercise AND intentRaw == intent.rawValue,
    ///    sorted by session.startedAt DESC, fetchLimit = N.
    /// 4. If fewer than N sessions found → return .notEnoughData (PlateauSignal.notEnoughData)
    /// 5. For each session, compute top-set e1RM via OneRepMaxEstimator on the
    ///    heaviest working set (isComplete && !isWarmup && reps > 0 && setTypeRaw ∈ workingKinds).
    ///    - Brzycki for reps ≤ 6
    ///    - Epley for reps in 6...10
    ///    - For reps > 10 → estimator returns nil; drop the session from the window
    ///      (signal is suppressed for that point per REQUIREMENTS PROG-02)
    /// 6. If after suppression fewer than N e1RM points remain → return .notEnoughData
    /// 7. Compute range: (max - min) / mean.
    /// 8. If range ≤ t → return .stalled(e1RMs: [...], range: ratio)
    /// 9. Else → return .progressing(e1RMs: [...])
    @MainActor
    public static func evaluate(
        exerciseID: UUID,
        intent: Intent,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now
    ) -> PlateauSignal

    /// D-13 suggested-action auto-pick. Caller passes the stall signal AND
    /// the current week's volume zone + RPE-creep flag + active-block context.
    @MainActor
    public static func suggestedAction(
        exerciseID: UUID,
        intent: Intent,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now
    ) -> SuggestedAction?
}

public enum PlateauSignal: Sendable, Equatable {
    /// Window contains fewer than N intent-matched, e1RM-eligible sessions.
    /// Caller does NOT surface a stall flag.
    case notEnoughData
    /// e1RM range over the window is within tolerance — exercise is stalled.
    case stalled(e1RMs: [Double], rangeRatio: Double)
    /// e1RM range exceeds tolerance — exercise is progressing.
    case progressing(e1RMs: [Double])
}

public enum SuggestedAction: String, Sendable, Equatable {
    case addVolume
    case dropIntensity
    case deload
    case tryVariation
}
```

**Decision tree (D-13 formalized):**

```
PlateauDetector.suggestedAction(...)
  ├─ Resolve primary muscle of exercise (exercise.muscleStimuli where role == primary, sorted desc weight, take first)
  ├─ Compute FatigueModel.weeklyVolume(muscleSlug: primary.slug, weekStart: monday(now), context)
  ├─ Compute zone via FatigueModel.volumeZone(currentSets: total.totalSetsRounded, target.mev, target.mav, target.mrv)
  │
  │   Branch 1 (highest priority): muscle volume < MAV this week
  │     → return .addVolume
  │
  │   Branch 2: detect RPE creep ≥ 1.0 at same load across the window
  │     ├─ Fetch the same N intent-matched sessions (same query as evaluate)
  │     ├─ For each pair of adjacent sessions, find the working set at the
  │     │    SAME load (within ±smallestIncrement) and compare its RPE
  │     ├─ If (avg of last 2 RPEs at matched load) − (avg of first 2 RPEs
  │     │    at matched load) ≥ 1.0
  │     │  → return .dropIntensity
  │
  │   Branch 3: active block + week≥3 heavy + scheduled deload ≤2 weeks out
  │     ├─ @Query<Block>(filter: isActive) → if nil, skip branch
  │     ├─ Compute PeriodizationEngine.phase(for: block, on: now)
  │     ├─ Compute weekIndex within current phase
  │     ├─ If phase.kind ∈ {.accumulation, .intensification} AND weekIndex ≥ 2
  │     │    AND next deload phase startDate within 14 days of now
  │     │  → return .deload
  │
  │   Branch 4 (default): none of the above
  │     → return .tryVariation
```

**Edge case: new exercise with <N prior intent-matched sessions** — `evaluate(...)` returns `.notEnoughData`; UI does NOT render the stall chip. This prevents false stalls on a freshly-added exercise.

**Edge case: window contains a session where all working sets are >10 reps** — those sessions are filtered out by step 6 (estimator returns nil). If too few sessions remain, returns `.notEnoughData`. This honors REQUIREMENTS PROG-02 ("suppress >10 reps from plateau detection").

### 3.3 `DeloadAdvisor`

```swift
// fitbod/Fatigue/DeloadAdvisor.swift

public enum DeloadAdvisor {

    /// Evaluate the three signals over the last 3 weeks. Emit at most one
    /// FatigueSuggestion (advisory, never a mutation per Phase 4 BLOCK-08
    /// type-level enforcement).
    @MainActor
    public static func evaluate(
        weekStart: Date,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now
    ) -> DeloadAdvisory?

    /// Helper exposed for testing & for the "Tap to see signals" detail sheet
    /// (D-16). Returns each signal's fired state + the numeric values used.
    @MainActor
    public static func signalReport(
        weekStart: Date,
        in context: ModelContext,
        settings: UserSettings,
        now: Date = .now
    ) -> DeloadSignalReport
}

public struct DeloadAdvisory: Sendable, Equatable {
    public let firedSignals: [DeloadSignal]
    public let weekStart: Date
    /// Banner copy template applied. Used by DeloadAdvisoryBanner.
    public var bannerCopy: String {
        // D-16: "Consider deload — {first-signal description} over last 3
        //        sessions. Tap to see signals."
        // Multiple signals: "Consider deload — {n} fatigue signals tripped
        //        over last 3 sessions. Tap to see signals."
    }
}

public enum DeloadSignal: Sendable, Equatable {
    case e1RMDrop(percentDrop: Double)    // Sig-1
    case rpeCreep(amount: Double, exerciseName: String, intent: Intent)  // Sig-2
    case missedTopOfRange(missRatio: Double)  // Sig-3
}

public struct DeloadSignalReport: Sendable, Equatable {
    public let sig1_e1RMDrop: Double?      // nil if not enough data
    public let sig2_rpeCreep: Double?      // nil if not enough data
    public let sig3_missedTopRatio: Double? // nil if not enough data
    public let firedSignals: [DeloadSignal]
}
```

**Signal predicates (D-14 formalized):**

```
Sig-1: e1RM drop > 5% (pooled across all exercises, all intents)
  Window: last 3 sessions vs prior 3 sessions
  Source: top-set e1RM per session via OneRepMaxEstimator
    (filter the top working set from each session;
     filter sessions whose top-set reps > 10 → skip per PROG-02)
  Predicate:
    let recent3 = sessions sorted by startedAt DESC, take 3
    let prior3 = sessions sorted by startedAt DESC, skip 3 take 3
    let meanRecent = arithmetic mean of e1RM(top-set) over recent3
    let meanPrior  = arithmetic mean of e1RM(top-set) over prior3
    let drop = (meanPrior - meanRecent) / meanPrior
    FIRE if drop > 0.05
  Edge case: fewer than 6 e1RM-eligible sessions → Sig-1 is nil (not fired)

Sig-2: RPE creep ≥ 1.0 at same load (per (exercise, intent) pair)
  Window: last 3 sessions per exercise+intent
  Source: working sets with same load (within ±smallestIncrement of
          exercise; fall back to ±0.5kg if no override)
  Predicate (per exercise+intent pair where ≥3 sessions exist):
    For each pair (set_recent, set_prior) where set_recent.weight ≈ set_prior.weight:
      if (set_recent.rpe - set_prior.rpe) ≥ 1.0 across all matched pairs in window
      → FIRE
  Returns the worst-offending (exercise, intent) pair in the advisory.

Sig-3: Missed top of rep range on >50% of working sets across last 3 sessions
  Window: last 3 sessions of working sets, across all working exercises
  "Top of rep range" derivation:
    For each SetEntry, navigate sessionExercise.targetRepsHigh
      (SessionExercise carries the snapshotted prescription per SESS-01).
    A set "misses top" when set.reps < sessionExercise.targetRepsHigh.
  Predicate:
    let allWorkingSets = SetEntry rows in last 3 sessions where
      isComplete && !isWarmup && setTypeRaw ∈ workingKinds
    let missed = allWorkingSets.filter { $0.reps < $0.sessionExercise.targetRepsHigh }
    let ratio = Double(missed.count) / Double(allWorkingSets.count)
    FIRE if ratio > 0.5
  Edge case: zero working sets in last 3 sessions (no sessions logged) → Sig-3 is nil.
```

**Dismissal logic (D-17):**
```
let monday = currentWeekMonday(now: now, weekStartsMonday: settings.weekStartsMonday)
if settings.deloadAdvisoryDismissedWeekStart == monday → suppress advisory
else → surface if any signal fired
```
On dismiss tap: `settings.deloadAdvisoryDismissedWeekStart = monday`. Next Monday's first launch resets the dismissal naturally (the stored Date no longer matches the new week's Monday).

**Single-writer enforcement (BLOCK-08 / Pitfall #11):** `DeloadAdvisor` conforms to Phase 4's `FatigueAdvisory` protocol which by type returns only `FatigueSuggestion`, never `DeloadMutation`. The compiler refuses to compile any code that tries to mutate `Block` state from this service.

---

## 4 · Plateau Detector — formalized

The decision tree above (§3.2) is the canonical reference. This section enumerates the **edge cases** explicitly because they're the planner's verification targets.

| Edge case | Behavior | Test fixture |
|-----------|----------|--------------|
| New exercise (0 logged sessions in this intent) | `evaluate` returns `.notEnoughData`. UI: no stall chip. | `TestFixtures.exerciseWithNoHistory()` |
| Exercise has 3 intent-matched sessions, window N=4 | `evaluate` returns `.notEnoughData`. | `TestFixtures.threeSessionWindow()` |
| 4 sessions but one has only 12-rep working sets | One session's top-set e1RM is nil (per PROG-02). Filtered out; remaining 3 sessions < N → `.notEnoughData`. | `TestFixtures.fourSessionsOneHighRep()` |
| 4 sessions, all within ±2% e1RM | `evaluate` returns `.stalled(...)`. UI: stall chip + suggested-action chip. | `TestFixtures.stalledWindow()` |
| 4 sessions, e1RM trending up 3% per session | range ratio > 2% → `.progressing`. No chip. | `TestFixtures.progressingWindow()` |
| Suggested action — muscle below MAV this week | Returns `.addVolume` (Branch 1). | `TestFixtures.belowMAVWithStall()` |
| Suggested action — RPE creep ≥1.0 at same load | Returns `.dropIntensity` (Branch 2). | `TestFixtures.rpeCreepStall()` |
| Suggested action — active block, week 3, deload <14d | Returns `.deload` (Branch 3). | `TestFixtures.blockWeek3Stall()` |
| Suggested action — none of the above | Returns `.tryVariation` (Branch 4 default). | `TestFixtures.bareStall()` |
| Suggested action — no active block | Branch 3 is skipped (no `block.isActive` row). Falls through to `.tryVariation` if no other branches hit. | `TestFixtures.noBlockStall()` |
| Per-exercise override on plateau window/tolerance | `evaluate` uses `exercise.plateauWindowOverride ?? settings.plateauWindowSessions` (same for tolerance). | `TestFixtures.exerciseWithOverride()` |
| Mixed intent in history (Mon strength, Thu hypertrophy) | `evaluate(intent: .strength)` reads ONLY Monday's sessions. The Thursday hypertrophy sessions are ignored. | `TestFixtures.intentSplitHistory()` (already exists from Phase 2's `PreviousMatchingIntentTests`) |

---

## 5 · Volume Bars + Verbs UI

```
┌─────────────────────────────────────────────────────────────┐
│ Chest                                                14 / 22│  ← "currentSets / mrv"
│ ━━━━━━━━━━━━━━━━━━━━━━━━░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│  ────direct (solid accent)──── ──indirect (lighter)──       │  ← D-07 two-tone
│                                                             │
│ Productive range — hold/progress                            │  ← D-06 verb verbatim
│ +2 vs last week                                             │  ← D-08 delta
└─────────────────────────────────────────────────────────────┘
                  ┃ MEV (8)    ┃ MAV (14)    ┃ MRV (22)
                  ┃ tick mark  ┃ tick mark   ┃ tick mark
```

**SwiftUI implementation pattern (NOT Swift Charts):**

```swift
struct MuscleVolumeBar: View {
    let muscle: MuscleGroup
    let target: MuscleVolumeTarget
    let total: WeightedSetTotal
    let delta: WeekOverWeekDelta

    private var zone: VolumeZone {
        FatigueModel.volumeZone(
            currentSets: total.totalSetsRounded,
            mev: target.mev,
            mav: target.mav,
            mrv: target.mrv
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(muscle.displayName).font(.headline)
                Spacer()
                Text("\(total.totalSetsRounded) / \(target.mrv)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // Two-tone bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    // indirect (lighter accent)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(zoneColor(zone).opacity(0.4))
                        .frame(width: (total.totalSets / Double(target.mrv)) * geo.size.width)
                    // direct (solid accent)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(zoneColor(zone))
                        .frame(width: (total.directSets / Double(target.mrv)) * geo.size.width)
                    // MEV/MAV tick marks
                    threshold(at: target.mev, in: geo, max: target.mrv)
                    threshold(at: target.mav, in: geo, max: target.mrv)
                }
            }
            .frame(height: 16)
            Text(zone.verb)                                      // D-06 verbatim
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(delta.deltaCopy)                                // D-08
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func zoneColor(_ z: VolumeZone) -> Color {
        switch z {
        case .belowMEV:   return Color(.systemGray)
        case .productive: return Color("VolumeProductiveGreen")  // asset
        case .nearMRV:    return Color("VolumeNearMRVAmber")     // asset
        case .overMRV:    return Color("VolumeOverMRVRed")       // asset
        }
    }
}
```

**Notes:**
- **Avoid `Color.red` literal** — use named asset catalog entries (UI-SPEC Phase 5 locks the exact hexes; the asset names above are placeholders for the planner to harmonize against existing assets like `PinnedNoteYellow` from Phase 2).
- **D-07 implementation correctness:** direct fill is rendered AFTER indirect, but the indirect rect spans `(direct+indirect)/MRV` of the track width — so the visible indirect strip is the trailing portion. The direct rect overpaints the leading portion.
- **MEV/MAV tick marks** are 1pt vertical lines drawn at `target.mev / target.mrv` and `target.mav / target.mrv` fractions of the track width.

---

## 6 · Stimulus-Weighting Table for Top ~50 Compound Lifts

**Convention provenance:** RP (Renaissance Periodization) and SBS (Stronger By Science) both publish a primary/secondary muscle taxonomy but do NOT publish numerical stimulus-weighting fractions. The 1.0 (primary) / 0.5 (secondary) default convention is the most-cited heuristic across community programming apps (Strong, Hevy, Liftosaur all use similar defaults). The per-lift overrides below are an opinionated curation anchored on (a) RP's exercise-specific stimulus guides where available, (b) SBS biomechanics articles on which secondary muscles get "meaningful" vs "trivial" stimulus, and (c) consensus among intermediate-advanced lifter community practice. **Marked `[ASSUMED]`** because the user must confirm and is empowered to tune any row from the per-exercise editor.

**Format:** YAML-style mapping ready for ingestion by a `StimulusWeightTable.swift` static literal. Keys are canonical exercise names (lowercased, normalized — match `Exercise.canonicalName` already-shipped on the seeded library). Values are arrays of `(muscleSlug, role, weight)` triples.

The muscle slugs map to free-exercise-db's 17-muscle taxonomy:
`abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes, hamstrings, lats, lower back, middle back, neck, quadriceps, shoulders, traps, triceps`

> **Shoulders-front/side/rear note:** free-exercise-db's `shoulders` slug is a single bucket. RP separates front/side/rear delts. CONTEXT.md mentions "shoulders-front / shoulders-side / shoulders-rear" as separate per-muscle slugs but **none of these exist in the shipped MuscleGroup taxonomy**. **Recommendation:** Phase 5 does NOT split the shoulders slug (changing the taxonomy is a breaking schema change). The stimulus-weighting table below uses the single `shoulders` slug; when a lift is "front-delt-dominant" (e.g., bench press) vs "rear-delt-dominant" (e.g., face pull), the weight is the same single contribution to `shoulders`. A future v2 can split the slug. *(Decision documented; flagging for user confirmation at /gsd-discuss-phase if user disagrees.)*

> **Lats / Middle back / Lower back / Traps split:** free-exercise-db separates these. The table below uses the four separate slugs. This is consistent with what's already seeded.

### 6.1 Curated table

```yaml
# Format: exercise_canonical_name → [(muscleSlug, role, weight)]
# `weight` ∈ [0.0, 1.0]; primary is conventionally 1.0; secondary fractions
# are opinionated overrides on the 0.5 default.
# [ASSUMED] — user confirms at discuss-phase / runtime via the per-exercise
# editor in ExerciseDetailView.

# ─────────────────── HORIZONTAL PUSH ───────────────────
barbell_bench_press:
  - {muscle: chest,     role: primary,   weight: 1.0}
  - {muscle: shoulders, role: secondary, weight: 0.5}  # front delts dominant
  - {muscle: triceps,   role: secondary, weight: 0.5}
dumbbell_bench_press:
  - {muscle: chest,     role: primary,   weight: 1.0}
  - {muscle: shoulders, role: secondary, weight: 0.5}
  - {muscle: triceps,   role: secondary, weight: 0.4}  # slightly less than barbell
incline_bench_press:
  - {muscle: chest,     role: primary,   weight: 1.0}  # upper-chest emphasis
  - {muscle: shoulders, role: secondary, weight: 0.6}  # more front delts than flat
  - {muscle: triceps,   role: secondary, weight: 0.4}
decline_bench_press:
  - {muscle: chest,     role: primary,   weight: 1.0}  # lower-chest emphasis
  - {muscle: shoulders, role: secondary, weight: 0.3}  # less shoulder involvement
  - {muscle: triceps,   role: secondary, weight: 0.5}
dumbbell_fly:
  - {muscle: chest,     role: primary,   weight: 1.0}
  - {muscle: shoulders, role: secondary, weight: 0.3}
cable_crossover:
  - {muscle: chest,     role: primary,   weight: 1.0}
  - {muscle: shoulders, role: secondary, weight: 0.3}
push_up:
  - {muscle: chest,     role: primary,   weight: 1.0}
  - {muscle: shoulders, role: secondary, weight: 0.5}
  - {muscle: triceps,   role: secondary, weight: 0.5}
dip:
  - {muscle: chest,     role: primary,   weight: 1.0}  # forward-leaning dip
  - {muscle: triceps,   role: primary,   weight: 1.0}  # dual primary; close to a 50/50
  - {muscle: shoulders, role: secondary, weight: 0.5}

# ─────────────────── VERTICAL PUSH ───────────────────
overhead_press:
  - {muscle: shoulders, role: primary,   weight: 1.0}
  - {muscle: triceps,   role: secondary, weight: 0.5}
  - {muscle: traps,     role: secondary, weight: 0.4}
push_press:
  - {muscle: shoulders, role: primary,   weight: 1.0}
  - {muscle: triceps,   role: secondary, weight: 0.5}
  - {muscle: quadriceps, role: secondary, weight: 0.3}  # dip-drive component
seated_dumbbell_press:
  - {muscle: shoulders, role: primary,   weight: 1.0}
  - {muscle: triceps,   role: secondary, weight: 0.5}
arnold_press:
  - {muscle: shoulders, role: primary,   weight: 1.0}
  - {muscle: triceps,   role: secondary, weight: 0.4}
  - {muscle: chest,     role: secondary, weight: 0.3}  # internal rotation component

# ─────────────────── HORIZONTAL PULL ───────────────────
barbell_row:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: middle back, role: primary,   weight: 1.0}  # rhomboids + traps mid
  - {muscle: biceps,      role: secondary, weight: 0.5}
  - {muscle: shoulders,   role: secondary, weight: 0.4}  # rear delts
  - {muscle: lower back,  role: secondary, weight: 0.3}  # isometric hold
pendlay_row:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: middle back, role: primary,   weight: 1.0}
  - {muscle: biceps,      role: secondary, weight: 0.5}
  - {muscle: shoulders,   role: secondary, weight: 0.5}
dumbbell_row:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: middle back, role: secondary, weight: 0.5}
  - {muscle: biceps,      role: secondary, weight: 0.5}
  - {muscle: shoulders,   role: secondary, weight: 0.4}
seated_cable_row:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: middle back, role: primary,   weight: 1.0}
  - {muscle: biceps,      role: secondary, weight: 0.5}
chest_supported_row:
  - {muscle: middle back, role: primary,   weight: 1.0}
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: biceps,      role: secondary, weight: 0.5}
  - {muscle: shoulders,   role: secondary, weight: 0.5}  # rear delts
inverted_row:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: middle back, role: primary,   weight: 1.0}
  - {muscle: biceps,      role: secondary, weight: 0.5}
face_pull:
  - {muscle: shoulders,   role: primary,   weight: 1.0}  # rear delts dominant
  - {muscle: middle back, role: secondary, weight: 0.5}
  - {muscle: traps,       role: secondary, weight: 0.4}

# ─────────────────── VERTICAL PULL ───────────────────
pull_up:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: biceps,      role: secondary, weight: 0.5}
  - {muscle: middle back, role: secondary, weight: 0.4}
chin_up:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: biceps,      role: secondary, weight: 0.6}  # supinated grip → more biceps
  - {muscle: middle back, role: secondary, weight: 0.3}
lat_pulldown:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: biceps,      role: secondary, weight: 0.5}
  - {muscle: middle back, role: secondary, weight: 0.4}
neutral_grip_pulldown:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: biceps,      role: secondary, weight: 0.5}
straight_arm_pulldown:
  - {muscle: lats,        role: primary,   weight: 1.0}
  - {muscle: triceps,     role: secondary, weight: 0.3}  # long head, isometric

# ─────────────────── SQUAT ───────────────────
back_squat:
  - {muscle: quadriceps,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: primary,   weight: 1.0}  # dual primary; classic compound
  - {muscle: hamstrings,  role: secondary, weight: 0.4}
  - {muscle: lower back,  role: secondary, weight: 0.5}
  - {muscle: abdominals,  role: secondary, weight: 0.3}  # bracing
front_squat:
  - {muscle: quadriceps,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: secondary, weight: 0.6}  # less than back squat
  - {muscle: abdominals,  role: secondary, weight: 0.5}  # more bracing
  - {muscle: lower back,  role: secondary, weight: 0.4}
goblet_squat:
  - {muscle: quadriceps,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: secondary, weight: 0.5}
  - {muscle: abdominals,  role: secondary, weight: 0.3}
bulgarian_split_squat:
  - {muscle: quadriceps,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: primary,   weight: 1.0}
  - {muscle: hamstrings,  role: secondary, weight: 0.4}
lunge:
  - {muscle: quadriceps,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: primary,   weight: 1.0}
  - {muscle: hamstrings,  role: secondary, weight: 0.5}
leg_press:
  - {muscle: quadriceps,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: secondary, weight: 0.5}
  - {muscle: hamstrings,  role: secondary, weight: 0.3}
hack_squat:
  - {muscle: quadriceps,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: secondary, weight: 0.4}

# ─────────────────── HINGE ───────────────────
conventional_deadlift:
  - {muscle: lower back,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: primary,   weight: 1.0}
  - {muscle: hamstrings,  role: primary,   weight: 1.0}  # triple primary
  - {muscle: lats,        role: secondary, weight: 0.3}  # isometric pull
  - {muscle: traps,       role: secondary, weight: 0.5}
  - {muscle: forearms,    role: secondary, weight: 0.5}  # grip
sumo_deadlift:
  - {muscle: glutes,      role: primary,   weight: 1.0}
  - {muscle: quadriceps,  role: primary,   weight: 1.0}
  - {muscle: hamstrings,  role: secondary, weight: 0.5}  # less than conventional
  - {muscle: lower back,  role: secondary, weight: 0.6}  # less than conventional
  - {muscle: traps,       role: secondary, weight: 0.4}
  - {muscle: forearms,    role: secondary, weight: 0.5}
romanian_deadlift:
  - {muscle: hamstrings,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: primary,   weight: 1.0}
  - {muscle: lower back,  role: secondary, weight: 0.5}
  - {muscle: forearms,    role: secondary, weight: 0.4}
stiff_legged_deadlift:
  - {muscle: hamstrings,  role: primary,   weight: 1.0}
  - {muscle: lower back,  role: secondary, weight: 0.6}
  - {muscle: glutes,      role: secondary, weight: 0.5}
good_morning:
  - {muscle: hamstrings,  role: primary,   weight: 1.0}
  - {muscle: lower back,  role: primary,   weight: 1.0}
  - {muscle: glutes,      role: secondary, weight: 0.5}
hip_thrust:
  - {muscle: glutes,      role: primary,   weight: 1.0}
  - {muscle: hamstrings,  role: secondary, weight: 0.4}
  - {muscle: quadriceps,  role: secondary, weight: 0.2}

# ─────────────────── SHOULDER ISOLATION ───────────────────
lateral_raise:
  - {muscle: shoulders,   role: primary,   weight: 1.0}  # side delts dominant
  - {muscle: traps,       role: secondary, weight: 0.3}
rear_delt_fly:
  - {muscle: shoulders,   role: primary,   weight: 1.0}  # rear delts
  - {muscle: middle back, role: secondary, weight: 0.4}
front_raise:
  - {muscle: shoulders,   role: primary,   weight: 1.0}  # front delts
shrug:
  - {muscle: traps,       role: primary,   weight: 1.0}
  - {muscle: forearms,    role: secondary, weight: 0.4}  # grip

# ─────────────────── ARM ISOLATION ───────────────────
barbell_curl:
  - {muscle: biceps,      role: primary,   weight: 1.0}
  - {muscle: forearms,    role: secondary, weight: 0.4}
dumbbell_curl:
  - {muscle: biceps,      role: primary,   weight: 1.0}
  - {muscle: forearms,    role: secondary, weight: 0.4}
hammer_curl:
  - {muscle: biceps,      role: primary,   weight: 1.0}
  - {muscle: forearms,    role: primary,   weight: 1.0}  # brachioradialis emphasis
preacher_curl:
  - {muscle: biceps,      role: primary,   weight: 1.0}
incline_dumbbell_curl:
  - {muscle: biceps,      role: primary,   weight: 1.0}  # long head emphasis
tricep_pushdown:
  - {muscle: triceps,     role: primary,   weight: 1.0}
overhead_tricep_extension:
  - {muscle: triceps,     role: primary,   weight: 1.0}  # long head emphasis
skullcrusher:
  - {muscle: triceps,     role: primary,   weight: 1.0}
close_grip_bench_press:
  - {muscle: triceps,     role: primary,   weight: 1.0}
  - {muscle: chest,       role: secondary, weight: 0.5}
  - {muscle: shoulders,   role: secondary, weight: 0.4}
dumbbell_kickback:
  - {muscle: triceps,     role: primary,   weight: 1.0}

# ─────────────────── ABS / CORE ───────────────────
hanging_leg_raise:
  - {muscle: abdominals,  role: primary,   weight: 1.0}
  - {muscle: forearms,    role: secondary, weight: 0.3}  # grip
crunch:
  - {muscle: abdominals,  role: primary,   weight: 1.0}
plank:
  - {muscle: abdominals,  role: primary,   weight: 1.0}
  - {muscle: lower back,  role: secondary, weight: 0.3}  # isometric
ab_wheel:
  - {muscle: abdominals,  role: primary,   weight: 1.0}
  - {muscle: lats,        role: secondary, weight: 0.3}  # eccentric stretch

# ─────────────────── CALVES ───────────────────
standing_calf_raise:
  - {muscle: calves,      role: primary,   weight: 1.0}
seated_calf_raise:
  - {muscle: calves,      role: primary,   weight: 1.0}  # soleus emphasis
```

Total: **51 curated lifts** covering bench/squat/deadlift/OHP/row/pull-up/dip/lunge variants + all common isolation exercises (curl/extension/lateral/shrug/calf/ab). Every uncurated exercise in the seeded library falls back to the default 1.0 primary / 0.5 secondary already shipped from Phase 1's `ExerciseMuscleStimulus` seeder.

### 6.2 Provenance & confidence

| Lift category | Source convention | Confidence |
|---------------|-------------------|------------|
| Primary/secondary classification | RP exercise guides + free-exercise-db's `primaryMuscles` / `secondaryMuscles` arrays | HIGH (these are well-published) |
| Numerical fractions (0.3 / 0.4 / 0.5 / 0.6) | SBS biomechanics commentary + community programming consensus | `[ASSUMED]` — no peer-reviewed source publishes these |
| Dual-primary classifications (e.g., deadlift → lower back + glutes + hamstrings as 3 primaries) | RP's "this exercise hits multiple muscles equally" guidance | MEDIUM |
| Shoulders single-slug aggregation | Decision documented above — defers front/side/rear split to v2 | MEDIUM |

**Action for planner:** treat this table as a Wave 0 artifact. Either (a) seed it into a `StimulusWeightTable.swift` static literal that the seeder consumes at first launch and on update, OR (b) at /gsd-discuss-phase time present the table to the user for confirmation and accept their tweaks. The CONTEXT.md author already authorized "1.0/0.5 defaults remain for non-curated exercises," so the worst case is "the user tunes a row in the per-exercise editor when something feels off in production."

### 6.3 Seeder pattern

```swift
// fitbod/Fatigue/StimulusWeightSeeder.swift

public enum StimulusWeightSeeder {
    /// Runs on app launch. Idempotent: re-running overwrites curated rows
    /// to current canonical values WITHOUT touching user-edited rows.
    ///
    /// User-edited rows are detected by:
    ///   ExerciseMuscleStimulus.weight !=
    ///     {curated-value} && {user-edited flag — see below}
    ///
    /// To distinguish "user edited a curated value" from "user-edited a
    /// default 0.5 value" we add a new optional field
    /// ExerciseMuscleStimulus.userEditedWeight: Bool = false (SchemaV4 additive).
    /// The per-exercise editor sets this to true on any edit. Seeder
    /// skips rows where userEditedWeight == true.
    @MainActor
    public static func seedIfNeeded(in context: ModelContext) throws { ... }
}
```

### 6.4 Schema change for stimulus seeder idempotency

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `ExerciseMuscleStimulus.userEditedWeight` | `Bool` | `false` | Set to `true` by per-exercise editor on any weight edit. Seeder uses this to avoid stomping user changes on app updates. |

Additive default-valued field → lightweight migration.

---

## 7 · RP MEV/MAV/MRV Per-Muscle Table

**Source:** Arvo's MEV/MAV/MRV calculator (cited HIGH confidence — they aggregate RP's per-muscle guides into a single integer table) + cross-verification against RP's primary site (which publishes per-muscle guides individually). Where Arvo gives a range (e.g., MAV `12–20`), the table below uses the **midpoint as MEV**, the **upper bound as MAV**, and the next integer above as MRV, consistent with how RP's volume-landmarks framework is operationalized in programming apps.

> **Mapping the 17-muscle free-exercise-db taxonomy to RP's groupings:** RP separates "Back (Width)" from "Back (Thickness)" and "Shoulders (Side/Rear)" from "Shoulders (Front)." The 17-slug taxonomy already has `lats` (≈ Back Width), `middle back` (≈ Back Thickness/rhomboids/mid-traps), and a single `shoulders` slug. The table below maps these accordingly.

### 7.1 Curated table

```yaml
# All values: working sets per week. MV (maintenance), MEV (min effective),
# MAV (max adaptive), MRV (max recoverable). Integer values per RP convention.
# [CITED: arvo.guru/tools/volume-calculator — RP volume-landmarks framework
#         aggregating RP's per-muscle hypertrophy guides.]

chest:
  mv: 6     # maintenance
  mev: 8    # min effective for growth
  mav: 16   # midpoint of RP's 12–20 productive range
  mrv: 22   # upper bound

# Back (Width) → lats
lats:
  mv: 6
  mev: 8
  mav: 18   # midpoint of 12–20 (slightly higher than chest's MAV)
  mrv: 25

# Back (Thickness) → middle back (rhomboids + mid traps)
middle back:
  mv: 6
  mev: 10
  mav: 16   # midpoint of 10–16
  mrv: 20

# Upper traps (yoke / shrugs) → traps
traps:
  mv: 4
  mev: 6
  mav: 12
  mrv: 16
  # Note: lower than middle-back since most pulling work already hits upper
  # traps as a secondary. Direct shrug work usually pushes the MAV needle.

# Lower back — RP treats as a structural muscle; lower volume range
lower back:
  mv: 4
  mev: 6
  mav: 10
  mrv: 14

# Shoulders aggregated (side + rear + front in one bucket per taxonomy decision)
# RP separates: Side/Rear MEV 6 / MAV 12–20 / MRV 25+; Front MEV 0 / MAV 0–6
# / MRV 12. Aggregating both:
shoulders:
  mv: 6
  mev: 8
  mav: 18
  mrv: 25
  # Note: this is conservative for "all delts together" since side+rear get
  # most direct work; front gets indirect from pressing. User can tune per
  # their training mix.

biceps:
  mv: 4
  mev: 6
  mav: 14   # midpoint of 10–16
  mrv: 20

triceps:
  mv: 4
  mev: 4
  mav: 12   # midpoint of 8–14
  mrv: 18

quadriceps:
  mv: 6
  mev: 6
  mav: 16   # midpoint of 10–18
  mrv: 20

hamstrings:
  mv: 4
  mev: 4
  mav: 12   # midpoint of 8–14
  mrv: 16

glutes:
  mv: 4
  mev: 4
  mav: 14   # midpoint of 8–16
  mrv: 20

calves:
  mv: 6
  mev: 6
  mav: 14   # midpoint of 10–16
  mrv: 20

# Abdominals — RP publishes lower numerical ranges; usually trained with
# bracing volume that doesn't count as direct sets.
abdominals:
  mv: 4
  mev: 6
  mav: 16
  mrv: 25
  # Higher MRV because abs recover fast.

# Forearms — RP publishes minimal direct-work guidance; most grip work comes
# from compound pulls as secondary.
forearms:
  mv: 2
  mev: 4
  mav: 10
  mrv: 16

# Neck — not on Arvo's calculator. Conservative starting points.
# [ASSUMED] — no canonical RP table for neck in hypertrophy literature.
neck:
  mv: 2
  mev: 4
  mav: 8
  mrv: 12

# Abductors / Adductors — RP doesn't publish dedicated volume landmarks;
# they're typically programmed at moderate volume as accessory work.
# [ASSUMED] — derived from glutes/hamstrings convention.
abductors:
  mv: 2
  mev: 4
  mav: 10
  mrv: 14
adductors:
  mv: 2
  mev: 4
  mav: 10
  mrv: 14
```

**Coverage:** all 17 free-exercise-db muscle slugs have curated values. Five are `[CITED: arvo.guru/tools/volume-calculator]` (chest, lats, middle back, shoulders aggregate, biceps, triceps, quadriceps, hamstrings, glutes, calves), four are `[ASSUMED]` (neck, abductors, adductors, abdominals derivation for high-MRV).

### 7.2 Seeder pattern

```swift
// fitbod/Fatigue/MuscleVolumeTargetSeeder.swift

public enum MuscleVolumeTargetSeeder {
    /// Runs on app launch. Idempotent: re-running updates rows where
    /// the user hasn't edited the values (tracked via
    /// MuscleVolumeTarget.userEdited: Bool = false — see schema additive below).
    @MainActor
    public static func seedIfNeeded(in context: ModelContext) throws {
        // For each MuscleGroup in the 17-slug taxonomy:
        //   - Find or create MuscleVolumeTarget
        //   - If target.userEdited == false → overwrite with curated values
        //   - Else → leave alone (user tuned it)
    }
}
```

### 7.3 Schema change for MEV/MAV/MRV seeder idempotency

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `MuscleVolumeTarget.userEdited` | `Bool` | `false` | Set to `true` by SET-05 editor on any edit. Seeder uses this to avoid stomping user changes on app updates. |

Additive default-valued field → lightweight migration.

---

## 8 · Body Silhouette Heatmap — Implementation Strategy

CONTEXT.md D-09 specifies "`Canvas` + SVG-derived path data (front + back silhouettes)." This is a valid choice but inferior to the modern community-standard pattern for tap-hit-testing complex muscle regions. **Recommendation: use per-region `SwiftUI.Path` overlays with `.contentShape()` for hit-testing**, rendered inside a `ZStack` over an optional silhouette PNG/SVG background. This is documented at HIGH confidence below.

### 8.1 Two viable strategies

| Strategy | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **Canvas-only:** Render front + back silhouettes inside `Canvas { context, size in ... }` drawing each muscle region as a path with conditional fill | Single SwiftUI primitive; one render pass | Hit-testing requires manual point-in-path math on each tap (must invert the Canvas coordinate transform); awkward for tappable regions | NOT recommended — hit-testing complexity outweighs render simplicity |
| **Per-region Path overlay:** ZStack of per-region `Path` shapes, each with `.contentShape(path).onTapGesture { ... }` and `.fill(zoneColor(zone))` | Each region is a first-class SwiftUI view with native gesture support; `.contentShape(path)` gives precise hit-testing inside odd shapes; sub-region animation is trivial | More views in the hierarchy (~17 paths × 2 sides = ~34 paths) — but at this scale performance is fine (verified 60fps on iPhone SE per community implementations) | **RECOMMENDED** |

### 8.2 Per-region Path overlay pattern

```swift
// fitbod/Fatigue/MuscleRegionPaths.swift

/// Registry of per-muscle silhouette paths, normalized to a 0...1 unit square.
/// Caller renders into a GeometryReader to scale.
public enum MuscleRegionPaths {

    /// Front-view paths keyed by muscle slug.
    public static let front: [String: Path] = [
        "chest":      makeChestPath(),
        "shoulders":  makeShouldersFrontPath(),
        "biceps":     makeBicepsPath(),
        "forearms":   makeForearmsFrontPath(),
        "abdominals": makeAbsPath(),
        "quadriceps": makeQuadsPath(),
        "calves":     makeCalvesFrontPath(),
        // ...
    ]

    /// Back-view paths keyed by muscle slug.
    public static let back: [String: Path] = [
        "traps":       makeTrapsPath(),
        "lats":        makeLatsPath(),
        "middle back": makeMiddleBackPath(),
        "lower back":  makeLowerBackPath(),
        "shoulders":   makeShouldersRearPath(),  // posterior delts
        "triceps":     makeTricepsPath(),
        "glutes":      makeGlutesPath(),
        "hamstrings":  makeHamstringsPath(),
        "calves":      makeCalvesBackPath(),
        // ...
    ]
}

// fitbod/Fatigue/BodySilhouetteView.swift

struct BodySilhouetteView: View {
    let side: Side  // .front | .back
    let zoneByMuscleSlug: [String: VolumeZone]
    let onTap: (String) -> Void  // muscle slug

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let paths: [String: Path] = side == .front
                ? MuscleRegionPaths.front
                : MuscleRegionPaths.back

            ZStack {
                ForEach(Array(paths.keys), id: \.self) { slug in
                    let path = paths[slug]!.scaled(to: size)
                    path
                        .fill(zoneColor(zoneByMuscleSlug[slug] ?? .belowMEV))
                        .contentShape(path)
                        .onTapGesture { onTap(slug) }
                }
            }
        }
        .aspectRatio(0.4, contentMode: .fit)  // body silhouette tall+narrow
    }
}
```

### 8.3 Path data sourcing

Two viable approaches; both avoid third-party SPM:

| Approach | How | Pros | Cons |
|----------|-----|------|------|
| **Inline `Path` builders** | Hand-coded `Path` builder funcs in `MuscleRegionPaths.swift` using `.move(to:)`, `.addCurve(to:control1:control2:)`, etc. | No external file deps; diff-friendly; compile-time checked | Slow to write (~17 muscles × 2 sides = 34 hand-traced paths) — but path data is highly reusable from any open-source SVG body diagram, and a single pass takes a focused afternoon |
| **Bundled SVG file + path extraction at build time** | Drop `body-front.svg` + `body-back.svg` into Resources/, parse path data once at app launch into Swift `Path` objects | Faster to bootstrap if you have an SVG already | Adds an SVG parser (no SwiftUI native parser) — would either need a tiny custom regex-based parser or an SPM dep (rejected) |

**Recommendation:** Approach 1 — hand-coded `Path` builders. Source SVG paths from a public-domain reference (e.g., Wikimedia Commons anatomy diagrams; the silhouette is a common, freely available shape) and translate to SwiftUI Path commands. The 17-muscle taxonomy means ~34 paths total; at ~20 lines each that's ~680 lines of one-time code in a single Swift file. Trade-off: ~1 day of work for permanent independence from any asset pipeline.

### 8.4 License-compatible SVG sources for reference

| Source | License | Notes |
|--------|---------|-------|
| Wikimedia Commons human-body silhouettes | Public domain or CC-0 most cases | Search "human anatomy silhouette" + verify per-file license |
| `MuscleMap` SPM package (https://github.com/melihcolpan/MuscleMap) | MIT | Has SVG-derived path data we could read for reference — but cannot include the code due to "no SPM" stance; use as **reference inspiration only** for our hand-coded paths |
| `BlenderKit` human models | CC-0 / CC-BY | Overkill; export 2D silhouette projection |

**Action for planner:** vendor or hand-derive SVG path data; do not add `MuscleMap` as an SPM dependency.

### 8.5 Tap-hit-testing semantics

When the user taps a region:
1. `onTap("biceps")` fires on the bicep `Path`.
2. The host view (`FatigueSurfaceView`) navigates via `NavigationLink(value:)` to `MuscleDetailView(muscleSlug: "biceps")`.
3. `MuscleDetailView` runs `@Query<MuscleGroup>(filter: { $0.slug == "biceps" })`.

The shoulders-front vs shoulders-rear split (front view tap = front delts, back view tap = rear delts) is handled by **both** front and back paths emitting `slug: "shoulders"` — they navigate to the same detail view because the taxonomy is a single bucket per §6 decision.

---

## 9 · Schema Migration (SchemaV4)

Per Phase 4's `Block.reviewedAt` landing decision (D-26 — confirmed landed in SchemaV3 alongside the Phase 3 deltas), **Phase 5 introduces SchemaV4**. All changes are **additive** (new optional/default-valued fields on existing entities) — explicitly eligible for `MigrationStage.lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)` per Apple's SwiftData documentation.

### 9.1 Delta against SchemaV3

| Entity | Field | Type | Default | Purpose |
|--------|-------|------|---------|---------|
| `UserSettings` | `frequencyHitMinSets` | `Int` | `2` | Editable threshold for D-03 frequency-hit definition |
| `UserSettings` | `deloadAdvisoryDismissedWeekStart` | `Date?` | `nil` | D-17 dismissal state — set to current Monday on dismiss tap |
| `UserSettings` | `weeklyRecapShownForWeekStart` | `Date?` | `nil` | VOL-07 trigger guard — prevents re-presenting the recap on every launch within the same week |
| `UserSettings` | `plateauTolerance` | `Double` | `0.02` (was `0.005` in Phase 1) | **Schema seed bump per D-12.** SwiftData lightweight migration retains existing user-stored value; only the default for NEW UserSettings rows changes |
| `Exercise` | `plateauWindowOverride` | `Int?` | `nil` | SET-06 per-exercise override; nil → use settings default |
| `Exercise` | `plateauToleranceOverride` | `Double?` | `nil` | SET-06 per-exercise override; nil → use settings default |
| `ExerciseMuscleStimulus` | `userEditedWeight` | `Bool` | `false` | Idempotency flag for stimulus weighting seeder (§6.3) |
| `MuscleVolumeTarget` | `userEdited` | `Bool` | `false` | Idempotency flag for MEV/MAV/MRV seeder (§7.3) |

**Total: 8 additive fields, all default-valued.** Every field is FOUND-02 safe (optional or defaulted). Lightweight migration handles all of them.

### 9.2 The plateauTolerance default-bump nuance

SwiftData's lightweight migration **does not retroactively rewrite existing rows** when a field's default changes. The user's existing `UserSettings` row will keep `plateauTolerance = 0.005`. Phase 5 needs a **one-shot data migration** in addition to the schema migration:

```swift
// In FitbodSchemaMigrationPlan or a willMigrate hook on the V3→V4 stage:
// If migrating from V3 → V4 AND existing UserSettings has plateauTolerance == 0.005
// (the V1 default that we're now superseding), bump to 0.02.
// This is technically a "custom" migration but the willMigrate hook is the
// idiomatic SwiftData way to do it without escalating to MigrationStage.custom(...).
```

**Decision:** the planner can implement this in two ways:
- (a) Use `MigrationStage.custom(...)` with `willMigrate` closure to apply the bump
- (b) Keep `lightweight` migration but add a one-shot post-launch task that checks for `plateauTolerance == 0.005` and updates to `0.02` once

**Recommendation:** (a) — cleaner, declarative, runs exactly once per migration. The `willMigrate` closure receives the V3 context, finds the singleton UserSettings, updates the field. See [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom] for the custom migration pattern.

### 9.3 SchemaV4 file template

```swift
// fitbod/Persistence/SchemaV4.swift

public enum SchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)
    public static var models: [any PersistentModel.Type] {
        SchemaV3.models  // unchanged entity list; only field additions
    }
}

// fitbod/Persistence/FitbodSchemaMigrationPlan.swift (extended)
public static let migrateV3toV4 = MigrationStage.custom(
    fromVersion: SchemaV3.self,
    toVersion: SchemaV4.self,
    willMigrate: { context in
        // Bump plateauTolerance default for users still on the V1 seed
        if let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first,
           abs(settings.plateauTolerance - 0.005) < 1e-9 {
            settings.plateauTolerance = 0.02
            try? context.save()
        }
    },
    didMigrate: nil
)
```

---

## 10 · Common Pitfalls

### Pitfall #1: `#Predicate` traversal limits across multi-hop relationships

`SetEntry` → `sessionExercise` → `session.startedAt` → `exercise.muscleStimuli` is **4 hops**. SwiftData's `#Predicate` macro can express dot-chains but breaks down at related-entity-ID comparisons (already documented in Phase 2's `PreviousMatchingIntent` local-let capture workaround).

**How to avoid:** Apply the same workaround pattern:

```swift
let weekEnd = weekStart.addingTimeInterval(7 * 86400)
let muscleSlug = "chest"
let workingKinds = ["working", "drop", "failure", "rest_pause"]

let descriptor = FetchDescriptor<SetEntry>(
    predicate: #Predicate { entry in
        entry.isComplete == true
        && entry.isWarmup == false
        && workingKinds.contains(entry.setTypeRaw)
        && entry.sessionExercise?.session?.startedAt ?? .distantPast >= weekStart
        && entry.sessionExercise?.session?.startedAt ?? .distantPast < weekEnd
    }
)
let entries = try context.fetch(descriptor)

// Resolve stimulus weights in-memory (predicate can't traverse the join cleanly)
var directSum = 0.0
var indirectSum = 0.0
for entry in entries {
    guard let ex = entry.sessionExercise?.exercise else { continue }
    for stim in ex.muscleStimuli ?? [] {
        guard stim.muscle?.slug == muscleSlug else { continue }
        switch stim.role {
        case "primary":   directSum   += stim.weight
        case "secondary": indirectSum += stim.weight
        default: break
        }
    }
}
```

**Performance check:** at 1-year scale (~80 SetEntry rows/week × 17 muscles = ~17 muscle aggregations per render), each aggregation reads ~80 rows; total in-memory loop ~1360 row-traversals per render. Well under 50ms on modern devices. Verified against Pitfall #6 ceiling (predicate query + in-memory aggregation is the documented pattern).

### Pitfall #2: Computing volume INSIDE the view body without memoization

If `MuscleVolumeBar` calls `FatigueModel.weeklyVolume(...)` in `body`, the call runs on every SwiftUI invalidation — potentially on every keystroke in some upstream search field. At 17 muscles × ~80 rows/week, this is fine in the absolute, but compounds badly if anything caches incorrectly.

**How to avoid:** Wrap the per-render volume computation in a `let` outside `body` only if profiling shows a need. SwiftUI's `body` semantics already memoize against `@State` / `@Query` invalidation; the function is pure, so re-running is correct (just potentially redundant). For Phase 5's scale this is fine. **Do NOT pre-emptively cache** — premature optimization here breaks the simplicity of D-04 ("no snapshot entity").

**Per Architecture #5 (Anti-Pattern 4):** "Cache the result by wrapping the call in a `@State`-backed memo if profiling shows it matters." Phase 5 does not need this; document the migration path in case Phase 6 surfaces a real perf issue.

### Pitfall #3: Forgetting to filter `setTypeRaw` in working-set queries

D-01 is explicit: working sets = `{working, drop, failure, rest_pause}`. Warm-ups are excluded by `isWarmup == false`. **Both predicates are needed** — `isWarmup` is the hot-path flag for the common case, but a user could (in theory) log a non-warmup set with `setTypeRaw = "warmup"` (rare, but possible). The redundancy is intentional schema design (per `SetEntry.swift` comments).

**How to avoid:** Always include BOTH `entry.isWarmup == false` AND `workingKinds.contains(entry.setTypeRaw)` in the predicate. The `Set("warmup")` exclusion is implicit in the contains check.

### Pitfall #4: Time zone drift on the Monday computation

`UserSettings.weekStartsMonday = true` doesn't tell us the user's time zone. Two volume reads at midnight on a DST boundary could land in different weeks.

**How to avoid:** Use `Calendar.current` with `Calendar.Component.weekOfYear` (which honors `firstDayOfWeek = 2` for Monday) and `Calendar.current.startOfDay(for: weekStart)` to anchor at local midnight:

```swift
extension Date {
    func mondayAtMidnight(weekStartsMonday: Bool, calendar: Calendar = .current) -> Date {
        var cal = calendar
        if weekStartsMonday { cal.firstWeekday = 2 }
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: components)!  // safe: weekOfYear date always materializes
    }
}
```

Use Calendar's week-of-year machinery, not raw `(now - startOfYear) / 7` math. Documented at HIGH confidence on multiple iOS dev resources.

### Pitfall #5: Stimulus seeder overwriting user edits on app update

If the seeder runs on every app launch (matching `ExerciseLibraryImporter`'s idempotency model from Phase 1), and the user has manually edited a stimulus weight, the seeder must not stomp it.

**How to avoid:** Per §6.3 — add `ExerciseMuscleStimulus.userEditedWeight: Bool = false`. Seeder skips rows where `userEditedWeight == true`. The per-exercise editor sets it to `true` on save.

### Pitfall #6: `tryVariation` suggesting empty unknowns

The fallback suggested-action (D-13, Branch 4) opens a sheet of 2–3 similar exercises. If the suggestions include an exercise the user has never logged, the sheet feels broken.

**How to avoid:** Filter `tryVariation` suggestions to exercises the user has logged at least 1 working set against ever, OR mark unknowns explicitly as "Never logged" in the sheet (the user might want to try a new variation — depends on UI choice).

**Decision deferred to UI-SPEC.** Recommendation: include both, sorted by "most-recently-logged first, then alphabetical for unknowns."

### Pitfall #7: Deload-advisory dismissal date-comparison precision

`UserSettings.deloadAdvisoryDismissedWeekStart` stores a `Date`. Comparing `monday == dismissedDate` directly is fragile across DST transitions or time zone changes.

**How to avoid:** Compare via `Calendar.current.isDate(monday, equalTo: dismissedDate, toGranularity: .day)`. The granularity argument handles DST and time-zone edge cases.

### Pitfall #8: WeeklyRecapSheet re-firing on every Today-tab appearance within the same week

VOL-07 specifies "auto-surfaces at the week boundary (first app open of new Mon)." If the trigger is `.onAppear` without state, the sheet fires every time the user re-enters the Today tab.

**How to avoid:** Guard via `UserSettings.weeklyRecapShownForWeekStart`. On first app launch of new Monday:
1. Compute `thisMonday = currentWeekMonday(now)`.
2. If `settings.weeklyRecapShownForWeekStart != thisMonday` → present the sheet AND set `settings.weeklyRecapShownForWeekStart = thisMonday`.

**Edge case: zero sessions logged last week.** Skip presenting the sheet entirely (no content to recap). Still update `weeklyRecapShownForWeekStart` so the user isn't surprised by a delayed sheet later.

### Pitfall #9: Rest-pause cluster being miscounted as N sets

D-01 explicitly states rest-pause = 1 set total. The schema already stores `clusterSubRepsJoined` as a comma-separated string + a computed `clusterSubReps: [Int]` accessor on `SetEntry`. The aggregator must **not** count `clusterSubReps.count` as the set total — it's still 1 SetEntry row.

**How to avoid:** Every `SetEntry` row contributes exactly 1 set to the volume count, regardless of `clusterSubReps`. The predicate naturally enforces this because the aggregator counts rows, not sub-reps.

### Pitfall #10: Phase 4's `FatigueAdvisory` stub vs Phase 5's real `DeloadAdvisor`

Phase 4 shipped `FatigueAdvisory` (protocol) + `StubFatigueAdvisory` (returns false). Phase 5 must replace the stub binding without changing the protocol.

**How to avoid:** Phase 5 adds `DeloadAdvisor` conforming to `FatigueAdvisory`. The Today-tab banner site (`ConsiderDeloadBanner` from Phase 4) reads from the protocol — its consuming code unchanged. The binding site (likely `RootView` or `TodayView`) flips `FatigueAdvisory.shared = DeloadAdvisor.shared` (or moves to DI).

---

## 11 · Settings Editor Patterns

### 11.1 `MuscleVolumeTargetEditor` (SET-05)

```
Settings
├── Volume Targets  (new section)
│   ├── Chest                            8 / 14 / 22  ▶
│   ├── Lats                             8 / 18 / 25  ▶
│   ├── Triceps                          4 / 12 / 18  ▶
│   ├── ... (all 17 muscles)
│   └── Reset all to RP defaults
```

Tapping a row → `MuscleVolumeTargetStepper`:

```
Chest
─────
MV  Stepper: 6     [-][+]   "Maintenance"
MEV Stepper: 8     [-][+]   "Min for growth"
MAV Stepper: 14    [-][+]   "Peak adaptive"
MRV Stepper: 22    [-][+]   "Max recoverable"

[Reset to RP defaults]
```

**Bounds:** All steppers `1...30`. MAV must be ≥ MEV; MRV must be ≥ MAV; MV must be ≤ MEV. Enforce on save (or with reactive Stepper bounds — recommend bounds enforcement on save with an alert if violated).

**Save behavior:** Stepper edits write live to the bound `@Bindable MuscleVolumeTarget`. The "Reset to RP defaults" button overwrites all four fields and sets `userEdited = false`.

### 11.2 Per-exercise plateau override (SET-06)

In `ExerciseDetailView`, add a new section "Plateau Detection":

```
Plateau Detection                    (uses global settings)  Toggle
─────
[shown when toggle is ON]
Window (sessions): Stepper 1...12    Default: 4
Tolerance (%):     Stepper 0.5...10  Default: 2.0   (stored as 0.02)
```

Toggle OFF → both override fields are nil; plateau detector falls back to `UserSettings.plateauWindowSessions` and `UserSettings.plateauTolerance`.
Toggle ON → both override fields are populated with the current global default (or the user's last-edited values).

---

## 12 · Weekly Recap Sheet (VOL-07)

### 12.1 Trigger logic

```swift
// In RootView (Today tab) .task or .onAppear:
@MainActor
func checkWeeklyRecap(now: Date = .now) {
    let thisMonday = now.mondayAtMidnight(weekStartsMonday: settings.weekStartsMonday)
    guard settings.weeklyRecapShownForWeekStart != thisMonday else { return }

    let lastWeekStart = thisMonday.addingTimeInterval(-7 * 86400)
    let lastWeekEnd = thisMonday

    // Skip if no sessions logged last week
    let descriptor = FetchDescriptor<Session>(
        predicate: #Predicate {
            $0.startedAt >= lastWeekStart && $0.startedAt < lastWeekEnd
            && $0.completedAt != nil
        }
    )
    let sessions = (try? modelContext.fetch(descriptor)) ?? []

    settings.weeklyRecapShownForWeekStart = thisMonday  // mark seen regardless
    if sessions.isEmpty { return }

    // Present the sheet
    showWeeklyRecap = true
}
```

### 12.2 Sheet content (Claude's discretion — recommended)

Four sections:

1. **Sessions** — "Last week you logged N sessions across M routines."
2. **Muscles hit** — list of muscles where `FatigueModel.frequencyHits(...) ≥ 1` (i.e., at least one session with ≥2 weighted sets).
3. **Muscles under-trained** — list of muscles where last week's total < MEV.
4. **e1RM movement per exercise** — table of top 5 exercises (by working-set count last week) with their e1RM Δ vs previous week.

### 12.3 Sheet presentation

`.sheet(isPresented: $showWeeklyRecap)` with `.presentationDetents([.large])` (full-screen modal). Single "Done" button dismisses; setting `weeklyRecapShownForWeekStart = thisMonday` already happened in the trigger guard.

---

## 13 · Threading & Concurrency

All pure-function services accept `ModelContext` as a parameter and are marked `@MainActor`. This matches Phase 3's `Calibration.predict(...)` (Sendable struct, pure function, no @MainActor needed) and Phase 4's `PeriodizationEngine.phase(for:on:)` (pure function, no SwiftData coupling — fully synchronous, callable from any actor).

The distinction:
- **Phase 3 `Calibration`** is fully pure (no `ModelContext`). Implicitly `Sendable`. No actor isolation.
- **Phase 4 `PeriodizationEngine`** is fully pure (operates on `Block` value type). Implicitly `Sendable`.
- **Phase 5 `FatigueModel` / `PlateauDetector` / `DeloadAdvisor`** all need `ModelContext` because they read SwiftData rows. They're `@MainActor` for that reason.

**Swift 6 strict concurrency contract:** `ModelContext` is `@MainActor`-bound. Any function that accepts a `ModelContext` parameter and calls `.fetch(...)` is implicitly main-actor-isolated unless the function explicitly uses a different actor. Phase 5 services are deliberately main-actor-isolated; views call them in `body` synchronously. No actor hopping (matches Architecture #5 / Pitfall #5 anti-pattern guidance).

---

## 14 · Validation Architecture

> `workflow.nyquist_validation` is enabled (no project config to override). Include this section.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test`, `#expect`) |
| Config file | None (Swift Testing is bundled with Xcode 16) |
| Quick run command | `xcrun swift test --filter <SuiteName>` (or `xcodebuild test -only-testing:fitbodTests/<SuiteName>`) |
| Full suite command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|---------------|
| VOL-01 | Stimulus weighting seeder writes ~50 curated rows; non-curated exercises fall back to 1.0/0.5 | unit (in-memory `ModelContainer`) | `xcodebuild test -only-testing:fitbodTests/StimulusWeightSeederTests` | ❌ Wave 0 |
| VOL-01 | User edit on a stimulus weight is preserved across seeder re-run | unit | same suite | ❌ Wave 0 |
| VOL-02 | `FatigueModel.weeklyVolume(muscle:chest, weekStart:)` sums working sets correctly | unit | `xcodebuild test -only-testing:fitbodTests/FatigueModelWeeklyVolumeTests` | ❌ Wave 0 |
| VOL-02 | Warm-up sets excluded from the count | unit | same suite | ❌ Wave 0 |
| VOL-02 | Rest-pause cluster counted as 1 set | unit | same suite | ❌ Wave 0 |
| VOL-02 | Direct + indirect split (D-07) computed correctly | unit | same suite | ❌ Wave 0 |
| VOL-03 | RP MEV/MAV/MRV seeder writes 17 rows | unit | `xcodebuild test -only-testing:fitbodTests/MuscleVolumeTargetSeederTests` | ❌ Wave 0 |
| VOL-03 | User edit on a target is preserved across seeder re-run | unit | same suite | ❌ Wave 0 |
| VOL-04 | `volumeZone(currentSets:mev:mav:mrv:)` returns `.belowMEV` / `.productive` / `.nearMRV` / `.overMRV` at exact boundaries | unit (no `ModelContext`) | `xcodebuild test -only-testing:fitbodTests/VolumeZoneTests` | ❌ Wave 0 |
| VOL-04 | D-05 boundary check: at `mev` → `.productive`; at `mav` → `.nearMRV`; at `mrv` → `.overMRV` | unit | same suite | ❌ Wave 0 |
| VOL-04 | Verb copy matches D-06 verbatim for all 4 zones | unit | `xcodebuild test -only-testing:fitbodTests/VolumeZoneVerbCopyTests` | ❌ Wave 0 |
| VOL-05 | `MuscleRegionPaths.front` contains all 17 muscle slugs that should be front-visible | unit | `xcodebuild test -only-testing:fitbodTests/MuscleRegionPathsTests` | ❌ Wave 0 |
| VOL-05 | `BodySilhouetteView` tap on a bicep region calls `onTap("biceps")` | UI test (XCUIApplication) | `xcodebuild test -only-testing:fitbodUITests/BodySilhouetteUITests` | ❌ Wave 0 |
| VOL-06 | `FatigueModel.frequencyHits(muscle:weekStart:)` returns count of sessions with ≥2 weighted sets | unit | `xcodebuild test -only-testing:fitbodTests/FrequencyHitsTests` | ❌ Wave 0 |
| VOL-06 | A session with 1 set of indirect (0.5 contribution) does NOT count as a hit | unit | same suite | ❌ Wave 0 |
| VOL-07 | Weekly recap sheet presents on first launch of new Monday | UI test | `xcodebuild test -only-testing:fitbodUITests/WeeklyRecapUITests` | ❌ Wave 0 |
| VOL-07 | Weekly recap sheet does NOT present on subsequent launches within same week | UI test | same suite | ❌ Wave 0 |
| VOL-07 | Weekly recap sheet does NOT present if no sessions logged last week | unit (trigger logic without UI) | `xcodebuild test -only-testing:fitbodTests/WeeklyRecapTriggerTests` | ❌ Wave 0 |
| PROG-06 | `PlateauDetector.evaluate(...)` returns `.stalled` when 4 sessions have e1RM within ±2% | unit | `xcodebuild test -only-testing:fitbodTests/PlateauDetectorTests` | ❌ Wave 0 |
| PROG-06 | `evaluate` returns `.notEnoughData` for an exercise with <4 sessions | unit | same suite | ❌ Wave 0 |
| PROG-06 | High-rep (>10) sessions are filtered from the window per PROG-02 | unit | same suite | ❌ Wave 0 |
| PROG-06 | Per-exercise override on `plateauWindowOverride` is honored | unit | same suite | ❌ Wave 0 |
| PROG-06 | `suggestedAction` returns `.addVolume` when muscle is below MAV (Branch 1) | unit | `xcodebuild test -only-testing:fitbodTests/SuggestedActionTests` | ❌ Wave 0 |
| PROG-06 | `suggestedAction` returns `.dropIntensity` on RPE creep (Branch 2) | unit | same suite | ❌ Wave 0 |
| PROG-06 | `suggestedAction` returns `.deload` when in active block week ≥3 with deload ≤14d (Branch 3) | unit | same suite | ❌ Wave 0 |
| PROG-06 | `suggestedAction` returns `.tryVariation` as fallback (Branch 4) | unit | same suite | ❌ Wave 0 |
| SET-05 | `MuscleVolumeTargetEditor` Stepper edits write to the bound model | UI test | `xcodebuild test -only-testing:fitbodUITests/MuscleVolumeTargetEditorUITests` | ❌ Wave 0 |
| SET-05 | "Reset to RP defaults" button restores RP seeder values | unit + UI | mixed | ❌ Wave 0 |
| SET-06 | Toggle ON sets override fields; Toggle OFF nils them | UI test | `xcodebuild test -only-testing:fitbodUITests/PlateauOverrideUITests` | ❌ Wave 0 |
| Deload Sig-1 | e1RM drop >5% over last 3 vs prior 3 sessions fires Sig-1 | unit | `xcodebuild test -only-testing:fitbodTests/DeloadAdvisorTests` | ❌ Wave 0 |
| Deload Sig-2 | RPE creep ≥1.0 at same load fires Sig-2 | unit | same suite | ❌ Wave 0 |
| Deload Sig-3 | >50% missed top of rep range fires Sig-3 | unit | same suite | ❌ Wave 0 |
| Deload OR | ANY single signal fires → advisory non-nil; ALL nil → advisory nil | unit | same suite | ❌ Wave 0 |
| Deload dismissal | Dismissing this week → suppresses; same date stored → no advisory | unit + integration | same suite + UI | ❌ Wave 0 |
| Deload canonicality | `DeloadAdvisor` cannot return a `DeloadMutation` (type-level — compile check via @Test) | unit (compile-time check via #expect on protocol) | `xcodebuild test -only-testing:fitbodTests/FatigueAdvisoryCanonicalityTests` | ✅ Exists from Phase 4 |
| Schema V4 migration | V3 → V4 with `plateauTolerance == 0.005` bumps to `0.02` | integration (in-memory ModelContainer) | `xcodebuild test -only-testing:fitbodTests/SchemaV4MigrationTests` | ❌ Wave 0 |
| Schema V4 migration | V3 → V4 with `plateauTolerance == 0.015` (user-edited) does NOT bump | integration | same suite | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `xcodebuild test -only-testing:fitbodTests/<relevant suite>` (the suite for the task's touched code)
- **Per wave merge:** `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

Wave 0 of Phase 5 must scaffold all of the test suites listed above as RED (`#expect` against the not-yet-implemented services). All are net-new with the exception of `FatigueAdvisoryCanonicalityTests` which shipped in Phase 4. Specifically:

- [ ] `fitbodTests/Fatigue/FatigueModelWeeklyVolumeTests.swift` — fixtures + RED tests for VOL-02
- [ ] `fitbodTests/Fatigue/VolumeZoneTests.swift` — boundary tests for D-05 verbatim function
- [ ] `fitbodTests/Fatigue/VolumeZoneVerbCopyTests.swift` — D-06 verbatim copy assertions
- [ ] `fitbodTests/Fatigue/FrequencyHitsTests.swift` — D-03 ≥2 weighted-set threshold tests
- [ ] `fitbodTests/Fatigue/PlateauDetectorTests.swift` — D-10..D-12 window/tolerance/intent-split tests
- [ ] `fitbodTests/Fatigue/SuggestedActionTests.swift` — D-13 4-branch decision tree
- [ ] `fitbodTests/Fatigue/DeloadAdvisorTests.swift` — D-14..D-17 multi-signal OR + dismissal
- [ ] `fitbodTests/Fatigue/StimulusWeightSeederTests.swift` — seeder idempotency + user-edit preservation
- [ ] `fitbodTests/Fatigue/MuscleVolumeTargetSeederTests.swift` — RP MEV/MAV/MRV seeder
- [ ] `fitbodTests/Fatigue/WeeklyRecapTriggerTests.swift` — VOL-07 trigger logic
- [ ] `fitbodTests/Fatigue/MuscleRegionPathsTests.swift` — path registry contains all 17 slugs
- [ ] `fitbodTests/Persistence/SchemaV4MigrationTests.swift` — V3→V4 lightweight + custom plateauTolerance bump
- [ ] `fitbodTests/Fatigue/FatigueTestFixtures.swift` — `TestFixtures.weeklySessions(...)` helper for deterministic in-memory data
- [ ] `fitbodUITests/MuscleVolumeTargetEditorUITests.swift` — SET-05 Stepper UI flows
- [ ] `fitbodUITests/PlateauOverrideUITests.swift` — SET-06 toggle + Stepper flows
- [ ] `fitbodUITests/BodySilhouetteUITests.swift` — tap-region navigation
- [ ] `fitbodUITests/WeeklyRecapUITests.swift` — VOL-07 sheet presentation flow

`TestFixtures.weeklySessions(forExercise:weights:reps:rpe:)` is the critical shared fixture helper — every detector/advisor test needs deterministic in-memory data.

---

## 15 · Performance Ceiling Check

| Operation | Row count (1-year scale) | Predicted time | Pitfall #6 ceiling |
|-----------|---------------------------|----------------|---------------------|
| `FatigueModel.weeklyVolume(muscleSlug:weekStart:)` | ~80 SetEntry rows/week + traversal through ~20 ExerciseMuscleStimulus per Exercise | <20ms | 500ms (volume dashboard ceiling per PITFALLS Performance Traps) |
| All 17 muscles aggregated for one render | 17 × ~80 = ~1360 row traversals | <100ms | Same |
| `PlateauDetector.evaluate(exerciseID:intent:)` | 4 sessions × ~5 working sets each = ~20 rows | <5ms | n/a |
| `DeloadAdvisor.evaluate(weekStart:)` | 3 weeks × ~240 rows = ~720 rows | <50ms | n/a |
| Heatmap render (17 paths × 2 sides) | 34 Path overlays + 17 fills | 60fps maintained (per MuscleMap reference) | n/a |
| WeeklyRecapSheet load | 1 week × ~80 sessions = 80 sets aggregated 4 ways | <100ms | n/a |

**Conclusion:** Every Phase 5 operation is well under the documented ceiling. D-04's "no snapshot entity" decision is safe. No caching needed.

---

## 16 · Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Brzycki/Epley/suppression e1RM partitioning | Custom math in `PlateauDetector` | Extract `OneRepMaxEstimator.swift` once; share with Phase 6 | Already implicit in `RPEAutoregStrategy`; extract to avoid divergence |
| Weekly Monday computation | Custom date math | `Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from:)` | DST and time-zone edge cases are hard; Calendar machinery is battle-tested |
| `Date` comparison for dismissal/recap state | Custom equality | `Calendar.current.isDate(_:equalTo:toGranularity:)` | DST and timezone-safe |
| Stimulus weight curated table | Per-exercise editor as the only entry point | `StimulusWeightTable.swift` static literal + seeder | User would never enter ~50 lifts manually |
| RP MEV/MAV/MRV per muscle | Per-muscle editor as the only entry point | `RPVolumeLandmarks.swift` static literal + seeder | Same reason |
| Body silhouette SVG parsing | SVG parser at runtime | Hand-coded `Path` builders in Swift | No SwiftUI native SVG parser; community pattern is hand-coded paths |
| Snapshot entity for weekly volume | `WeeklyVolumeSnapshot` @Model | On-demand `FatigueModel.weeklyVolume(...)` per D-04 | Performance is fine at v1 scale (§15); cache later if needed |
| Custom deload signal computation outside `DeloadAdvisor` | Inline RPE-creep math in views | `DeloadAdvisor.signalReport(...)` returns numeric values for the detail sheet | Single source of truth |

---

## 17 · Sources

### Primary (HIGH confidence)
- `.planning/PROJECT.md` — Core value, constraints (SwiftUI + SwiftData iOS 18, local-only, phone-only v1)
- `.planning/REQUIREMENTS.md` — Phase 5 owns VOL-01..07 + PROG-06 + SET-05/06
- `.planning/research/ARCHITECTURE.md` — `FatigueModel` + `PlateauDetector` as pure-function value types behind protocols (FOUND-07); MV-VM-lite (FOUND-06)
- `.planning/research/PITFALLS.md` — Pitfalls #1 (template/instance, extends to muscle-mapping), #3 (volume UX must drive a decision), #5 (custom exercise muscle mapping), #6 (main-thread bulk ops), #11 (deload conflict — block canonical), #12 (e1RM rep-range aware)
- `.planning/research/STACK.md` — Charting Decision: body silhouette is `Canvas` + SVG paths, not Swift Charts; `#Index` iOS 18 on hot fields
- `.planning/research/SUMMARY.md` § Highest-Leverage Decisions #5 (stimulus weighting), #10 (pure-function services), Phase 5
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` — Schema baseline (already shipped)
- `.planning/phases/02-core-loop-routines-sessions/02-CONTEXT.md` — `SessionFactory.start(...)` snapshot pattern; `SetEntry.isWarmup` hot-path flag; intent-split history pattern; `PreviousMatchingIntent` query
- `.planning/phases/03-smart-prescription-warm-ups/03-CONTEXT.md` — `ProgressionStrategy` protocol shape; `fitbod/Prescription/` directory; pure-function strategy + `PrescriptionExplanation` value type
- `.planning/phases/04-periodization-blocks/04-CONTEXT.md` — `FatigueAdvisory` protocol scaffold (Phase 4 shipped stub; Phase 5 fills); deload-canonicality type-level enforcement (BLOCK-08); Block + BlockPhase models shipped
- `.planning/phases/04-periodization-blocks/04-RESEARCH.md` — RP/Issurin verified multipliers (referenced for Branch 3 of D-13 suggested-action)
- `fitbod/Models/*.swift` — Verified Phase 1 + Phase 3 + Phase 4 schema: `ExerciseMuscleStimulus.weight: Double`, `MuscleVolumeTarget.mev/mav/mrv/mv: Int`, `MuscleGroup.slug @Unique` with 17-slug taxonomy, `UserSettings.plateauWindowSessions/plateauTolerance/weekStartsMonday/deloadAlertEnabled`, `SetEntry.isWarmup` + `setTypeRaw` + `clusterSubReps` computed accessor, `Session.startedAt #Index`, `SessionExercise.intentRaw #Index`, `Exercise.canonicalName #Index` + `primaryMuscleSlugsJoined`
- `fitbod/Prescription/Calibration.swift` — Gaussian time-kernel weighted-mean e1RM predictor (Phase 3 Plan 03-03); Phase 5 reuses for plateau detector
- `fitbod/Prescription/TuchschererTable.swift` — RPE-to-percent table; used by `RPEAutoregStrategy` to back-calculate per-set e1RM (Phase 5 plateau detector inputs)
- `fitbod/Persistence/SchemaV1.swift / SchemaV2.swift / SchemaV3.swift / FitbodSchemaMigrationPlan.swift` — Verified existing lightweight-migration pattern; Phase 5 V4 follows same pattern with one custom-migration nuance for the plateauTolerance bump
- [free-exercise-db schema.json](https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/schema.json) — 17 muscle slugs verified (HIGH; direct fetch in Phase 1 research)
- [Apple Developer: SwiftData — VersionedSchema, MigrationStage](https://developer.apple.com/documentation/swiftdata) — Lightweight vs custom migration patterns

### Secondary (MEDIUM confidence — community-verified)
- [Arvo MEV/MAV/MRV Volume Calculator](https://arvo.guru/tools/volume-calculator) — RP per-muscle volume landmarks table; cited as the source for §7 RP MEV/MAV/MRV table values. Cross-verified against RP Strength's per-muscle articles for chest/biceps/triceps (HTTP 403 on direct help.rpstrength.com URLs prevented full cross-check; Arvo's aggregation is the most reliable proxy)
- [Volume Landmarks RP visualization](https://volume-landmarks-rp-rals.vercel.app/) — Confirms MV/MEV/MAV/MRV framework definitions match Arvo's; per-muscle integer values not extractable from homepage but framework convention verified
- [RP Strength — Training Volume Landmarks for Muscle Growth](https://rpstrength.com/training-volume-landmarks-muscle-growth/) — Confirms `MV ~6 sets/week` general value; framework definitions; references per-muscle guides without inline tables
- [SwiftUI Tutorial: Build an Interactive Muscle-Map — JC](https://medium.com/@jc_builds/swiftui-tutorial-build-an-interactive-muscle-map-3321ea391e33) — Confirms per-region `Path` + `.contentShape()` pattern; 60fps on iPhone SE with 19 shapes (article paywalled; methodology summary publicly available)
- [MuscleMap SPM package on GitHub](https://github.com/melihcolpan/MuscleMap) — MIT-licensed reference for SVG-based body rendering at 36 muscle groups; **not used as a dependency** (PROJECT.md "no SPM" stance), used as reference for path data sourcing
- [Tracking Indirect Training Volume — Triage Method](https://triagemethod.com/tracking-indirect-training-volume/) — Confirms "no validated methodology exists" for numerical secondary-muscle fractions; the 1.0/0.5 + curated overrides convention is opinionated, not peer-reviewed
- [Hacking with Swift: SwiftData by Example](https://www.hackingwithswift.com/quick-start/swiftdata) — Predicate composition patterns; lightweight migration documentation
- [Apple Developer Forums: SwiftData performance with multi-hop predicates](https://developer.apple.com/forums/thread/740517) — Confirms predicate traversal limits; in-memory aggregation is the workaround

### Tertiary (LOW confidence — opinionated curation)
- §6 Stimulus-Weighting Table per-lift numerical fractions — `[ASSUMED]` opinionated curation; no peer-reviewed source publishes lift-specific fractions; convention anchored on RP's primary/secondary taxonomy + SBS biomechanics commentary
- §7 abductors/adductors/neck MEV/MAV/MRV values — `[ASSUMED]`; RP doesn't publish these landmarks; derived from accessory-muscle convention
- D-12's `±2%` tolerance default — empirical "tight enough to catch real plateaus" per CONTEXT.md; not derived from a peer-reviewed source

---

## 18 · Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The 50-lift stimulus weighting table values (e.g., bench press → triceps 0.5) are an opinionated curation, not RP-published numerics | §6 | Volume math is biased by the curation; **mitigation: user-tunable per-exercise editor empowers correction**; default 1.0/0.5 falls back for non-curated rows |
| A2 | Shoulders single-slug aggregation (not splitting front/side/rear) is acceptable for v1 | §6 introductory note | Front-delt-dominant exercises (bench, OHP) contribute to the same `shoulders` bucket as rear-delt-dominant (face pull, rear fly); a serious lifter might want the front/rear split |
| A3 | The RP `shoulders aggregate` MEV/MAV/MRV values (8/18/25) are a reasonable midpoint between RP's separate side/rear and front guides | §7 | If shoulders is consistently flagged as below-MEV, the user knows to either tune the targets up OR add isolation work |
| A4 | `OneRepMaxEstimator` extraction happens in Phase 5 Wave 0; Phase 3's `RPEAutoregStrategy` is refactored to use it | §1, §3 | If `RPEAutoregStrategy` shipped without separate estimator (verified by reading Phase 3 code — Phase 3 plan 03-03 is `Calibration.swift` which works on pre-computed e1RM, NOT raw weight × reps); the estimator likely lives implicitly inside the strategy. Phase 5 must extract it. Mitigation: planner verifies before Wave 0 |
| A5 | `MuscleRegionPaths.front` and `.back` will include all 17 muscle slugs with hand-coded `Path` builders (~680 lines of code, 1 day of work) | §8 | If hand-coding paths is slower than 1 day, Wave 3 timeline expands; alternative: use a license-compatible SVG body diagram as visual reference only and trace each region |
| A6 | The `plateauTolerance` bump from 0.005 → 0.02 needs a custom migration (not lightweight) to retroactively update the existing UserSettings singleton | §9.2 | If lightweight migration silently leaves users on 0.005, plateau detector fires false positives constantly. Mitigation: explicit `willMigrate` closure verifies and updates |
| A7 | `Calendar.current.firstWeekday = 2` (Monday) honors the user's locale + DST correctly | §10 Pitfall #4 | If a user travels across time zones mid-week, the Monday calculation might drift by one day. Mitigation: use the same `Calendar.current` instance throughout for consistency |
| A8 | The `tryVariation` suggestion sheet should exclude exercises with zero logged history (suggested in §10 Pitfall #6) | §10 | If excluded, the user can't discover new variations from the stall flag; if included, sheet may suggest unknowns the user doesn't recognize. Decision deferred to UI-SPEC |
| A9 | Phase 4's `FatigueAdvisory` protocol returns `FatigueSuggestion?`, not `DeloadAdvisory?` — Phase 5 either adopts the protocol's existing return type OR exposes both APIs | §10 Pitfall #10 | If `DeloadAdvisor.evaluate(...)` returns a different type from what Phase 4's banner expects, the integration site needs adaptation. Mitigation: planner verifies Phase 4's protocol signature before naming `DeloadAdvisor`'s public API |
| A10 | At 1-year scale, on-demand volume aggregation (per render, no snapshot entity per D-04) stays under 100ms per full-screen render | §15 | If it doesn't, the planner needs to introduce a `WeeklyVolumeSnapshot` entity in Phase 6 — but D-04 forbids this in Phase 5. Mitigation: the architecture rejection of caching is correct at v1 scale per profiling estimates; Phase 6 can revisit if needed |

**If this table is empty:** Not empty — 10 assumptions documented above for user confirmation at /gsd-discuss-phase or at plan-phase review.

---

## 19 · Open Questions

1. **Should the shoulders slug be split into front/side/rear in Phase 5, or deferred to v2?**
   - What we know: Free-exercise-db ships a single `shoulders` slug; RP separates front/side/rear. Splitting now means changing the seeded MuscleGroup taxonomy.
   - What's unclear: How important is the front/side/rear separation to the user's training programming?
   - Recommendation: **defer to v2** (per §6 introductory note). Surface the question at /gsd-discuss-phase if the user disagrees.

2. **Should the `OneRepMaxEstimator` extraction live in `fitbod/Prescription/` or `fitbod/Fatigue/`?**
   - What we know: Phase 3's `Calibration.swift` is in `Prescription/`; Phase 5's `PlateauDetector.swift` will be in `Fatigue/`.
   - What's unclear: Where does the estimator naturally belong?
   - Recommendation: `fitbod/Prescription/OneRepMaxEstimator.swift` — it's a math primitive for the prescription system (used by `RPEAutoregStrategy` and exposed for use by `PlateauDetector`).

3. **Should Phase 5's `DeloadAdvisor` replace `StubFatigueAdvisory` directly, or compose with it via a feature flag?**
   - What we know: Phase 4 shipped `FatigueAdvisory` protocol + `StubFatigueAdvisory` returning false.
   - What's unclear: Does the user want to A/B between stub and real in early dogfooding?
   - Recommendation: replace directly — single-user app, no A/B value. The detail sheet (D-16) gives the user transparency into the firing logic.

4. **Is hand-coding all 17 muscle Path builders the right Wave 3 strategy, or should the planner front-load this in Wave 0?**
   - What we know: ~680 lines of code, ~1 day of focused work.
   - What's unclear: Whether the planner sequences this as part of UI work (Wave 3) or scaffolding (Wave 0).
   - Recommendation: scaffold the `MuscleRegionPaths` registry in Wave 0 with **stub paths** (simple rectangles), then refine to anatomically-correct paths in Wave 3 alongside the UI. Tests for "paths registry contains all 17 slugs" can pass before paths are perfect.

5. **Per-exercise plateau override UI: Toggle ON/OFF or always-visible Steppers with "Reset to default" button?**
   - What we know: §11.2 recommends Toggle + conditional Steppers.
   - What's unclear: Does showing Steppers with default-grayed values feel cleaner than the Toggle?
   - Recommendation: Toggle pattern (matches Settings convention for optional overrides — clearer "this is an opt-in"). Deferred to UI-SPEC.

6. **Should the deload advisory banner appear inside `RootView` (above Phase 4's `BlockCard`) or inside `FatigueSurfaceView` (the new volume bars surface)?**
   - What we know: CONTEXT D-16 says "Today tab dismissible top banner."
   - What's unclear: Which exact stacking position.
   - Recommendation: ABOVE everything else on Today tab (above Phase 4's `BlockCard`). Most-urgent signal goes top.

---

## 20 · Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16.x (Swift Testing) | Unit/integration tests | ✓ | (project default) | None |
| iOS 18.0 deployment target | `#Index` on Phase 1 entities | ✓ | (project default) | None |
| SwiftData iOS 18 API (`MigrationStage.custom`) | SchemaV4 willMigrate for plateauTolerance bump | ✓ | (iOS 18) | None |
| `Calendar.current` with `Locale.current` | Monday computation | ✓ | (iOS standard) | None |
| `Path` + `.contentShape()` modifier | Body silhouette hit-testing | ✓ | (iOS 17+) | None |
| Asset catalog (`Color("VolumeProductiveGreen")` etc.) | Zone colors per D-09 | ✓ | (existing project Assets.xcassets) | None |

**Missing dependencies with no fallback:** None — all requirements are first-party Apple frameworks already in use.

---

## 21 · Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Pure-function service shape (`enum` + `static func` + `ModelContext` param) | HIGH | Matches Phase 3 (`Calibration`, `PlateCalculator`, `WarmupRamp`) and Phase 4 (`PeriodizationEngine`) verbatim. Zero architectural risk. |
| Schema migration V3 → V4 (lightweight + one custom willMigrate) | HIGH | Apple-documented pattern; reference implementation in `FitbodSchemaMigrationPlan.swift` already shipped for V1→V2 and V2→V3 |
| `PlateauDetector` algorithm (window, tolerance, intent-split, suggested-action decision tree) | HIGH | CONTEXT D-10..D-13 specifies the algorithm in full; this research formalizes edge cases (new exercise, high-rep filter, per-exercise override) |
| `DeloadAdvisor` 3-signal OR | HIGH | CONTEXT D-14 specifies signals; this research formalizes predicates (Sig-1 mean comparison, Sig-2 same-load matching, Sig-3 reps < targetRepsHigh) |
| `FatigueModel.weeklyVolume` math | HIGH | Predicate + in-memory aggregation is the documented SwiftData pattern; no new architecture |
| Body silhouette `Path` overlay pattern | HIGH | Community-verified (60fps on iPhone SE per cited tutorials); no third-party deps needed |
| §7 RP MEV/MAV/MRV values | MEDIUM | Arvo aggregation is reliable but RP doesn't publish a single canonical table; user-tunable mitigates risk |
| §6 stimulus-weighting per-lift fractions | LOW (but `[ASSUMED]` tagged) | No peer-reviewed source publishes fractions; convention-based curation; user-tunable mitigates risk |
| `BodySilhouetteView` Path hand-coding (~680 lines) | MEDIUM | Pattern is sound but represents a multi-hour focused work item; planner sequences |
| Threading / Swift 6 strict concurrency | HIGH | `@MainActor` on services + `ModelContext` is well-documented; matches Phase 3/4 patterns |
| Test fixture deterministic data construction | HIGH | Pattern already proven in Phase 1's `PreviewModelContainer` and Phase 2's `PreviousMatchingIntentTests` |

---

## 22 · Metadata

**Research date:** 2026-05-22
**Valid until:** 2026-06-22 (30 days — stack is mature, RP literature is stable; only the §6 stimulus table is opinionated and may evolve with user feedback)

**Phase requirements covered:**
- VOL-01 (stimulus weighting) — §6 curated table + seeder
- VOL-02 (weekly volume math) — §3.1 `FatigueModel.weeklyVolume`
- VOL-03 (RP MEV/MAV/MRV seeding) — §7 curated table + seeder
- VOL-04 (volume bars with verbs) — §5 UI pattern, D-05/D-06 verbatim
- VOL-05 (heatmap + per-muscle detail) — §8 Path overlay pattern, §1 MuscleDetailView
- VOL-06 (frequency tracking) — §3.1 `FatigueModel.frequencyHits`, D-03 ≥2-set threshold
- VOL-07 (weekly recap) — §12 trigger logic + sheet content
- PROG-06 (plateau detection) — §3.2 / §4 `PlateauDetector` design
- SET-05 (MEV/MAV/MRV editor) — §11.1 `MuscleVolumeTargetEditor`
- SET-06 (per-exercise plateau override) — §11.2 ExerciseDetailView extension

---

## RESEARCH COMPLETE

**Phase:** 5 — Fatigue Model & Plateau Detection
**Confidence:** HIGH (overall)

### Key Findings

- **Phase 5 is pure composition** — every primitive needed (schema, snapshot pattern, intent-split, pure-function services behind protocols, deload-canonicality contract) already exists from Phases 1–4. Phase 5 adds one new directory (`fitbod/Fatigue/`), one new schema version (V4 with 8 additive fields + 1 custom-migration nuance), and three new pure-function services (`FatigueModel`, `PlateauDetector`, `DeloadAdvisor`).
- **Stimulus-weighting table is opinionated, not peer-reviewed** — 51 lifts curated below using RP/SBS convention; default 1.0/0.5 falls back for the rest. User can correct any row from the per-exercise editor. Seeder idempotency tracked via new `ExerciseMuscleStimulus.userEditedWeight: Bool`.
- **RP MEV/MAV/MRV table is anchored on Arvo's aggregation** of RP's per-muscle guides — values published as integers across 17 muscles (14 cited, 4 `[ASSUMED]` derivations for abductors/adductors/neck/abs-MRV).
- **Body silhouette uses per-region `Path` overlay + `.contentShape()` hit-testing** — community-proven 60fps pattern; no third-party SPM. ~17 muscles × 2 sides = ~34 hand-coded paths (~680 lines, ~1 day of work).
- **`OneRepMaxEstimator` must be extracted** into a shared helper (`fitbod/Prescription/OneRepMaxEstimator.swift`) — Phase 3's `Calibration.swift` operates on pre-computed e1RM, NOT raw weight × reps. Phase 5 needs the Brzycki/Epley/suppression partitioning explicitly.
- **`plateauTolerance` schema-seed bump (0.005 → 0.02) requires a custom willMigrate closure** (not pure lightweight) — additive default change does not retroactively rewrite existing rows. Custom migration verifies and bumps the singleton UserSettings row exactly once.

### File Created

`/Users/chrissaechao/Desktop/fitbod/.planning/phases/05-fatigue-model-plateau-detection/05-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Architecture (pure-function services, schema migration, threading) | HIGH | Matches Phases 3/4 verbatim; zero architectural risk |
| Volume math + plateau detection algorithms | HIGH | CONTEXT D-01..D-17 specifies behavior in full; edge cases formalized |
| RP MEV/MAV/MRV values (§7) | MEDIUM | Arvo aggregation is reliable; user-tunable mitigates remaining risk |
| Stimulus-weighting per-lift fractions (§6) | LOW (tagged `[ASSUMED]`) | No peer-reviewed source publishes fractions; user-tunable per-exercise editor empowers correction |
| Body silhouette `Path` overlay implementation | MEDIUM | Pattern is sound; represents a focused work item to hand-code ~34 paths |

### Open Questions

1. Shoulders single-slug aggregation vs front/side/rear split — recommend defer to v2
2. `OneRepMaxEstimator` directory — recommend `Prescription/`
3. `DeloadAdvisor` replacing `StubFatigueAdvisory` directly — recommend yes
4. Hand-coded `Path` registry sequencing (Wave 0 stubs vs Wave 3 full) — recommend Wave 0 stubs + Wave 3 anatomical refinement
5. Per-exercise plateau override UX (Toggle vs always-visible) — recommend Toggle, defer final to UI-SPEC
6. Deload banner stacking position on Today tab — recommend above `BlockCard`

### Ready for Planning

Research complete. Planner can now create PLAN.md files. Recommended wave structure:
- **Wave 0:** SchemaV4 + 2 seeders (stimulus weights, RP MEV/MAV/MRV) + `OneRepMaxEstimator` extraction + Path registry stubs + ALL test scaffolding (RED)
- **Wave 1:** `FatigueModel` pure functions (weeklyVolume, frequencyHits, weekOverWeekDelta, volumeZone) — turn relevant Wave 0 tests GREEN
- **Wave 2:** `PlateauDetector` + `DeloadAdvisor` pure functions — turn relevant Wave 0 tests GREEN
- **Wave 3:** Volume bars UI + body silhouette UI (full anatomical paths) + per-muscle detail view
- **Wave 4:** Settings editors (SET-05, SET-06) + Today-tab deload banner + weekly recap sheet wire-up
