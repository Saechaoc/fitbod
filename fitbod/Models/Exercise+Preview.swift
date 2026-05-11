//
//  Exercise+Preview.swift
//  fitbod
//
//  Test/preview convenience factory for `Exercise`. Used by both
//  `PreviewModelContainer.make()` (production target) and the
//  Swift Testing suites in `fitbodTests/` (via `@testable import fitbod`).
//
//  Keeps the canonical-name normalisation and the
//  `primaryMuscleSlugsJoined` "|chest|triceps|" encoding in a single
//  place so previews and tests agree on the wire format the importer
//  (Phase 1 Wave 2) will also emit.
//
//  This is purely additive — no production code path consumes
//  `previewSample`. The function lives in the production target rather
//  than the test target so `#Preview` blocks (which compile in the
//  production target) can reach it without a `@testable` ceremony.
//

import Foundation

extension Exercise {
    /// Builds an `Exercise` populated with deterministic field values
    /// suitable for previews and unit tests. The `canonicalName` is
    /// derived from `name` using the same lowercase + diacritic-fold
    /// transform the importer applies.
    public static func previewSample(
        name: String,
        equipment: Equipment,
        mechanic: Mechanic,
        primaryMuscleSlugs: [String] = [],
        isCustom: Bool = false
    ) -> Exercise {
        let ex = Exercise(
            name: name,
            canonicalName: name.lowercased().folding(
                options: .diacriticInsensitive,
                locale: .current
            ),
            equipmentRaw: equipment.rawValue,
            mechanicRaw: mechanic.rawValue,
            category: "strength",
            isCustom: isCustom
        )
        // Match the importer's pipe-bracketed convention so
        // `.contains("|chest|")` predicate filtering works (Pitfall 3
        // denormalised muscle filter — see Exercise.swift header).
        ex.primaryMuscleSlugsJoined = "|" + primaryMuscleSlugs.joined(separator: "|") + "|"
        return ex
    }
}
