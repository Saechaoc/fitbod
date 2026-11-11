//
//  ExerciseCatalog.swift
//  fitbod
//
//  The bundled exercise catalog as the importer writes it: the upstream
//  snapshot (`exercises.json`), the local rows (`additions.json`), the
//  curation overlay (`curation.json`) and the muscle credits
//  (`muscles.json`) resolved into one list.
//
//  It reads no store, so the seed checks read the same entries the importer
//  writes and cannot drift from it.
//

import Foundation

/// One muscle an exercise trains, and how much of each working set it
/// counts toward that muscle's weekly volume.
public struct MuscleCredit: Equatable, Sendable {
    public let slug: String
    /// "primary" or "secondary", as `ExerciseMuscleStimulus.role` stores it.
    public let role: String
    public let weight: Double
}

/// `muscles.json` (RM-065): the muscles each family trains, and the
/// variants that train them differently, keyed by catalog ID. A primary
/// muscle gets the whole set; a secondary one the weight given.
public struct MuscleCredits: Decodable, Sendable {
    public struct Profile: Decodable, Equatable, Sendable {
        public let primary: [String]
        public let secondary: [String: Double]
    }

    public var families: [String: Profile] = [:]
    public var exercises: [String: Profile] = [:]

    public init() {}
}

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
    public let familyName: String?
    public let variantLabel: String?
    public let brand: String?
    public let loadingRaw: String?
    /// Curation hides the row. The importer still lists it while a routine
    /// or a logged workout uses it.
    public let isHidden: Bool
    public let mechanicRaw: String
    public let forceRaw: String?
    public let levelRaw: String
    public let category: String
    public let instructions: [String]
    public let imagePaths: [String]
    /// The exercise's stimulus rows, primary muscles first. Empty for a
    /// cardio row, which adds no muscle volume.
    public let muscles: [MuscleCredit]

    public var primaryMuscles: [String] {
        muscles.filter { $0.role == "primary" }.map(\.slug)
    }
}

public enum ExerciseCatalog {

    /// Resolves the seed files into the rows the importer writes. A row
    /// outside the strength categories is in the catalog only when curation
    /// imports it.
    public static func entries(
        upstream: [ExerciseDTO], additions: [ExerciseDTO], curation: [String: ExerciseCuration],
        muscles: MuscleCredits = MuscleCredits()
    ) -> [CatalogEntry] {
        (upstream + additions).compactMap { dto in
            let curated = curation[dto.id]
            guard EquipmentMapper.shouldImport(category: dto.category) || curated?.imports == true else { return nil }
            let isCardio = dto.category.lowercased() == "cardio"
            let profile = muscles.exercises[dto.id] ?? curated?.family.flatMap { muscles.families[$0] }
            return CatalogEntry(
                id: dto.id,
                name: curated?.name ?? dto.name,
                equipmentRaw: curated?.equipment ?? EquipmentMapper.map(dto.equipment).rawValue,
                trackingRaw: curated?.tracking,
                aliasesJoined: (curated?.aliases ?? []).map { $0.lowercased() }.joined(separator: "|"),
                familyName: curated?.family,
                variantLabel: curated?.variant,
                brand: curated?.brand,
                loadingRaw: curated?.loading,
                isHidden: curated?.hidden ?? false,
                mechanicRaw: dto.mechanic ?? Mechanic.compound.rawValue,
                forceRaw: dto.force,
                levelRaw: dto.level,
                category: dto.category,
                instructions: dto.instructions,
                imagePaths: dto.images,
                muscles: isCardio ? [] : profile.map(credits) ?? upstreamCredits(dto)
            )
        }
    }

    private static func credits(_ profile: MuscleCredits.Profile) -> [MuscleCredit] {
        profile.primary.map { MuscleCredit(slug: $0, role: "primary", weight: 1) }
            + profile.secondary.sorted { $0.key < $1.key }
                .map { MuscleCredit(slug: $0.key, role: "secondary", weight: $0.value) }
    }

    /// A row `muscles.json` does not cover, such as a hidden row a workout
    /// still uses, keeps the upstream tags at 1.0 primary and 0.5 secondary.
    /// Upstream has one "shoulders" muscle; it reads as the delt the row's
    /// force works.
    static func upstreamCredits(_ dto: ExerciseDTO) -> [MuscleCredit] {
        let delt = switch dto.force {
        case "push": "front delts"
        case "pull": "rear delts"
        default: "side delts"
        }
        var credits: [MuscleCredit] = []
        for (slugs, role, weight) in [(dto.primaryMuscles, "primary", 1.0), (dto.secondaryMuscles, "secondary", 0.5)] {
            for raw in slugs {
                let slug = raw == "shoulders" ? delt : raw
                if !credits.contains(where: { $0.slug == slug }) {
                    credits.append(MuscleCredit(slug: slug, role: role, weight: weight))
                }
            }
        }
        return credits
    }

    /// The catalog bundled with the app.
    public static func bundled(in bundle: Bundle = .main) throws -> [CatalogEntry] {
        try entries(
            upstream: decode([ExerciseDTO].self, from: "exercises", in: bundle),
            additions: decode([ExerciseDTO].self, from: "additions", in: bundle),
            curation: decode([String: ExerciseCuration].self, from: "curation", in: bundle),
            muscles: decode(MuscleCredits.self, from: "muscles", in: bundle)
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
