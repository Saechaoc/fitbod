---
phase: 6
slug: progress-views-export-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-22
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from 06-RESEARCH.md §"Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test`, `#expect`) for unit/integration; XCTest with `XCUIApplication` for any UI smoke (deferred — personal-app voice, single eye on UI). |
| **Config file** | Xcode test plan `fitbod/fitbodTests/fitbodTests.swift` (existing target) |
| **Quick run command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests/Phase6 -quiet` |
| **Full suite command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~25–40 seconds for Phase 6 quick suite (in-memory `ModelContainer`, no haptics, no animation waits); ~3–4 min full suite |

Notes:
- All math kernels (`OneRepMax`, `PRDetector`, `WeeklyTonnageAggregator`, `SessionComparator`) are pure functions — tests do not require a `ModelContainer` and run in <100ms aggregate.
- Backup round-trip suite (D-33) uses `ModelConfiguration(isStoredInMemoryOnly: true)` per test — no on-disk pollution.
- Export/import suites operate on in-memory `Data` blobs, no filesystem I/O.

---

## Sampling Rate

- **After every task commit:** Run quick suite for the task's plan (e.g., `-only-testing:fitbodTests/Phase6/OneRepMaxTests`)
- **After every plan wave:** Run full Phase 6 quick suite (`-only-testing:fitbodTests/Phase6`)
- **Before `/gsd:verify-work`:** Full app test suite must be green
- **Max feedback latency:** 60 seconds (per-task quick run on M-series Mac; iPhone simulator boots cold once per session)

---

## Per-Task Verification Map

> Planner fills in concrete Task IDs once PLAN.md files exist. Skeleton structure below maps each requirement to the verification type research recommends. The exact `Task ID` column (`6-NN-MM`) will be back-filled after planner completes.

| Requirement | Plan (provisional) | Wave | Verification Type | Test Surface | Notes |
|-------------|--------------------|------|-------------------|--------------|-------|
| PROG-01 (intent-split chart) | 06-02 ExerciseProgressView | 2 | snapshot/unit | `ExerciseProgressViewModel` predicate composition + series builder | Pure-function reducer over fixture `SetEntry` array; no SwiftUI render in unit tests. |
| PROG-02 (e1RM Brzycki/Epley) | 06-01 Math Kernel | 1 | parameterized unit | `OneRepMaxTests` | `@Test(arguments: zip([weights], [reps], [expected]))` — grid covers reps 1..15, edge cases reps=0/negative, suppression boundary at 10/11. |
| PROG-03 (top-set vs avg toggle) | 06-02 ExerciseProgressView | 2 | unit | `SeriesBuilder` | Two pure functions: `topSetSeries(_:)`, `avgSetSeries(_:)`. Equality on emitted `(Date, Double)` arrays. |
| PROG-04 (weekly tonnage sliceable) | 06-03 WeeklyTonnage | 2 | unit + fixture | `WeeklyTonnageAggregator`, `MuscleVolumeProvider` | Test both `UnweightedMuscleVolumeProvider` (Phase 6 fallback) and the protocol contract for the future Phase 5 stimulus-weighted variant. |
| PROG-05 (PRs view per exercise) | 06-04 PRDetector | 1 | unit | `PRDetectorTests` | Test each PR kind (weight, reps, volume, e1RM) per intent, per rep-bucket. Tie-break by date. |
| PROG-07 (session comparison) | 06-05 SessionComparison | 2 | unit + integration | `SessionComparator` predicate + 14-day window | In-memory ModelContainer test — seed two sessions, assert match by `(routine, exercise, intent)` triple per research §"D-22 correction". |
| PROG-08 (live PR banner) | 06-06 InSessionPRBanner | 2 | unit + manual | `PRDetector.check(set:)` returns expected `Set<PRKind>`; banner UX manual-verified. | Pure-function detection covered by tests; SwiftUI banner animation + haptic require manual smoke. |
| EXP-01 (CSV export) | 06-07 CSVExport | 3 | snapshot | `CSVExporter` produces byte-stable output for a fixture dataset | Golden-file snapshot at `Tests/Fixtures/csv/example-export.csv`; RFC 4180 quoting verified per-cell. |
| EXP-02 (JSON export) | 06-08 JSONExport | 3 | snapshot | `JSONExporter` produces byte-stable output for a fixture dataset | `.sortedKeys` ensures stable serialization; golden-file snapshot. |
| EXP-03 (backup file) | 06-09 Backup | 4 | unit + integration | `BackupArchiver` writes manifest + store.json + images/; checksum verifies | In-memory `Data`-blob ZIP/AppleArchive round-trip; no real filesystem. |
| EXP-04 (restore + round-trip) | 06-09 Backup, 06-10 Restore | 4 | acceptance (MUST-PASS per ROADMAP) | `BackupRoundTripTests.test_export_wipe_restore_equality` | Seed → export → fresh in-memory container → restore → entity-by-entity equality (DTO `Equatable`). This is the canary for the entire phase. |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `fitbodTests/Phase6/Fixtures/SessionFixtures.swift` — factory for seeded `Session` / `SessionExercise` / `SetEntry` graphs (multi-intent, multi-rep-range, multi-week) for math-kernel and aggregator tests
- [ ] `fitbodTests/Phase6/Fixtures/PRFixtures.swift` — known-PR-history fixture with hand-computed expected `PRKind` sets
- [ ] `fitbodTests/Phase6/Fixtures/csv/example-export.csv` — golden CSV snapshot
- [ ] `fitbodTests/Phase6/Fixtures/json/example-export.json` — golden JSON snapshot
- [ ] `fitbodTests/Phase6/Support/InMemoryContainer.swift` — helper that returns a fresh `ModelContainer(for: SchemaV2.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))` per test (extend the existing Phase 1 pattern at `fitbod/Persistence/PreviewModelContainer.swift`)
- [ ] No new framework install — Swift Testing is built into Xcode 16+ toolchain (per CLAUDE.md tech stack)

*If existing Phase 2/3 fixture helpers can be reused, prefer extension over duplication.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| In-session PR banner appearance animation | PROG-08 | SwiftUI transition + haptic timing not deterministic in unit test | Start a session, log a set that beats the prior PR, observe banner slides in from top, success haptic fires, auto-dismisses at 5s. |
| `ShareLink` → share sheet flow | EXP-01, EXP-02, EXP-03 | iOS share sheet is OS-owned; no automation surface | Trigger Export CSV / Export JSON / Create Backup, verify share sheet appears with `AirDrop`, `Files`, `Save to Files`, `iCloud Drive` destinations. |
| Restore destructive confirmation | EXP-04 | UX flow correctness; partial automation possible | Select a `.fitbodbackup`, verify two-step confirmation alert "This will replace all current data..." appears, verify cancel preserves state, verify confirm wipes and restores. |
| Chart interactions (tap to drill, scrub) | PROG-01, PROG-04 | SwiftUI gesture system needs human eyes | Tap a weekly-tonnage bar → drills to that week's session list; pinch to zoom on per-exercise chart works. |
| `reduce motion` accessibility | D-35 | Requires settings toggle | Enable Reduce Motion in iOS Settings, verify PR banner and chart toggles use opacity-only transitions (no slide). |

*All math, aggregation, export encoding, and round-trip behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (fixtures, in-memory container helper, golden snapshots)
- [ ] No watch-mode flags (Xcode test runs once, exits)
- [ ] Feedback latency < 60s (per-plan quick suite)
- [ ] `nyquist_compliant: true` set in frontmatter once planner back-fills Task IDs and the planner-check pass confirms coverage

**Approval:** pending
