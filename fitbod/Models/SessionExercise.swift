//
//  SessionExercise.swift
//  fitbod
//
//  Per-exercise logged data within a Session. Fields here are *snapshots*
//  of the parent RoutineExercise — copied at session-start time, never
//  re-read from the template (PITFALLS #1).
//
//  `prescribedWeight: Double?` is populated by Phase 3's
//  ProgressionStrategy based on the user's history. It is the weight the
//  user is *prescribed* for the session, distinct from the weight they
//  actually log (which lives on SetEntry).
//
//  Phase 3.1 (PIVOT-03) reshape: `intentRaw` and `progressionKindRaw` are
//  hoisted OUT of this type up to `Session`. Plan 02 of Phase 3.1 deletes
//  the field declarations + computed accessors AND the `#Index<SessionExercise>([\.intentRaw])`
//  macro from the V4 shape; the analogous index group moves to
//  `Session.intentRaw` (see Session.swift).
//
//  Schema architecture (BLOCKER 3): `SchemaV3.SessionExercise` (nested
//  in `Persistence/SchemaV3.swift`) preserves the V3-shape field set —
//  including the now-removed `intentRaw` / `progressionKindRaw` fields
//  AND the V3-shape `#Index` semantics — so the V3→V4 custom migration
//  closure can fetch the per-exercise values and compute the
//  mode-of-children backfill onto V4 `Session.intentRaw`. This top-level
//  `fitbod.SessionExercise` is the V4 shape and the production runtime
//  entity; `SchemaV4.SessionExercise` is a typealias pointing back here.
//
//  Cascade rules (CONTEXT.md Area 4):
//    - SessionExercise → SetEntry: cascade (sets are owned)
//    - Exercise → SessionExercise: **nullify** (LIB-05). The `exercise`
//      field is a plain optional relationship with no forward declaration
//      from Exercise; SwiftData's default rule for non-owning inverses is
//      nullify, so deleting a library entry sets `exercise = nil` on
//      historical session rows. This preserves the history while
//      surfacing "your library exercise was removed" via the nil read.
//      The cascade-test in 01-03 (`CascadeRuleTests/
//      exerciseToSessionExerciseNullifies`) proves the behavior.
//

import Foundation
import SwiftData

@Model
public final class SessionExercise {
    @Attribute(.unique) public var id: UUID = UUID()
    public var session: Session? = nil
    public var exercise: Exercise? = nil
    public var orderIndex: Int = 0

    public var targetSets: Int = 3
    public var targetRepsLow: Int = 8
    public var targetRepsHigh: Int = 12
    public var targetRPE: Double? = nil
    public var targetRIR: Int? = nil
    public var prescribedRestSeconds: Int = 120
    public var tempo: String? = nil
    public var tracksTempo: Bool = false
    public var tracksPartialReps: Bool = false
    public var prescribedWeight: Double? = nil
    public var pinnedNote: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    public var sets: [SetEntry]? = []

    public init() {}
}
