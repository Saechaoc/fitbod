# Phase 5: Fatigue Model & Plateau Detection - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning
**Mode:** Interactive discuss-phase (default mode, single-question turns, all 4 keystone areas covered)

<domain>
## Phase Boundary

This phase delivers **decision-driving fatigue surfaces** — weekly per-muscle volume is computed as a stimulus-weighted sum, surfaced as MEV/MAV/MRV bars with verb labels, a front/back body heatmap drillable into per-muscle detail, a plateau detector that flags stalled exercises with a suggested action, and a fatigue-triggered "consider deload" advisory (block schedule remains canonical per BLOCK-08 + Pitfall #11).

1. **Volume aggregation** — `FatigueModel.weeklyVolume(muscle:in:context:) -> WeightedSetTotal` pure function computes stimulus-weighted working-set counts per muscle for the current calendar week (Mon–Sun per `UserSettings.weekStartsMonday = true`). Working sets include `working / drop / failure / rest_pause` (each counted as 1 set; rest-pause clusters are 1 set total, not N). Warmups excluded via existing `SetEntry.isWarmup` hot-path flag. Aggregation is on-demand (no denormalized snapshot entity).
2. **Volume bars with verbs** — per-muscle bars on the fatigue surface. Zones use a `VolumeZone` enum with bounds `<MEV → belowMEV` / `MEV..<MAV → productive` / `MAV..<MRV → nearMRV` / `>=MRV → overMRV`. Two-tone fill (direct primary, lighter indirect secondary). Each bar shows "+N vs last week" delta. Verb copy locked verbatim (see Decisions D-08).
3. **Body silhouette heatmap** — `Canvas` + SVG-derived paths (front + back). Each muscle region tinted with the same 4 discrete zone colors used on the bars (visual encoding consistency). Tappable muscle regions navigate to per-muscle detail view (VOL-05).
4. **Plateau detector** — `PlateauDetector.evaluate(exerciseID:intent:in:context:) -> PlateauSignal` pure function. Signal source: top-set e1RM per session (Brzycki ≤6 reps / Epley 6–10 / suppress >10 per existing REQUIREMENTS PROG-02), per intent stream. Window default = 4 intent-matched sessions of this exercise. Tolerance default = ±2% (bumps schema seed from 0.005 → 0.02). When triggered, surfaces a stall flag on the exercise card + an auto-picked suggested action: `dropIntensity / addVolume / deload / tryVariation` chosen by signal pattern.
5. **Deload advisory** — `DeloadAdvisor.evaluate(in:context:) -> DeloadAdvisory?` pure function. Multi-signal OR — fires when ANY of three signals trip over 3 weeks of working-exercise data, whole-week aggregate scope: (1) top-set e1RM drop >5%, (2) RPE creep ≥1.0 at same load, (3) >50% of working sets miss top of rep range. Surfaces as a dismissible Today-tab top banner + amber tint ring on volume bars. Banner copy explains which signal(s) fired. Dismissal suppresses for the current calendar week; re-evaluates next Monday. **Never** schedules a deload (BLOCK-08 — block schedule is canonical, advisory only).
6. **Settings surfaces** — `MuscleVolumeTarget` editor (SET-05) per muscle in Settings → "Volume Targets" section. Per-exercise plateau threshold override (SET-06) editable from `ExerciseDetailView`. Schema entities `MuscleVolumeTarget` and `UserSettings` already exist (Phase 1); this phase wires the editor UIs.
7. **Weekly recap (VOL-07)** — auto-surfaces on first app open of a new calendar week as a sheet from the Today tab. Contents: muscles hit (frequency ≥2 weighted-set sessions/week), muscles under-trained (< MEV), e1RM movement per exercise vs last week, sessions logged. Snooze for the week dismisses. **Surface form is Claude's discretion** (sheet detents, copy details).

In scope: VOL-01..07, PROG-06, SET-05, SET-06 (10 requirements).
Out of scope: charts of any kind (Phase 6 PROG-01..05), session comparison (Phase 6 PROG-07), live PR detection (Phase 6 PROG-08), CSV/JSON export (Phase 6 EXP-*).

</domain>

<decisions>
## Implementation Decisions

### Area A — Volume scope + week boundary

- **D-01: Set scope** — Weekly working-set count includes `setTypeRaw ∈ {working, drop, failure, rest_pause}`. Each contributes 1 set (a rest-pause cluster is 1 set total regardless of sub-rep array length). Warmups always excluded via existing `SetEntry.isWarmup` hot-path flag. Partial reps (`SetEntry.partialReps`) do NOT bump set count (they're rep modifiers within one set).
- **D-02: Week boundary** — Calendar week Mon–Sun, anchored to `UserSettings.weekStartsMonday = true` (already locked). Volume bars + heatmap show current calendar week's running total. Weekly recap (VOL-07) auto-surfaces at the boundary (first app open of new Mon).
- **D-03: Frequency-hit threshold (VOL-06)** — A session "counts as a frequency hit" for a muscle when the stimulus-weighted set contribution to that muscle is ≥2. Single 0.5 indirect contribution does NOT count.
- **D-04: Aggregation strategy** — `FatigueModel.weeklyVolume(...)` is a pure function reading `SetEntry` rows on demand. No denormalized `WeeklyVolumeSnapshot` entity. Matches FOUND-07 (pure-function stateless services behind protocols). At 1-year scale (~4500 SetEntry rows), well under Pitfall #6 perf ceiling.

### Area B — Verb thresholds + bar style

- **D-05: VolumeZone enum (verbatim)**:
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
  Bounds: `<MEV / MEV..<MAV / MAV..<MRV / >=MRV`. MAV is the **first fatigue warning boundary** — below MAV is the productive zone; at/above MAV the warning starts.
- **D-06: Verb copy (verbatim, locked)**:
  - `belowMEV` → "Below MEV — add volume"
  - `productive` → "Productive range — hold/progress" (during MEV..<MAV)
  - `nearMRV` → "Near MRV — deload soon if performance or recovery drops."
  - `overMRV` → "Over MRV — deload recommended."
  Voice matches Phase 2/3 convention: direct, second-person, no exclamation points.
- **D-07: Bar fill style** — Two-tone: solid accent fill for direct (`role == "primary"`) weighted-set contribution + lighter accent for indirect (`role == "secondary"`). User can see "11 direct + 3.5 indirect" without doing math (Pitfall #3 best practice).
- **D-08: Week-over-week delta** — Each bar shows "+N vs last week" (or "-N", or "no change") below the verb. Always visible. Catches accumulation/cut/stall mid-mesocycle without needing the weekly recap.
- **D-09: Heatmap color encoding** — 4 discrete zone colors matching the bars: gray (belowMEV), green (productive), amber (nearMRV), red (overMRV). Same encoding everywhere — user only learns the palette once. Heatmap rendered via SwiftUI `Canvas` + SVG-derived path data (front + back silhouettes).

### Area C — Plateau detector signal + window

- **D-10: Signal source** — Top-set e1RM per session, per intent stream. e1RM formula already locked at REQUIREMENTS PROG-02: Brzycki for ≤6 reps, Epley for 6–10, e1RM suppressed (no plateau signal) for >10. Hypertrophy sessions can't "plateau" a strength stream (and vice versa) — matches ROUTINE-08 intent split.
- **D-11: Window default** — 4 intent-matched sessions of the exercise (keep existing `UserSettings.plateauWindowSessions = 4` schema seed). Per-exercise override deferred to Per-exercise threshold editor (SET-06).
- **D-12: Tolerance default** — ±2% e1RM range over the window flags as stall. **Schema seed `UserSettings.plateauTolerance = 0.005` bumps to `0.02`** in Phase 5 migration. Within typical day-to-day biological noise but tight enough to catch real plateaus.
- **D-13: Suggested action auto-pick** — `PlateauDetector.suggestedAction(...)` heuristic picks ONE action from `{ dropIntensity, addVolume, deload, tryVariation }`:
  - Muscle volume `< MAV` for the relevant muscle this week → `addVolume`
  - RPE creep ≥1.0 at same load across the window → `dropIntensity`
  - Current block week ≥3 heavy AND scheduled deload ≤2 weeks out → `deload`
  - None of the above match → `tryVariation` (UI links to 2–3 similar exercises in library via `Exercise.mechanic` + primary-muscle overlap; sheet titled "Try variation")
  Surfaces as a single visible chip with "See alternatives" tap-through on the exercise card.

### Area D — Deload advisory triggers + UI

- **D-14: Trigger model** — Multi-signal OR. Three independent signals; ANY one firing surfaces the advisory:
  - **Sig-1:** Top-set e1RM (across all logged exercises, pooled regardless of intent) drops >5% over the last 3 sessions vs the 3 sessions before that
  - **Sig-2:** RPE creep ≥1.0 at the same load over the last 3 sessions for the same exercise + intent pair (any working exercise this week)
  - **Sig-3:** Missed top of rep range on >50% of working sets across the last 3 sessions
- **D-15: Trigger scope** — Whole-week aggregate, not per-exercise (per-exercise stalls are already covered by plateau detector). Reads the last 3 weeks of working-exercise sessions; emits at most ONE `DeloadAdvisory` per evaluation.
- **D-16: UI surface** — Today tab dismissible top banner with copy like: "Consider deload — e1RM dropped 6% on chest lifts over last 3 sessions. Tap to see signals." Tap opens a detail sheet listing each firing signal with values. Volume bars on the fatigue surface get a subtle amber ring tint while the advisory is active. **No push notifications** (personal-app stance — alerts must feel collaborative, not nagging).
- **D-17: Dismissal scope** — Dismiss suppresses the advisory for the current calendar week. Re-evaluates each Monday — if signals persist, surfaces again. **Never schedules** a deload (block schedule canonical per BLOCK-08 + Pitfall #11); "accept" = "acknowledged, I'll deload manually or wait for next scheduled block deload."

### Claude's Discretion

The user explicitly delegated these for write-CONTEXT-now:
- **Weekly recap (VOL-07)** surface form: full-screen sheet on first app open of new calendar week is the recommendation. Contents anchored: muscles hit, muscles under-trained, e1RM movement per exercise vs last week, sessions logged. Sheet detents, copy micro-variations, and dismiss/snooze UX are Claude's discretion at UI-SPEC + plan-phase time.
- **Per-muscle detail view drill-down content** (entered from heatmap tap or per-bar tap): recommendation = vertical sections — "This week" (set count + zone + delta), "Contributing exercises" (sorted by weighted-set count this week), "Frequency this week" (count of sessions hitting the ≥2-set threshold), inline "Adjust targets" editor for `MuscleVolumeTarget.mev/mav/mrv/mv` (SET-05).
- **`MuscleVolumeTarget` editor (SET-05)** surface: reachable from Settings → "Volume Targets" section (sectioned list per muscle with steppers) AND inline from per-muscle detail view. Both surfaces edit the same row; Settings is the primary entry point.
- **Per-exercise plateau threshold override (SET-06)** surface: editable from `ExerciseDetailView` (added in Phase 1). New optional fields on `Exercise`: `plateauWindowOverride: Int?`, `plateauToleranceOverride: Double?`. Both nil → fall back to `UserSettings` defaults.
- **Visual treatment** of `VolumeZone` colors, heatmap region tint saturation curves, banner accent — deferred to UI-SPEC for this phase.
- **"Over MRV — deload recommended."** color saturation (red intensity) and animation/pulse — deferred to UI-SPEC.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project + requirements
- `.planning/PROJECT.md` — Core value, constraints, RP-style volume model commitment
- `.planning/REQUIREMENTS.md` — Phase 5 owns VOL-01..07 + PROG-06 + SET-05/06 (10 requirements)
- `.planning/ROADMAP.md` § Phase 5 — 6 must-be-true success criteria

### Architecture + pitfalls
- `.planning/research/SUMMARY.md` § Phase 5 + Highest-Leverage Decisions (#5 stimulus weighting, #10 pure-function services)
- `.planning/research/ARCHITECTURE.md` — `FatigueModel` + `PlateauDetector` as pure-function value types behind protocols (FOUND-07)
- `.planning/research/PITFALLS.md` Pitfall #3 (volume UX must drive a decision), #5 (custom exercise muscle mapping), #11 (deload conflict — block canonical, fatigue advisory), #12 (e1RM rep-range aware)
- `.planning/research/STACK.md` § Charting Decision — body silhouette is `Canvas` + SVG paths, not Swift Charts

### Phase ancestors
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` — Schema, `ExerciseMuscleStimulus.weight: Double`, `MuscleVolumeTarget` placeholder defaults, `UserSettings.plateauWindowSessions/plateauTolerance/deloadAlertEnabled/weekStartsMonday`, 17-muscle taxonomy
- `.planning/phases/02-core-loop-routines-sessions/02-CONTEXT.md` — `SessionFactory.start(...)` snapshot, `SetEntry.isWarmup` hot-path flag, intent-split history pattern
- `.planning/phases/03-smart-prescription-warm-ups/03-CONTEXT.md` — `ProgressionStrategy` protocol shape (Phase 5's PlateauDetector + FatigueModel follow the same protocol-behind-pure-value-types pattern); per-exercise plateau override schema design hints
- `.planning/phases/02-core-loop-routines-sessions/*-SUMMARY.md` + `.planning/phases/01-foundation-exercise-library/*-SUMMARY.md` — what exists in code (Session, SessionExercise, SetEntry, ExerciseMuscleStimulus, MuscleVolumeTarget, UserSettings)

### Research flags to resolve at plan-phase
- **Stimulus-weighting table for top ~50 compound lifts** (per ROADMAP Phase 5 research flag) — `Bench press → chest 1.0 + front delts 0.5 + triceps 0.5`, `Barbell row → lats 1.0 + biceps 0.5 + rear delts 0.3`, etc. Hand-curated table loaded at first launch or via migration; defaults 1.0/0.5 remain for non-curated exercises. Source: RP / Stronger By Science publications; planner-researcher to confirm exact per-lift numbers.
- **RP-published MEV/MAV/MRV per muscle** (per ROADMAP Phase 5 research flag) — Renaissance Periodization publishes per-muscle landmarks (e.g., chest MEV 8, MAV 12, MRV 22). Planner-researcher to curate canonical seed values; `MuscleVolumeTarget` row inserted per muscle on first launch (or via migration if Phase 1 placeholder rows already exist).
- **e1RM rep-range formula confirmation** — REQUIREMENTS PROG-02 already locks Brzycki ≤6 / Epley 6–10 / suppress >10. Plateau detector reuses this exact partitioning.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 1–2)

- `ExerciseMuscleStimulus` entity (`fitbod/Models/ExerciseMuscleStimulus.swift`) — `weight: Double` + `role: String` ("primary" / "secondary"). The stimulus-weighted volume sum keys off this. Schema seeded with 1.0 primary / 0.5 secondary defaults from Phase 1.
- `MuscleVolumeTarget` entity (`fitbod/Models/MuscleVolumeTarget.swift`) — `mev/mav/mrv/mv: Int` + `muscle: MuscleGroup?`. Phase 1 placeholder defaults (8/14/22/6); Phase 5 importer overwrites with RP-published values per muscle.
- `MuscleGroup` entity (`fitbod/Models/MuscleGroup.swift`) — 17-canonical-slug taxonomy from `free-exercise-db`; `slug` is `@Unique`; has `volumeTargets: [MuscleVolumeTarget]?` cascade-delete inverse.
- `UserSettings` entity (`fitbod/Models/UserSettings.swift`) — has `plateauWindowSessions: Int = 4`, `plateauTolerance: Double = 0.005`, `deloadAlertEnabled: Bool = true`, `weekStartsMonday: Bool = true`. **Phase 5 must bump `plateauTolerance` to `0.02`** (D-12) via SchemaV3 lightweight migration — additive default change. Add new field `frequencyHitMinSets: Int = 2` (D-03) — additive default-valued.
- `SetEntry` entity (`fitbod/Models/SetEntry.swift`) — `isWarmup: Bool` (hot-path flag for volume rollups, per schema comment), `setTypeRaw: String`, `isComplete: Bool`. All needed predicates already exist.
- `SessionExercise.intentRaw` — `#Index`ed for intent-split queries (used by plateau detector).
- `Session.startedAt` — `#Index`ed for week-window queries.
- `Exercise.equipment / mechanic / primaryMuscles` — input to `tryVariation` suggested-action heuristic (D-13).
- `RootView` Today tab (currently `PlaceholderTabView`) — gets the dismissible deload advisory banner + Volume / Heatmap surface in this phase.
- `SettingsView` placeholder — gets `MuscleVolumeTargetEditor` section (SET-05) + plateau-threshold override surface (SET-06).
- `ExerciseDetailView` (Phase 1) — gets new `plateauWindowOverride` + `plateauToleranceOverride` fields (SET-06).

### Established Patterns

- Pure-function strategies / services behind protocols (FOUND-07). `FatigueModel`, `PlateauDetector`, `DeloadAdvisor` follow the same pattern Phase 3 establishes with `ProgressionStrategy`.
- MV-VM-lite: views bind to `@Model` types directly via `@Query` / `@Bindable` (FOUND-06). NO view-model layer wrapping `@Query` (breaks SwiftData reactivity per Pitfall #8 corollary).
- Enums persisted as `*Raw: String` with computed accessors (FOUND-03). `VolumeZone` doesn't need to be persisted (it's a computed function output, not state).
- `#Index` on hot query paths (FOUND-04). `Session.startedAt` and `SessionExercise.intentRaw` already indexed; no new indexes required for this phase's queries.
- Atomic per-plan commits + Swift Testing `@Test` suites (Phase 1–3 convention). Math services unit-tested without `ModelContainer`.
- Verbatim UI-SPEC copywriting (Phase 2 convention) — verb copy in D-06 locked verbatim into CONTEXT and downstream UI-SPEC.
- `@MainActor` for ModelContext in views; `@ModelActor` reserved for bulk seed (none needed this phase) per ARCHITECTURE #10.

### Integration Points

- `FatigueModel.weeklyVolume(muscle:weekStart:context:)` — new pure function. Reads SetEntry rows via `ModelContext.fetch(...)` predicate filtered to (Session.startedAt in [weekStart, weekStart+7d), SessionExercise.intentRaw, SetEntry.isComplete && !isWarmup, setTypeRaw ∈ working set kinds). Sums `weight * 1.0` per set per muscle via `ExerciseMuscleStimulus` join.
- `PlateauDetector.evaluate(exerciseID:intent:in:)` — pure function. Reads last N=plateauWindowSessions intent-matched sessions of the exercise (Session.startedAt DESC, fetchLimit=N). Computes top-set e1RM per session via Brzycki/Epley/suppression rules. Returns `.stalled` if min/max within `±plateauTolerance`.
- `DeloadAdvisor.evaluate(weekStart:context:)` — pure function. Reads last 3 weeks of Session + SetEntry; checks each of 3 signals; emits `DeloadAdvisory?`. Dismissal state stored on `UserSettings.deloadAdvisoryDismissedWeekStart: Date?` (new additive optional field).
- Today tab home in `RootView` — `FatigueSurfaceView` hosts the volume bars + heatmap. Banner overlay via `.safeAreaInset(edge: .top)`.
- Plateau stall flag on `SessionExerciseCard` (existing from Phase 2) — adds a stall badge + suggested-action chip when `PlateauDetector` flags the exercise.

</code_context>

<specifics>
## Specific Ideas

- **Implementation per D-05** (user-supplied verbatim Swift):
  ```swift
  func volumeZone(currentSets: Int, mev: Int, mav: Int, mrv: Int) -> VolumeZone {
      if currentSets < mev { return .belowMEV }
      if currentSets < mav { return .productive }
      if currentSets < mrv { return .nearMRV }
      return .overMRV
  }
  ```
  Half-open intervals on the lower bound, closed at MRV. Use `<` strictly per the user's snippet — do NOT switch to `<=` elsewhere.
- **"Productive range" copy** is for `MEV..<MAV` (D-06). The user's snippet labeled this zone as "productive" — match that name in the enum case (`case productive`, not `case hold` or `case midZone`).
- **Verb copy is verbatim** — UI must use D-06 strings character-for-character. Voice: declarative, no exclamation points, lowercase mid-sentence (matches Phase 2/3 voice).
- **Heatmap palette** — gray / green / amber / red mapped to the 4 zones. Avoid `Color.red` literal — use a semantic asset like `Color("MRVRed")` in the Asset Catalog, same approach as Phase 2's `Color("PinnedNoteYellow")`.
- **Plateau e1RM partitioning** — top-set e1RM is computed per-session AFTER filtering to working sets (`isComplete && !isWarmup && reps > 0`). For rep ranges: Brzycki for `reps <= 6`, Epley for `6 < reps <= 10`, signal suppressed (return nil from estimator) for `reps > 10` — match REQUIREMENTS PROG-02.
- **`tryVariation` suggestion shape** — sheet titled "Try variation" lists 2–3 alternative `Exercise` rows. Selection criteria: same `Exercise.mechanic`, ≥1 overlapping primary muscle, ascending alphabetical, exclude the source exercise itself, exclude exercises with no logged sets ever (avoid suggesting empty unknowns).
- **Deload advisory banner copy template**: `"Consider deload — {signal-1 description} over last 3 sessions. Tap to see signals."` Multiple signals: `"Consider deload — {n} fatigue signals tripped over last 3 sessions. Tap to see signals."`
- **Frequency hit threshold (D-03) is additive on `UserSettings`** — new field `frequencyHitMinSets: Int = 2`. Editable from Settings (Claude's discretion section).
- The fatigue surface (volume bars + heatmap) IS a new top-level Tab? **NO** — surface lives inside the Today tab (per Phase 4's "block timeline on home" precedent). Today tab grows; no new tab. Keeps RootView at 5 tabs total.

</specifics>

<deferred>
## Deferred Ideas

- **Live PR detection at set save** — Phase 6 (PROG-08)
- **Per-exercise time-series chart (intent-split)** — Phase 6 (PROG-01)
- **PRs view (weight / rep / volume / e1RM per exercise)** — Phase 6 (PROG-05)
- **Weekly tonnage chart** — Phase 6 (PROG-04)
- **Session comparison view** — Phase 6 (PROG-07)
- **Plate-rounded warm-up scaling on deload weeks** — already handled by Phase 4 (the conditional flag is wired in Phase 3, sourced in Phase 4)
- **Adaptive MEV/MAV/MRV auto-tune** (algorithm learns user's actual MEV from recovery patterns) — v2; out of scope for v1
- **Body-fat / morphology-aware heatmap** (silhouette that matches user's actual proportions) — v2
- **Per-block volume targets** (different MEV/MAV/MRV for accumulation vs intensification phases) — out of scope for v1; one tunable set per muscle
- **Push notification on plateau** — explicitly rejected (personal-app stance, "no nagging")
- **Adaptive deload schedule** that auto-inserts deload weeks based on advisory acceptance — explicitly rejected by BLOCK-08 (block schedule canonical)
- **"Show me why" deep-dive panel** on deload advisory — covered by the tap-into-signals sheet (D-16); no separate panel needed

</deferred>

---

*Phase: 5-Fatigue Model & Plateau Detection*
*Context gathered: 2026-05-22*
