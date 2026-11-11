//
//  ExerciseCatalogTests.swift
//  fitbodTests
//
//  The bundled catalog as the importer writes it (RM-022): the upstream
//  snapshot, the local rows, the curation overlay and the muscle credits
//  (RM-065) resolved into one list, with no store.
//

import Foundation
import Testing
@testable import fitbod

@Suite("ExerciseCatalog")
struct ExerciseCatalogTests {

    private func row(_ id: String, category: String = "strength", equipment: String? = "machine") -> ExerciseDTO {
        ExerciseDTO(
            id: id, name: id.replacingOccurrences(of: "_", with: " "), level: "beginner", equipment: equipment,
            primaryMuscles: ["quadriceps"], secondaryMuscles: ["calves"], category: category
        )
    }

    private func curation(_ json: String) throws -> [String: ExerciseCuration] {
        try JSONDecoder().decode([String: ExerciseCuration].self, from: Data(json.utf8))
    }

    @Test("a row outside the strength categories is in the catalog only when curation imports it")
    func optInImport() throws {
        let entries = ExerciseCatalog.entries(
            upstream: [
                row("Squat"), row("Stairmaster", category: "cardio"),
                row("Skating", category: "cardio"), row("Calf_Stretch", category: "stretching"),
            ],
            additions: [row("Local_Press")],
            curation: try curation("""
            {
              "Stairmaster": {
                "import": true, "name": "Stair Climber", "equipment": "cardio_machine",
                "tracking": "duration_level", "aliases": ["StairMaster", "stair stepper"]
              },
              "Squat": { "equipment": "smith_machine" },
              "Local_Press": {
                "family": "Chest Press", "variant": "Panatta", "brand": "Panatta", "loading": "plate", "hidden": true
              }
            }
            """)
        )
        // Upstream rows first, then the local ones.
        #expect(entries.map(\.id) == ["Squat", "Stairmaster", "Local_Press"])

        let climber = try #require(entries.first { $0.id == "Stairmaster" })
        #expect(climber.name == "Stair Climber")
        #expect(climber.equipmentRaw == Equipment.cardioMachine.rawValue)
        #expect(climber.trackingRaw == Tracking.durationLevel.rawValue)
        #expect(climber.aliasesJoined == "stairmaster|stair stepper")
        // Cardio adds no muscle volume.
        #expect(climber.muscles.isEmpty)

        // A strength row keeps its name and, with no muscle credits, the
        // upstream muscles; curation may retag it.
        let squat = try #require(entries.first)
        #expect(squat.name == "Squat")
        #expect(squat.equipmentRaw == Equipment.smithMachine.rawValue)
        #expect(squat.trackingRaw == nil && squat.aliasesJoined.isEmpty)
        #expect(squat.muscles == [
            MuscleCredit(slug: "quadriceps", role: "primary", weight: 1),
            MuscleCredit(slug: "calves", role: "secondary", weight: 0.5),
        ])
        #expect(squat.familyName == nil && squat.variantLabel == nil && !squat.isHidden)

        let press = try #require(entries.last)
        #expect(press.equipmentRaw == Equipment.machine.rawValue)
        #expect(press.familyName == "Chest Press" && press.variantLabel == "Panatta")
        #expect(press.brand == MachineBrand.panatta.rawValue && press.loadingRaw == "plate")
        #expect(press.isHidden)
    }

    @Test("the bundled files resolve: one row per ID, curation names real rows and values, local rows stay local")
    func bundledCatalog() throws {
        let entries = try ExerciseCatalog.bundled()
        let ids = entries.map(\.id)
        #expect(Set(ids).count == ids.count, "an ID is used twice across exercises.json and additions.json")

        func decode<Value: Decodable>(_ type: Value.Type, _ name: String) throws -> Value {
            let url = try #require(Bundle.main.url(forResource: name, withExtension: "json"))
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        }
        let upstream = try decode([ExerciseDTO].self, "exercises")
        let additions = try decode([ExerciseDTO].self, "additions")
        // The refresh procedure overwrites exercises.json, so no local row
        // may live there.
        #expect(!upstream.contains { $0.id.hasPrefix("Panatta_") || $0.id.hasPrefix("local:") })
        let moved = additions.filter { $0.id.hasPrefix("Panatta_") || $0.id == "Single-Leg_Kneeling_Leg_Curl" }
        #expect(moved.count == 28, "the 28 local rows that left exercises.json must stay in additions.json")
        #expect(Set(additions.map(\.id)).isDisjoint(with: upstream.map(\.id)))

        let known = Set(upstream.map(\.id)).union(additions.map(\.id))
        for (id, entry) in try decode([String: ExerciseCuration].self, "curation") {
            #expect(known.contains(id), "curation.json names \(id), which no seed file has")
            #expect(ids.contains(id), "curation.json names \(id), which the catalog leaves out")
            if let raw = entry.equipment {
                #expect(Equipment(rawValue: raw) != nil, "\(id) has unknown equipment \(raw)")
            }
            if let raw = entry.tracking {
                #expect(Tracking(rawValue: raw) != nil, "\(id) has unknown tracking \(raw)")
            }
            if let raw = entry.brand {
                #expect(MachineBrand(rawValue: raw) != nil, "\(id) has unknown brand \(raw)")
            }
            if let raw = entry.loading {
                #expect(["plate", "stack"].contains(raw), "\(id) has unknown loading \(raw)")
            }
            #expect(entry.variant == nil || entry.family != nil, "\(id) has a variant but no family")
        }

        let climber = try #require(entries.first { $0.id == "Stairmaster" })
        #expect(climber.name == "Stair Climber")
        #expect(climber.aliasesJoined.split(separator: "|").contains("stairmaster"))
        #expect(climber.primaryMuscles.isEmpty)
        // Stretching stays out; a plyometric or cardio row comes in only by
        // name (`optInImport`).
        #expect(!entries.contains { $0.category == "stretching" })
    }

    @Test("the bundled catalog's visible rows: one per name, each in a family, a load only on known equipment, an alias in one family")
    func visibleRows() throws {
        let entries = try ExerciseCatalog.bundled()
        let visible = entries.filter { !$0.isHidden }
        func key(_ text: String) -> String { text.lowercased().folding(options: .diacriticInsensitive, locale: nil) }

        var names: [String: String] = [:]
        for entry in visible {
            if let other = names.updateValue(entry.id, forKey: key(entry.name)) {
                Issue.record("\(other) and \(entry.id) are both named \(entry.name)")
            }
            #expect(entry.familyName != nil, "\(entry.id) (\(entry.name)) is in no family")
            let equipment = Equipment(rawValue: entry.equipmentRaw) ?? .other
            let tracking = entry.trackingRaw.flatMap(Tracking.init) ?? .implied(by: equipment)
            #expect(equipment != .other || tracking != .weightReps, "\(entry.id) (\(entry.name)) tracks a load on unknown equipment")
        }
        // A hidden row a workout uses stays listed beside the visible ones.
        for entry in entries where entry.isHidden {
            #expect(names[key(entry.name)] == nil, "hidden \(entry.id) has the name of \(names[key(entry.name)] ?? "")")
        }

        let families = Set(entries.compactMap(\.familyName))
        let listed = Set(visible.compactMap(\.familyName))
        #expect(families == listed, "families with no visible row: \(families.subtracting(listed).sorted())")

        var aliasFamilies: [String: Set<String>] = [:]
        for entry in visible {
            for alias in entry.aliasesJoined.split(separator: "|") {
                aliasFamilies[key(String(alias)), default: []].insert(entry.familyName ?? entry.name)
            }
        }
        let familyByKey = Dictionary(listed.map { (key($0), $0) }) { first, _ in first }
        for (alias, owners) in aliasFamilies {
            #expect(owners.count == 1, "the alias \(alias) is in the families \(owners.sorted())")
            if let family = familyByKey[alias] {
                #expect(owners == [family], "the alias \(alias) names the family \(family) but is in \(owners.sorted())")
            }
        }
    }

    @Test("a variant's own muscle credits win over its family's; a row with neither keeps upstream's tags")
    func muscleCreditsPrecedence() throws {
        var credits = MuscleCredits()
        credits.families["Row"] = .init(primary: ["middle back", "lats"], secondary: ["biceps": 0.5])
        credits.exercises["Kroc_Row"] = .init(primary: ["lats"], secondary: ["middle back": 0.5])
        let entries = ExerciseCatalog.entries(
            upstream: [row("Cable_Row"), row("Kroc_Row"), row("Old_Row")],
            additions: [],
            curation: try curation("""
            { "Cable_Row": { "family": "Row" }, "Kroc_Row": { "family": "Row" }, "Old_Row": { "hidden": true } }
            """),
            muscles: credits
        )
        #expect(entries[0].muscles == [
            MuscleCredit(slug: "middle back", role: "primary", weight: 1),
            MuscleCredit(slug: "lats", role: "primary", weight: 1),
            MuscleCredit(slug: "biceps", role: "secondary", weight: 0.5),
        ])
        #expect(entries[1].muscles == [
            MuscleCredit(slug: "lats", role: "primary", weight: 1),
            MuscleCredit(slug: "middle back", role: "secondary", weight: 0.5),
        ])
        #expect(entries[2].muscles.map(\.slug) == ["quadriceps", "calves"])
    }

    @Test("upstream's one shoulders muscle reads as the delt the row's force works, once per row")
    func upstreamShouldersBecomeADelt() {
        func credits(force: String?, primary: [String], secondary: [String]) -> [MuscleCredit] {
            ExerciseCatalog.upstreamCredits(ExerciseDTO(
                id: "Lift", name: "Lift", force: force, level: "beginner",
                primaryMuscles: primary, secondaryMuscles: secondary, category: "strength"
            ))
        }
        #expect(credits(force: "push", primary: ["chest"], secondary: ["shoulders", "triceps"]) == [
            MuscleCredit(slug: "chest", role: "primary", weight: 1),
            MuscleCredit(slug: "front delts", role: "secondary", weight: 0.5),
            MuscleCredit(slug: "triceps", role: "secondary", weight: 0.5),
        ])
        #expect(credits(force: "pull", primary: ["shoulders"], secondary: []).map(\.slug) == ["rear delts"])
        #expect(credits(force: nil, primary: ["shoulders"], secondary: []).map(\.slug) == ["side delts"])
        // A muscle named twice keeps its first, stronger credit.
        #expect(credits(force: "push", primary: ["shoulders"], secondary: ["shoulders"]) == [
            MuscleCredit(slug: "front delts", role: "primary", weight: 1),
        ])
    }

    @Test("every listed row but cardio takes its muscles from muscles.json, which names real families, rows and muscles")
    func muscleCreditsCoverTheCatalog() throws {
        let url = try #require(Bundle.main.url(forResource: "muscles", withExtension: "json"))
        let credits = try JSONDecoder().decode(MuscleCredits.self, from: Data(contentsOf: url))
        let catalog = try ExerciseCatalog.bundled()
        let listed = catalog.filter { !$0.isHidden && $0.category.lowercased() != "cardio" }
        let muscles = Set(MuscleRegionMap.allSlugs)

        for entry in listed {
            #expect(
                credits.exercises[entry.id] != nil || entry.familyName.flatMap { credits.families[$0] } != nil,
                "\(entry.id) (\(entry.name)) has no muscle credits"
            )
        }
        let families = Set(listed.compactMap(\.familyName))
        for family in credits.families.keys {
            #expect(families.contains(family), "muscles.json credits \(family), which no listed row is in")
        }
        // A hidden row a workout still uses keeps its own credits, as the
        // Panatta rows hidden in seed version 9 do (RM-066).
        let ids = Set(catalog.map(\.id))
        for id in credits.exercises.keys {
            #expect(ids.contains(id), "muscles.json credits \(id), which no catalog row has")
        }
        for (name, profile) in credits.families.merging(credits.exercises, uniquingKeysWith: { $1 }) {
            #expect(!profile.primary.isEmpty, "\(name) has no primary muscle")
            #expect(Set(profile.primary).isDisjoint(with: profile.secondary.keys), "\(name) names a muscle twice")
            for slug in profile.primary + profile.secondary.keys where !muscles.contains(slug) {
                Issue.record("\(name) names the unknown muscle \(slug)")
            }
            #expect(profile.secondary.values.allSatisfy { $0 > 0 && $0 < 1 }, "\(name) has a secondary weight outside 0 to 1")
        }
    }
}
