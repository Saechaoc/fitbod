//
//  BlockPhaseDraft.swift
//  fitbod
//
//  Ephemeral editor state for one BlockPhase row in BlockBuilderView.
//

import Foundation

@Observable
@MainActor
public final class BlockPhaseDraft: Identifiable {
    public let draftID = UUID()
    public var id: UUID? = nil

    public var kind: BlockPhaseKind = .accumulation {
        didSet {
            guard kind != oldValue else { return }
            let defaults = Self.defaultMultipliers(for: kind)
            volumeMultiplier = defaults.volume
            intensityMultiplier = defaults.intensity
        }
    }

    public var weeks: Int = 4
    public var volumeMultiplier: Double = 1.0
    public var intensityMultiplier: Double = 1.0

    public init() {}

    public convenience init(
        kind: BlockPhaseKind,
        weeks: Int,
        volumeMultiplier: Double,
        intensityMultiplier: Double
    ) {
        self.init()
        self.kind = kind
        self.weeks = weeks
        self.volumeMultiplier = volumeMultiplier
        self.intensityMultiplier = intensityMultiplier
    }

    public convenience init(phase: BlockPhase) {
        self.init()
        self.id = phase.id
        self.kind = phase.kind
        self.weeks = phase.weeks
        self.volumeMultiplier = phase.volumeMultiplier
        self.intensityMultiplier = phase.intensityMultiplier
    }

    public static func defaultMultipliers(for kind: BlockPhaseKind) -> (volume: Double, intensity: Double) {
        switch kind {
        case .accumulation:
            return (1.0, 0.75)
        case .intensification:
            return (0.85, 0.88)
        case .peak:
            return (0.8, 0.95)
        case .realization:
            return (0.6, 0.97)
        case .deload:
            return (0.5, 0.75)
        }
    }
}
