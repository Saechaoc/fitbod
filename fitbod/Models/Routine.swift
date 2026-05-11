//
//  Routine.swift
//  fitbod
//
//  Reusable workout template — the "plan" half of the snapshot-and-decouple
//  pattern (ARCHITECTURE.md Pattern 1). The Phase 1 schema ships this in
//  final shape; Phase 2 (RoutineBuilderView) is the first user-visible
//  consumer.
//
//  The optional `block` relationship lets a routine belong to a
//  periodization block when one is active; the inverse declaration lives
//  on `Block.routines` so the inverse keypath chain is single-sided
//  (per CONTEXT.md Area 4 — explicit inverses everywhere).
//
//  Cascade: deleting a Routine cascades its RoutineExercise lines (owned
//  rows). Routine→Session is intentionally NOT a SwiftData relationship —
//  `Session.sourceRoutineID: UUID?` is a soft reference so deleting a
//  template never erases history (LIB-05 + PITFALLS #1).
//

import Foundation
import SwiftData

@Model
public final class Routine {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var notes: String? = nil
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var isArchived: Bool = false
    public var block: Block? = nil

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    public var exercises: [RoutineExercise]? = []

    public init() {}
}
