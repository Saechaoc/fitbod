//
//  ExerciseCatalogTests.swift
//  fitbodTests
//
//  The bundled catalog as the importer writes it (RM-022): the upstream
//  snapshot, the local rows and the curation overlay resolved into one
//  list, with no store.
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
        #expect(climber.primaryMuscles.isEmpty && climber.secondaryMuscles.isEmpty)

        // A strength row keeps its name and muscles; curation may retag it.
        let squat = try #require(entries.first)
        #expect(squat.name == "Squat")
        #expect(squat.equipmentRaw == Equipment.smithMachine.rawValue)
        #expect(squat.trackingRaw == nil && squat.aliasesJoined.isEmpty)
        #expect(squat.primaryMuscles == ["quadriceps"] && squat.secondaryMuscles == ["calves"])
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

    @Test("every curated stimulus weight names a catalog row")
    func stimulusWeightsResolve() throws {
        let ids = Set(try ExerciseCatalog.bundled().map(\.id))
        let missing = StimulusWeightTable.overrides.keys.filter { !ids.contains($0) }.sorted()
        #expect(missing.isEmpty, "StimulusWeightTable names rows the catalog lacks: \(missing)")
    }
}
