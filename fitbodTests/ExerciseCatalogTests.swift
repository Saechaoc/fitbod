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
              "Squat": { "equipment": "smith_machine" }
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
        #expect(entries.last?.equipmentRaw == Equipment.machine.rawValue)
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
        #expect(!upstream.contains { $0.id.hasPrefix("Panatta_") })
        #expect(additions.count == 28)
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
        }

        let climber = try #require(entries.first { $0.id == "Stairmaster" })
        #expect(climber.name == "Stair Climber")
        #expect(climber.aliasesJoined.split(separator: "|").contains("stairmaster"))
        #expect(climber.primaryMuscles.isEmpty)
        // Stretching and plyometrics stay out.
        #expect(!entries.contains { ["stretching", "plyometrics"].contains($0.category) })
    }
}
