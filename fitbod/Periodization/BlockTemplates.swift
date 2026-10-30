//
//  BlockTemplates.swift
//  fitbod
//
//  Static stock block templates for Phase 4. The values are Swift
//  literals, not bundled JSON, so changes remain easy to inspect in diff.
//
//  `BlockTemplates.catalog` is the one template catalog: Program's
//  template rows and New Block's preset pickers are built from it, in its
//  order, and show only the facts a template holds.
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

extension BlockTemplate {
    /// Weeks across every phase.
    public var totalWeeks: Int {
        phases.reduce(0) { $0 + $1.weeks }
    }

    /// The phases as Program's rows write them: "ACCUM 5 · INTNS 2 · DELOAD 1".
    public var phaseSummary: String {
        phases.map { "\($0.kind.shortLabel) \($0.weeks)" }.joined(separator: " · ")
    }
}

extension BlockPhaseKind {
    /// The short label Program's template rows give a phase, such as "ACCUM".
    public var shortLabel: String {
        switch self {
        case .accumulation:    return "ACCUM"
        case .intensification: return "INTNS"
        case .peak:            return "PEAK"
        case .realization:     return "REAL"
        case .deload:          return "DELOAD"
        }
    }
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

    /// One week of each phase, with the same per-kind multipliers as the
    /// templates above.
    public static let fiveThreeOne = BlockTemplate(
        name: "5/3/1 Cycle",
        phases: [
            (.accumulation, 1, 1.0, 0.75),
            (.intensification, 1, 0.85, 0.88),
            (.realization, 1, 0.6, 0.97),
            (.deload, 1, 0.5, 0.75),
        ]
    )

    public static let blank = BlockTemplate(name: "Blank Block", phases: [])

    /// The one template catalog, in the order Program and New Block list it.
    /// New Block adds BLANK (`blank`) ahead of it as its own choice.
    public static let catalog: [BlockTemplate] = [hypertrophy, generic, powerliftingPeak, fiveThreeOne]

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
