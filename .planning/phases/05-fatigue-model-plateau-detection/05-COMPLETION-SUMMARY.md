# Phase 5 Completion Summary

Completed on 2026-05-23.

## Phase Overview

Phase 5 (Fatigue Model & Plateau Detection) shipped the decision-driving fatigue surfaces that turn raw session data into actionable advisories: stimulus-weighted weekly volume + verb-labeled MEV/MAV/MRV bars + body silhouette heatmap + per-exercise plateau flags with auto-picked suggested actions + fatigue-triggered deload advisory banner + auto-presented weekly recap. All 11 requirements (VOL-01..07 + PROG-06 + SET-05/06 + BLOCK-06b) close; type-level BLOCK-08 / Phase 4 D-25 canonicality is preserved end-to-end.

## Implemented

### Data + schema

- **SchemaV5 → V6 additive migration** with 8 new default-valued fields + 1 custom willMigrate for the `UserSettings.plateauTolerance` default bump (0.005 → 0.02 per D-12); user-edited values preserved by float-equality guard. The `FitbodSchemaMigrationPlan` extends to 6 schemas + 5 stages.
- **`OneRepMaxEstimator`** — pure-function namespace in `fitbod/Prescription/` (Brzycki ≤6 / Epley 6–10 / nil >10 per REQUIREMENTS PROG-02). Consumed by PlateauDetector + DeloadAdvisor + WeeklyRecapSheet Progress section.
- **`VolumeZone`** — D-05 verbatim enum (`belowMEV` / `productive` / `nearMRV` / `overMRV`) + free function with strict-< boundaries; D-06 verbatim verb copy character-for-character (including the intentional trailing-period asymmetry).
- **`StimulusWeightTable`** — 57 curated lifts per RESEARCH §6.1 verbatim (the doc header miscounted as 51 but enumerated 57).
- **`RPVolumeLandmarks`** — 17-muscle landmark dictionary per RESEARCH §7.1 verbatim + conservative `landmark(for:)` fallback for unknown slugs.
- **`MuscleRegionPaths`** — anatomically-informed `SwiftUI.Path` registry (rounded rects + ellipses + 3 custom beziers for chest/lats/abdominals) keyed by muscle slug across front/back views; combined coverage hits all 17 free-exercise-db slugs.
- **4 new Asset Catalog colorsets** — `VolumeBelowMEVGray` (#8E8E93/#636366) / `VolumeProductiveGreen` (#34C759/#30D158) / `VolumeNearMRVAmber` (#FF9500/#FF9F0A) / `VolumeOverMRVRed` (#FF3B30/#FF453A) per UI-SPEC §Asset Contract verbatim hex pairs.

### Services (pure-function namespaces)

- **`FatigueModel`** — 5 @MainActor static funcs (`weeklyVolume` + `contributionPerSession` + `frequencyHits` + `weekOverWeekDelta` + `volumeZone` delegate) + supporting Sendable value types (`WeightedSetTotal` with direct/indirect split per D-07; `WeekOverWeekDelta` with D-08 verbatim deltaCopy). Algorithm splits predicate composition across `#Predicate` (simple gates) + Swift post-filter (multi-hop optional traversal per Pitfall #1) because Swift 6's type checker times out on the all-inline form.
- **`StimulusWeightSeeder`** — idempotent per-launch seeder; iterates the 57 curated entries; find-or-update semantics (NOT delete-and-recreate) preserves SwiftData identity; row-level idempotency via `ExerciseMuscleStimulus.userEditedWeight`; T-05-01 stimulus-weight clamp `[0, 1]` enforced via internal `clampedWeight` helper.
- **`MuscleVolumeTargetSeeder`** — idempotent per-launch seeder; iterates 17 MuscleGroup rows; writes RP landmark values via `RPVolumeLandmarks.landmark(for:)`; row-level idempotency via `MuscleVolumeTarget.userEdited` (VOL-03 preservation); T-05-02 monotonic invariant defense-in-depth (RP data is pre-validated monotonic).
- **`PlateauDetector`** — 2 @MainActor static funcs (`evaluate` + `suggestedAction`) + Sendable Equatable enums (`PlateauSignal` .notEnoughData/.stalled/.progressing; `SuggestedAction` .addVolume/.dropIntensity/.deload/.tryVariation). evaluate honors per-exercise window + tolerance overrides; PROG-02 high-rep suppression; D-10 intent split. suggestedAction implements D-13 4-branch priority decision tree (Branch 1 addVolume when primary muscle < MAV; Branch 2 dropIntensity on RPE creep ≥1.0 at matched load; Branch 3 deload on active Block week ≥3 + deload ≤14d out; Branch 4 default tryVariation).
- **`DeloadAdvisor`** — 2 @MainActor static funcs (`evaluate` + `signalReport`) + Sendable Equatable types. D-14 3-signal multi-signal OR (Sig-1 e1RM drop >5% pooled across exercises last 3 vs prior 3 sessions; Sig-2 RPE creep ≥1.0 per (exercise, intent) pair; Sig-3 missed top of rep range >50% across last 3 sessions). D-17 dismissal scope via `Calendar.current.isDate(_:equalTo:toGranularity: .day)` per Pitfall #7. Type-level T-05-03 canonicality: evaluate returns `DeloadAdvisory?` — a value type the compiler refuses to coerce into a mutation. `DeloadAdvisorAdapter` bridges Phase 4's `FatigueAdvisory` protocol.
- **`WeeklyRecapTrigger`** — pure-function helper with `Decision` struct (shouldPresent + shouldMarkSeen); applies Pitfall #7 (Calendar same-day comparison) + Pitfall #8 (zero-sessions short-circuit marks seen without presenting).

### UI

- **`MuscleVolumeBar`** — single-muscle bar row per UI-SPEC §MuscleVolumeBar layout verbatim: name + sets-vs-mrv trailing accessory + GeometryReader ZStack bar track with D-07 two-tone fill (indirect 0.40 opacity + direct 1.0 opacity) + MEV/MAV tick marks + D-06 verbatim verb label + D-08 verbatim delta line. Reduce-motion-gated overMRV pulse animation; advisory amber ring overlay when `isAdvisoryActive`.
- **`FatigueSurfaceView`** — Today-tab host. Volume This Week section + Muscle Heatmap section (Picker .segmented Front/Back + BodySilhouetteView). @Query-driven (MV-VM-lite per FOUND-06). Mounts in `RootView.TodayView` below ResumeWorkoutBanner. Both heatmap region taps + volume bar taps append `MuscleSlugRoute.detail(slug)` onto the parent's NavigationPath.
- **`BodySilhouetteView`** — GeometryReader-scaled ZStack of per-region Path overlays per RESEARCH §8.2; .aspectRatio(0.4, contentMode: .fit); `.contentShape(scaledPath)` precise hit-testing; small regions wrap minimum 44pt `.frame`; Asset Catalog zone colors only.
- **`StallBadge` + `SuggestedActionChip`** — orange "Stalled" capsule + accent-tinted suggested-action capsule with D-13 verbatim labels ("Add volume" / "Drop intensity" / "Consider deload" / "Try variation"); rendered on stalled `SessionExerciseCard` between CalibratingBadge and Spacer.
- **`TryVariationSheet`** — NavigationStack sheet (medium + large detents) listing 2–3 alternative exercises by mechanic + ≥1 overlapping primary muscle slug + logged-at-least-once filter (Pitfall #6 mitigation); empty-state + "View all similar exercises in library" footer link.
- **`PerMuscleDetailView`** — 4-section List drill-down reached via heatmap region taps + volume bar taps: This Week / Contributing Exercises / Frequency This Week / Adjust Targets (DisclosureGroup wrapping `MuscleVolumeTargetStepper`).
- **`MuscleVolumeTargetStepper`** — shared 4-Stepper editor (MV/MEV/MAV/MRV) with monotonic invariant validation (T-05-02 inline systemRed error) + Reset to RP defaults accent button; any edit sets `target.userEdited = true`.
- **`MuscleVolumeTargetEditor`** — Settings entry point for SET-05; sectioned List per muscle + global "Reset All to RP Defaults" destructive button with .alert confirmation per UI-SPEC §Copywriting Contract verbatim.
- **`DeloadAdvisoryBanner`** — Today-tab top banner with body Text + xmark dismiss (44pt hit area) + amber background per UI-SPEC §Color. Replaces Phase 4's `ConsiderDeloadBanner()` stub. Tap body presents `DeloadSignalDetailSheet`; xmark dismisses for the current calendar week.
- **`DeloadSignalDetailSheet`** — NavigationStack + List with per-signal rows (verbatim labels + numeric values) + advisory-only footer + Done toolbar.
- **`WeeklyRecapSheet`** — full-screen sheet auto-presented on first Monday of each new week with sessions logged in the prior week. 4 sections (Sessions / Muscles Hit / Under-Trained / Progress). Progress section computes top-5 exercises by working-set count last week with their e1RM delta vs week prior.
- **`SettingsView`** — adds "Volume Targets" Section with NavigationLink to MuscleVolumeTargetEditor + frequencyHitMinSets Stepper (D-03 + VOL-06 surface).
- **`ExerciseDetailView`** — adds "Plateau Detection" section (SET-06): Toggle "Override global settings" + conditional Window/Tolerance Steppers + "Use global defaults" button.
- **`SessionExerciseCard`** — wires PlateauDetector evaluation in `.task(id: sessionExercise.id)`; renders StallBadge + SuggestedActionChip when stalled; routes `.tryVariation` → TryVariationSheet, `.deload` → DeloadSignalDetailSheet, `.addVolume` and `.dropIntensity` are no-op (the on-card editor IS the affordance for .dropIntensity; .addVolume can be wired to PerMuscleDetailView via the existing MuscleSlugRoute pattern in a future polish plan).
- **`RootView.TodayView`** — full Phase 5 surface integration: DeloadAdvisoryBanner mount (replacing Phase 4 ConsiderDeloadBanner stub), FatigueSurfaceView mount with navigationPath + isAdvisoryActive bindings, MuscleSlugRoute navigationDestination, DeloadSignalDetailSheet + WeeklyRecapSheet auto-presentation; `refreshAdvisory` + `dismissAdvisory` + `checkWeeklyRecap` helpers gated by `settings.deloadAlertEnabled` and `settings.weeklyRecapShownForWeekStart`.

### Wiring

- **`RootView.runSeed`** runs the 3 Phase 5 seeders in order: ExerciseLibraryImporter (Phase 1) → PlateInventorySeeder (Phase 3) → StimulusWeightSeeder → MuscleVolumeTargetSeeder. Idempotent — safe to call on every launch.
- **`MondayAtMidnight.swift`** — shared public Date extension `mondayAtMidnightForToday(weekStartsMonday:)` per Pitfall #4 (Calendar.current.firstWeekday=2). Replaces fileprivate copies; consumed by RootView + FatigueSurfaceView + WeeklyRecapSheet + SessionExerciseCard.

## Tests

### Unit / SwiftTesting suites (data layer)

- **SchemaV6MigrationTests** (10 GREEN @Test functions) — schema wiring + 8 additive fields round-trip + the plateauTolerance bump + preserve paths.
- **OneRepMaxEstimatorTests** (8 GREEN @Test functions) — Brzycki/Epley/suppression boundaries at reps 0/1/5/6/7/10/11/-3.
- **VolumeZoneTests** (9 GREEN @Test functions) — sweeps every D-05 strict-< boundary transition.
- **VolumeZoneVerbCopyTests** (5 GREEN @Test functions) — pins D-06 verbatim copy + intentional trailing-period asymmetry.
- **MuscleRegionPathsTests** (4 GREEN @Test functions) — pins slug coverage independent of geometry (stays GREEN after Wave 4 anatomical refinement).
- **FatigueModelWeeklyVolumeTests** (13 GREEN @Test functions) — D-01/D-04/D-07/D-08 + Pitfall #1/#3/#9 corner cases.
- **FrequencyHitsTests** (5 GREEN @Test functions) — D-03 threshold semantics including the "single 0.5 indirect doesn't count" anchor + "multiple indirect can add up to a hit" test.
- **StimulusWeightSeederTests** (6 GREEN @Test functions) — 57-row writeback + user-edit preservation + non-curated immutability + idempotency + T-05-01 clamp + find-or-update no-duplicates.
- **PlateauDetectorTests** (9 GREEN @Test functions) — D-10 intent split + D-11 window override + D-12 tolerance override + PROG-02 high-rep filter + top-set selection by e1RM + rangeRatio formula.
- **SuggestedActionTests** (8 GREEN @Test functions) — D-13 4-branch decision tree + no-stall short-circuit + branch priority Branch-1-wins-over-Branch-2 + no-active-block edge.
- **DeloadAdvisorTests** (13 GREEN @Test functions) — Sig-1 fires + does NOT fire + Sig-2 fires + Sig-3 fires + multi-signal OR + all-nil → nil + dismissal suppresses + next Monday re-evaluates + canonicality compile-time pin + signalReport per-signal values + all-nil case + bannerCopy single/multi verbatim.
- **MuscleVolumeTargetSeederTests** (5 GREEN @Test functions) — 17-row seed + user-edit preservation + non-edited overwrite + idempotency + T-05-02 RP monotonicity defense-in-depth.
- **WeeklyRecapTriggerTests** (5 GREEN @Test functions) — first-launch fires + same-week suppresses + zero-sessions marks-seen-without-present + next-Monday refires + Pitfall #7 same-day Calendar comparison.

### UI tests (XCUITest)

- **VolumeBarsUITests** (2 GREEN tests) — Today tab Volume This Week header reachable; empty-state or D-06 verb-string visible.
- **PlateauOverrideUITests** (2 GREEN tests) — Exercise detail Plateau Detection section reachable; override toggle reveals Steppers.
- **BodySilhouetteUITests** (2 GREEN tests) — Today tab Muscle Heatmap section reachable; Front/Back segmented control present.
- **PerMuscleDetailUITests** (1 GREEN test) — Volume bar tap lands on PerMuscleDetailView with one of the 4 section headers visible.
- **DeloadAdvisoryBannerUITests** (2 GREEN tests) — Today tab still renders with banner wiring; banner hidden by default on fresh installs.
- **MuscleVolumeTargetEditorUITests** (2 GREEN tests) — Settings → Volume Targets section reachable; editor + Reset All button visible.
- **WeeklyRecapUITests** (1 GREEN test) — Today tab doesn't spuriously show the recap on fresh install.

### Final verification

- `xcodebuild test -project fitbod.xcodeproj -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:fitbodUITests` → **TEST SUCCEEDED** (all unit + Swift Testing suites GREEN).
- Each new UI test suite runs GREEN on the iPhone 17 simulator (full UI sweep takes longer; individual suites verified during execution).
- All 8 of plan-01's RED scaffolds are now GREEN.

## Known Limitations

- **MuscleRegionPaths anatomical refinement is approximate, not hand-traced from anatomy references.** Rounded rects + ellipses + 3 custom beziers for chest/lats/abdominals. A future polish plan can refine further to Wikimedia-traced bezier polylines if user feedback demands higher visual fidelity. Slug coverage is decoupled from geometry — tests stay GREEN regardless.
- **`.dropIntensity` chip route is a no-op** — the on-card prescription editor (Phase 3) IS the affordance; a dedicated "drop intensity" wizard is deferred to Phase 6 polish.
- **`.addVolume` chip route is a no-op** for the same reason — the user navigates to PerMuscleDetailView via the heatmap or volume bar to adjust volume targets. A dedicated push surface from the chip is deferred to Phase 6 polish.
- **UI tests are smoke checks**, not full algorithmic round-trips. Driving Steppers and toggles via XCUITest on iOS 26 simulator has known fragility (button accessibility identifiers vary). Full algorithm round-trips are pinned at the data layer via the 88+ GREEN unit tests across 13 Phase 5 test suites.
- **WeeklyRecapSheet auto-presentation is gated by real wall-clock dates** — it only fires on a real Monday-of-a-new-week with prior-week sessions. Forcing the recap to appear in a UI test would require a test-seed env var that the app doesn't yet expose; the algorithm is pinned at the unit-test level instead.

## Deferred Work

- **Phase 6** owns full progress views (PROG-01..05/07/08) + export (EXP-01..04) + polish. The data primitives Phase 5 ships (FatigueModel, OneRepMaxEstimator, MuscleSlugRoute pattern, WeeklyRecapSheet Progress section) compose into Phase 6's per-exercise time-series + PR detection + weekly tonnage chart + session comparison + CSV/JSON export surfaces.
- **`.addVolume` / `.dropIntensity` chip routes** with dedicated push destinations (e.g., a "drop the weight by 10% for next session" wizard) — Phase 6 polish.
- **Anatomical MuscleRegionPaths refinement** to hand-traced bezier polylines — Phase 6 polish if user feedback demands it.
- **Force-show recap test seed env var** — would let UI tests drive the auto-presentation path; deferred.
