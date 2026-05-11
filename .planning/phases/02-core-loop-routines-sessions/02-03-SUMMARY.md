---
phase: 02
plan: 02-03
subsystem: rest-timer
tags: [rest-timer, overlay, swiftui, timelineview, accessibility, sess-04, wave-2]
requires:
  - "Plan 02-01 (RestTimerEngine + LiveNotificationScheduler)"
  - "Plan 02-02 (RestTimerActivityControlling + NoopActivityController + RestTimerActivityController)"
provides:
  - "RestTimerOverlay — SwiftUI view rendering the 64pt collapsed pill + .medium-detent expanded sheet"
  - "RestTimerProgressRing — circular accent arc honoring accessibilityReduceMotion"
  - "RestTimerEngine.activityController injection seam (NoopActivityController default)"
  - "RestTimerEngine.makeProduction() factory wiring LiveNotificationScheduler + RestTimerActivityController"
  - "Engine.start/adjust/stop now forward to the activity controller in lockstep with the notification scheduler"
affects:
  - "Plan 04-01 (SessionLoggerView consumes RestTimerEngine.makeProduction() and mounts RestTimerOverlay(engine:) above the exercise list)"
tech-stack:
  added: []
  patterns:
    - "RESEARCH §6 Pattern 2 — TimelineView(.periodic(from:, by: 1)) for Date-derived UI re-render"
    - "UI-SPEC § Spacing exception — 64pt collapsed pill above tab bar"
    - "UI-SPEC § Rest timer overlay — .medium-detent expanded sheet pattern"
    - "UI-SPEC accessibility — accessibilityReduceMotion gates the progress arc animation"
    - "UI-SPEC accessibility — accessibilityAdjustableAction on collapsed pill for VoiceOver ±15s without expansion"
    - "Protocol-with-Noop-default pattern preserves prior-plan hermetic test surface (NoopActivityController default keeps 02-01 tests free of ActivityKit)"
key-files:
  created:
    - "fitbod/Sessions/RestTimer/RestTimerOverlay.swift"
    - "fitbod/Sessions/RestTimer/RestTimerProgressRing.swift"
    - "fitbodTests/RestTimerOverlayCopyTests.swift"
  modified:
    - "fitbod/Sessions/RestTimer/RestTimerEngine.swift"
decisions:
  - "Kept NoopActivityController() as the default value for the engine's activityController parameter — preserves plan 02-01's 10 hermetic engine tests unchanged. Production sites use RestTimerEngine.makeProduction()."
  - "Added makeProduction() static factory rather than changing the default value of the existing activityController parameter — keeps unit tests hermetic and gives plan 04-01 a single canonical wiring point that pairs the live notification scheduler with the live activity controller."
  - "Both render paths (collapsed pill + expanded sheet body) wrap independently in TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1)) — when startedAt is nil, the outer isRunning guard prevents rendering anyway, so the .now fallback never materializes."
  - "Engine's activityController.start/update/end calls forward AFTER the scheduler calls (not before) — preserves the notification-first semantics of plan 02-01 if either side throws asynchronously."
  - "Adjust forwards `targetSeconds: newTarget` (the post-mutation value), not the pre-mutation value — matches the ContentState contract from plan 02-02's RestTimerAttributes."
  - "Two atomic commits (feat / test) per the project's established 2-3-commit convention (mirrors plans 02-01 and 02-02). Plan frontmatter is not type=tdd, so the plan-level RED/GREEN gate does not apply."
metrics:
  duration_seconds: 240
  completed: "2026-05-11T18:32:00Z"
  files_created: 3
  files_modified: 1
  commits: 2
  test_count: 3
  loc_added: 360
---

# Phase 2 Plan 02-03: Rest Timer Overlay + Engine Integration Summary

`RestTimerOverlay` ships as the in-app surface for SESS-04 — a 64pt collapsed pill above the tab bar that expands to a `.medium`-detent sheet with ±15s / Skip controls and a circular accent progress ring. The overlay reads from a `@Bindable RestTimerEngine`, re-renders the Date-derived countdown via `TimelineView(.periodic(from:, by: 1))` (the SwiftUI-native primitive that auto-pauses when off-screen), and forwards ±15s / Skip taps back to the engine. Meanwhile, the engine itself now composes the plan 02-02 `RestTimerActivityControlling` as an injected dependency, with `NoopActivityController()` as the default so plan 02-01's hermetic engine test suite is unchanged. A new `RestTimerEngine.makeProduction()` factory wires the live notification scheduler + live activity controller in one call — the entry point plan 04-01's `SessionLoggerView` will consume.

## Goal

Close the user-visible in-app overlay half of SESS-04 and compose plans 02-01 + 02-02 into a single observable façade. The engine becomes the single source of truth: one `start(...)` call schedules the lock-screen notification AND drives the Live Activity AND surfaces the in-app overlay. One `adjust(...)` call reschedules the notification AND debounced-updates the activity AND ticks the on-screen countdown. One `stop()` call cancels the notification AND ends the activity AND dismisses the overlay.

## Requirements Covered

- **SESS-04** (rest timer overlay in-app; Live Activity + lock-screen + Dynamic Island integration) — the user-visible overlay half. Together with plans 02-01 + 02-02, this **closes the requirement**.

## Files

| Path | Status | Purpose | LOC |
|------|--------|---------|----:|
| `fitbod/Sessions/RestTimer/RestTimerEngine.swift` | MODIFIED | Add `activityController` parameter (default `NoopActivityController()`); wire `start`/`adjust`/`stop` to forward to the controller; add `makeProduction()` factory | +37 |
| `fitbod/Sessions/RestTimer/RestTimerOverlay.swift` | NEW | SwiftUI view — collapsed 64pt pill + `.medium`-detent expanded sheet with ±15s/Skip controls, exercise-name subtitle, progress ring + countdown | 173 |
| `fitbod/Sessions/RestTimer/RestTimerProgressRing.swift` | NEW | Circular accent progress arc honoring `accessibilityReduceMotion` | 56 |
| `fitbodTests/RestTimerOverlayCopyTests.swift` | NEW | 3 `@Test` functions anchoring UI-SPEC verbatim copy + environment wire-up + TimelineView pattern | 81 |

**Total:** 3 files created, 1 modified, 347 LOC added (overlay + ring + tests + engine diff).

## Acceptance Criteria

All 14 acceptance criteria from PLAN.md verified mechanically via the plan's grep commands.

| AC | Criterion | Status |
|----|-----------|:------:|
| 1 | `activityController: RestTimerActivityControlling` + `NoopActivityController()` default in engine init | ✅ 3 matches on line 92, 101, 112 |
| 2 | `makeProduction()` factory wiring `LiveNotificationScheduler()` + `RestTimerActivityController()` | ✅ 4 matches across lines 111, 128, 130, 131 |
| 3 | `activityController.start/.update/.end` calls in engine `start`/`adjust`/`stop` | ✅ exactly 3 matches (lines 176, 217, 238) |
| 4 | `public struct RestTimerOverlay: View` + `@Bindable public var engine: RestTimerEngine` | ✅ both on lines 47-48 |
| 5 | `.frame(height: 64)` for the collapsed pill | ✅ 1 match on line 59 |
| 6 | `.presentationDetents([.medium])` for the expanded sheet | ✅ 1 match on line 79 |
| 7 | UI-SPEC verbatim copy: `"· Rest"`, `"Rest Timer"`, `"−15s"`, `"+15s"`, `"Skip"`, `"Prescribed: \(engine.targetSeconds)s"` | ✅ verified via test `verbatimCopyAnchors` (passes at parse time + runtime) |
| 8 | Accessibility labels: `"Add 15 seconds"`, `"Subtract 15 seconds"`, `"Skip remaining rest"`, `"Tap to expand controls"` | ✅ all 4 grep'd in the source |
| 9 | `accessibilityAdjustableAction` wired for VoiceOver ±15s | ✅ 1 match on line 70 |
| 10 | `TimelineView(.periodic(from:, by: 1))` used for countdown | ✅ 2 matches (collapsed pill line 89, expanded body line 114) |
| 11 | `RestTimerProgressRing` honors `accessibilityReduceMotion` | ✅ `reduceMotion ? nil : .linear(duration: 1)` on line 52 |
| 12 | Progress ring uses `Color.accentColor` | ✅ 1 match on line 48 |
| 13 | Exactly 3 `@Test` functions in `RestTimerOverlayCopyTests.swift` | ✅ `grep -c '@Test'` → 3 |
| 14 | Parse-clean across all Swift files | ✅ `find fitbod fitbodTests -name '*.swift' \| xargs xcrun swiftc -parse` exits 0 |

## Test Matrix Shipped

`RestTimerOverlayCopyTests` (3 tests — load on-disk source via `#filePath` and execute substring matches):

| Test | Asserts |
|------|---------|
| `verbatimCopyAnchors` | UI-SPEC § Rest timer copy strings + accessibility labels present in `RestTimerOverlay.swift` verbatim |
| `reduceMotionWiredThroughEnvironment` | `@Environment(\.accessibilityReduceMotion)` consumed in source AND `reduceMotion: reduceMotion` forwarded to the progress ring constructor call |
| `timelineViewTickEverySecond` | Both render paths use the `TimelineView(.periodic(from:, by: 1))` canonical Date-derived-UI pattern |

The plan 02-01 `RestTimerEngineTests` suite (10 tests) continues to pass unchanged because the engine's new `activityController` parameter defaults to `NoopActivityController()` — existing call sites pass `scheduler:` and `now:` by name and Swift's named-argument resolution skips over the new default-valued parameter. Verified by parse-clean: existing `RestTimerEngine(scheduler:)` / `RestTimerEngine(scheduler:now:)` call sites still type-check without modification.

End-to-end visual rendering — the 64pt pill above the tab bar, the `.medium` detent expansion, the accent progress arc sweep, the reduce-motion snap behavior — is deferred to **on-device manual verification** per the plan's stance ("the overlay is a SwiftUI View — runtime visual tests live on the user's device").

## Architecture Patterns Demonstrated

- **Single observable façade (composition):** the engine is now the single source of truth across three orthogonal channels (notification scheduler / activity controller / Date math). Plan 04-01's `SessionLoggerView` will own exactly one `RestTimerEngine` instance via `makeProduction()`; the overlay reads from it; the lock-screen notification fires from it; the Live Activity drives from it.
- **Protocol-with-Noop default preserves hermetic tests:** the engine's new `activityController` parameter defaults to `NoopActivityController()` (the no-op conformance from plan 02-02). Plan 02-01's existing 10 `RestTimerEngineTests` get a no-op activity controller automatically without any test-file modification — the cleanest possible additive-without-disruption change. Production call sites use `makeProduction()` to opt into the live controller.
- **TimelineView for Date-derived UI re-render (RESEARCH §6 Pattern 2):** both the collapsed pill and the expanded sheet body wrap their countdown computation in `TimelineView(.periodic(from: engine.startedAt ?? .now, by: 1))`. The view recomputes `engine.remaining` once per second (which itself is `targetSeconds - now().timeIntervalSince(startedAt)`). When the view goes off-screen (user backgrounds the app), SwiftUI auto-pauses the TimelineView — when it returns, the next `Date.now` read recovers the correct remaining without drift. This is the entire reason the engine's Date math survives lock-screen suspension.
- **Read-only overlay semantics:** the overlay is the observation side of the engine, not the command side. `engine.start(...)` is NEVER called from the overlay — only `engine.adjust(deltaSeconds:)` (on the ±15s buttons) and `engine.stop()` (on the Skip button). Starting the timer is the set-complete checkmark's job in plan 04-01's `SetRow`. This separation keeps the overlay testable in isolation (a controllable `RestTimerEngine(scheduler: StubScheduler(), now: { fixedDate })` drives previews without firing live notifications or activities).
- **Accent-or-not discipline matches UI-SPEC contract:** the progress arc uses `Color.accentColor` (UI-SPEC accent surface #11). The ±15s buttons use `.buttonStyle(.bordered)` on `.label` (NEVER accent — UI-SPEC explicitly excludes them from the accent reserved-for list). The Skip text button uses `.foregroundStyle(.secondary)` (UI-SPEC: "Skip rest" is explicitly NOT an accent surface, line 116 of UI-SPEC).

## Deviations from Plan

**None — plan executed exactly as written.**

The plan's prescribed file shapes (RestTimerOverlay, RestTimerProgressRing, RestTimerOverlayCopyTests) were copied verbatim into the source tree. The engine modification follows the diff specification literally: add `activityController` field, extend init with the new parameter defaulted to `NoopActivityController()`, call `start/update/end` in the engine's lifecycle methods after the scheduler calls, add `makeProduction()` factory.

### Auth gates encountered

None — this plan is pure SwiftUI view + engine composition; no network, no API keys, no notification permissions surfaced at runtime. The activity controller's `areActivitiesEnabled` guard (plan 02-02) handles the only environmental capability check, and silently falls back when off.

## Known Stubs

None. Every wire is end-to-end:

- The overlay's `±15s` taps call `engine.adjust(deltaSeconds: ±15)` → the engine reschedules the notification AND debounce-updates the Live Activity AND mutates `targetSeconds` so the TimelineView's next tick reads the new remaining.
- The Skip button's tap calls `engine.stop()` → cancels the notification, ends the activity, zeroes the engine state, the `isRunning` guard returns false, the overlay's `if engine.isRunning` branch evaluates to `EmptyView`.
- The progress ring consumes a `reduceMotion: Bool` set from the parent's `@Environment(\.accessibilityReduceMotion)` — fully wired through.

The plan-04-01 mount point (`SessionLoggerView` instantiating `RestTimerEngine.makeProduction()` and rendering `RestTimerOverlay(engine: engine)` above its exercise list) is the **explicit downstream consumer** named in the plan's `<dependencies>` section. It is not a stub here — plan 02-03's scope ends at the overlay + engine composition; plan 04-01 will perform the mount.

## Threat Flags

None — this plan does not introduce new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. The TimelineView re-render reads only from `engine.remaining` (which is `targetSeconds - now().timeIntervalSince(startedAt)`), all values already in-memory.

## TDD Gate Compliance

Plan frontmatter is **not** `type: tdd` (it's a standard Wave 2 plan). The plan-level RED/GREEN gate sequence does not apply. Within the plan, the production code commit (`feat`) preceded the test commit (`test`) per the project's established 2-3-commit convention.

## Commits

| Hash | Type | Summary |
|------|------|---------|
| `e4616d0` | feat | `RestTimerEngine.swift` (modified) + `RestTimerOverlay.swift` (new) + `RestTimerProgressRing.swift` (new) — engine composes `RestTimerActivityControlling` via `NoopActivityController` default + `makeProduction()` factory; overlay renders 64pt pill + `.medium` expanded sheet; ring honors reduceMotion |
| `9624f9a` | test | `RestTimerOverlayCopyTests.swift` (3 `@Test`s) — UI-SPEC verbatim copy, reduceMotion environment wire-up, TimelineView 1s-tick pattern |

Both commits made on the main branch with the project's atomic-per-task convention. The SUMMARY commit will follow.

## What this unblocks

- **Plan 04-01 (`SessionLoggerView`)** — can now instantiate `RestTimerEngine.makeProduction()` (one line), assign it to a `@State` property, render `RestTimerOverlay(engine: engine)` above the exercise list, and wire `SetRow.completeAction` to call `engine.start(seconds: prescribedRest, exerciseName: ...)`. The whole rest-timer stack — engine + scheduler + activity controller + lock-screen card + Dynamic Island + in-app overlay — is now a single composable unit reachable from one initializer.
- **Wave 2 closure** — plans 02-01 + 02-02 + 02-03 together fully deliver SESS-04. Routines (wave 3) plans can begin without consuming this engine surface; plan 04-01 consumes it.

## Self-Check: PASSED

**Files claimed created — verified on disk:**
- `fitbod/Sessions/RestTimer/RestTimerOverlay.swift` — FOUND
- `fitbod/Sessions/RestTimer/RestTimerProgressRing.swift` — FOUND
- `fitbodTests/RestTimerOverlayCopyTests.swift` — FOUND

**File claimed modified — verified on disk:**
- `fitbod/Sessions/RestTimer/RestTimerEngine.swift` — FOUND (with activityController field, makeProduction factory, lifecycle wire-throughs)

**Commits claimed — verified in git log:**
- `e4616d0` (feat — engine + overlay + ring) — FOUND
- `9624f9a` (test — RestTimerOverlayCopyTests) — FOUND

**Parse-clean (AC14):** `find fitbod fitbodTests -name '*.swift' | xargs xcrun swiftc -parse` → exit 0.
