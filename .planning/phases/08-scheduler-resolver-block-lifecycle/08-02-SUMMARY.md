---
phase: 08-scheduler-resolver-block-lifecycle
plan: "02"
subsystem: Periodization
tags: [training-days, calendar, locale, sort, swift-testing, tdd]
dependency_graph:
  requires: []
  provides: [TrainingDaysWriter.sort]
  affects: [Block.trainingDays write sites, Phase 9 day-chips]
tech_stack:
  added: []
  patterns: [Calendar value injection, static enum namespace]
key_files:
  created:
    - fitbod/Periodization/TrainingDaysWriter.swift
    - fitbodTests/TrainingDaysWriterTests.swift
  modified: []
decisions:
  - "Sort happens ONCE at write via injected Calendar; read is verbatim — no re-sort path exists"
  - "Calendar passed by value (copy at call time) so later locale changes cannot affect stored order"
  - "Foundation-only import in service file — no SwiftData/SwiftUI dependency"
metrics:
  duration: "2m 12s"
  completed: "2026-06-11"
  tasks_completed: 1
  files_changed: 2
---

# Phase 8 Plan 02: TrainingDaysWriter Summary

Sort-once-at-write utility with injected Calendar, pinning the locale/region-change-stability invariant required by SPEC-8-TRAININGDAYS.

## What Was Built

`TrainingDaysWriter` — a caseless `public enum` namespace in `fitbod/Periodization/` exposing a single static function:

```swift
public static func sort(weekdays: [Int], using calendar: Calendar = .current) -> [Int]
```

The function reads `calendar.firstWeekday` (1=Sun, 2=Mon per NSCalendar contract) and returns the input weekdays sorted so the locale's first day of week appears first, wrapping modulo 7. The Calendar is passed by value — a copy is captured at call time, so later region changes cannot remap an already-stored array.

## Tasks

| # | Name | Status | Commit |
|---|------|--------|--------|
| 1 | TrainingDaysWriter.sort + TrainingDaysWriterTests | Done | b69e33b (impl), 3f5306f (tests RED) |

## Deviations from Plan

None — plan executed exactly as written.

## TDD Gate Compliance

| Gate | Commit | Note |
|------|--------|------|
| RED (test) | 3f5306f | 4 failing tests; compile error confirmed TrainingDaysWriter absent |
| GREEN (feat) | b69e33b | All 4 tests pass; no refactor needed |

## Threat Coverage

| Threat ID | Mitigation | Verified |
|-----------|-----------|---------|
| T-08-03 (schedule drift via re-sort at read) | `sort` is write-only; `Block.trainingDays` getter stores/reads verbatim; `regionChangeDoesNotResort` test asserts stability | Test green |

## Self-Check: PASSED

- `fitbod/Periodization/TrainingDaysWriter.swift` exists — FOUND
- `fitbodTests/TrainingDaysWriterTests.swift` exists — FOUND
- Commit `3f5306f` (RED) exists — FOUND
- Commit `b69e33b` (GREEN) exists — FOUND
- `rg -c "@Test" fitbodTests/TrainingDaysWriterTests.swift` → 4 — FOUND
- `using calendar: Calendar = .current` in implementation — FOUND
- `firstWeekday` consulted in implementation — FOUND
- Only `import Foundation` in service file — FOUND
