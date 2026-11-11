//
//  ExerciseCatalog.swift
//  fitbod
//
//  The bundled exercise catalog as the importer writes it: the upstream
//  snapshot (`exercises.json`), the local rows (`additions.json`) and the
//  curation overlay (`curation.json`) resolved into one list.
//
//  It reads no store, so the seed checks read the same entries the importer
//  writes and cannot drift from it.
//

import Foundation

/// One catalog row with its curation applied.
public struct CatalogEntry: Equatable, Sendable {
    /// The row's stable ID, stored as `Exercise.externalID`.
    public let id: String
    public let name: String
    public let equipmentRaw: String
    /// Nil when the row tracks what its equipment implies.
    public let trackingRaw: String?
    /// Other names people use, lowercased and joined by "|".
    public let aliasesJoined: String
    public let mechanicRaw: String
    public let forceRaw: String?
    public let levelRaw: String
    public let category: String
    public let instructions: [String]
    public let imagePaths: [String]
    /// Empty for a cardio row, which adds no muscle volume.
    public let primaryMuscles: [String]
    public let secondaryMuscles: [String]
}

public enum ExerciseCatalog {

    /// Resolves the three seed files into the rows the importer writes. A
    /// row outside the strength categories is in the catalog only when
    /// curation imports it.
    public static func entries(
        upstream: [ExerciseDTO], additions: [ExerciseDTO], curation: [String: ExerciseCuration]
    ) -> [CatalogEntry] {
        (upstream + additions).compactMap { dto in
            let curated = curation[dto.id]
            guard EquipmentMapper.shouldImport(category: dto.category) || curated?.imports == true else { return nil }
            let isCardio = dto.category.lowercased() == "cardio"
            return CatalogEntry(
                id: dto.id,
                name: curated?.name ?? dto.name,
                equipmentRaw: curated?.equipment ?? EquipmentMapper.map(dto.equipment).rawValue,
                trackingRaw: curated?.tracking,
                aliasesJoined: (curated?.aliases ?? []).map { $0.lowercased() }.joined(separator: "|"),
                mechanicRaw: dto.mechanic ?? Mechanic.compound.rawValue,
                forceRaw: dto.force,
                levelRaw: dto.level,
                category: dto.category,
                instructions: dto.instructions,
                imagePaths: dto.images,
                primaryMuscles: isCardio ? [] : dto.primaryMuscles,
                secondaryMuscles: isCardio ? [] : dto.secondaryMuscles
            )
        }
    }

    /// The catalog bundled with the app.
    public static func bundled(in bundle: Bundle = .main) throws -> [CatalogEntry] {
        try entries(
            upstream: decode([ExerciseDTO].self, from: "exercises", in: bundle),
            additions: decode([ExerciseDTO].self, from: "additions", in: bundle),
            curation: decode([String: ExerciseCuration].self, from: "curation", in: bundle)
        )
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from name: String, in bundle: Bundle) throws -> Value {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw SeedError.bundledResourceMissing(name: "\(name).json")
        }
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch {
            throw SeedError.decodeFailed(underlying: error)
        }
    }
}
