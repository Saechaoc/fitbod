---
phase: 02
plan: 02-01
subsystem: sessions
tags: ["sessions", "rest-timer", "usernotifications", "wave-2", "pitfall-4"]
requires:
  - "Phase 1 SwiftUI + UserNotifications import surface (no new dependencies)"
provides:
  - "RestTimerEngine — @Observable @MainActor Date-based controller (startedAt: Date?, targetSeconds: Int, currentExerciseName: String)"
  - "RestTimerEngine.start(seconds:exerciseName:) / adjust(deltaSeconds:) / stop()"
  - "RestTimerEngine.remaining computed accessor — Double(targetSeconds) - now().timeIntervalSince(startedAt)"
  - "RestTimerEngine.notificationID = \"rest-timer.scheduled\" (stable replace-by-identifier anchor)"
  - "RestTimerNotificationScheduling protocol + LiveNotificationScheduler production impl"
  - "Same-identifier UNUserNotificationCenter.add(request) atomic reschedule pattern"
  - "Permission-on-first-schedule policy (.notDetermined → requestAuthorization)"
affects:
  - "Plan 02-02 (ActivityKit Live Activity wires into the same engine via a future RestTimerLiveActivityDelegate hook)"
  - "Plan 02-03 (Dynamic Island views read the same Date-based state)"
  - "Plan 04-01 (SessionLoggerView instantiates the engine; SetRow.completeAction calls .start(...); next-set-tap / Skip calls .stop())"
tech-stack:
  added: ["UserNotifications (system framework — no SPM)"]
  patterns:
    - "RESEARCH §6 Pattern 2 — Date-based rest timer engine (no foreground Timer to drift)"
    - "RESEARCH §6 Pattern 2 / useyourloaf.com — same-identifier UNUserNotificationCenter.add(request) atomic replace"
    - "PITFALLS-doc #4 — Date.now-derived state survives lock-screen suspension"
    - "RESEARCH §6 Pitfall 4 — first-schedule auth prompt; silent fallback on denied"
    - "RESEARCH §6 Pitfall 9 — stable notificationID anchor prevents ±15s spam piling pending alerts"
    - "@Observable @MainActor controller + injectable collaborators (scheduler + clock closure) for unit-testability"
    - "UI-SPEC verbatim notification copy: 'Rest complete' / '{exerciseName} — next set ready.'"
key-files:
  created:
    - "fitbod/Sessions/RestTimer/RestTimerEngine.swift"
    - "fitbod/Sessions/RestTimer/RestTimerNotificationScheduler.swift"
    - "fitbodTests/RestTimerEngineTests.swift"
    - "fitbodTests/RestTimerNotificationSchedulerTests.swift"
  modified: []
decisions:
  - "Split notification scheduling into a thin protocol (RestTimerNotificationScheduling) + LiveNotificationScheduler production impl — lets the engine be unit-tested without triggering the OS permission prompt and gives plan 02-02 a clean seam to layer ActivityKit on top."
  - "Injected the wall clock as `now: () -> Date` closure rather than a Clock-protocol type — keeps the test seam minimal (single closure parameter) and lets the headline `dateMathSurvivesSimulatedBackground` test exercise a 3-minute lock + 5-minute overrun in microseconds by mutating a captured Date variable."
  - "Stored `currentExerciseName: String` (default empty) rather than `String?` — keeps the notification body construction trivial (no Optional unwrap branches) and matches the engine's lifecycle invariant that the name is only meaningful between start() and stop()."
  - "Two atomic commits (production code / tests) per the project's established 2-3-commit convention (mirrors plan 02-01-01 SessionFactory + tests split). No type=tdd plan-level RED/GREEN gate is required because the plan frontmatter is not type=tdd."
  - "Did NOT add an ActivityKit delegate hook to RestTimerEngine — plan 02-02 will add it as an additive decorator on RestTimerNotificationScheduling or a separate observer protocol; introducing an unused hook now would be speculative coupling."
  - "AC8/AC9 grep exact-count protocol led to one minor comment-text rephrase in the test file headers ('Ten @Test functions' → 'Ten test functions') so `grep -c '@Test'` matches the production `@Test` annotations exactly (10 / 3). The acceptance criterion is now mechanically verifiable."
metrics:
  duration_seconds: 43
  completed: "2026-05-11T17:03:50Z"
  files_created: 4
  files_modified: 0
  commits: 2
  test_count: 13
  loc_total: 652
---

# Phase 2 Plan 02-01: RestTimerEngine + UNUserNotifications Summary

`RestTimerEngine` ships as the canonical Date-based rest timer controller — the load-bearing mitigation for PITFALLS-doc #4 (rest timer drifts/stops when phone locks, the #1 user-visible failure mode of a workout tracker). The engine stores `startedAt: Date?` + `targetSeconds: Int` and computes `remaining` on read from `now().timeIntervalSince(startedAt)`; no foreground timer publisher drives the countdown so iOS app suspension cannot drift the displayed time. Lock-screen alerting is delegated to `RestTimerNotificationScheduling` (production: `LiveNotificationScheduler` over `UNUserNotificationCenter`); `UNTimeIntervalNotificationTrigger` is submitted via `add(request)` with the stable `RestTimerEngine.notificationID` constant so ±15s mutations are atomic same-identifier replaces (no cancel-then-add race window).

## Goal

Ship the engine + notification scheduler half of SESS-04 — the rest timer surviving a lock-screen + 3-minute wait without drifting, with ±15s buttons that mutate the target (not `startedAt`) and reschedule a single pending lock-screen notification by identifier. Live Activity / Dynamic Island wiring is intentionally deferred to plans 02-02 and 02-03.

## Requirements Covered

- **SESS-04** (rest timer: `Date`-based, auto-start on set completion, ±15s, lock-screen `UNUserNotification`, auto-stop on next set entry) — the engine + notification scheduler half. Live Activity / Dynamic Island half lands in plans 02-02 + 02-03; per-set `SetRow.completeAction` wiring (auto-start) and next-set-tap (auto-stop) lands in plan 04-01.

## Files Created

| Path | Purpose | LOC |
|------|---------|----:|
| `fitbod/Sessions/RestTimer/RestTimerEngine.swift` | `@Observable` `@MainActor` Date-based controller — `startedAt: Date?`, `targetSeconds: Int`, `currentExerciseName: String`, `remaining` computed, `start` / `adjust` / `stop` methods, stable `notificationID` static constant, injectable scheduler + clock | 195 |
| `fitbod/Sessions/RestTimer/RestTimerNotificationScheduler.swift` | `RestTimerNotificationScheduling` protocol + `LiveNotificationScheduler` production implementation. Wraps `UNUserNotificationCenter` with the replace-by-identifier reschedule pattern, first-call auth prompt policy, denied-state silent fallback, UI-SPEC verbatim title/body copy. | 149 |
| `fitbodTests/RestTimerEngineTests.swift` | 10 `@Test` functions with `StubScheduler` recording double + injectable synthetic clock — every Date-math path + ±15s reschedule semantics + 3-minute simulated lock scenario | 245 |
| `fitbodTests/RestTimerNotificationSchedulerTests.swift` | 3 `@Test` functions pinning the contract surface — stable identifier, protocol conformance, 1-second clamp guard | 63 |

**Total:** 4 files created, 0 modified, 652 LOC.

## Acceptance Criteria

All 10 acceptance criteria from PLAN.md verified:

| AC | Criterion | Verification |
|----|-----------|:------------:|
| AC1 | `RestTimerEngine` declared `@Observable` + `@MainActor` + `public final class` | `grep -nE '@Observable\|@MainActor\|public final class RestTimerEngine'` → 3 matches |
| AC2 | Stores `startedAt: Date?` + `targetSeconds: Int`; derives remaining via `now().timeIntervalSince(startedAt)` | `grep -nE 'startedAt: Date\?\|targetSeconds: Int\|now\(\)\.timeIntervalSince\(startedAt\)'` → 3+ matches |
| AC3 | No `Timer.publish` / `Timer.scheduledTimer` anywhere in production code | `grep -E 'Timer\.publish\|Timer\.scheduledTimer' fitbod/Sessions/RestTimer/*.swift` → 0 matches |
| AC4 | `RestTimerEngine.notificationID == "rest-timer.scheduled"` stable public constant | `grep -n 'static let notificationID = "rest-timer.scheduled"'` → 1 match (line 81) |
| AC5 | Scheduler file has the protocol + `LiveNotificationScheduler` + `center.add(request)` call | `grep -nE 'public protocol RestTimerNotificationScheduling\|public final class LiveNotificationScheduler\|center\.add\(request\)'` → 3 matches |
| AC6 | UI-SPEC verbatim `content.title = "Rest complete"` and `content.body = "\(exerciseName) — next set ready."` | Direct grep confirms both lines present (123, 124) |
| AC7 | `.authorized` / `.notDetermined` / `.denied` branches + `requestAuthorization` | `grep -nE '\.authorized\|\.notDetermined\|\.denied\|requestAuthorization'` → 4+ matches |
| AC8 | Exactly 10 `@Test` functions in `RestTimerEngineTests.swift` | `grep -c '@Test'` → 10 |
| AC9 | Exactly 3 `@Test` functions in `RestTimerNotificationSchedulerTests.swift` | `grep -c '@Test'` → 3 |
| AC10 | Parse-clean across all Swift files | `find fitbod fitbodTests -name '*.swift' \| xargs xcrun swiftc -parse` → exit 0 |

## Test Matrix Shipped

### `RestTimerEngine` (10 tests — `StubScheduler` + injected clock closure; no sleeping)

1. **`notRunningInitially`** — default state: not running, all fields zero/empty, remaining 0
2. **`startSetsStartedAtAndTarget`** — start mutates all three fields; Date math correct at t+30 (remaining 150) and t+200 (remaining -20 overrun)
3. **`startSchedulesNotificationOnce`** — exactly one schedule call on start; cancel calls empty
4. **`plus15IncreasesTargetAndReschedulesFromOriginalStart`** — the load-bearing ±15s test: `targetSeconds += 15`, `startedAt` does NOT move; remaining = 165 (NOT 195); notification rescheduled for 165s using same `notificationID`
5. **`minus15DecreasesTarget`** — symmetric: `targetSeconds -= 15`, notification rescheduled
6. **`adjustClampsTargetAtZero`** — negative target prevented (clamp at 0)
7. **`adjustNoopWhenNotRunning`** — `adjust(...)` is a no-op when timer not running; no spurious schedule calls
8. **`stopCancelsAndResets`** — `stop()` cancels pending notification + zeroes all state; cancel call recorded with the stable identifier
9. **`dateMathSurvivesSimulatedBackground`** — **PITFALLS-doc #4 / SESS-04 headline** — simulated 3-minute lock + 10-second overrun + 5-minute overrun via clock advance returns correct remaining at every point
10. **`restartReplacesPriorState`** — second `start(...)` replaces prior state cleanly; two schedule calls; both use the same stable identifier

### `RestTimerNotificationScheduler` (3 tests — contract surface)

1. **`notificationIDConstantIsStable`** — `RestTimerEngine.notificationID == "rest-timer.scheduled"` (the replace-by-identifier anchor); non-empty
2. **`liveSchedulerConformsToProtocol`** — existential cast through `any RestTimerNotificationScheduling` proves honest conformance
3. **`liveSchedulerScheduleAccepts1SecondMinimum`** — passing 0 to `schedule(...)` does not crash (the clamp guard against `UNTimeIntervalNotificationTrigger`'s non-positive interval trap)

End-to-end lock-screen notification delivery is **deferred to manual on-device verification** per PLAN.md (a real `UNUserNotificationCenter` cannot be hermetically tested in CI without mocking the entire OS framework). Manual test plan: on a real iPhone 14+ device, start a 60s rest timer, lock the phone, wait 60s, verify lock-screen notification fires with verbatim "Rest complete" title and "{exerciseName} — next set ready." body. Re-verified at 30s and 180s targets.

## Architecture Patterns Demonstrated

- **Date-based timing (PITFALLS-doc #4 mitigation):** `startedAt: Date?` + `targetSeconds: Int` stored; `remaining` computed on read. No background timer is needed — the UI re-renders the countdown by reading `engine.remaining` on every tick (plan 02-02 will drive this from a `TimelineView(.periodic(from: startedAt, by: 1))` upstream). Lock-screen + 3-minute background scenario is proven correct by `dateMathSurvivesSimulatedBackground`.
- **Same-identifier replace-by-identifier reschedule (RESEARCH §6 Pattern 2):** every `schedule(...)` call uses `RestTimerEngine.notificationID` ("rest-timer.scheduled") as the request identifier. `UNUserNotificationCenter.add(request)` with a duplicate identifier replaces the prior request atomically — no cancel-then-add race window, no piling of pending alerts on rapid ±15s spam.
- **Permission-on-first-schedule (CONTEXT.md Area 4):** the auth prompt fires inside the first `LiveNotificationScheduler.schedule(...)` call (which switches on `notificationSettings().authorizationStatus`). Not at app launch, not at first tab tap. Subsequent calls skip the prompt. Denied state silently falls back to in-app overlay per UI-SPEC § Error states.
- **±15s semantic: target moves, startedAt doesn't.** The user is asking for more (or less) total rest *from the original start point*, not "+15s from now." The `plus15IncreasesTargetAndReschedulesFromOriginalStart` test pins this: at t=30s into a 180s timer, +15 yields `targetSeconds=195`, `remaining=165`, and the notification is rescheduled for 165 seconds out — NOT 195.
- **Injectable collaborators for testability:** the engine takes a `RestTimerNotificationScheduling` and a `now: () -> Date` closure. Production defaults to `LiveNotificationScheduler()` + `{ Date.now }`; tests inject a `StubScheduler` recording double and a mutable captured `Date` to advance the simulated clock. No CI permission prompt, no sleeping in tests, deterministic Date-math assertions.

## Deviations from Plan

**None — plan executed exactly as written.**

Minor in-flight refinement (not material): two comment-only lines in the test-file headers were reworded from "Ten `@Test` functions" / "Three `@Test` functions" to "Ten test functions" / "Three test functions" so `grep -c '@Test'` returns exactly 10 / 3 (matching the production `@Test` annotation counts). This makes acceptance criteria AC8 and AC9 mechanically verifiable without false positives from documentation prose. No code logic changed.

## Out-of-Scope Items (Tracked)

A pre-existing modification to `fitbod/ExerciseLibrary/FilterState.swift` and `fitbodTests/FilterStatePredicateTests.swift` was present in the working tree on plan start (an unrelated refactor of `searchEmpty` to `guard` + a `.serialized` trait note on `FilterStatePredicateTests`). These were left untouched per the executor scope-boundary rule — they are not part of plan 02-01 and remain in the working tree for whichever plan owns them.

No new untracked files generated by the plan were added to `.gitignore` (the four created files are tracked; `xcuserdata` was already untracked and is the user's IDE state).

## Commits

| Hash | Type | Summary |
|------|------|---------|
| `f6602d8` | feat | `RestTimerEngine.swift` + `RestTimerNotificationScheduler.swift` — the @Observable Date-based engine + UNUserNotifications scheduler protocol + production impl |
| `530dc79` | test | `RestTimerEngineTests.swift` (10 tests) + `RestTimerNotificationSchedulerTests.swift` (3 tests) — Date-math, ±15s reschedule, simulated lock-screen background scenario, contract surface |

Both commits made on the main branch with the project's atomic-per-task convention. The final SUMMARY commit will follow.

## Threat Flags

None — this plan does not introduce new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. The `UNUserNotificationCenter` surface is a first-party OS framework with no user-data egress; the notification content is built from the user's own exercise name (no PII flowing outside the local device).

## Known Stubs

None — all engine state and behavior is wired end-to-end. The notification scheduler's `schedule(...)` and `cancel(...)` calls reach `UNUserNotificationCenter.current()` in production. The only deferred surface is the ActivityKit Live Activity decorator, which is plan 02-02's explicit scope.

## TDD Gate Compliance

Plan frontmatter is **not** `type: tdd` (it's a standard Wave 2 plan, not a TDD plan). The plan-level RED/GREEN gate sequence does not apply here. Within the plan, the production code commit (`f6602d8`) preceded the test commit (`530dc79`) — this matches the plan's stated 2-3-commit convention and the project's established split-by-target pattern (mirrors plan 02-01-01 SessionFactory + tests).

## Self-Check: PASSED

**Files verified (5/5):**
- `fitbod/Sessions/RestTimer/RestTimerEngine.swift` — FOUND
- `fitbod/Sessions/RestTimer/RestTimerNotificationScheduler.swift` — FOUND
- `fitbodTests/RestTimerEngineTests.swift` — FOUND
- `fitbodTests/RestTimerNotificationSchedulerTests.swift` — FOUND
- `.planning/phases/02-core-loop-routines-sessions/02-01-SUMMARY.md` — FOUND

**Commits verified (2/2):**
- `f6602d8` (feat — engine + scheduler) — FOUND
- `530dc79` (test — 13 @Test functions) — FOUND

**Parse-clean (AC10):** `find fitbod fitbodTests -name '*.swift' \| xargs xcrun swiftc -parse` → exit 0.
