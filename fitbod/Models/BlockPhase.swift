//
//  BlockPhase.swift
//  fitbod
//
//  A phase within a periodization Block (accumulation / intensification /
//  realization / deload). `volumeMultiplier` and `intensityMultiplier`
//  are applied by Phase 3's `BlockPeriodizedStrategy` and `HybridStrategy`
//  to scale the prescribed weight/sets relative to the baseline.
//
//  Defaults represent the standard "accumulation" phase: 4 weeks,
//  multipliers at 1.0 (no scaling).
//
//  The phase kind is persisted as `nameRaw: String` (note: spec uses
//  `nameRaw` not `kindRaw` so the field reads literally as "phase name")
//  with the `kind` computed accessor below.
//

import Foundation
import SwiftData

@Model
public final class BlockPhase {
    @Attribute(.unique) public var id: UUID = UUID()
    public var block: Block? = nil
    public var orderIndex: Int = 0
    public var nameRaw: String = "accumulation"
    public var weeks: Int = 4
    public var volumeMultiplier: Double = 1.0
    public var intensityMultiplier: Double = 1.0
    public var notes: String? = nil

    public init() {}
}

extension BlockPhase {
    public var kind: BlockPhaseKind { BlockPhaseKind(rawValue: nameRaw) ?? .accumulation }
}
