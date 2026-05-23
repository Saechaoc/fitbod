//
//  SetEntry.swift
//  fitbod
//
//  Single logged set within a SessionExercise. The leaf of the
//  Session → SessionExercise → SetEntry cascade chain.
//
//  Both `isWarmup: Bool` and `setTypeRaw: String` are present. They are
//  not redundant: `isWarmup` is a hot-path flag (used by Phase 4 volume
//  rollups to exclude warmup sets from working-set counts), while
//  `setTypeRaw` is the full taxonomy (warmup / working / drop / failure /
//  rest_pause) that Phase 2 will branch on when logging back-off and drop
//  sets. Keeping both Day 1 avoids a Phase 2 schema migration.
//
//  Tempo strings follow the conventional "eccentric-pause-concentric-pause"
//  notation, e.g. "3-1-1-0". They are recorded as actuals here
//  (vs the prescribed value on SessionExercise.tempo) for post-session
//  review.
//

import Foundation
import SwiftData

@Model
public final class SetEntry {
    // Phase 6 plan 06-02 — additive #Index on completedAt. The PR detector,
    // weekly tonnage aggregator, and Phase 6 chart queries all fetch
    // SetEntry rows in completedAt order. #Index is non-persistent
    // metadata so no SchemaV7 bump is required (RESEARCH §"#Index addition").
    #Index<SetEntry>([\.completedAt])

    @Attribute(.unique) public var id: UUID = UUID()
    public var sessionExercise: SessionExercise? = nil
    public var orderIndex: Int = 0
    public var weight: Double = 0
    public var reps: Int = 0
    public var rpe: Double? = nil
    public var rir: Int? = nil
    public var restAfterSeconds: Int? = nil
    public var tempoActual: String? = nil
    public var notes: String? = nil
    public var isWarmup: Bool = false
    public var setTypeRaw: String = "working"
    public var completedAt: Date = Date.now
    public var partialReps: Int? = nil
    public var clusterSubRepsJoined: String? = nil
    public var isComplete: Bool = false
    public var wasManualOverride: Bool = false

    public init() {}
}

extension SetEntry {
    public var setType: SetType { SetType(rawValue: setTypeRaw) ?? .working }

    public var clusterSubReps: [Int] {
        get {
            guard let joined = clusterSubRepsJoined, !joined.isEmpty else { return [] }
            return joined.split(separator: ",").compactMap { Int($0) }
        }
        set {
            clusterSubRepsJoined = newValue.isEmpty ? nil : newValue.map(String.init).joined(separator: ",")
        }
    }
}
