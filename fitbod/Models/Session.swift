//
//  Session.swift
//  fitbod
//
//  Instance — a logged workout. The "instance" half of the snapshot-and-
//  decouple pattern. Phase 1 ships the schema; Phase 2 ships
//  `SessionFactory.start(routine:date:...)` which populates a Session by
//  copying the Routine's RoutineExercise list into SessionExercise rows.
//
//  `sourceRoutineID: UUID?` is a *soft* reference to the source template
//  (not a SwiftData relationship) so deleting the template never deletes
//  the history. `routineSnapshotName: String` records the template name
//  at session-start time, surviving subsequent template renames.
//
//  Phase 3.1 (PIVOT-02) reshape: `intentRaw` + `progressionKindRaw` are
//  hoisted from `SessionExercise` up to `Session` and snapshotted at
//  session-start time alongside `routineSnapshotName` / `sourceRoutineID`.
//  The two fields persist as `String` with computed `intent: Intent` /
//  `progressionKind: ProgressionKind` accessors (FOUND-03 enum-as-String
//  pattern) in the extension at the bottom of this file. Defaults are
//  `"strength"` / `"double"` per D-03 / D-04 in 03.1-CONTEXT.md.
//
//  Indexes per FOUND-04 + D-CD (03.1-CONTEXT.md):
//    - startedAt: calendar / history queries
//    - sourceRoutineID: "all sessions from this routine"
//    - intentRaw: intent-split history charts (Phase 4) — the index group
//      moved here from `SessionExercise` because intent is now a
//      per-session field. D-CD recommendation: YES for Session (history
//      queries hot), NO for Routine (routine list is small).
//
//  Cascade: deleting a Session cascades into SessionExercise (and through
//  SessionExercise → SetEntry, giving us the documented Session →
//  SessionExercise → SetEntry cascade chain).
//
//  Schema architecture (BLOCKER 3): `SchemaV3.Session` (nested in
//  `Persistence/SchemaV3.swift`) preserves the V3-shape field set — no
//  `intentRaw` / `progressionKindRaw` and no `#Index` — for the V3→V4
//  custom migration closure to fetch against. This top-level
//  `fitbod.Session` is the V4 shape and the production runtime entity;
//  `SchemaV4.Session` is a typealias pointing back here.
//

import Foundation
import SwiftData

@Model
public final class Session {
    #Index<Session>([\.startedAt], [\.sourceRoutineID], [\.intentRaw])

    @Attribute(.unique) public var id: UUID = UUID()
    public var startedAt: Date = Date.now
    public var completedAt: Date? = nil
    public var routineSnapshotName: String = ""
    public var sourceRoutineID: UUID? = nil
    public var block: Block? = nil
    public var notes: String? = nil
    public var totalDurationSeconds: Int? = nil
    public var intentRaw: String = "strength"
    public var progressionKindRaw: String = "double"

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    public var exercises: [SessionExercise]? = []

    // V7 additive: proper relationship replacing the soft UUID ref. nullify on template delete (default).
    public var template: SessionTemplate? = nil

    // V7 additive: which slot launched this workout; nil = ad-hoc.
    // Nullify inverse declared on SplitSessionSlot.sessions — SwiftData fires
    // the nullify rule from the managed to-many side; this plain var is the
    // to-one side (single-sided convention). NEVER cascade (Pitfall 6).
    public var slot: SplitSessionSlot? = nil

    // V7 additive: log-time snapshot of template name (freeze #1 insurance).
    public var templateName: String? = nil

    public init() {}
}

extension Session {
    public var intent: Intent { Intent(rawValue: intentRaw) ?? .strength }
    public var progressionKind: ProgressionKind {
        ProgressionKind(rawValue: progressionKindRaw) ?? .double
    }
}
