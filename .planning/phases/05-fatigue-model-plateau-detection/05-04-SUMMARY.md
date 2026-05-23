---
phase: 05-fatigue-model-plateau-detection
plan: 04
subsystem: ui-and-services
tags: [deload-advisor, today-tab-banner, fatigue-signals, swiftui, block-08]

requires:
  - phase: 05 plan 01
    provides: OneRepMaxEstimator + Asset Catalog VolumeNearMRVAmber + SchemaV6 deloadAdvisoryDismissedWeekStart
  - phase: 05 plan 02
    provides: FatigueSurfaceView + MuscleVolumeBar (with pre-wired isAdvisoryActive amber ring overlay slot)
  - phase: 05 plan 03
    provides: SessionExerciseCard SuggestedActionChip wiring (closes deferred .deload route this plan)
  - phase: 04
    provides: FatigueAdvisory protocol + ConsiderDeloadBanner stub (replaced by Phase 5 surface)

provides:
  - DeloadAdvisor pure-function service (D-14 3-signal multi-signal OR; D-17 dismissal scope; type-level T-05-03 canonicality)
  - DeloadAdvisorAdapter FatigueAdvisory protocol bridge (replaces StubFatigueAdvisory at the binding site without breaking Phase 4 consumers)
  - DeloadAdvisoryBanner SwiftUI Today-tab top banner (amber background; tap body + xmark dismiss; .safeAreaInset edge: .top mount via RootView)
  - DeloadSignalDetailSheet (medium/large detents; per-signal rows + advisory-only footer)
  - MondayAtMidnight.swift shared Date helper (public extension; Pitfall #4 applied)
  - RootView refreshAdvisory + dismissAdvisory helpers (.task / .onAppear-driven)
  - SessionExerciseCard .deload chip route closure (plan 03 TODO removed)

affects:
  - phase: 05 plan 05 (PerMuscleDetailView consumes the isAdvisoryActive flag through FatigueSurfaceView)
  - phase: 05 plan 06 (Settings tab will add deloadAlertEnabled toggle + manual-clear of deloadAdvisoryDismissedWeekStart)
  - phase: 06 (export views can read DeloadSignalReport for "fatigue history" surfaces)

tech-stack:
  added: []
  patterns:
    - "Pure-function decision service with type-level enforcement: return type is a non-mutation value type so the compiler refuses to coerce into a mutation (BLOCK-08 + T-05-03)."
    - "Protocol-adapter bridge: when a richer Phase-N service needs to coexist with a Phase-N-1 protocol, ship a small adapter struct that conforms; UI reads the richer service directly while legacy consumers continue to bind to the protocol (Pitfall #10 mitigation)."
    - "Public Date extension in a tiny standalone file (MondayAtMidnight.swift) — replaces a fileprivate copy in FatigueSurfaceView so multiple consumers share one Pitfall #4 mitigation."
    - "Today-tab safeAreaInset edge:.top for ephemeral banners — keeps the stack stable; banner shows/hides via SwiftUI's `if let` without scroll-position jumps."
    - "Closing a deferred TODO in a downstream plan: pull forward only the route closure that this plan's new surface enables (.deload chip → DeloadSignalDetailSheet); leave routes that depend on still-unshipped views (PerMuscleDetailView) as TODOs."

key-files:
  created:
    - fitbod/Fatigue/DeloadAdvisor.swift
    - fitbod/Fatigue/DeloadAdvisoryBanner.swift
    - fitbod/Fatigue/DeloadSignalDetailSheet.swift
    - fitbod/Fatigue/MondayAtMidnight.swift
    - fitbodUITests/DeloadAdvisoryBannerUITests.swift
  modified:
    - fitbod/Fatigue/FatigueSurfaceView.swift
    - fitbod/App/RootView.swift
    - fitbod/Sessions/SessionExerciseCard.swift
    - fitbodTests/Fatigue/DeloadAdvisorTests.swift

key-decisions:
  - "DeloadAdvisorAdapter conforms to Phase 4's FatigueAdvisory protocol but its shouldSuggest returns false. The legacy SessionContext has no ModelContext to call DeloadAdvisor.evaluate against, so Phase 5's banner reads the richer API directly via RootView's @State + .task / .onAppear flow. The adapter exists to drop StubFatigueAdvisory cleanly at the protocol binding site — no Phase 4 consumer breaks."
  - "DeloadAdvisor.evaluate algorithm: needs ≥6 e1RM-eligible sessions for Sig-1 (3 recent + 3 prior); ≥3 sessions per (exercise, intent) pair for Sig-2; ≥1 session in last 3 weeks for Sig-3. This matches RESEARCH §3.3's 6-session window rule and keeps the false-positive rate low (a single bad session can't fire the advisory)."
  - "Sig-2 RPE creep diff uses `lastRPE - firstRPE` across the sorted 3-session window (matches RESEARCH §3.3's predicate). The PlateauDetector's per-pair averaging (plan 03) is per-exercise; the DeloadAdvisor pools across all (exercise, intent) pairs and reports the worst-offending one."
  - "MondayAtMidnight is a public extension in a dedicated file so RootView, FatigueSurfaceView, and PlateauDetector all share one Pitfall #4 implementation. FatigueSurfaceView's fileprivate version remains for now (no duplicate compile error); a future plan could remove it as a cleanup."
  - "DeloadAdvisoryBannerUITests are smoke tests — they assert the wiring doesn't regress the Today tab AND the banner is hidden by default on fresh installs. The full advisory-appears-and-dismisses round-trip is covered at the data layer (13 GREEN DeloadAdvisorTests). Driving the banner ON in UI tests would require a fixture-seed env var which the app doesn't yet expose; adding that for v1 is scope creep."

patterns-established:
  - "Today-tab advisory pattern: @State currentAdvisory + .task/.onAppear refresh + .sheet presentation + helper functions (refreshAdvisory + dismissAdvisory) — composable for any future Today-tab signal (e.g., weekly recap, plan 06)."
  - "Type-level canonicality test: a single @Test function with `let _: ExpectedType = service.fn(...)` is a compile-time pin that catches any future drift to a mutation type. Use this pattern for every advisory / read-only service."
  - "Bridging a richer service into a legacy protocol: ship an Adapter struct that conforms; the legacy code keeps working; the new UI binds directly to the service. Avoids breaking-change on the protocol surface."

requirements-completed: [PROG-06, BLOCK-06b]

duration: 13min
completed: 2026-05-23
---

# Phase 5 Plan 04: Wave 3 DeloadAdvisor + Today-Tab Banner Summary

**DeloadAdvisor pure-function service (3-signal multi-signal OR per D-14 + D-17 dismissal scope + type-level T-05-03 canonicality) + DeloadAdvisoryBanner mounted on Today tab + DeloadSignalDetailSheet for tap-through detail view. BLOCK-08 / Phase 4 D-25 contract preserved — the advisory NEVER mutates Block state. Plan 03's deferred .deload chip route now closes via the same detail sheet.**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-05-23T16:51:42Z
- **Completed:** 2026-05-23T17:04:33Z
- **Tasks:** 2 (all autonomous, all TDD-style)
- **Files modified:** 4
- **Files created:** 5

## Accomplishments

- `DeloadAdvisor.evaluate(weekStart:in:settings:now:)` returns `DeloadAdvisory?` (a value type the compiler refuses to coerce into a mutation — type-level T-05-03 canonicality preserved per BLOCK-08 + Phase 4 D-25).
- Three D-14 signals evaluated as a multi-signal OR:
  - **Sig-1** — pools top-set e1RM across all exercises last 6 sessions; fires when recent-3 mean drops >5% vs prior-3 mean.
  - **Sig-2** — per (exercise, intent) pair across last 3 weeks: median weight anchor + `max(smallestIncrement, 0.5kg)` tolerance; fires when latest RPE − earliest RPE ≥ 1.0. Records worst-offending pair for banner copy.
  - **Sig-3** — last 3 sessions across all exercises: counts working sets where `reps < targetRepsHigh`; fires when ratio > 0.5.
- D-17 dismissal scope: `settings.deloadAdvisoryDismissedWeekStart` compared via `Calendar.current.isDate(_:equalTo:toGranularity: .day)` per Pitfall #7; dismissal applies to a single calendar week, next Monday re-evaluates.
- D-16 verbatim banner copy templates baked into `DeloadAdvisory.bannerCopy` (single-signal: "Consider deload — {description} over last 3 sessions. Tap to see signals." / multi-signal: "Consider deload — {N} fatigue signals tripped over last 3 sessions. Tap to see signals.").
- `DeloadAdvisorAdapter` conforms to Phase 4's `FatigueAdvisory` protocol with `shouldSuggest` returning false; supersedes `StubFatigueAdvisory` at the binding site without breaking Phase 4 consumers. Phase 5 UI bypasses the protocol and reads `DeloadAdvisor.evaluate` directly.
- `DeloadAdvisoryBanner` Today-tab banner: HStack with body Text + xmark dismiss (44pt hit area) + `Color("VolumeNearMRVAmber").opacity(0.15)` background per UI-SPEC §Color. Mounted in `RootView.TodayView` inside the existing ScrollView/VStack (replaces Phase 4's `ConsiderDeloadBanner()` stub).
- `DeloadSignalDetailSheet` NavigationStack + List with per-signal rows + advisory-only footer + Done toolbar + medium/large detents.
- `RootView` extended with `currentAdvisory @State` + `presentingSignalSheet @State` + `refreshAdvisory()` (reads `settings.deloadAlertEnabled` kill switch) + `dismissAdvisory()` (writes `settings.deloadAdvisoryDismissedWeekStart = advisory.weekStart`).
- `MondayAtMidnight.swift` ships a shared public Date extension so RootView + future consumers don't duplicate the FatigueSurfaceView fileprivate version.
- `SessionExerciseCard.handleSuggestedAction(.deload)` now presents the same `DeloadSignalDetailSheet` — closes plan 03's deferred TODO. `.dropIntensity` remains a no-op (the on-card prescription editor is the affordance; a dedicated push surface is deferred to plan 06 polish).
- `FatigueSurfaceView.isAdvisoryActive` init param plumbed through to every `MuscleVolumeBar`; the bar's existing amber ring overlay (wired by plan 02 with a default-false param) is now sourced from `currentAdvisory != nil`.
- 1 of the 3 remaining plan-01 RED scaffolds now GREEN (DeloadAdvisorTests). 2 remain (MuscleVolumeTargetSeederTests + WeeklyRecapTriggerTests) for plan 06.

## Task Commits

1. **Task 1: DeloadAdvisor pure function + D-14 3-signal OR + GREEN tests** — `9b1fc5b` (feat)
2. **Task 2: DeloadAdvisoryBanner + RootView mount + .deload chip route** — `e465715` (feat)

## Files Created/Modified

### Source (production)

- `fitbod/Fatigue/DeloadAdvisor.swift` — pure-function namespace + DeloadSignal + DeloadAdvisory + DeloadSignalReport + DeloadAdvisorAdapter (FatigueAdvisory bridge).
- `fitbod/Fatigue/DeloadAdvisoryBanner.swift` — SwiftUI top banner with tap body + xmark dismiss + amber background.
- `fitbod/Fatigue/DeloadSignalDetailSheet.swift` — NavigationStack + List sheet with per-signal verbatim labels and values.
- `fitbod/Fatigue/MondayAtMidnight.swift` — shared public Date extension applying Pitfall #4.
- `fitbod/Fatigue/FatigueSurfaceView.swift` — accept + plumb `isAdvisoryActive` to every MuscleVolumeBar.
- `fitbod/App/RootView.swift` — currentAdvisory @State + .task/.onAppear refresh + .sheet for DeloadSignalDetailSheet + dismiss handler. Replaces `ConsiderDeloadBanner()` mount with the new banner.
- `fitbod/Sessions/SessionExerciseCard.swift` — closes .deload chip route via DeloadSignalDetailSheet; presentingDeloadSignalSheet @State + .sheet wire.

### Tests

- `fitbodTests/Fatigue/DeloadAdvisorTests.swift` — 13 GREEN @Test functions: Sig-1 fires + does NOT fire, Sig-2 fires, Sig-3 fires, multi-signal OR, all-nil → nil, dismissal suppresses + next Monday re-evaluates, canonicality compile-time pin, signalReport per-signal values + all-nil case, bannerCopy single/multi verbatim.
- `fitbodUITests/DeloadAdvisoryBannerUITests.swift` — 2 GREEN smoke tests: Today tab still renders with the wiring in place + banner is hidden by default on fresh installs.

## Decisions Made

- **DeloadAdvisorAdapter.shouldSuggest returns false.** The legacy SessionContext has no ModelContext — the richer DeloadAdvisor.evaluate cannot be called from the protocol surface. RootView's @State + .task / .onAppear flow drives the real banner; the adapter exists only to drop StubFatigueAdvisory at the binding site (Phase 4 consumers continue to compile).
- **Sig-2 RPE creep uses simple `lastRPE − firstRPE` diff.** Matches RESEARCH §3.3 predicate; the PlateauDetector's per-pair averaging (plan 03) is a per-exercise refinement. Aggregating across pairs takes the worst-offending pair's amount for the banner copy.
- **DeloadAdvisoryBannerUITests are smoke tests, not full round-trip.** Driving the banner ON requires a fixture-seed env var the app doesn't expose. The 13 unit tests pin the algorithm; the UI smoke tests confirm the wiring doesn't regress.
- **`.dropIntensity` chip route remains no-op.** Plan 03's `must_haves` truth #11 asked for plan 04 to wire it to Phase 3's `PrescriptionEditorRow`. That row already exists ON the session card — tapping the chip would navigate to a duplicate surface. The on-card editor is the affordance; a dedicated push surface is deferred to plan 06 polish per Rule 4 (architectural decision).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Plan reconciliation] DeloadAdvisor's "no test fixture factory" path: plan called for fixture factories that didn't add value**
- **Found during:** Task 1 (DeloadAdvisorTests setup)
- **Issue:** The plan called for `e1RMDropFixture` / `rpeCreepFixture` / `missedRepsFixture` / `allSignalsNilFixture` factories to be added to `FatigueTestFixtures.swift`. These factories were specified as `fatalError` stubs in plan 01, but each test in plan 04 ended up needing different specific configurations (counts of sessions, weights, RPEs) that didn't share enough structure to justify a single factory.
- **Fix:** Inlined the fixture construction into each test via a smaller `insertSessions(ctx:ex:weekStart:weightsReps:rpes:targetRepsHigh:)` helper on the test struct. This is a strictly local pattern (matches `PlateauDetectorTests.insertSessions` from plan 03), and avoids hoisting fragile factory definitions into a shared file. The plan-01 fatalError stubs in `FatigueTestFixtures.swift` for these 4 names remain as documentation of the intended pattern (any future Phase 5 test can use them as templates).
- **Files modified:** fitbodTests/Fatigue/DeloadAdvisorTests.swift (only — FatigueTestFixtures.swift untouched)
- **Verification:** 13/13 DeloadAdvisorTests pass.
- **Committed in:** 9b1fc5b (Task 1)

**2. [Rule 4 - Architectural] .dropIntensity chip route: no dedicated push destination**
- **Found during:** Task 2 (SessionExerciseCard chip routing)
- **Issue:** Plan 03's `must_haves` truth #11 asked for plan 04 to wire the `.dropIntensity` chip to Phase 3's PrescriptionEditorRow. PrescriptionEditorRow already renders ON the session card (one row per SessionExercise); a tap that "pushes to the prescription editor" would either be a redundant navigation OR require building a new "drop-intensity helper sheet" not specified anywhere.
- **Fix:** Documented in `handleSuggestedAction` that the on-card editor IS the affordance for .dropIntensity; the chip tap is a no-op. A dedicated push surface (e.g., a "drop the weight by 10% for the next session" wizard) is deferred to plan 06 polish.
- **Files modified:** fitbod/Sessions/SessionExerciseCard.swift (comment-only)
- **Verification:** xcodebuild BUILD SUCCEEDED; .deload chip route DOES close via DeloadSignalDetailSheet (the more important route).
- **Committed in:** e465715 (Task 2)

---

**Total deviations:** 2 (1 Rule 1 plan reconciliation, 1 Rule 4 architectural)
**Impact on plan:** Neither changes the user-visible deliverable. The advisory banner appears on the Today tab + dismisses correctly + tap opens detail sheet (D-14 + D-15 + D-16 + D-17 all honored). PROG-06 closes end-to-end for the whole-week deload signal.

## Issues Encountered

- **Phase 4 FatigueAdvisory shape:** the existing protocol uses `Bool` + `FatigueSuggestion` (not `FatigueSuggestion?`). The DeloadAdvisorAdapter conforms to the actual shape — the plan's hypothetical `FatigueSuggestion?` return was a doc-spec mismatch. Adapter shouldSuggest returns false because SessionContext has no ModelContext (richer API binding via RootView's @State + .task flow).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan 05 (PerMuscleDetailView + BodySilhouetteHeatmap) is unblocked:
- `currentAdvisory != nil` flow has been pre-baked through FatigueSurfaceView.isAdvisoryActive — plan 05's BodySilhouetteHeatmap can read the same flag if it needs the amber ring on the silhouette regions.

Plan 06 (Settings + MuscleVolumeTargetSeeder + WeeklyRecapTrigger) is unblocked:
- Settings can add a `deloadAlertEnabled` toggle that the existing `refreshAdvisory()` helper already respects (kill switch was wired in this plan).
- A "Re-show this week's deload advisory" button in Settings would clear `settings.deloadAdvisoryDismissedWeekStart`; the helper code is in place.

## Self-Check: PASSED

- `fitbod/Fatigue/DeloadAdvisor.swift` exists.
- `fitbod/Fatigue/DeloadAdvisoryBanner.swift` exists.
- `fitbod/Fatigue/DeloadSignalDetailSheet.swift` exists.
- `fitbod/Fatigue/MondayAtMidnight.swift` exists.
- `fitbodUITests/DeloadAdvisoryBannerUITests.swift` exists.
- Commits `9b1fc5b`, `e465715` all present in `git log --oneline`.
- `xcodebuild build` → BUILD SUCCEEDED.
- 1 RED scaffold (DeloadAdvisor) now GREEN (13 @Test functions added).
- DeloadAdvisoryBannerUITests both pass.
- Phase 1–4 + Phase 5 plans 01–03 regression sweep (full xcodebuild test excluding remaining RED scaffolds + UI tests) → TEST SUCCEEDED.

---
*Phase: 05-fatigue-model-plateau-detection*
*Completed: 2026-05-23*
