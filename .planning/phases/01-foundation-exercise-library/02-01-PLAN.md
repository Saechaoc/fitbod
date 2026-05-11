---
phase: 01
plan: 02-01
wave: 2
slug: vendor-exercise-dataset
complexity: M
requirements: ["LIB-01", "LIB-06"]
covers_pitfalls: ["#2 in RESEARCH (don't decode JSON into @Model)"]
depends_on: ["01-03"]
files_modified:
  - fitbod/Resources/ExerciseSeed/exercises.json  # NEW (vendored, ~1 MB)
  - fitbod/Resources/ExerciseSeed/SEED_VERSION.txt  # NEW (plain text "1")
  - fitbod/Resources/ExerciseSeed/SOURCE.md  # NEW (provenance + commit pin + license)
  - fitbod/ExerciseLibrary/ExerciseDTO.swift  # NEW
  - fitbod/ExerciseLibrary/EquipmentMapper.swift  # NEW (dataset string → canonical Equipment)
  - fitbod/ExerciseLibrary/MuscleRegionMap.swift  # NEW (17 slugs → MuscleRegion)
  - fitbodTests/DTODecodingTests.swift  # NEW
  - fitbod.xcodeproj/project.pbxproj  # add JSON + TXT as bundle resources
created: 2026-05-10
---

# Plan 02-01 — Vendor Exercise Dataset

> **Wave 2 / Sequence 1.** Vendors the `yuhonas/free-exercise-db` JSON into the app target as a bundle resource, defines the `ExerciseDTO` Codable struct, the canonical `Equipment` mapping table, the 17-muscle → 3-region map, and the decoding tests. Sets up everything the `@ModelActor` importer needs in plan `02-02`.

## Goal

Add the strength-filtered exercise dataset to the app bundle along with the DTO layer that decodes it. No SwiftData writes yet — that's plan `02-02`. After this plan, `JSONDecoder().decode([ExerciseDTO].self, from: bundledData)` works and the equipment + region mapping tables are unit-tested.

## Requirements Covered

- **LIB-01** (data source): The `yuhonas/free-exercise-db` JSON (Unlicense, public domain) is vendored at `fitbod/Resources/ExerciseSeed/exercises.json`. The pbxproj registers it as a bundle resource.
- **LIB-06** (equipment mapping): `EquipmentMapper.swift` maps the dataset's 12+ raw `equipment` string values to the 9-case canonical `Equipment` enum. Verified by `DTODecodingTests/equipmentMappingCovered`.

## Files to Create / Modify

### Create — Resources

1. `fitbod/Resources/ExerciseSeed/exercises.json` — fetch from `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json` at a commit-pinned SHA (planner records SHA in `SOURCE.md`). File size: ~1.5 MB pre-filter.

   **Filter-at-build-time approach (recommended):** The bundled file is the *full* dataset; the runtime filter to `category ∈ {strength, powerlifting, olympic weightlifting, strongman}` happens in the importer (plan `02-02`). This keeps the bundled artifact byte-for-byte traceable to upstream and shifts the filter logic into the testable importer.

   **Alternative considered + rejected:** Pre-filter at vendor time. Rejected because it makes future dataset refreshes harder to validate (have to diff against a filtered subset).

2. `fitbod/Resources/ExerciseSeed/SEED_VERSION.txt` — single line containing `1` (no trailing newline). This is the version stamp checked by `ExerciseLibraryImporter.seedIfNeeded()`. Bumping it to `2` triggers re-seed. Phase 1 only handles the empty-to-full transition.

3. `fitbod/Resources/ExerciseSeed/SOURCE.md` — provenance / attribution file (not bundled, lives in repo for git history):
   ```markdown
   # Exercise Seed Source

   - **Repository:** https://github.com/yuhonas/free-exercise-db
   - **Commit SHA:** <pinned at vendor time — record exact 40-char SHA>
   - **Vendored on:** 2026-05-10
   - **License:** The Unlicense (public domain) — no attribution required.
   - **File:** `dist/exercises.json` → bundled at `fitbod/Resources/ExerciseSeed/exercises.json`
   - **SEED_VERSION.txt:** Local stamp; bump to trigger re-seed via
     `UserDefaults["exercise_seed_version"]`.

   ## Refresh procedure

   1. `curl https://raw.githubusercontent.com/yuhonas/free-exercise-db/<NEW_SHA>/dist/exercises.json -o fitbod/Resources/ExerciseSeed/exercises.json`
   2. Update commit SHA + date in this file.
   3. Bump `SEED_VERSION.txt` from N to N+1.
   4. Run `xcodebuild test -only-testing:fitbodTests/DTODecodingTests`.
   5. Future phases may add a delta-migration; Phase 1 only handles empty-to-full.
   ```

### Create — Production code

4. `fitbod/ExerciseLibrary/ExerciseDTO.swift`:
   ```
   import Foundation

   /// Decoded shape of one row from yuhonas/free-exercise-db/dist/exercises.json.
   /// Maps to `@Model Exercise` in ExerciseLibraryImporter — NOT a @Model itself.
   struct ExerciseDTO: Codable, Equatable, Sendable {
       let id: String              # e.g. "Barbell_Bench_Press"
       let name: String
       let force: String?          # "static" | "pull" | "push" | nil
       let level: String           # "beginner" | "intermediate" | "expert"
       let mechanic: String?       # "isolation" | "compound" | nil
       let equipment: String?      # 12+ values; collapsed by EquipmentMapper
       let primaryMuscles: [String]
       let secondaryMuscles: [String]
       let instructions: [String]
       let category: String        # "strength" | "powerlifting" | "olympic weightlifting" | "strongman" | "cardio" | "stretching" | "plyometrics"
       let images: [String]
   }
   ```

5. `fitbod/ExerciseLibrary/EquipmentMapper.swift`:
   ```
   import Foundation

   enum EquipmentMapper {
       /// Maps dataset's raw equipment string → canonical Equipment enum.
       /// Per RESEARCH § Dataset Schema Mapping → Equipment mapping table.
       static func map(_ raw: String?) -> Equipment {
           guard let raw, !raw.isEmpty else { return .other }
           switch raw.lowercased() {
           case "barbell":                     return .barbell
           case "dumbbell":                    return .dumbbell
           case "cable":                       return .cable
           case "machine":                     return .machine
           case "bands":                       return .bands
           case "body only":                   return .bodyweight
           case "kettlebells":                 return .kettlebell
           case "e-z curl bar":                return .barbell    # collapse
           case "medicine ball",
                "exercise ball",
                "foam roll":                   return .other
           default:                            return .other       # null / unknown
           }
       }

       /// Categories accepted into the seed (strength-only filter).
       static let acceptedCategories: Set<String> = [
           "strength", "powerlifting", "olympic weightlifting", "strongman"
       ]

       static func shouldImport(category: String) -> Bool {
           acceptedCategories.contains(category.lowercased())
       }
   }
   ```

6. `fitbod/ExerciseLibrary/MuscleRegionMap.swift`:
   ```
   import Foundation

   enum MuscleRegionMap {
       /// 17-muscle dataset taxonomy → 3-region buckets per RESEARCH Open Q #3.
       static func region(for slug: String) -> MuscleRegion {
           switch slug.lowercased() {
           case "chest", "lats", "middle back", "lower back",
                "traps", "shoulders", "biceps", "triceps",
                "forearms", "neck":
               return .upper
           case "quadriceps", "hamstrings", "glutes", "calves",
                "abductors", "adductors":
               return .lower
           case "abdominals":
               return .core
           default:
               return .upper                  # safe default
           }
       }

       /// Canonical display-name for a slug. Dataset uses lowercased slugs;
       /// we present title-cased.
       static func displayName(for slug: String) -> String {
           switch slug.lowercased() {
           case "lats":         return "Lats"
           case "lower back":   return "Lower Back"
           case "middle back":  return "Middle Back"
           default:             return slug.capitalized
           }
       }
   }
   ```

### Create — Tests

7. `fitbodTests/DTODecodingTests.swift`:
   ```
   import Testing
   import Foundation
   @testable import fitbod

   @Suite("ExerciseDTO decoding")
   struct DTODecodingTests {
       @Test("Bundled exercises.json decodes")
       func decodesBundled() throws {
           let url = try #require(Bundle.main.url(forResource: "exercises", withExtension: "json"))
           let data = try Data(contentsOf: url)
           let dtos = try JSONDecoder().decode([ExerciseDTO].self, from: data)
           #expect(dtos.count > 0, "Dataset should contain at least 1 exercise")
       }

       @Test("Strength filter retains ≥600 exercises")
       func strengthFilter() throws {
           let url = try #require(Bundle.main.url(forResource: "exercises", withExtension: "json"))
           let data = try Data(contentsOf: url)
           let dtos = try JSONDecoder().decode([ExerciseDTO].self, from: data)
           let strengthOnly = dtos.filter { EquipmentMapper.shouldImport(category: $0.category) }
           #expect(strengthOnly.count >= 600, "Strength-only filter should retain at least 600 exercises (typical: ~800)")
       }

       @Test("SEED_VERSION.txt is readable")
       func seedVersionBundled() throws {
           let url = try #require(Bundle.main.url(forResource: "SEED_VERSION", withExtension: "txt"))
           let stamp = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
           #expect(Int(stamp) == 1, "Phase 1 vendored at SEED_VERSION=1")
       }

       @Test("Equipment mapping covers known dataset values",
             arguments: [
                 ("barbell", Equipment.barbell),
                 ("dumbbell", Equipment.dumbbell),
                 ("cable", Equipment.cable),
                 ("machine", Equipment.machine),
                 ("bands", Equipment.bands),
                 ("body only", Equipment.bodyweight),
                 ("kettlebells", Equipment.kettlebell),
                 ("e-z curl bar", Equipment.barbell),
                 ("medicine ball", Equipment.other),
                 ("", Equipment.other),
             ] as [(String, Equipment)])
       func equipmentMappingCovered(raw: String, expected: Equipment) {
           #expect(EquipmentMapper.map(raw) == expected)
       }

       @Test("Region map handles all 17 dataset slugs")
       func regionMapCovers17() {
           let allSlugs = [
               "abdominals", "abductors", "adductors", "biceps", "calves", "chest",
               "forearms", "glutes", "hamstrings", "lats", "lower back", "middle back",
               "neck", "quadriceps", "shoulders", "traps", "triceps"
           ]
           for slug in allSlugs {
               let region = MuscleRegionMap.region(for: slug)
               #expect([.upper, .lower, .core].contains(region))
           }
           #expect(MuscleRegionMap.region(for: "abdominals") == .core)
           #expect(MuscleRegionMap.region(for: "quadriceps") == .lower)
           #expect(MuscleRegionMap.region(for: "chest") == .upper)
       }
   }
   ```

### Modify

8. `fitbod.xcodeproj/project.pbxproj` — register the new resources:
   - Add `fitbod/Resources/ExerciseSeed/exercises.json` as a `PBXFileReference` and include it in `PBXResourcesBuildPhase` for the `fitbod` target.
   - Add `fitbod/Resources/ExerciseSeed/SEED_VERSION.txt` the same way.
   - `SOURCE.md` is NOT added to the bundle (it's a developer-facing note).

   Approach: open in Xcode, drag the `ExerciseSeed/` folder into the project navigator under `fitbod > Resources`, select "Create groups" + "Add to targets: fitbod". This generates the correct pbxproj edits automatically.

## Acceptance Criteria

1. `fitbod/Resources/ExerciseSeed/exercises.json` exists and decodes:
   ```bash
   python3 -c "import json; print(len(json.load(open('fitbod/Resources/ExerciseSeed/exercises.json'))))"
   # must print an integer ≥ 800
   ```
2. `fitbod/Resources/ExerciseSeed/SEED_VERSION.txt` contains exactly `1` (with or without trailing newline; the importer's `trimmingCharacters` handles either):
   ```bash
   cat fitbod/Resources/ExerciseSeed/SEED_VERSION.txt | tr -d '[:space:]'
   # must print "1"
   ```
3. `fitbod/Resources/ExerciseSeed/SOURCE.md` records the upstream commit SHA (40-char hex).
4. The 3 new Swift files (`ExerciseDTO.swift`, `EquipmentMapper.swift`, `MuscleRegionMap.swift`) compile under `fitbod` target.
5. After Xcode registers the resources, `Bundle.main.url(forResource: "exercises", withExtension: "json")` returns a non-nil URL in tests (verified by `DTODecodingTests/decodesBundled` passing).
6. All 5 tests in `DTODecodingTests` pass:
   ```bash
   xcodebuild test -project fitbod.xcodeproj -scheme fitbod \
     -destination 'platform=iOS Simulator,name=iPhone 16' \
     -only-testing:fitbodTests/DTODecodingTests
   ```
   exits 0.

## Test Expectations

5 tests in `DTODecodingTests`:
- `decodesBundled` — bundle has the JSON, JSONDecoder parses it cleanly.
- `strengthFilter` — after filter, ≥600 exercises remain (typical ~800).
- `seedVersionBundled` — SEED_VERSION.txt is readable from the bundle and contains `1`.
- `equipmentMappingCovered` — parameterized test across 10 dataset values.
- `regionMapCovers17` — all 17 dataset muscle slugs map to a valid region; spot-check 3 known mappings (abdominals→core, quadriceps→lower, chest→upper).

**Run command:**
```bash
xcodebuild test -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:fitbodTests/DTODecodingTests
```

## Decisions Honored

- **C-9 (CONTEXT.md Area 1 — source dataset):** `yuhonas/free-exercise-db` JSON bundled in target. Unlicense (public domain). Filter at seed time, not at vendor time (keeps upstream traceability).
- **C-10 (CONTEXT.md Area 1 — no images bundled v1):** The `images` field on `ExerciseDTO` is decoded and persisted to `Exercise.imagePaths`, but the binary blobs are NOT vendored. Plan `02-02` writes path strings without trying to load binaries.
- **R-9 (RESEARCH § Don't Hand-Roll — DTO struct):** `Codable` lives on `ExerciseDTO` (plain struct), NEVER on `@Model Exercise`. SwiftData reference-type quirks are the documented footgun (PITFALLS #2 in RESEARCH).
- **R-10 (RESEARCH Open Q #3 — region taxonomy):** 17-slug → 3-region map per recommendation: upper (10 slugs), lower (6 slugs), core (1 slug).
- **R-11 (RESEARCH § Dataset Schema Mapping — equipment table):** Verbatim from research.

## Anti-Patterns Avoided

- **Not** putting `Codable` on `@Model Exercise` directly (PITFALLS #2 in RESEARCH).
- **Not** pre-filtering the dataset at vendor time — keeps byte-for-byte upstream traceability and shifts filter logic into the testable importer.
- **Not** bundling exercise image binaries — CONTEXT.md defers these (Phase 1.x polish or later). The `imagePaths: [String]` field on Exercise persists relative paths so a future seed can hydrate them.
- **Not** parking the version stamp inside the JSON itself — `SEED_VERSION.txt` is a plain-text companion file. Easier to diff, easier to bump.

## Out of Scope (handled by later plans)

- `ExerciseLibraryImporter @ModelActor` that consumes `[ExerciseDTO]` and writes `@Model Exercise` rows → plan `01-PLAN-02-02`.
- Idempotency check via `UserDefaults["exercise_seed_version"]` against `SEED_VERSION.txt` → plan `02-02`.
- Performance test (<2s seed) → plan `02-02`.
- Delta-migration when `SEED_VERSION.txt` bumps from N to N+1 → deferred (out of Phase 1 scope; documented in `SOURCE.md` refresh procedure).

## Commit Message Template

```
chore(01): vendor free-exercise-db JSON + ExerciseDTO/EquipmentMapper/RegionMap

- Resources/ExerciseSeed/exercises.json (~800 strength exercises after filter,
  ~1.5 MB raw; Unlicense / public domain; commit-pinned in SOURCE.md)
- Resources/ExerciseSeed/SEED_VERSION.txt = 1 (bumped to trigger re-seed)
- Resources/ExerciseSeed/SOURCE.md: provenance + refresh procedure
- ExerciseLibrary/ExerciseDTO.swift: Codable shape matching dataset rows
- ExerciseLibrary/EquipmentMapper.swift: dataset string → 9-case canonical
  Equipment enum (LIB-06); shouldImport() strength-category filter
- ExerciseLibrary/MuscleRegionMap.swift: 17-slug → 3-region (upper/lower/core)
  per RESEARCH Open Q #3
- fitbodTests/DTODecodingTests.swift: 5 tests including parameterized
  equipment mapping coverage
- pbxproj: ExerciseSeed/ added as bundle resources for fitbod target

Next plan (02-02) wires the @ModelActor importer.
```
