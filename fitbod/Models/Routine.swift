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
//  Phase 3.1 (PIVOT-01) reshape: `intentRaw` + `progressionKindRaw` hoist
//  from `RoutineExercise` up to `Routine`. The two fields persist as
//  `String` with computed `intent: Intent` / `progressionKind: ProgressionKind`
//  accessors (FOUND-03 enum-as-String pattern) in the extension at the
//  bottom of this file. Defaults are `"strength"` / `"double"` per D-03
//  / D-04 in 03.1-CONTEXT.md.
//
//  Schema architecture (BLOCKER 3): `SchemaV3.Routine` (nested in
//  `Persistence/SchemaV3.swift`) preserves the V3-shape field set — no
//  `intentRaw` / `progressionKindRaw` — for the V3→V4 custom migration
//  closure to fetch against. This top-level `fitbod.Routine` is the V4
//  shape and the production runtime entity; `SchemaV4.Routine` is a
//  typealias pointing back here.
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
    public var folderID: UUID? = nil
    public var intentRaw: String = "strength"
    public var progressionKindRaw: String = "double"

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    public var exercises: [RoutineExercise]? = []

    public init() {}
}

extension Routine {
    public var intent: Intent { Intent(rawValue: intentRaw) ?? .strength }
    public var progressionKind: ProgressionKind {
        ProgressionKind(rawValue: progressionKindRaw) ?? .double
    }
}
