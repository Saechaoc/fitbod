//
//  BlockTemplates.swift
//  fitbod
//
//  Static stock block templates for Phase 4. The values are Swift
//  literals, not bundled JSON, so changes remain easy to inspect in diff.
//

import Foundation

public struct BlockTemplate: Sendable {
    public let name: String
    public let phases: [(kind: BlockPhaseKind, weeks: Int, volumeMultiplier: Double, intensityMultiplier: Double)]

    public init(
        name: String,
        phases: [(kind: BlockPhaseKind, weeks: Int, volumeMultiplier: Double, intensityMultiplier: Double)]
    ) {
        self.name = name
        self.phases = phases
    }
}

extension BlockTemplate: Identifiable {
    public var id: String { name }
}

public enum BlockTemplates {
    public static let generic = BlockTemplate(
        name: "Generic Strength Meso",
        phases: [
            (.accumulation, 4, 1.0, 0.75),
            (.intensification, 2, 0.85, 0.88),
            (.realization, 1, 0.6, 0.97),
            (.deload, 1, 0.5, 0.75),
        ]
    )

    public static let hypertrophy = BlockTemplate(
        name: "Hypertrophy Meso",
        phases: [
            (.accumulation, 5, 1.0, 0.75),
            (.intensification, 2, 0.85, 0.88),
            (.deload, 1, 0.5, 0.75),
        ]
    )

    public static let powerliftingPeak = BlockTemplate(
        name: "Powerlifting Peak",
        phases: [
            (.accumulation, 3, 1.0, 0.75),
            (.intensification, 3, 0.85, 0.88),
            (.realization, 1, 0.6, 0.97),
            (.deload, 1, 0.5, 0.75),
        ]
    )

    public static let blank = BlockTemplate(name: "Blank Block", phases: [])

    public static func template(for kind: BlockPhaseKind) -> BlockTemplate {
        switch kind {
        case .accumulation:
            return generic
        case .intensification:
            return hypertrophy
        case .peak:
            return powerliftingPeak
        case .realization:
            return powerliftingPeak
        case .deload:
            return generic
        }
    }
}
