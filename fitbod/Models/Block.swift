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
//  Cascade rules per CONTEXT.md Area 4 / ARCHITECTURE.md:
//    - Block → BlockPhase: cascade (phases are owned by their block)
//    - Block → Routine: inverse only (deleting the block sets
//      `Routine.block = nil` via SwiftData's default nullify on a
//      non-cascade inverse)
//    - Block → Session: inverse only (same — sessions outlive their block)
//

import Foundation
import SwiftData

@Model
public final class Block {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var startDate: Date = Date.now
    public var endDate: Date? = nil
    public var notes: String? = nil
    public var isActive: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \BlockPhase.block)
    public var phases: [BlockPhase]? = []

    @Relationship(inverse: \Routine.block)
    public var routines: [Routine]? = []

    @Relationship(inverse: \Session.block)
    public var sessions: [Session]? = []

    public init() {}
}
