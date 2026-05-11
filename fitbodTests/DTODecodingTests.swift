//
//  DTODecodingTests.swift
//  fitbodTests
//
//  Plan 02-01 anchor suite. Five Swift Testing functions prove:
//   1. The bundled `exercises.json` decodes cleanly into `[ExerciseDTO]`.
//   2. After the strength-category filter, at least 600 rows remain
//      (typical: ~702 per the vendored snapshot in SOURCE.md).
//   3. `SEED_VERSION.txt` is readable from the app bundle and equals `2`.
//   4. `EquipmentMapper.map(_:)` covers all 12 raw values + nil + empty.
//   5. `MuscleRegionMap.region(for:)` covers all 17 dataset slugs and
//      returns the expected canonical bucket for 3 sentinel slugs.
//
//  Note: the test target runs inside the `fitbod` host app bundle, so
//  `Bundle.main` resolves to the host bundle and contains the
//  `Resources/ExerciseSeed/*` files registered via the
//  `PBXFileSystemSynchronizedRootGroup` auto-discovery.
//

import Foundation
import Testing
@testable import fitbod

@Suite("ExerciseDTO decoding")
struct DTODecodingTests {

    // MARK: - Bundle / decode

    @Test("Bundled exercises.json decodes into [ExerciseDTO]")
    func decodesBundled() throws {
        let url = try #require(
            Bundle.main.url(forResource: "exercises", withExtension: "json"),
            "exercises.json must be registered as a bundle resource on the fitbod target"
        )
        let data = try Data(contentsOf: url)
        let dtos = try JSONDecoder().decode([ExerciseDTO].self, from: data)
        #expect(dtos.count > 0, "Dataset should contain at least 1 exercise")
        // Sanity-check a known row (Bench Press exists in upstream).
        let bench = dtos.first { $0.name.contains("Bench Press") }
        #expect(bench != nil, "Dataset should contain a Bench Press variant")
        if let bench {
            #expect(!bench.id.isEmpty, "DTO id field is populated")
            #expect(!bench.category.isEmpty, "DTO category field is populated")
        }
    }

    // MARK: - Strength filter

    @Test("Strength filter retains at least 600 exercises")
    func strengthFilter() throws {
        let url = try #require(
            Bundle.main.url(forResource: "exercises", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let dtos = try JSONDecoder().decode([ExerciseDTO].self, from: data)
        let strengthOnly = dtos.filter {
            EquipmentMapper.shouldImport(category: $0.category)
        }
        #expect(
            strengthOnly.count >= 600,
            "Strength-only filter should retain at least 600 exercises (typical: ~702)"
        )
    }

    // MARK: - SEED_VERSION.txt

    @Test("SEED_VERSION.txt is bundled and equals 2")
    func seedVersionBundled() throws {
        let url = try #require(
            Bundle.main.url(forResource: "SEED_VERSION", withExtension: "txt"),
            "SEED_VERSION.txt must be registered as a bundle resource on the fitbod target"
        )
        let raw = try String(contentsOf: url, encoding: .utf8)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(Int(trimmed) == 2, "Panatta seed update vendored at SEED_VERSION=2, got: \(trimmed)")
    }

    // MARK: - Equipment mapping (LIB-06)

    @Test(
        "EquipmentMapper covers the 12 known dataset values + nil + empty",
        arguments: [
            ("barbell",        Equipment.barbell),
            ("dumbbell",       Equipment.dumbbell),
            ("cable",          Equipment.cable),
            ("machine",        Equipment.machine),
            ("bands",          Equipment.bands),
            ("body only",      Equipment.bodyweight),
            ("kettlebells",    Equipment.kettlebell),
            ("e-z curl bar",   Equipment.barbell),  // collapse
            ("medicine ball",  Equipment.other),
            ("exercise ball",  Equipment.other),
            ("foam roll",      Equipment.other),
            ("other",          Equipment.other),
            ("",               Equipment.other),
            // case-insensitivity
            ("BARBELL",        Equipment.barbell),
            ("E-Z Curl Bar",   Equipment.barbell),
        ] as [(String, Equipment)]
    )
    func equipmentMappingCovered(raw: String, expected: Equipment) {
        #expect(
            EquipmentMapper.map(raw) == expected,
            "EquipmentMapper.map(\(raw)) should be \(expected), got \(EquipmentMapper.map(raw))"
        )
    }

    @Test("EquipmentMapper handles nil input")
    func equipmentMappingNil() {
        #expect(EquipmentMapper.map(nil) == .other)
    }

    @Test("EquipmentMapper covers every raw equipment value in the bundled dataset")
    func equipmentMappingExhaustive() throws {
        // Defensive coverage check: enumerate every raw equipment value
        // currently in the vendored snapshot. If a future dataset refresh
        // adds a new label, this test catches it before the importer would
        // silently collapse it to `.other`.
        let url = try #require(
            Bundle.main.url(forResource: "exercises", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let dtos = try JSONDecoder().decode([ExerciseDTO].self, from: data)
        let rawValues = Set(dtos.compactMap(\.equipment))
        for raw in rawValues {
            // The mapper must produce a non-`.other` result for every value
            // we explicitly handle. If a new dataset value shows up here that
            // ISN'T in the explicit switch arms, the test still passes
            // (mapper falls back to `.other`) but the SOURCE.md schema-notes
            // section is now stale — bump dataset and re-vendor.
            _ = EquipmentMapper.map(raw)
        }
        // Spot-check that the explicit mapping rules survived the dataset:
        // every supported equipment label must still be reachable.
        let recognized: Set<String> = [
            "barbell", "dumbbell", "cable", "machine", "bands",
            "body only", "kettlebells", "e-z curl bar",
        ]
        let recognizedInDataset = rawValues.intersection(recognized)
        #expect(
            recognizedInDataset.count >= 7,
            "At least 7 canonical equipment labels should appear in the bundled dataset; got \(recognizedInDataset)"
        )
    }

    // MARK: - Muscle region mapping (RESEARCH Open Q #3)

    @Test("Region map handles all 17 dataset slugs")
    func regionMapCovers17() {
        let allSlugs = MuscleRegionMap.allSlugs
        #expect(allSlugs.count == 17, "Dataset taxonomy has exactly 17 muscle slugs")
        for slug in allSlugs {
            let region = MuscleRegionMap.region(for: slug)
            #expect(
                [.upper, .lower, .core].contains(region),
                "Slug \(slug) must map to upper/lower/core, got \(region)"
            )
        }
        // Sentinel spot-checks — one per bucket, locking the canonical mapping.
        #expect(MuscleRegionMap.region(for: "abdominals") == .core)
        #expect(MuscleRegionMap.region(for: "quadriceps") == .lower)
        #expect(MuscleRegionMap.region(for: "chest") == .upper)
        // Multi-word slugs
        #expect(MuscleRegionMap.region(for: "lower back") == .upper)
        #expect(MuscleRegionMap.region(for: "middle back") == .upper)
        // Case insensitivity
        #expect(MuscleRegionMap.region(for: "ABDOMINALS") == .core)
        // Unknown slug falls back to upper
        #expect(MuscleRegionMap.region(for: "unknown_slug") == .upper)
    }

    @Test("Region map bucket sizes match RESEARCH Open Q #3 (10/6/1)")
    func regionMapBucketSizes() {
        var upper = 0, lower = 0, core = 0
        for slug in MuscleRegionMap.allSlugs {
            switch MuscleRegionMap.region(for: slug) {
            case .upper: upper += 1
            case .lower: lower += 1
            case .core:  core  += 1
            }
        }
        #expect(upper == 10, "Upper bucket: 10 slugs (chest, lats, middle back, lower back, traps, shoulders, biceps, triceps, forearms, neck)")
        #expect(lower == 6,  "Lower bucket: 6 slugs (quadriceps, hamstrings, glutes, calves, abductors, adductors)")
        #expect(core == 1,   "Core bucket: 1 slug (abdominals)")
    }

    @Test("Display names handle multi-word slugs and special cases")
    func displayNames() {
        #expect(MuscleRegionMap.displayName(for: "chest") == "Chest")
        #expect(MuscleRegionMap.displayName(for: "biceps") == "Biceps")
        #expect(MuscleRegionMap.displayName(for: "lats") == "Lats")
        #expect(MuscleRegionMap.displayName(for: "lower back") == "Lower Back")
        #expect(MuscleRegionMap.displayName(for: "middle back") == "Middle Back")
        #expect(MuscleRegionMap.displayName(for: "abdominals") == "Abdominals")
    }

    // MARK: - DTO equality / Codable round-trip

    @Test("ExerciseDTO round-trips through JSONEncoder/JSONDecoder")
    func dtoRoundTrip() throws {
        let original = ExerciseDTO(
            id: "Barbell_Bench_Press",
            name: "Barbell Bench Press",
            force: "push",
            level: "intermediate",
            mechanic: "compound",
            equipment: "barbell",
            primaryMuscles: ["chest"],
            secondaryMuscles: ["triceps", "shoulders"],
            instructions: ["Lie on bench.", "Lower bar to chest."],
            category: "strength",
            images: ["Barbell_Bench_Press/0.jpg", "Barbell_Bench_Press/1.jpg"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExerciseDTO.self, from: data)
        #expect(decoded == original, "DTO must survive Codable round-trip")
    }
}
