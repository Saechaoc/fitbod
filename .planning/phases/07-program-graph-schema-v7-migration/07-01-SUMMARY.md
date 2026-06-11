---
phase: 07-program-graph-schema-v7-migration
plan: "01"
subsystem: models
tags: [schema, dto, enum, codable, archive]
dependency_graph:
  requires: []
  provides:
    - SchedulingMode enum (consumed by Block.schedulingModeRaw in 07-02)
    - ArchivedBlockConfig DTO (consumed by migration backfill in 07-04 and block-end write in Phase 8)
  affects:
    - fitbod/Models/Enums/SchedulingMode.swift
    - fitbod/Models/ArchivedBlockConfig.swift
tech_stack:
  added: []
  patterns:
    - String rawValue enum with CaseIterable/Sendable (mirrors BlockPhaseKind/Intent pattern)
    - Codable DTO struct with nested DTOs and explicit public inits (mirrors ExportDTOs pattern)
    - iso8601 date encoding strategy on encoder and decoder
    - decode(from:) throws — no live-template fallback (T-07-01 threat mitigation)
key_files:
  created:
    - fitbod/Models/Enums/SchedulingMode.swift
    - fitbod/Models/ArchivedBlockConfig.swift
    - fitbodTests/SchedulingModeTests.swift
    - fitbodTests/ArchivedBlockConfigTests.swift
  modified: []
decisions:
  - SchedulingMode comment in file calls out the schedulingModeRaw persistence convention (not wired to Block yet — that is 07-02)
  - ArchivedExerciseDTO mirrors RoutineExercise V6 field set including intentRaw and progressionKindRaw as Strings to avoid coupling to enums
  - Verify script false-positive noted: comment text "NOT a SwiftData @Model" matches the grep pattern; all actual code criteria pass cleanly
metrics:
  duration_minutes: 3
  completed_date: "2026-06-10"
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 0
---

# Phase 7 Plan 01: SchedulingMode Enum and ArchivedBlockConfig DTO Summary

**One-liner:** SchedulingMode String enum (.rotation default) and ArchivedBlockConfig Codable DTO (v=1, iso8601, 4 nested DTOs, decode-throws on malformed JSON) as stable type contracts for the V7 rename and migration waves.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | SchedulingMode failing test | e9a750c | fitbodTests/SchedulingModeTests.swift |
| 1 (GREEN) | SchedulingMode enum | 90f9c51 | fitbod/Models/Enums/SchedulingMode.swift |
| 2 (RED) | ArchivedBlockConfig failing tests | 6b9b48f | fitbodTests/ArchivedBlockConfigTests.swift |
| 2 (GREEN) | ArchivedBlockConfig DTO | 336ce00 | fitbod/Models/ArchivedBlockConfig.swift |

## What Was Built

**SchedulingMode** (`fitbod/Models/Enums/SchedulingMode.swift`):
- `public enum SchedulingMode: String, CaseIterable, Sendable` with `.rotation` and `.fixedWeekly`
- `public static let \`default\`: SchedulingMode = .rotation` per spec §3
- No SwiftData import; persisted later as `schedulingModeRaw: String` on Block (07-02)

**ArchivedBlockConfig** (`fitbod/Models/ArchivedBlockConfig.swift`):
- Top-level envelope: `v: Int` (default 1), `blockName`, `startedAt`/`endedAt: Date`, `mode: String`, `trainingDays: [Int]`, `phases`, `split`
- `ArchivedPhaseDTO`: mirrors BlockPhase fields — `kind/weeks/volumeMultiplier/intensityMultiplier/notes`
- `ArchivedSplitDTO`: `name + slots: [ArchivedSlotDTO]`
- `ArchivedSlotDTO`: `position + sessionName + exercises: [ArchivedExerciseDTO]`
- `ArchivedExerciseDTO`: full RoutineExercise prescription mirror — `exerciseID/exerciseName/orderIndex/targetSets/targetRepsLow/targetRepsHigh/targetRPE/targetRIR/prescribedRestSeconds/tempo/notes/intentRaw/progressionKindRaw/generateWarmups/tracksTempo/tracksPartialReps`
- `encoded() throws -> Data` with `.dateEncodingStrategy = .iso8601`
- `static decode(from: Data) throws -> ArchivedBlockConfig` with `.dateDecodingStrategy = .iso8601`; throws on malformed JSON — T-07-01 mitigation

## Verification

- Parse check: both files clean (`xcrun swiftc -parse` no errors)
- All 7 acceptance criteria verified individually (file exists, Codable/Equatable/Sendable, v:Int, 4 nested DTOs, iso8601 decode, no import SwiftData, no @Model attribute)
- Note: plan's automated verify regex has a false-positive (comment text "NOT a SwiftData @Model" triggers `rg -q @Model`); all actual code criteria confirmed passing

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — these are pure type definitions; no UI data paths or placeholder values.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries beyond what the plan's threat model already covers (T-07-01 mitigated by decode-throws, T-07-02 accepted).

## Self-Check: PASSED

- `fitbod/Models/Enums/SchedulingMode.swift` — FOUND
- `fitbod/Models/ArchivedBlockConfig.swift` — FOUND
- `fitbodTests/SchedulingModeTests.swift` — FOUND
- `fitbodTests/ArchivedBlockConfigTests.swift` — FOUND
- Commits e9a750c, 90f9c51, 6b9b48f, 336ce00 — all present in git log
