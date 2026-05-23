---
phase: 06
plan: 09
slug: export-dtos-and-envelope
status: complete
completed: 2026-05-23
wave: 3
type: execute
requirements: ["EXP-02"]
depends_on: ["06-02"]
tech_stack:
  added: []
  patterns:
    - "Codable DTO graph mirroring SchemaV6 — pure value types, no SwiftData coupling"
    - "Schema-versioned envelope with canonicalSchemaVersion = 'v6' constant"
    - "Shared JSONEncoder.exportConfigured() (.prettyPrinted + .sortedKeys + .withoutEscapingSlashes + .iso8601)"
    - "Golden-file snapshot test pattern — fixture regen-and-fail on first run; byte-equal compare thereafter"
key_files:
  created:
    - fitbod/Export/ExportDTOs.swift
    - fitbodTests/Phase6/ExportDocumentSnapshotTests.swift
    - fitbodTests/Phase6/Fixtures/json/example-export.json
  modified: []
decisions:
  - "schemaVersion = 'v6' (NOT 'v2' from CONTEXT D-28). Plan landed AFTER Phase 5 closed SchemaV6 (5 schema bumps since CONTEXT was written); v6 is the honest current value. Contract preserved: single string constant exposed via ExportDocument.canonicalSchemaVersion."
  - "17 DTOs total (1 envelope + 16 entity DTOs). Adds ExportPlateInventoryDTO + ExportRoutineFolderDTO + ExportSupersetGroupDTO + ExportExerciseMuscleStimulusDTO above the CONTEXT D-28 baseline of 11 entities to cover Phase 3 + 4 + 5 schema additions (PlateInventory + RoutineFolder + SupersetGroup + ExerciseMuscleStimulus + Block.reviewedAt + new UserSettings fields)."
  - "Empty-string-for-nil-exercise convention adopted (Open Question 2). ExportSessionExerciseDTO.exerciseID: UUID? = nil + exerciseName: String = '' when SessionExercise.exercise is nullified (post-delete cascade). Documented in file-header; 06-07 + 06-09b + 06-10 downstream consumers inherit the convention."
  - "Encoder configuration co-located with DTO definitions (JSONEncoder.exportConfigured() extension inside ExportDTOs.swift) so 06-09b JSONExporter + 06-09b snapshot tests + 06-10 BackupArchiver all reuse one source of truth."
metrics:
  duration_minutes: ~7 (work shipped in stream-recovery commit c8072a8; this plan only writes the SUMMARY)
  tasks_completed: 2
  files_created: 3
  files_modified: 0
  commits: 2
---

# Phase 6 Plan 06-09: ExportDTOs + ExportDocument Envelope Summary

Ship the Codable DTO graph + `ExportDocument` envelope that both the JSON export (06-09b) and the backup archive (06-10) consume. Locked the canonical `schemaVersion` constant + the shared `JSONEncoder.exportConfigured()` so downstream plans never duplicate encoder configuration.

## Overview

This plan shipped the data-shape contract for every Phase 6 export surface. The DTOs are plain Codable value types — not @Model classes — to keep the on-disk JSON stable independent of SwiftData migrations. The envelope's `canonicalSchemaVersion = "v6"` constant is the only schema-version source-of-truth the backup restore-side schema-skew check compares against (06-10 reads it).

The byte-stable golden-snapshot fixture (`fitbodTests/Phase6/Fixtures/json/example-export.json`, 6112 bytes) is committed and tested via `ExportDocumentSnapshotTests`. The two @Test functions cover both structural invariants (formatVersion / schemaVersion / ISO-8601 `Z` suffix / sorted-keys ordering) and byte-equal comparison against the committed fixture.

## Implementation

### Architecture decisions

**Schema versioning:** The plan literal `"v2"` (from CONTEXT D-28, written when SchemaV2 was the runtime version) was replaced with `"v6"` to be honest about the current SchemaV6 runtime. The CONTRACT — a single string constant exposed via `ExportDocument.canonicalSchemaVersion` — is preserved verbatim. The restore-side schema-skew check in 06-10 will compare against this constant unchanged.

**DTO coverage expansion (CONTEXT baseline → reality):** CONTEXT D-28 listed 11 entity types. The shipped envelope covers 16 entity DTOs because Phase 3 + 4 + 5 added entities not present at CONTEXT time:

| Entity | Source phase |
|--------|--------------|
| RoutineFolder | Phase 2 (already shipped) |
| SupersetGroup | Phase 2 (already shipped) |
| ExerciseMuscleStimulus | Phase 1 (already shipped) |
| PlateInventory | Phase 3 (already shipped) |
| Block.reviewedAt | Phase 4 (additive field on ExportBlockDTO) |
| UserSettings new fields | Phase 5 (frequencyHitMinSets, deloadAdvisoryDismissedWeekStart, weeklyRecapShownForWeekStart) |

**DTO name collision (RESEARCH §"DTO name collision"):** `fitbod/ExerciseLibrary/ExerciseDTO.swift` already declares `ExerciseDTO` for the free-exercise-db seed pipeline. All Phase 6 export DTOs are prefixed `Export` (e.g., `ExportExerciseDTO`) to avoid the collision.

**Empty-string convention for nil exercise (Open Question 2 deferred):** When `SessionExercise.exercise == nil` (post-delete cascade-nullify per RESEARCH Pitfall 11), `ExportSessionExerciseDTO.exerciseID` is `nil` and `exerciseName` is `""`. v1 pragmatic — a future restore-side cleanup pass can re-link or prune orphans. Documented in the file-header so 06-07 + 06-09b + 06-10 downstream consumers inherit the same contract.

### Files created

#### `fitbod/Export/ExportDTOs.swift` (587 lines)
- 1 envelope: `ExportDocument` with formatVersion (Int) + schemaVersion (String) + exportedAt (Date) + unitSystem (String) + 11 per-entity arrays + userSettings?: ExportUserSettingsDTO
- 16 entity DTOs: `ExportExerciseDTO`, `ExportRoutineDTO`, `ExportRoutineExerciseDTO`, `ExportRoutineExerciseSetOverrideDTO`, `ExportRoutineFolderDTO`, `ExportSupersetGroupDTO`, `ExportSessionDTO`, `ExportSessionExerciseDTO`, `ExportSetEntryDTO`, `ExportBlockDTO`, `ExportBlockPhaseDTO`, `ExportMuscleGroupDTO`, `ExportExerciseMuscleStimulusDTO`, `ExportMuscleVolumeTargetDTO`, `ExportPlateInventoryDTO`, `ExportUserSettingsDTO`
- All DTOs: `public struct ... : Codable, Equatable, Sendable` with `let` properties + public memberwise init
- Nested ownership: ExportSessionDTO embeds [ExportSessionExerciseDTO]; ExportSessionExerciseDTO embeds [ExportSetEntryDTO]; ExportRoutineDTO embeds [ExportRoutineExerciseDTO]; ExportRoutineExerciseDTO embeds [ExportRoutineExerciseSetOverrideDTO]; ExportBlockDTO embeds [ExportBlockPhaseDTO]
- Non-owning refs (Exercise→SessionExercise, MuscleGroup→ExerciseMuscleStimulus) emit UUID references only
- `JSONEncoder.exportConfigured()` extension co-located: `.prettyPrinted + .sortedKeys + .withoutEscapingSlashes + .iso8601`
- `ExportDocument.canonicalSchemaVersion = "v6"` static constant

#### `fitbodTests/Phase6/ExportDocumentSnapshotTests.swift` (299 lines)
- `@MainActor @Suite("ExportDocument JSON snapshot (EXP-02 envelope)") struct ExportDocumentSnapshotTests`
- Private `static func makeFixture()` constructs a deterministic ExportDocument: hand-fixed UUIDs `00000000-0000-0000-0000-0000000000{01..11}` + fixed `Date(timeIntervalSince1970: 1_700_000_000)` + exactly one of each top-level entity type
- `@Test invariants()`: encodes via `JSONEncoder.exportConfigured()`, decodes via JSONSerialization; asserts formatVersion == 1, schemaVersion == "v6", exportedAt has "Z" suffix; verifies sorted-keys ordering (`"exercises"` appears before `"exportedAt"` appears before `"formatVersion"` in raw bytes)
- `@Test goldenSnapshotMatch()`: locates fixture via `#filePath` ascent; on empty fixture writes generated + fails with re-run guidance; otherwise byte-equal compares. Includes graceful skip when fixture path unreachable (defensive for non-host test runners).

#### `fitbodTests/Phase6/Fixtures/json/example-export.json` (6112 bytes)
- Byte-stable snapshot of the deterministic ExportDocument fixture
- Pretty-printed, sorted-keys, ISO-8601 UTC dates, no escaped slashes
- Committed as the byte-source-of-truth for the golden snapshot test

### Verification

**Both @Test functions PASS:**
```
Test case 'ExportDocumentSnapshotTests/invariants()' passed (0.242 seconds)
Test case 'ExportDocumentSnapshotTests/goldenSnapshotMatch()' passed (0.242 seconds)
```

**Build:** `xcodebuild -project fitbod.xcodeproj -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17' build` → BUILD SUCCEEDED.

**Field-mapping verification (real SchemaV6 field names — RESEARCH §"Schema reality vs CONTEXT"):**
- `setTypeRaw` (not `setKind`)
- `weight` / `reps` / `rpe` (not `actualWeight` / `actualReps` / `actualRPE`)
- `completedAt` (not `performedAt`)
- `intentRaw` lives on `Session` (Phase 3.1 PIVOT-02), NOT on `SessionExercise`
- `wasManualOverride` field IS present on `SetEntry` (Phase 3 forward-compat) — included for round-trip completeness

### Deviations from Plan

**1. [Rule 1 - Schema reality] schemaVersion bumped 'v2' → 'v6'**
- **Found during:** Initial DTO graph construction
- **Issue:** CONTEXT D-28 wrote "v2" as the canonical version string. By the time this plan landed, Phase 1→5 had bumped through SchemaV3→V4→V5→V6 with multiple migrations.
- **Fix:** Replaced the literal "v2" with "v6" (matching current runtime); preserved the constant's contract (single string typed source-of-truth via ExportDocument.canonicalSchemaVersion).
- **Files modified:** fitbod/Export/ExportDTOs.swift (canonicalSchemaVersion constant + file-header doc-block)
- **Commit:** c8072a8

**2. [Rule 2 - Entity coverage expansion] 11 → 16 entity DTOs**
- **Found during:** Schema audit against current SchemaV6
- **Issue:** CONTEXT D-28 baseline of 11 entities did not enumerate every SchemaV6 @Model. RoutineFolder, SupersetGroup, ExerciseMuscleStimulus, PlateInventory are persistent entities the user would want round-tripped.
- **Fix:** Added 5 additional Export*DTO declarations to cover the full SchemaV6 surface area.
- **Files modified:** fitbod/Export/ExportDTOs.swift (5 additional structs + envelope adds 4 new array fields)
- **Commit:** c8072a8

**Auth gates:** None.

### Known Stubs

None.

## Deferred Items

- **Open Question 2 — `SessionExercise.exerciseSnapshotName: String?` field:** Deferred to Phase 6 follow-up (or v2). v1 emits empty-string for nil-exercise rows; this convention is documented in ExportDTOs.swift file-header and inherited by 06-07 (PR row "no exercise name" path) and 06-10 (backup-restore orphan tolerance).

## Commit SHAs

- **`c8072a8`** — `docs(06): summaries for Plans 06-01..06-05 + Export scaffold from stream-timeout recovery` — shipped the ExportDTOs.swift + ExportDocumentSnapshotTests.swift + example-export.json fixture (snapshot test passes on first run because fixture was generated and committed in the same commit).

## Self-Check: PASSED

Files exist:
- FOUND: fitbod/Export/ExportDTOs.swift
- FOUND: fitbodTests/Phase6/ExportDocumentSnapshotTests.swift
- FOUND: fitbodTests/Phase6/Fixtures/json/example-export.json

Commits exist:
- FOUND: c8072a8 (containing all three files above)

Verification commands:
- `xcodebuild test -only-testing:fitbodTests/ExportDocumentSnapshotTests` → 2/2 @Test PASS
- `grep -c 'canonicalSchemaVersion = "v6"' fitbod/Export/ExportDTOs.swift` → 1
- `grep -c 'extension JSONEncoder' fitbod/Export/ExportDTOs.swift` → 1
