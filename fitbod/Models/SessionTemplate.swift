//
//  SessionTemplate.swift
//  fitbod
//
//  V7 rename of Routine.swift. This top-level @Model is the "plan" half
//  of the snapshot-and-decouple pattern (ARCHITECTURE.md Pattern 1).
//  Previously named `Routine`; renamed to `SessionTemplate` per spec §3
//  of the Phase 7 program-graph migration.
//
//  Historical shape: `SchemaV6.Routine` (nested in Persistence/SchemaV6.swift)
//  preserves the V6 field set verbatim for the V6→V7 custom migration
//  closure. This top-level `fitbod.SessionTemplate` is the V7 production
//  runtime entity; `SchemaV7.SessionTemplate` is a typealias pointing back
//  here.
//
//  The optional `block` relationship lets a template belong to a
//  periodization block when one is active. As of V7 this is a *one-sided*
//  relationship: the former inverse `Block.routines` was REMOVED (see
//  Block.swift), so no inverse keypath exists. The field is still
//  load-bearing — `SessionFactory` reads `template.block` to resolve the
//  scheduled `BlockPhase` (volume/intensity multipliers) at log time, and
//  `RoutineDraft` / `RoutineDuplicator` carry it across edits. V7's
//  Split→SplitSessionSlot graph is the new program structure; this direct
//  template→block link is retained for periodization resolution until the
//  Phase 8 unified resolver supersedes it.
//
//  Cascade: deleting a SessionTemplate cascades its SessionExerciseTemplate
//  lines (owned rows). SessionTemplate→Session is intentionally NOT a
//  SwiftData relationship — `Session.sourceRoutineID: UUID?` is a soft
//  reference so deleting a template never erases history (LIB-05 + PITFALLS #1).
//
//  Phase 3.1 (PIVOT-01) reshape: `intentRaw` + `progressionKindRaw` hoist
//  from `SessionExerciseTemplate` up to `SessionTemplate`. The two fields
//  persist as `String` with computed `intent: Intent` / `progressionKind:
//  ProgressionKind` accessors (FOUND-03 enum-as-String pattern) in the
//  extension at the bottom of this file. Defaults are `"strength"` /
//  `"double"` per D-03 / D-04 in 03.1-CONTEXT.md.
//

import Foundation
import SwiftData

@Model
public final class SessionTemplate {
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

    @Relationship(deleteRule: .cascade, inverse: \SessionExerciseTemplate.sessionTemplate)
    public var exercises: [SessionExerciseTemplate]? = []

    public init() {}
}

extension SessionTemplate {
    public var intent: Intent { Intent(rawValue: intentRaw) ?? .strength }
    public var progressionKind: ProgressionKind {
        ProgressionKind(rawValue: progressionKindRaw) ?? .double
    }
}
