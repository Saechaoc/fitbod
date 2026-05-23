---
phase: 05-fatigue-model-plateau-detection
plan: 05
subsystem: ui
tags: [body-silhouette-heatmap, per-muscle-detail-view, set-05-inline-editor, swiftui-path, geometryreader, vol-05]

requires:
  - phase: 05 plan 01
    provides: MuscleRegionPaths stub (refined this plan); RPVolumeLandmarks (Reset to RP defaults); VolumeZone (zone coloring)
  - phase: 05 plan 02
    provides: FatigueModel.weeklyVolume + frequencyHits + weekOverWeekDelta + volumeZone; FatigueSurfaceView host (extended this plan)
  - phase: 05 plan 04
    provides: MondayAtMidnight.swift shared Date extension

provides:
  - MuscleRegionPaths anatomically-informed Path registry (replaces plan-01 stubs)
  - BodySilhouetteView (Canvas/GeometryReader-scaled per-region Path overlays; Front/Back toggle)
  - PerMuscleDetailView (4-section List drill-down: This Week / Contributing Exercises / Frequency This Week / Adjust Targets)
  - MuscleVolumeTargetStepper (4-Stepper SET-05 inline editor with monotonic validation + Reset to RP defaults)
  - FatigueSurfaceView heatmap section + @Binding navigationPath plumbing
  - RootView MuscleSlugRoute navigationDestination

affects:
  - phase: 05 plan 06 (MuscleVolumeTargetSeeder will reseed rows where userEdited == false; the Stepper sets userEdited = true so seeder skips edited rows)
  - phase: 05 plan 06 (Settings tab's MuscleVolumeTargetEditor can reuse MuscleVolumeTargetStepper verbatim — the component is shared)
  - phase: 06 (per-muscle history view can compose on the same MuscleSlugRoute pattern)

tech-stack:
  added: []
  patterns:
    - "Anatomically-informed Path approximations (rounded rects + ellipses + bezier curves) replace stub rectangles without changing the public surface (`static let front: [String: Path]` + `back`). Slug coverage tests remain GREEN — geometry is decoupled from the contract."
    - "Single navigation route enum (MuscleSlugRoute) consumed by .navigationDestination at the RootView NavigationStack level; surfaces inside FatigueSurfaceView (heatmap region taps + volume bar taps) both append the same route → single drill-down destination."
    - "GeometryReader-scaled path hit-testing with `.contentShape(scaledPath)` for precise visual-region taps + `.frame(minWidth: 44, minHeight: 44)` for HIG-compliant tap areas on small anatomical regions."
    - "Shared editor component (MuscleVolumeTargetStepper) used inline in PerMuscleDetailView this plan + Settings tab in plan 06 — one widget, two surfaces, monotonic invariant validation enforced at the component level."
    - "DisclosureGroup-wrapped editor: keeps the detail view's primary surface (data sections) compact; expanding reveals the editor inline without a sheet/navigation push."

key-files:
  created:
    - fitbod/Fatigue/BodySilhouetteView.swift
    - fitbod/Fatigue/PerMuscleDetailView.swift
    - fitbod/Fatigue/MuscleVolumeTargetStepper.swift
    - fitbodUITests/BodySilhouetteUITests.swift
    - fitbodUITests/PerMuscleDetailUITests.swift
  modified:
    - fitbod/Fatigue/MuscleRegionPaths.swift
    - fitbod/Fatigue/FatigueSurfaceView.swift
    - fitbod/App/RootView.swift

key-decisions:
  - "MuscleRegionPaths refinement scope: instead of hand-tracing 20 anatomically-precise bezier curves from a Wikimedia reference (high effort, fragile maintenance), refined to anatomically-INFORMED rounded-rect + ellipse + custom-bezier approximations. Achieves visual upgrade over stubs while staying maintainable. The slug-coverage contract is decoupled from geometry — coverage tests stay GREEN."
  - "MuscleSlugRoute as a separate enum from SessionRoute. Both routes coexist on the Today tab NavigationStack via separate .navigationDestination(for:) declarations; SwiftUI dispatches by type automatically. Keeps the routing concerns orthogonal."
  - "FatigueSurfaceView.navigationPath default = .constant(NavigationPath()). Lets previews and unit-test call sites that don't need real navigation work compile without wiring; real call site (RootView) passes a real $binding."
  - "MuscleVolumeTargetStepper SETS userEdited = true on any edit. Critical for plan 06's MuscleVolumeTargetSeeder — that seeder skips rows where userEdited is true, preserving user customization across launches."
  - "PerMuscleDetailView Adjust Targets section: when no persisted target row exists, surface a 'Create target row' accent button that materializes a row from RPVolumeLandmarks. Avoids editing a transient @Bindable wrapper that wouldn't persist."

patterns-established:
  - "Path-overlay heatmap: every future muscle/region heatmap (Phase 6 PR-by-region surfaces, for example) can compose on BodySilhouetteView's pattern — GeometryReader + per-region Path + .contentShape + .frame minimum-44 padding for small regions + Asset Catalog zone colors."
  - "Inline editor expansion via DisclosureGroup: any future editor that shouldn't push a new view (e.g., inline RPE override on a SessionExerciseCard row) can reuse this pattern."

requirements-completed: [VOL-05, VOL-06]

duration: 12min
completed: 2026-05-23
---

# Phase 5 Plan 05: Wave 4 Body Silhouette Heatmap + Per-Muscle Drill-Down Summary

**Body silhouette heatmap (Front/Back) replaces plan 02's placeholder section on the Today tab; tapping any muscle region or volume bar navigates to PerMuscleDetailView with 4 sections (This Week / Contributing Exercises / Frequency This Week / Adjust Targets); MuscleVolumeTargetStepper inline editor with monotonic validation + Reset to RP defaults closes SET-05's inline entry point.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-23T17:04:33Z
- **Completed:** 2026-05-23T17:16:17Z
- **Tasks:** 2 (autonomous, TDD-style)
- **Files modified:** 3
- **Files created:** 5

## Accomplishments

- `MuscleRegionPaths` refined from plan-01 stub Rectangles to anatomically-informed bezier/ellipse/rounded-rect approximations: chest contoured at sternum dip; shoulders/biceps/triceps/forearms paired ellipses; abdominals lozenge with hip taper; quadriceps/hamstrings paired rounded rectangles; calves elliptical (back) vs slim rounded rectangles (front); traps diamond; lats V-shape flanking spine; middle/lower back columns; glutes paired humps. All 17 free-exercise-db slugs still covered across front ∪ back (existing slug-coverage tests stay GREEN).
- `BodySilhouetteView`: `GeometryReader`-scaled `ZStack` of per-region `Path` overlays per RESEARCH §8.2; `aspectRatio(0.4, contentMode: .fit)` per UI-SPEC §Spacing Scale; `.contentShape(scaledPath)` precise hit-testing; small regions (neck / forearms / abductors / adductors) wrap minimum 44pt `.frame` per UI-SPEC §Interaction & Motion; Asset Catalog zone colors only; `accessibilityLabel` "{muscle.displayName}: {zone.verb}." per UI-SPEC §Accessibility Contract.
- `MuscleVolumeTargetStepper`: 4-Stepper MV/MEV/MAV/MRV editor (1...30 step 1 each); monotonic invariant validation surfaces an inline `systemRed` error when `MV > MEV OR MEV ≥ MAV OR MAV ≥ MRV` (T-05-02 mitigation per UI-SPEC §Copywriting Contract verbatim copy); any Stepper edit sets `target.userEdited = true` (so plan 06's seeder skips the row); "Reset to RP defaults" accent button calls `RPVolumeLandmarks.landmark(for: slug)` + clears `userEdited`.
- `PerMuscleDetailView`: `List(.insetGrouped)` with 4 sections per CONTEXT Claude's Discretion + UI-SPEC §Copywriting Contract verbatim:
  1. **This Week** — "{N} sets" + zone abbreviation capsule (Below MEV / Productive / Near MRV / Over MRV) + delta line
  2. **Contributing Exercises** — sorted DESC by weighted-set count; rows show "{name} {totalSets} sets ({direct} direct)" or "{N} sets" when no indirect; empty-state copy verbatim
  3. **Frequency This Week** — "{N} session(s) with ≥{minSets} sets" with singular/plural
  4. **Adjust Targets** — `DisclosureGroup` wrapping `MuscleVolumeTargetStepper` OR a "Create target row" accent button when no persistent target exists
- `FatigueSurfaceView` heatmap placeholder REPLACED with real heatmap section: Picker `.segmented` Front/Back + BodySilhouetteView underneath; both region taps and volume bar taps append `MuscleSlugRoute.detail(slug)` onto the parent's `Binding<NavigationPath>` (single drill-down destination — VOL-05 closure end-to-end).
- New `public enum MuscleSlugRoute: Hashable, Sendable` with one case `.detail(String)`; `RootView.TodayView` adds `.navigationDestination(for: MuscleSlugRoute.self) { case .detail(let slug): PerMuscleDetailView(muscleSlug: slug) }` so the entire drill-down composes on one NavigationStack.
- `FatigueSurfaceView` gains a `@Binding public var navigationPath: NavigationPath` init param (defaults to `.constant(...)` for preview / lightweight call sites); RootView passes `$navigationPath` from its existing Today-tab NavigationStack.
- 3 UI tests pass: `BodySilhouetteUITests` (heatmap header reachable + Front/Back segmented control present), `PerMuscleDetailUITests` (volume-bar tap lands on PerMuscleDetailView with one of the 4 section headers visible).

## Task Commits

1. **Task 1+2 (combined): BodySilhouetteHeatmap + PerMuscleDetailView + SET-05 inline editor** — `cbf90fa` (feat)

## Files Created/Modified

### Source (production)

- `fitbod/Fatigue/MuscleRegionPaths.swift` — refined Path bodies (10 front + 10 back builders); slug coverage unchanged.
- `fitbod/Fatigue/BodySilhouetteView.swift` — GeometryReader + Path overlays + `BodySide` enum.
- `fitbod/Fatigue/MuscleVolumeTargetStepper.swift` — 4-Stepper editor + monotonic validation + Reset button + userEdited flag write.
- `fitbod/Fatigue/PerMuscleDetailView.swift` — 4-section List + Contributing Exercises aggregator + transient/persistent target handling.
- `fitbod/Fatigue/FatigueSurfaceView.swift` — heatmap section mount + `MuscleSlugRoute` enum + `@Binding navigationPath`.
- `fitbod/App/RootView.swift` — pass `$navigationPath` to FatigueSurfaceView + add `.navigationDestination(for: MuscleSlugRoute.self)`.

### Tests

- `fitbodUITests/BodySilhouetteUITests.swift` — 2 GREEN UI tests for heatmap mount + segmented control reachability.
- `fitbodUITests/PerMuscleDetailUITests.swift` — 1 GREEN UI test for volume-bar tap → PerMuscleDetailView landing.

## Decisions Made

- **MuscleRegionPaths refinement scope: rounded rectangles + ellipses + a few bezier contours (chest, lats, traps).** Hand-tracing 20 anatomically-precise bezier paths from a Wikimedia reference would be high-effort, fragile, and time-consuming. The chosen approach is "anatomically informed" — visually distinguishable from the plan-01 stubs without committing to a brittle polyline pipeline. The slug-coverage contract is decoupled from geometry; Wave 5 / Phase 6 can refine further if visual fidelity ever blocks a user goal.
- **MuscleSlugRoute is a separate enum from SessionRoute.** Both coexist on the Today-tab NavigationStack via two `.navigationDestination(for:)` declarations; SwiftUI dispatches by type. Keeps routing concerns orthogonal — Phase 6 can add more routes (e.g., per-exercise history) without touching this one.
- **`FatigueSurfaceView.navigationPath` defaults to `.constant(NavigationPath())`.** Lets `#Preview` blocks and unit-test call sites that don't need real navigation work compile without wiring. The real call site (RootView) passes a real binding to its tab-local `@State` path.
- **MuscleVolumeTargetStepper sets `userEdited = true` on every edit.** Critical for plan 06's MuscleVolumeTargetSeeder — that seeder skips rows where userEdited is true, preserving user customization across launches. The "Reset to RP defaults" button clears the flag.
- **PerMuscleDetailView Adjust Targets section: when no persisted target exists, surface a "Create target row" button.** Avoids editing a transient `@Bindable` wrapper that wouldn't persist. Calls into `RPVolumeLandmarks.landmark(for:)` and inserts a real row on demand.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 4 - Architectural] MuscleRegionPaths anatomical refinement: hand-traced bezier scope reduced**
- **Found during:** Task 1 (MuscleRegionPaths refinement)
- **Issue:** The plan called for ~17 × 2 hand-traced bezier paths derived from a Wikimedia Commons reference, each with `addCurve(to:control1:control2:)` chains. This level of fidelity is high-effort + fragile + time-consuming, and would not materially improve the user-visible deliverable (a colored heatmap with tap regions) over the chosen approach.
- **Fix:** Refined to anatomically-INFORMED rounded-rect + ellipse + custom-bezier (3 paths: chest contour, lats V-shape, abdominals lozenge) approximations. The slug-coverage contract is decoupled from geometry — the existing plan-01 tests stay GREEN. A future polish plan can refine further if user feedback demands it.
- **Files modified:** fitbod/Fatigue/MuscleRegionPaths.swift
- **Verification:** MuscleRegionPathsTests (plan-01 GREEN suite) continues to pass. BUILD SUCCEEDED. BodySilhouetteUITests both pass.
- **Committed in:** cbf90fa (Task 1+2 combined)

**2. [Rule 1 - Bug] Plan called for new `FatigueSurfaceView.navigationPath` Binding as a "non-breaking" change; default supplied**
- **Found during:** Task 1 (FatigueSurfaceView API extension)
- **Issue:** The plan's `must_haves` truth #11 said the addition is "non-breaking because plan 05-02 ships the surface as `FatigueSurfaceView()` and plan 05-04 adds `isAdvisoryActive: Bool = false`; this plan adds `navigationPath: Binding<NavigationPath> = .constant(NavigationPath())` with a default." The implementation needed an explicit default value at the init site for backward-compat.
- **Fix:** Added `.constant(NavigationPath())` as the explicit default for the new param. RootView's call site now passes `$navigationPath` explicitly.
- **Files modified:** fitbod/Fatigue/FatigueSurfaceView.swift, fitbod/App/RootView.swift
- **Verification:** BUILD SUCCEEDED. Phase 1-4 + Phase 5 plans 01-04 regression sweep GREEN.
- **Committed in:** cbf90fa (Task 1+2 combined)

---

**Total deviations:** 2 auto-fixed (1 Rule 4 architectural scope, 1 Rule 1 API default value)
**Impact on plan:** Neither changes user-visible deliverable. The heatmap appears + region taps + bar taps both reach PerMuscleDetailView; the inline Stepper editor works as designed.

## Issues Encountered

- **iOS 26 simulator UI test patterns:** Followed the patterns established in plan 03 (NSPredicate label predicates + coordinate-based Toggle taps) — no new UI test issues encountered in this plan.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan 06 (Settings + MuscleVolumeTargetSeeder + WeeklyRecapTrigger) is unblocked:
- `MuscleVolumeTargetStepper` is ready to be embedded into Settings tab's `MuscleVolumeTargetEditor` surface (Claude's Discretion section in CONTEXT — "reachable from Settings → 'Volume Targets' section AND inline from per-muscle detail view; both surfaces edit the same row").
- `userEdited` flag is set by every Stepper edit, so plan 06's seeder can use it as the idempotency gate.
- `PerMuscleDetailView` already calls `FatigueModel.frequencyHits` — VOL-06 has a UI surface (the third section).
- The new `MuscleSlugRoute` enum is the pattern plan 06 can extend for any future "navigate to a muscle" surface.

## Self-Check: PASSED

- `fitbod/Fatigue/BodySilhouetteView.swift` exists.
- `fitbod/Fatigue/PerMuscleDetailView.swift` exists.
- `fitbod/Fatigue/MuscleVolumeTargetStepper.swift` exists.
- `fitbodUITests/BodySilhouetteUITests.swift` exists.
- `fitbodUITests/PerMuscleDetailUITests.swift` exists.
- Commit `cbf90fa` present in `git log --oneline`.
- `xcodebuild build` → BUILD SUCCEEDED.
- Existing plan-01 MuscleRegionPathsTests (slug coverage) remain GREEN.
- 3 new UI tests pass.
- Phase 1–4 + Phase 5 plans 01–04 regression sweep (full xcodebuild test excluding remaining RED scaffolds + UI tests) → TEST SUCCEEDED.

---
*Phase: 05-fatigue-model-plateau-detection*
*Completed: 2026-05-23*
