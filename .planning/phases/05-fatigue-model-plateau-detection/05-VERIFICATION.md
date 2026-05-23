---
phase: 05-fatigue-model-plateau-detection
verified: 2026-05-23T18:00:00Z
status: human_needed
score: 6/6 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Body silhouette heatmap renders recognizably and color-distinct zones are visually parseable"
    expected: "Front/Back segmented picker shows muscle regions that look approximately anatomical (rounded rects + ellipses + chest/lats/abdominals beziers); each region is tappable; gray/green/amber/red tints are visually distinguishable in light + dark mode"
    why_human: "Visual fidelity / anatomical recognizability cannot be grep-verified. COMPLETION-SUMMARY explicitly notes paths are 'rounded rects + ellipses + 3 custom beziers' — approximate, not hand-traced from anatomy refs."
  - test: "MuscleVolumeBar two-tone fill (direct + indirect, MEV/MAV tick marks, advisory amber ring) reads clearly"
    expected: "Solid accent fill for direct contribution, lighter accent (0.40 opacity) for indirect; MEV + MAV ticks visible; over-MRV pulse animates without reduce-motion enabled; amber ring overlay appears when deload advisory is active"
    why_human: "Visual layering and opacity blending must be inspected by eye; ticks at 1pt may render differently on actual device vs simulator."
  - test: "DeloadAdvisoryBanner placement and amber styling in Today tab"
    expected: "Banner renders above ResumeWorkoutBanner / BlockCard when DeloadAdvisor.evaluate returns non-nil; amber background, 44pt xmark dismiss hit area, copy reads correctly"
    why_human: "Banner visibility depends on real 6+ sessions of seeded data over 3 weeks meeting one of 3 signal triggers; verifying live requires logging realistic data."
  - test: "WeeklyRecapSheet auto-presents on first Monday of new week with prior-week sessions"
    expected: "Full-screen sheet titled 'Weekly Recap' appears on first app open of a new Monday when prior week had ≥1 logged session; 4 sections visible (Sessions / Muscles Hit / Under-Trained / Progress); Done dismisses"
    why_human: "Auto-presentation is gated by real wall-clock Monday + UserSettings.weeklyRecapShownForWeekStart; COMPLETION-SUMMARY notes 'forcing the recap to appear in a UI test would require a test-seed env var that the app doesn't yet expose'."
  - test: "Plateau detection stall badge + suggested action chip appears on stalled exercises in active session"
    expected: "After logging ≥4 intent-matched sessions of the same exercise with e1RM within ±2%, the SessionExerciseCard header shows orange 'Stalled' capsule + accent-colored chip with one of: 'Add volume' / 'Drop intensity' / 'Consider deload' / 'Try variation'; tap routes appropriately (tryVariation → sheet, deload → signal sheet)"
    why_human: "Live plateau detection requires real session log history; algorithm correctness is pinned at unit-test level (88+ GREEN tests across 13 suites) but end-to-end UX cannot be grep-verified."
  - test: "PerMuscleDetailView drill-down from heatmap region tap + volume bar tap"
    expected: "Tapping a muscle region OR a volume bar pushes PerMuscleDetailView onto Today tab's NavigationStack; 4 sections visible (This Week / Contributing Exercises / Frequency This Week / Adjust Targets); Adjust Targets DisclosureGroup opens MuscleVolumeTargetStepper which edits the same row Settings → Volume Targets edits"
    why_human: "Two-entry-point navigation (heatmap region tap + bar tap → same destination) must be verified end-to-end with finger gesture; visual feedback of region tap state can't be grep'd."
  - test: ".addVolume chip route is a no-op (deferred Phase 6 polish)"
    expected: "Tapping a stall chip labeled 'Add volume' does nothing visible. User must navigate to PerMuscleDetailView via the heatmap or volume bar to adjust volume targets. Documented as known limitation in COMPLETION-SUMMARY."
    why_human: "This is an intentional deferred behavior — user must confirm the no-op path is acceptable or surface a Phase 6 polish ticket. Alternative path (heatmap/bar tap) is wired and verified."
---

# Phase 5: Fatigue Model & Plateau Detection Verification Report

**Phase Goal:** Weekly volume per muscle is computed with stimulus-weighted aggregation, surfaced as MEV/MAV/MRV bars with verb labels and a muscle heatmap, plateau detection flags stalled exercises, and a fatigue-triggered deload alert surfaces as an advisory (block schedule remains canonical).

**Verified:** 2026-05-23T18:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Per-muscle weekly volume is computed as the stimulus-weighted sum of working sets via `ExerciseMuscleStimulus.weight`; top ~50 lifts have hand-curated weights, all others fall back to 1.0/0.5 defaults | VERIFIED | `FatigueModel.weeklyVolume(muscleSlug:weekStart:in:)` reads SetEntry rows filtered to working kinds (working/drop/failure/rest_pause), joins through `entry.sessionExercise.exercise.muscleStimuli`, sums by role (primary→direct, secondary→indirect). `StimulusWeightTable` ships 57 curated entries (counted via grep). `StimulusWeightSeeder` writes into `ExerciseMuscleStimulus.weight` with `userEditedWeight` idempotency. 13 GREEN tests in FatigueModelWeeklyVolumeTests + 5 GREEN in FrequencyHitsTests + 6 GREEN in StimulusWeightSeederTests. |
| 2 | Volume bars per muscle display current weekly sets within MEV/MAV/MRV color zones AND surface a verb label so every number drives a decision | VERIFIED | `VolumeZone` enum + `volumeZone(...)` free function in `/fitbod/Fatigue/VolumeZone.swift` with verbatim D-05 strict-`<` boundaries. D-06 verbatim verb copy ("Below MEV — add volume" / "Productive range — hold/progress" / "Near MRV — deload soon if performance or recovery drops." / "Over MRV — deload recommended.") in `verb` extension. `MuscleVolumeBar` renders the bar with two-tone fill (direct/indirect), MEV/MAV ticks, advisory amber ring overlay, reduce-motion-gated overMRV pulse. 9 GREEN VolumeZoneTests + 5 GREEN VolumeZoneVerbCopyTests pin the exact character-for-character copy. |
| 3 | Front and back body silhouette heatmap shows weekly volume per muscle as color intensity; muscle regions are tappable to drill into the per-muscle detail view; per-muscle frequency tracking is visible | VERIFIED | `BodySilhouetteView` renders ZStack of per-region Paths from `MuscleRegionPaths.front` (10 slugs) + `back` (10 slugs); combined coverage hits all 17 free-exercise-db muscle slugs (verified by MuscleRegionPathsTests 4 GREEN tests). `.contentShape(scaledPath)` for precise hit-testing, 44pt min-frame for small regions. Tap appends `MuscleSlugRoute.detail(slug)` onto NavigationPath → `PerMuscleDetailView` shows 4 sections including Frequency This Week via `FatigueModel.frequencyHits(...)` with `frequencyHitMinSets` setting. |
| 4 | Plateau detector flags stalled exercises with a visual stall flag on the exercise card and a suggested action (drop intensity, add volume, deload, try variation) | VERIFIED | `PlateauDetector.evaluate(exerciseID:intent:in:settings:now:)` returns `.notEnoughData` / `.stalled` / `.progressing`; honors per-exercise window/tolerance overrides via `Exercise.plateauWindowOverride` / `plateauToleranceOverride` (SchemaV6 additive fields). `suggestedAction(...)` implements D-13 4-branch decision tree (addVolume / dropIntensity / deload / tryVariation). `SessionExerciseCard` wires evaluation via `.task(id: sessionExercise.id)` and renders `StallBadge` + `SuggestedActionChip` when stalled. 9 GREEN PlateauDetectorTests + 8 GREEN SuggestedActionTests. **Caveat:** `.addVolume` and `.dropIntensity` chip routes are documented no-ops (Phase 6 polish); other routes wired. |
| 5 | "Consider deload" alert surfaces when fatigue/performance signals spike — always as an advisory the user explicitly accepts or dismisses; scheduled block deloads are never overridden | VERIFIED | `DeloadAdvisor.evaluate(weekStart:in:settings:now:) -> DeloadAdvisory?` implements D-14 multi-signal OR: Sig-1 (e1RM drop >5% recent 3 vs prior 3) + Sig-2 (RPE creep ≥1.0 at matched load) + Sig-3 (>50% missed top of rep range). D-17 dismissal via `UserSettings.deloadAdvisoryDismissedWeekStart` + Calendar.isDate(_:equalTo:toGranularity: .day). `DeloadAdvisoryBanner` mounted in Today tab via RootView; tap routes to `DeloadSignalDetailSheet` with verbatim footer "This is an advisory. Block schedule is canonical — deload when you decide, not automatically." 13 GREEN DeloadAdvisorTests including type-level canonicality pin (`DeloadAdvisor.evaluate` returns `DeloadAdvisory?` — value type that cannot mutate Block). BLOCK-08 preserved at the type level (verified by FatigueAdvisoryCanonicalityTests + DeloadAdvisorTests canonicality test). |
| 6 | MEV/MAV/MRV thresholds per muscle and plateau detection thresholds per exercise are user-tunable; weekly recap auto-surfaces at the week boundary | VERIFIED | `MuscleVolumeTargetEditor` reached from Settings → Volume Targets; per-muscle DisclosureGroup with `MuscleVolumeTargetStepper` (4 Steppers for MV/MEV/MAV/MRV with monotonic invariant validation). "Reset All to RP Defaults" destructive button with `.alert` confirmation. `ExerciseDetailView` (Phase 1) extends with "Plateau Detection" section: Toggle "Override global settings" + conditional Window/Tolerance Steppers + "Use global defaults" button. `WeeklyRecapSheet` auto-presented via RootView TodayView `.task` calling `WeeklyRecapTrigger.evaluate(...)` (5 GREEN WeeklyRecapTriggerTests including Pitfall #7 same-day Calendar comparison + Pitfall #8 zero-sessions short-circuit). |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `fitbod/Fatigue/FatigueModel.swift` | Pure-function weekly volume aggregation | VERIFIED | 250 lines; @MainActor static funcs `weeklyVolume`, `contributionPerSession`, `frequencyHits`, `weekOverWeekDelta`, `volumeZone` delegate; supporting `WeightedSetTotal` + `WeekOverWeekDelta` Sendable structs |
| `fitbod/Fatigue/VolumeZone.swift` | D-05 verbatim enum + free function | VERIFIED | 73 lines; 4 cases (belowMEV/productive/nearMRV/overMRV); strict-`<` boundaries; D-06 verbatim verb extension |
| `fitbod/Fatigue/PlateauDetector.swift` | Per-exercise plateau detection + suggested action | VERIFIED | 365 lines; `evaluate(...)` returns `PlateauSignal`; `suggestedAction(...)` implements D-13 4-branch tree; honors per-exercise overrides |
| `fitbod/Fatigue/DeloadAdvisor.swift` | Fatigue-triggered deload advisory + Phase 4 adapter | VERIFIED | 333 lines; `evaluate(...)` returns `DeloadAdvisory?`; `signalReport(...)` returns numeric values; `DeloadAdvisorAdapter` bridges Phase 4 FatigueAdvisory protocol; BLOCK-08 type-level enforcement preserved |
| `fitbod/Fatigue/StimulusWeightTable.swift` | Curated stimulus weights for top compound lifts | VERIFIED | 57 entries (counted via grep); CONTEXT specified ~50 — within range |
| `fitbod/Fatigue/StimulusWeightSeeder.swift` | Idempotent stimulus weight seeder | VERIFIED | @MainActor enum; find-or-update semantics; clamps weight to [0,1]; respects `userEditedWeight` flag |
| `fitbod/Fatigue/RPVolumeLandmarks.swift` | RP MEV/MAV/MRV per muscle | VERIFIED | All 17 muscle slugs present; conservative fallback for unknown slugs |
| `fitbod/Fatigue/MuscleVolumeTargetSeeder.swift` | Idempotent landmark seeder | VERIFIED | @MainActor enum; respects `userEdited` flag; pre-validated monotonic |
| `fitbod/Fatigue/MuscleVolumeBar.swift` | Single-muscle bar view | VERIFIED | Two-tone fill (D-07), MEV/MAV ticks, verbatim verb label, advisory amber ring, reduce-motion gated pulse |
| `fitbod/Fatigue/BodySilhouetteView.swift` | Front/back silhouette heatmap | VERIFIED | ZStack of per-region Paths; 0.4 aspect ratio; 44pt hit padding for small regions; tap routes via onTap |
| `fitbod/Fatigue/MuscleRegionPaths.swift` | Per-muscle SwiftUI.Path registry | VERIFIED | All 17 slugs covered across front/back; rounded rects + ellipses + 3 custom beziers (approximate, documented as known limitation) |
| `fitbod/Fatigue/FatigueSurfaceView.swift` | Today-tab host (Volume + Heatmap) | VERIFIED | @Query-driven (MV-VM-lite); routes taps via `MuscleSlugRoute.detail(slug)`; both bar + heatmap append same NavigationPath |
| `fitbod/Fatigue/PerMuscleDetailView.swift` | Per-muscle drill-down | VERIFIED | 4 sections (This Week, Contributing Exercises, Frequency This Week, Adjust Targets); DisclosureGroup wraps Stepper |
| `fitbod/Fatigue/MuscleVolumeTargetStepper.swift` | Shared 4-Stepper editor | VERIFIED | Monotonic invariant validation; "Reset to RP defaults" button; sets `userEdited = true` on any edit |
| `fitbod/Fatigue/StallBadge.swift` | Orange "Stalled" capsule | VERIFIED | UI-SPEC verbatim "Stalled" copy, semantic systemOrange color |
| `fitbod/Fatigue/SuggestedActionChip.swift` | Action chip with D-13 verbatim labels | VERIFIED | Labels: "Add volume" / "Drop intensity" / "Consider deload" / "Try variation"; accessibility hints per route |
| `fitbod/Fatigue/TryVariationSheet.swift` | Sheet for tryVariation chip route | VERIFIED | NavigationStack sheet; medium + large detents; filters by mechanic + primary muscle overlap + logged-at-least-once (Pitfall #6) |
| `fitbod/Fatigue/DeloadAdvisoryBanner.swift` | Today-tab top banner | VERIFIED | Amber background; 44pt xmark dismiss; body tap routes to DeloadSignalDetailSheet |
| `fitbod/Fatigue/DeloadSignalDetailSheet.swift` | Signal detail sheet | VERIFIED | List with per-signal rows; advisory-only footer; Done toolbar |
| `fitbod/Fatigue/WeeklyRecapSheet.swift` | VOL-07 weekly recap | VERIFIED | 4 sections (Sessions / Muscles Hit / Under-Trained / Progress); pure-function `WeeklyRecapTrigger.evaluate(...)` gates presentation |
| `fitbod/Fatigue/MondayAtMidnight.swift` | Shared Date extension | VERIFIED | `Date.mondayAtMidnightForToday(weekStartsMonday:)` consumed by RootView + FatigueSurfaceView + WeeklyRecapSheet + SessionExerciseCard |
| `fitbod/Prescription/OneRepMaxEstimator.swift` | Pure-function e1RM estimator | VERIFIED | Brzycki ≤6 / Epley 6–10 / nil >10 per PROG-02; 8 GREEN tests at boundaries |
| `fitbod/Persistence/SchemaV6.swift` | Schema wrapper with additive Phase 5 fields | VERIFIED | 8 additive default-valued fields across UserSettings/Exercise/ExerciseMuscleStimulus/MuscleVolumeTarget; `models` = `SchemaV5.models` (entity catalog unchanged) |
| `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` | V5→V6 custom migration stage | VERIFIED | `migrateV5toV6` is `.custom` with willMigrate closure calling `bumpPlateauToleranceDefault(in:)`; preserves user-edited 0.015 values via float-equality guard; 6 schemas + 5 stages registered |
| `fitbod/Settings/MuscleVolumeTargetEditor.swift` | SET-05 Settings entry point | VERIFIED | Sectioned List per muscle with DisclosureGroup → Stepper; global "Reset All to RP Defaults" destructive button + alert |
| `fitbod/App/RootView.swift` | Phase 5 surface integration | VERIFIED | runSeed runs all 3 seeders in order; TodayView mounts DeloadAdvisoryBanner + FatigueSurfaceView + WeeklyRecapSheet; .navigationDestination(for: MuscleSlugRoute.self) routes drill-down; refreshAdvisory + dismissAdvisory + checkWeeklyRecap helpers gated by settings flags |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| RootView.runSeed | StimulusWeightSeeder.seedIfNeeded | Direct call | WIRED | Line 232 — runs after ExerciseLibraryImporter (Phase 1) |
| RootView.runSeed | MuscleVolumeTargetSeeder.seedIfNeeded | Direct call | WIRED | Line 239 |
| RootView.TodayView | DeloadAdvisoryBanner | Conditional render when currentAdvisory != nil | WIRED | Lines 290-296 |
| RootView.TodayView | FatigueSurfaceView | Always rendered | WIRED | Lines 319-322; passes isAdvisoryActive + navigationPath bindings |
| RootView.TodayView | DeloadAdvisor.evaluate | refreshAdvisory() helper | WIRED | Lines 442-453; gated by settings.deloadAlertEnabled |
| RootView.TodayView | WeeklyRecapTrigger.evaluate | checkWeeklyRecap() helper | WIRED | Lines 405-425; called from .task + .onAppear |
| FatigueSurfaceView | MuscleVolumeBar | ForEach over visibleMuscles | WIRED | Lines 99-122 |
| FatigueSurfaceView | BodySilhouetteView | Always rendered with Front/Back picker | WIRED | Lines 142-150 |
| FatigueSurfaceView (taps) | PerMuscleDetailView | navigationPath.append(MuscleSlugRoute.detail) | WIRED | Both bar onTap + heatmap onTap route to same destination |
| SessionExerciseCard | PlateauDetector.evaluate | .task(id: sessionExercise.id) | WIRED | Line 280 → evaluatePlateau() at line 323 |
| SessionExerciseCard | StallBadge + SuggestedActionChip | Conditional on `case .stalled` | WIRED | Lines 239-249 |
| SessionExerciseCard | TryVariationSheet | `.sheet(isPresented: $presentingTryVariation)` | WIRED | Lines 284-290 |
| SessionExerciseCard | DeloadSignalDetailSheet | `.sheet(isPresented: $presentingDeloadSignalSheet)` | WIRED | Lines 294-306 |
| DeloadAdvisor | OneRepMaxEstimator.estimate | Used for top-set e1RM | WIRED | Multiple call sites in DeloadAdvisor + PlateauDetector + WeeklyRecapSheet |
| MuscleVolumeBar | VolumeZone.verb | zone.verb computed property | WIRED | Line 80 |
| Settings | MuscleVolumeTargetEditor | NavigationLink in volumeTargetsSection | WIRED | SettingsView.swift line 174 |
| Settings | frequencyHitMinSets | @Bindable Stepper | WIRED | SettingsView.swift line 185 |
| ExerciseDetailView | plateauWindowOverride + plateauToleranceOverride | Toggle + conditional Steppers | WIRED | Lines 383-447 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|---------------------|--------|
| FatigueSurfaceView.visibleMuscles | allMuscles, allTargets | @Query MuscleGroup + MuscleVolumeTarget | Yes — populated by ExerciseLibraryImporter (Phase 1) + MuscleVolumeTargetSeeder (Phase 5) | FLOWING |
| MuscleVolumeBar | total, delta | FatigueModel.weeklyVolume + weekOverWeekDelta read SetEntry rows | Yes — reads real SetEntry data via predicate + Swift post-filter | FLOWING |
| BodySilhouetteView | zoneByMuscleSlug | FatigueSurfaceView.computeZoneByMuscleSlug iterates @Query MuscleGroup + FatigueModel.weeklyVolume | Yes — real data flowing from SetEntry rows | FLOWING |
| DeloadAdvisoryBanner | currentAdvisory | RootView.refreshAdvisory → DeloadAdvisor.evaluate reads Session + SetEntry rows | Yes — reads real session log data | FLOWING |
| PlateauDetector (SessionExerciseCard) | plateauSignal | PlateauDetector.evaluate reads intent-matched SessionExercise rows | Yes — reads real session history | FLOWING |
| WeeklyRecapSheet | settings, allMuscles, allTargets | @Query + FatigueModel.frequencyHits + topExercisesProgress | Yes — reads real session log data | FLOWING |
| PerMuscleDetailView | total, delta, contributing exercises | FatigueModel + @Query + Swift post-filter | Yes — reads real session log data | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Project builds | `xcodebuild build -project fitbod.xcodeproj -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:fitbodUITests` | `** BUILD SUCCEEDED **` | PASS |
| All Phase 5 unit test suites pass | `xcodebuild test ... -only-testing:fitbodTests/{FatigueModelWeeklyVolumeTests,VolumeZoneTests,PlateauDetectorTests,DeloadAdvisorTests,OneRepMaxEstimatorTests,StimulusWeightSeederTests,MuscleVolumeTargetSeederTests,SuggestedActionTests,FrequencyHitsTests,VolumeZoneVerbCopyTests,WeeklyRecapTriggerTests}` | `** TEST SUCCEEDED **` | PASS |
| Asset catalog has 4 Volume color sets | `find Assets.xcassets -name 'Volume*.colorset'` | 4 colorsets present (VolumeBelowMEVGray, VolumeProductiveGreen, VolumeNearMRVAmber, VolumeOverMRVRed) | PASS |
| StimulusWeightTable has ≥50 curated entries | `grep -c '^        "[^"]*": \[' StimulusWeightTable.swift` | 57 entries | PASS |
| Schema additive fields persisted on @Model classes | `grep -n "deloadAdvisoryDismissedWeekStart\|weeklyRecapShownForWeekStart\|frequencyHitMinSets\|plateauWindowOverride\|plateauToleranceOverride\|userEditedWeight\|userEdited" Models/...` | All 7 fields present on UserSettings/Exercise/ExerciseMuscleStimulus/MuscleVolumeTarget | PASS |
| D-06 verbatim verb copy in VolumeZone | `grep -n "Below MEV — add volume\|Productive range — hold/progress\|Near MRV — deload soon\|Over MRV — deload recommended" VolumeZone.swift` | All 4 strings character-for-character verbatim | PASS |

### Probe Execution

No project-specific probes declared. The project verification model uses `xcodebuild test` (run above as a spot-check).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| VOL-01 | 05-02-PLAN | Each exercise maps primary/secondary muscles via ExerciseMuscleStimulus with weight | SATISFIED | StimulusWeightTable (57 entries) + StimulusWeightSeeder; ExerciseMuscleStimulus.weight + userEditedWeight (SchemaV6) |
| VOL-02 | 05-02-PLAN | Weekly volume per muscle computed as stimulus-weighted sum | SATISFIED | FatigueModel.weeklyVolume + 13 GREEN FatigueModelWeeklyVolumeTests |
| VOL-03 | 05-06-PLAN | Per-muscle MEV/MAV/MRV thresholds seeded from RP, user-tunable | SATISFIED | RPVolumeLandmarks (17 slugs) + MuscleVolumeTargetSeeder + MuscleVolumeTarget.userEdited (SchemaV6) |
| VOL-04 | 05-03-PLAN | Volume bars with color zones AND verb labels | SATISFIED | VolumeZone enum + D-06 verbatim verbs + MuscleVolumeBar + 5 GREEN VolumeZoneVerbCopyTests |
| VOL-05 | 05-05-PLAN | Front/back silhouette heatmap with tappable muscle regions | SATISFIED | BodySilhouetteView + MuscleRegionPaths (all 17 slugs covered) + PerMuscleDetailView destination |
| VOL-06 | 05-02-PLAN, 05-06-PLAN | Per-muscle frequency tracking | SATISFIED | FatigueModel.frequencyHits + UserSettings.frequencyHitMinSets (SchemaV6) + Settings Stepper |
| VOL-07 | 05-06-PLAN | Weekly recap auto-surfaces at week boundary | SATISFIED | WeeklyRecapSheet + WeeklyRecapTrigger + RootView.checkWeeklyRecap + UserSettings.weeklyRecapShownForWeekStart |
| PROG-06 | 05-03-PLAN | Plateau detection signal per exercise with visual stall flag + suggested action | SATISFIED | PlateauDetector.evaluate + suggestedAction (D-13 4-branch) + StallBadge + SuggestedActionChip; **note:** .addVolume and .dropIntensity chip routes are documented no-ops (Phase 6 polish) |
| SET-05 | 05-06-PLAN | User-tunable MEV/MAV/MRV per muscle | SATISFIED | MuscleVolumeTargetEditor (Settings entry) + MuscleVolumeTargetStepper (inline + Settings) + Reset All button |
| SET-06 | 05-03-PLAN | User-tunable plateau detection thresholds per exercise | SATISFIED | Exercise.plateauWindowOverride + .plateauToleranceOverride (SchemaV6) + ExerciseDetailView Toggle + Steppers |
| BLOCK-06b | 05-04-PLAN | Real fatigue/performance signal populates non-stub FatigueAdvisory; banner activates above threshold (suggestion only) | SATISFIED | DeloadAdvisor.evaluate with D-14 3-signal multi-signal OR + DeloadAdvisoryBanner + DeloadAdvisorAdapter (bridges Phase 4 protocol); BLOCK-08 type-level canonicality verified by DeloadAdvisorTests.canonicalityCannotReturnMutationType |

All 11 requirements claimed in COMPLETION-SUMMARY satisfied. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| fitbod/Sessions/SessionExerciseCard.swift | 342 | `// .addVolume → plan 05 wires PerMuscleDetailView (still a TODO).` (doc comment) | Info | Documents deferred work; alternative path verified (heatmap/bar tap → PerMuscleDetailView) |
| fitbod/Sessions/SessionExerciseCard.swift | 356 | `// TODO(plan 05): push PerMuscleDetailView for the primary muscle.` | Info | Same as above. Reference to "plan 05" is informal (plan-05 was already executed); COMPLETION-SUMMARY documents this `.addVolume` chip route as deferred Phase 6 polish with explicit alternative path described. Not blocking phase goal; consistent with COMPLETION-SUMMARY known limitations. |

No `TBD`, `FIXME`, `XXX`, or other blocker debt markers found in Phase 5 implementation files (`fitbod/Fatigue/*`, `fitbod/Persistence/SchemaV6.swift`, `fitbod/Persistence/FitbodSchemaMigrationPlan.swift`, `fitbod/Prescription/OneRepMaxEstimator.swift`, `fitbod/Settings/MuscleVolumeTargetEditor.swift`).

### Human Verification Required

The phase goal is achieved in code, but Phase 5 ships a substantial set of new visual surfaces (heatmap, volume bars, banners, sheets) and behavioral flows (auto-presented recap, signal-triggered advisory, plateau stall flags) that cannot be programmatically verified by grep / unit tests alone. Human UAT is required to validate:

#### 1. Body silhouette heatmap visual fidelity

**Test:** Open Today tab on a real device; confirm the front + back silhouette renders with distinguishable muscle regions
**Expected:** Front/Back segmented picker visible; rounded-rect + ellipse + bezier shapes approximate anatomy; tappable regions; color zones (gray/green/amber/red) visually distinct in light + dark mode
**Why human:** COMPLETION-SUMMARY explicitly notes paths are approximate ("rounded rects + ellipses + 3 custom beziers for chest/lats/abdominals") and anatomical fidelity is a deferred polish item

#### 2. MuscleVolumeBar two-tone fill + ticks + advisory ring

**Test:** Log enough sessions to populate volume data; inspect a MuscleVolumeBar with non-zero direct + indirect contribution
**Expected:** Solid accent fill for direct contribution; lighter accent (0.40 opacity) trailing portion for indirect; visible MEV + MAV tick marks; over-MRV pulse animates (toggleable via reduce-motion); amber ring overlay when advisory is active
**Why human:** Visual layering / opacity blending / 1pt ticks require eye inspection

#### 3. DeloadAdvisoryBanner placement and styling

**Test:** Log 6+ sessions over 3 weeks with one signal trigger (e.g., 5%+ e1RM drop); reopen Today tab
**Expected:** Banner renders ABOVE BlockCard + ResumeWorkoutBanner; amber background; 44pt xmark dismiss tap target; body tap opens DeloadSignalDetailSheet
**Why human:** Live data dependency; banner stacking order vs Phase 4 surfaces needs visual check

#### 4. WeeklyRecapSheet auto-presentation

**Test:** On a real Monday with prior-week sessions logged, open the app
**Expected:** Full-screen sheet titled "Weekly Recap" auto-presents; 4 sections visible (Sessions / Muscles Hit / Under-Trained / Progress); Done dismisses; same Monday relaunch does not re-show
**Why human:** Requires real wall-clock Monday + log history; no test-seed env var exposed (documented Phase 6 polish)

#### 5. Plateau detection stall badge + chip in active session

**Test:** Log ≥4 intent-matched sessions of the same exercise with e1RM within ±2%; start a new session for that exercise
**Expected:** SessionExerciseCard header shows orange "Stalled" capsule + accent-tinted chip with one of the 4 verbatim labels; tap routes appropriately (.tryVariation → sheet, .deload → signal sheet)
**Why human:** Live history + UX flow can't be grep-verified

#### 6. PerMuscleDetailView drill-down (two entry points)

**Test:** From Today tab, tap a muscle region in the heatmap; navigate back; tap a volume bar for a different muscle
**Expected:** Both taps push PerMuscleDetailView onto the Today NavigationStack; 4 sections visible; Adjust Targets DisclosureGroup opens MuscleVolumeTargetStepper that edits the same row Settings → Volume Targets edits
**Why human:** Two-entry-point navigation to same destination requires gesture verification

#### 7. .addVolume chip route is a no-op (intentional deferred behavior)

**Test:** Trigger a plateau where Branch 1 fires (primary muscle volume < MAV); tap the resulting "Add volume" chip
**Expected:** Nothing happens visibly. The user is expected to navigate to PerMuscleDetailView via heatmap or bar tap.
**Why human:** This is an intentional deferred behavior documented in COMPLETION-SUMMARY § Known Limitations. User must confirm the no-op path is acceptable or surface a Phase 6 polish ticket (alternative path via heatmap/bar tap is wired and verified).

### Gaps Summary

No blocking gaps found. All 6 ROADMAP Success Criteria are satisfied with substantive implementations (88+ GREEN unit tests, build green, asset catalog complete, schema migration custom-staged for the plateauTolerance default bump, runtime-wired into RootView's TodayView).

**Notable items routed to human verification:**
- 7 visual / behavioral checks that require real device + log history (heatmap fidelity, bar visual treatment, banner placement, recap auto-present, stall badge UX, two-entry-point drill-down, .addVolume no-op acceptance).
- The `.addVolume` and `.dropIntensity` chip route no-ops are documented as deferred Phase 6 polish in COMPLETION-SUMMARY § Known Limitations + § Deferred Work. Alternative paths (heatmap/bar tap → PerMuscleDetailView; on-card prescription editor) are wired and verified.
- The `TODO(plan 05)` and `(still a TODO)` doc-comment markers in SessionExerciseCard.swift reference the same deferred work. These do not block the phase goal because (a) the alternative paths are working, (b) the limitation is explicitly enumerated in COMPLETION-SUMMARY, and (c) the chip routes do not crash or surface broken UI (they are silent no-ops).

**Type-level BLOCK-08 canonicality preserved:** `DeloadAdvisor.evaluate` returns `DeloadAdvisory?` (a value type that cannot mutate Block state); `DeloadAdvisorTests.canonicalityCannotReturnMutationType` is a compile-time pin. `FatigueAdvisoryCanonicalityTests` separately verifies the Phase 4 `FatigueAdvisory` protocol surface has no Block-mutating field. The block schedule remains the sole writer (PeriodizationEngine.advance per Phase 4 D-25).

---

_Verified: 2026-05-23T18:00:00Z_
_Verifier: Claude (gsd-verifier)_
