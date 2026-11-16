//
//  SessionTemplate.swift
//  fitbod
//
//  V7 rename of Routine.swift. This top-level @Model is the "plan" half
//  of the snapshot-and-decouple pattern (ARCHITECTURE.md Pattern 1).
//  Previously named `Routine`; renamed to `SessionTemplate` per spec §3
//  of the Phase 7 program-graph migration.
//
//  `SchemaV7.SessionTemplate` (the baseline schema) is a typealias for
//  this type.
//
//  The optional `block` relationship is a deprecated edge, kept stored until a
//  later schema version removes it with its inverse `Block.legacyTemplates`
//  (declared in Block.swift), which nullifies it when the block is deleted.
//  No training code reads it: a workout takes the active block, and the
//  session editor offers Block Periodized and Hybrid from the program graph,
//  Block→Split→SplitSessionSlot (RM-026). Only backup export and restore
//  carry it.
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
    // DEPRECATED: no training code reads or writes this edge (RM-026); backup export and
    // restore keep it. Removing it needs a later schema version.
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
