//
//  Block.swift
//  fitbod
//
//  Periodization block — a multi-week training cycle organized as an
//  ordered sequence of `BlockPhase` rows (accumulation, intensification,
//  realization, deload). Phase 4 (`BlockBuilderView`) is the first
//  user-visible consumer; Phase 1 ships the schema in final shape so
//  Phase 4 can land without a schema migration (PITFALLS #1).
//
//  V7 additive fields (Phase 7 program-graph migration):
//    - split: Split? (nullify — optional, Phase 9 picker wires the UI)
//    - schedulingModeRaw / schedulingMode: computed accessor (FOUND-03)
//    - trainingDaysJoined / trainingDays: join-to-String [Int] accessor
//    - archivedConfigJSON: written once at block end (freeze #2); nil until done
//    - derivedStatus: computed ordering: completed → active → ready → draft
//
//  V7 removal:
//    - Block.routines (@Relationship inverse: \SessionTemplate.block) REMOVED.
//      Block→SessionTemplate was the V6 link; V7 uses Block→Split→SplitSessionSlot
//      instead. All consumers updated in 07-03.
//
//  Cascade rules per CONTEXT.md Area 4 / ARCHITECTURE.md:
//    - Block → BlockPhase: cascade (phases are owned by their block)
//    - Block → Session: inverse only (sessions outlive their block)
//    - Block → Split: nullify default (splits outlive their block reference)
//

import Foundation
import SwiftData

/// Lifecycle status of a periodization block.
/// Computed from block state — never persisted directly.
public enum BlockStatus: String, Sendable {
    case completed
    case active
    case ready
    case draft
}

/// The first piece a block still needs before it is ready, in the order
/// New Block names them.
public enum BlockMissingPiece: Equatable, Sendable {
    case name
    case phase
    case routine
    /// The routine has no sessions.
    case session
    /// Fixed weekly scheduling needs one training day per session; the
    /// count is the routine's session count.
    case trainingDays(Int)
}

@Model
public final class Block {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var startDate: Date = Date.now
    public var endDate: Date? = nil
    public var notes: String? = nil
    public var isActive: Bool = false
    public var reviewedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \BlockPhase.block)
    public var phases: [BlockPhase]? = []

    @Relationship(inverse: \Session.block)
    public var sessions: [Session]? = []

    // CR-02 carry-over — load-bearing legacy edge. SessionFactory still reads
    // SessionTemplate.block to resolve the scheduled BlockPhase (see SessionTemplate.swift).
    // This inverse exists ONLY to restore the nullify-on-block-delete contract that
    // Block.routines provided at baseline; it is NOT the new program-graph structure
    // (Block→Split→SplitSessionSlot is). Phase 8 removes both sides when SessionFactory
    // migrates off template.block.
    // Note: named `legacyTemplates` (NOT `routines`) — the public Block.routines name
    // stays permanently dead; this is an internal carry-over edge only.
    @Relationship(deleteRule: .nullify, inverse: \SessionTemplate.block)
    public var legacyTemplates: [SessionTemplate]? = []

    // V7 additive: optional split reference; nullify on split hard-delete (default).
    // No @Relationship decorator needed — SwiftData default is nullify for optional refs.
    // Inverse declared on Split.blocks.
    public var split: Split? = nil

    // V7 additive: scheduling mode. Default .rotation (spec §3).
    public var schedulingModeRaw: String = "rotation"

    // V7 additive: Calendar weekday numbers (1=Sun…7=Sat). Stored as comma-joined
    // String — established project pattern (see SetEntry.clusterSubRepsJoined).
    // Sorted once at write by the caller (Phase 8); accessor stores order verbatim.
    public var trainingDaysJoined: String = ""

    // V7 additive: written once at block end (freeze #2). Nil until block completes.
    public var archivedConfigJSON: String? = nil

    public init() {}
}

extension Block {

    /// Computed scheduling mode — raw String accessor (FOUND-03 / BlockPhase pattern).
    public var schedulingMode: SchedulingMode {
        get { SchedulingMode(rawValue: schedulingModeRaw) ?? .rotation }
        set { schedulingModeRaw = newValue.rawValue }
    }

    /// Computed weekday array — join-to-String [Int] accessor (SetEntry.clusterSubReps pattern).
    /// Getter guards !isEmpty (String default ""). Setter stores order verbatim.
    public var trainingDays: [Int] {
        get {
            guard !trainingDaysJoined.isEmpty else { return [] }
            return trainingDaysJoined.split(separator: ",").compactMap { Int($0) }
        }
        set {
            trainingDaysJoined = newValue.map(String.init).joined(separator: ",")
        }
    }

    /// Derived lifecycle status — ordered precedence switch per spec §3.
    /// completed (endDate != nil) → active (isActive) → ready (no missing piece) → draft
    public var derivedStatus: BlockStatus {
        if endDate != nil {
            return .completed
        }
        if isActive {
            return .active
        }
        return missingPiece == nil ? .ready : .draft
    }

    /// The first piece this block lacks before it is ready, or nil.
    public var missingPiece: BlockMissingPiece? {
        Block.firstMissingPiece(
            name: name,
            phaseCount: phases?.count ?? 0,
            sessionCount: split.map { $0.slots?.count ?? 0 },
            schedulingMode: schedulingMode,
            trainingDayCount: trainingDays.count
        )
    }

    /// The one readiness rule, shared by `derivedStatus` and New Block's
    /// SAVE AS READY: a name, at least one phase, and a routine with at
    /// least one session, whose training days match its sessions under
    /// fixed weekly scheduling. `sessionCount` is nil when no routine is
    /// attached. Returns the first piece missing, or nil when ready.
    public static func firstMissingPiece(
        name: String,
        phaseCount: Int,
        sessionCount: Int?,
        schedulingMode: SchedulingMode,
        trainingDayCount: Int
    ) -> BlockMissingPiece? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .name
        }
        if phaseCount < 1 {
            return .phase
        }
        guard let sessionCount else {
            return .routine
        }
        if sessionCount < 1 {
            return .session
        }
        if schedulingMode == .fixedWeekly && trainingDayCount != sessionCount {
            return .trainingDays(sessionCount)
        }
        return nil
    }
}
