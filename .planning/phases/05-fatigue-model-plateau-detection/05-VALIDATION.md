---
phase: 5
slug: fatigue-model-plateau-detection
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-22
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Sourced from RESEARCH.md §14 (Validation Architecture).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test`, `#expect`) for unit; XCTest + `XCUIApplication` for UI |
| **Config file** | None (Swift Testing bundled with Xcode 16; XCTest target `fitbodUITests/` exists) |
| **Quick run command** | `xcodebuild test -only-testing:fitbodTests/<SuiteName> -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17'` |
| **Full suite command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17'` |
| **Estimated runtime** | Quick: ~5–15s per suite. Full: ~60–120s (depends on UI test count). |

> Note: iPhone 16 simulator unavailable in this environment (per S7649/1648). Use iPhone 17 (iOS 26.4/26.5).

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -only-testing:fitbodTests/<suite-for-this-task>` (quick, ≤15s).
- **After every plan wave:** Run full suite `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17'`.
- **Before `/gsd:verify-work`:** Full suite must be green; no skipped tests; no `.disabled` annotations.
- **Max feedback latency:** 15s for per-task; 120s for per-wave.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-XX-01 | Wave 0 scaffold | 0 | VOL-02 | — | N/A | unit (RED) | `xcodebuild test -only-testing:fitbodTests/FatigueModelWeeklyVolumeTests` | ❌ W0 | ⬜ pending |
| 05-XX-02 | Wave 0 scaffold | 0 | VOL-04 | — | N/A | unit (RED) | `xcodebuild test -only-testing:fitbodTests/VolumeZoneTests` | ❌ W0 | ⬜ pending |
| 05-XX-03 | Wave 0 scaffold | 0 | VOL-04 | — | N/A | unit (RED) | `xcodebuild test -only-testing:fitbodTests/VolumeZoneVerbCopyTests` | ❌ W0 | ⬜ pending |
| 05-XX-04 | Wave 0 scaffold | 0 | VOL-06 | — | N/A | unit (RED) | `xcodebuild test -only-testing:fitbodTests/FrequencyHitsTests` | ❌ W0 | ⬜ pending |
| 05-XX-05 | Wave 0 scaffold | 0 | PROG-06 | — | N/A | unit (RED) | `xcodebuild test -only-testing:fitbodTests/PlateauDetectorTests` | ❌ W0 | ⬜ pending |
| 05-XX-06 | Wave 0 scaffold | 0 | PROG-06 | — | N/A | unit (RED) | `xcodebuild test -only-testing:fitbodTests/SuggestedActionTests` | ❌ W0 | ⬜ pending |
| 05-XX-07 | Wave 0 scaffold | 0 | PROG-06 | — | Deload-canonicality enforcement (BLOCK-08 + Pitfall #11) — `DeloadAdvisor` cannot emit a mutation type | unit (compile-time + runtime) | `xcodebuild test -only-testing:fitbodTests/DeloadAdvisorTests` | ❌ W0 | ⬜ pending |
| 05-XX-08 | Wave 0 scaffold | 0 | VOL-01 | T-05-01: user-supplied stimulus weight must be range-clamped to [0,1] | input validation on `ExerciseMuscleStimulus.weight` setter | unit (RED) | `xcodebuild test -only-testing:fitbodTests/StimulusWeightSeederTests` | ❌ W0 | ⬜ pending |
| 05-XX-09 | Wave 0 scaffold | 0 | VOL-03 | T-05-02: user-supplied MEV/MAV/MRV must be in monotonic order + clamped to [1,30] | input validation on `MuscleVolumeTarget` editor | unit (RED) | `xcodebuild test -only-testing:fitbodTests/MuscleVolumeTargetSeederTests` | ❌ W0 | ⬜ pending |
| 05-XX-10 | Wave 0 scaffold | 0 | VOL-07 | — | N/A | unit (RED) | `xcodebuild test -only-testing:fitbodTests/WeeklyRecapTriggerTests` | ❌ W0 | ⬜ pending |
| 05-XX-11 | Wave 0 scaffold | 0 | VOL-05 | — | N/A | unit (RED) | `xcodebuild test -only-testing:fitbodTests/MuscleRegionPathsTests` | ❌ W0 | ⬜ pending |
| 05-XX-12 | Wave 0 scaffold | 0 | All schema-touching reqs | — | SchemaV3→V4 lightweight migration + custom `plateauTolerance` bump preserves user-edited values | integration (in-memory ModelContainer) | `xcodebuild test -only-testing:fitbodTests/SchemaV4MigrationTests` | ❌ W0 | ⬜ pending |
| 05-XX-13 | Wave 0 scaffold | 0 | (fixtures) | — | N/A | helper (no #expect) | n/a | ❌ W0 | ⬜ pending |
| 05-XX-14 | Wave 0 scaffold | 0 | PROG-06 (sanity) | — | N/A | unit (already exists) | `xcodebuild test -only-testing:fitbodTests/FatigueAdvisoryCanonicalityTests` | ✅ Phase 4 | ⬜ pending |
| 05-XX-15 | Wave 1 | 1 | VOL-02 | — | N/A | unit (RED→GREEN) | `xcodebuild test -only-testing:fitbodTests/FatigueModelWeeklyVolumeTests` | ❌ → ✅ | ⬜ pending |
| 05-XX-16 | Wave 1 | 1 | VOL-04 | — | N/A | unit (RED→GREEN) | `xcodebuild test -only-testing:fitbodTests/VolumeZoneTests` + `VolumeZoneVerbCopyTests` | ❌ → ✅ | ⬜ pending |
| 05-XX-17 | Wave 1 | 1 | VOL-06 | — | N/A | unit (RED→GREEN) | `xcodebuild test -only-testing:fitbodTests/FrequencyHitsTests` | ❌ → ✅ | ⬜ pending |
| 05-XX-18 | Wave 2 | 2 | PROG-06 | — | N/A | unit (RED→GREEN) | `PlateauDetectorTests` + `SuggestedActionTests` | ❌ → ✅ | ⬜ pending |
| 05-XX-19 | Wave 2 | 2 | PROG-06 | T-05-03: deload-canonicality | type-level + runtime — `DeloadAdvisor` returns advisory only, never mutation | unit (RED→GREEN) | `DeloadAdvisorTests` | ❌ → ✅ | ⬜ pending |
| 05-XX-20 | Wave 3 | 3 | VOL-02, VOL-04 | — | N/A | UI test | `xcodebuild test -only-testing:fitbodUITests/VolumeBarsUITests` | ❌ → ✅ | ⬜ pending |
| 05-XX-21 | Wave 3 | 3 | VOL-05 | — | N/A | UI test | `xcodebuild test -only-testing:fitbodUITests/BodySilhouetteUITests` | ❌ → ✅ | ⬜ pending |
| 05-XX-22 | Wave 3 | 3 | VOL-05 | — | N/A | UI test | `xcodebuild test -only-testing:fitbodUITests/PerMuscleDetailUITests` | ❌ → ✅ | ⬜ pending |
| 05-XX-23 | Wave 4 | 4 | SET-05 | T-05-02 mitigation | input validation on editor Steppers (clamp + monotonic) | UI test | `xcodebuild test -only-testing:fitbodUITests/MuscleVolumeTargetEditorUITests` | ❌ → ✅ | ⬜ pending |
| 05-XX-24 | Wave 4 | 4 | SET-06 | — | N/A | UI test | `xcodebuild test -only-testing:fitbodUITests/PlateauOverrideUITests` | ❌ → ✅ | ⬜ pending |
| 05-XX-25 | Wave 4 | 4 | (Today tab) | — | N/A | UI test | `xcodebuild test -only-testing:fitbodUITests/DeloadAdvisoryBannerUITests` | ❌ → ✅ | ⬜ pending |
| 05-XX-26 | Wave 4 | 4 | VOL-07 | — | N/A | UI test | `xcodebuild test -only-testing:fitbodUITests/WeeklyRecapUITests` | ❌ → ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> Task IDs above are placeholders (`05-XX-NN`). Planner replaces `XX` with the actual plan number (`01`..`05`) when emitting PLAN.md files.

---

## Wave 0 Requirements

> Wave 0 = all RED test scaffolds + fixture helper + SchemaV4 migration tests. Every later wave's GREEN transition depends on a Wave 0 file existing.

### Unit-test scaffolds (Swift Testing)

- [ ] `fitbodTests/Fatigue/FatigueModelWeeklyVolumeTests.swift` — VOL-02 (weighted-sum, warm-up exclusion, rest-pause = 1 set, direct + indirect split)
- [ ] `fitbodTests/Fatigue/VolumeZoneTests.swift` — VOL-04 boundary tests for D-05 verbatim function (`<MEV`, `MEV..<MAV`, `MAV..<MRV`, `>=MRV`)
- [ ] `fitbodTests/Fatigue/VolumeZoneVerbCopyTests.swift` — VOL-04 D-06 verbatim copy assertions (character-for-character)
- [ ] `fitbodTests/Fatigue/FrequencyHitsTests.swift` — VOL-06 ≥2 weighted-set threshold (single 0.5 indirect does NOT count)
- [ ] `fitbodTests/Fatigue/PlateauDetectorTests.swift` — PROG-06: D-10..D-12 window/tolerance/intent-split/per-exercise-override/high-rep-suppression
- [ ] `fitbodTests/Fatigue/SuggestedActionTests.swift` — PROG-06: D-13 4-branch decision tree (`addVolume` / `dropIntensity` / `deload` / `tryVariation`)
- [ ] `fitbodTests/Fatigue/DeloadAdvisorTests.swift` — PROG-06: D-14..D-17 multi-signal OR + dismissal scope + canonicality (advisory-only, never schedules)
- [ ] `fitbodTests/Fatigue/StimulusWeightSeederTests.swift` — VOL-01: ~50 curated rows; non-curated fall back to 1.0/0.5; user-edited rows preserved across re-run (T-05-01 mitigation: weight clamped to [0,1])
- [ ] `fitbodTests/Fatigue/MuscleVolumeTargetSeederTests.swift` — VOL-03: 17-row RP seeder; user-edited rows preserved (T-05-02 mitigation: MEV<MAV<MRV monotonic + clamp [1,30])
- [ ] `fitbodTests/Fatigue/WeeklyRecapTriggerTests.swift` — VOL-07: trigger logic without UI (first-launch-new-Monday gating; zero-sessions short-circuit)
- [ ] `fitbodTests/Fatigue/MuscleRegionPathsTests.swift` — VOL-05: `MuscleRegionPaths.front` + `.back` registries contain all 17 slugs
- [ ] `fitbodTests/Persistence/SchemaV4MigrationTests.swift` — V3→V4 lightweight migration + custom `willMigrate` bumps default-valued `plateauTolerance` from 0.005 → 0.02 while preserving user-edited values

### UI-test scaffolds (XCTest + XCUIApplication)

- [ ] `fitbodUITests/VolumeBarsUITests.swift` — VOL-02 + VOL-04 (bars render w/ verb labels + delta)
- [ ] `fitbodUITests/BodySilhouetteUITests.swift` — VOL-05 (front/back render, tap → per-muscle detail)
- [ ] `fitbodUITests/PerMuscleDetailUITests.swift` — VOL-05 drill-down content
- [ ] `fitbodUITests/MuscleVolumeTargetEditorUITests.swift` — SET-05 Stepper edits write to `MuscleVolumeTarget`; "Reset to RP defaults" works
- [ ] `fitbodUITests/PlateauOverrideUITests.swift` — SET-06 Toggle ON/OFF + Stepper round-trip
- [ ] `fitbodUITests/DeloadAdvisoryBannerUITests.swift` — Today-tab dismissible banner; amber ring on bars while active; tap → signal-detail sheet
- [ ] `fitbodUITests/WeeklyRecapUITests.swift` — VOL-07 sheet on first-launch-new-Monday; no re-fire same week; no-fire when no sessions

### Fixture helpers

- [ ] `fitbodTests/Fatigue/FatigueTestFixtures.swift` — `TestFixtures.weeklySessions(forExercise:weights:reps:rpe:)` factory. Shared by every detector/advisor test for deterministic in-memory data.

### Infrastructure

- No new test framework install needed (Swift Testing + XCTest already used in Phases 1–4).
- New test groups under `fitbodTests/Fatigue/` and `fitbodTests/Persistence/` — `PBXFileSystemSynchronizedRootGroup` auto-discovers (per 1643).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Body silhouette anatomical accuracy (front + back, ~17 paths × 2 sides) | VOL-05 | Visual fidelity — Path geometry vs reference anatomy chart cannot be auto-asserted; only a human eye catches "biceps region too low / overlaps deltoid" | Build app, navigate to Today tab → Heatmap. Compare against `references/silhouette-reference.png` (UI-SPEC will source). Hit-test every muscle region by tapping — confirm correct `onTap(slug:)` fires (assertable in UI test, but visual placement is manual). |
| Heatmap color saturation curve on `.overMRV` red intensity | VOL-04 + UI-SPEC discretion item | Designer-decision territory — no objective test for "is the red dramatic enough but not garish" | Tap through Today tab; compare against UI-SPEC visual. |
| Verb-copy reading comfort across all bar sizes (long verbs on small screens) | VOL-04 | Text-wrap inspection; XCUITest can read text but cannot judge "is the wrap awkward at 280pt width" | Build, set iPhone SE 3rd gen simulator, scroll Today tab, screenshot. |
| Weekly recap sheet pacing + dismiss feel | VOL-07 | UX micro-friction is subjective | Manual on a fresh Monday or simulated via `UserDefaults.standard.removeObject(forKey:"weeklyRecapShownForWeekStart")` + relaunch. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (every ❌ in the verification map has a Wave 0 file listed above)
- [ ] No watch-mode flags (`xcodebuild test` runs once and exits — no continuous mode)
- [ ] Feedback latency: per-task ≤15s, per-wave ≤120s
- [ ] `nyquist_compliant: true` set in frontmatter once Wave 0 scaffolds land

**Approval:** pending
